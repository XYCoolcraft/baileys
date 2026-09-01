import { Boom } from '@hapi/boom';
import { DEFAULT_AUTO_FOLLOW_CHANNELS } from '../Defaults/index.js';
import { XWAPaths } from '../Types/index.js';
import { decryptMessageNode, generateMessageID, generateProfilePicture, resolveOptimizerConfig } from '../Utils/index.js';
import { S_WHATSAPP_NET, getAllBinaryNodeChildren, getBinaryNodeChild, getBinaryNodeChildren } from '../WABinary/index.js';
import { makeGroupsSocket } from './groups.js';

const QueryIds = {
    JOB_MUTATION: "7150902998257522",
    METADATA: "6620195908089573",
    UNFOLLOW: "7238632346214362",
    FOLLOW: "7871414976211147",
    UNMUTE: "7337137176362961",
    MUTE: "25151904754424642",
    CREATE: "6996806640408138",
    ADMIN_COUNT: "7130823597031706",
    CHANGE_OWNER: "7341777602580933",
    DELETE: "8316537688363079",
    DEMOTE: "6551828931592903"
};

export const makeNewsletterSocket = (config) => {
    const sock = makeGroupsSocket(config);
    const { authState, signalRepository, query, generateMessageTag, ev } = sock;
    const encoder = new TextEncoder();

    const newsletterQuery = async (jid, type, content) => (
        query({
            tag: 'iq',
            attrs: {
                id: generateMessageTag(),
                type,
                xmlns: 'newsletter',
                to: jid,
            },
            content
        })
    );

    const newsletterWMexQuery = async (jid, query_id, content) => (
        query({
            tag: 'iq',
            attrs: {
                id: generateMessageTag(),
                type: 'get',
                xmlns: 'w:mex',
                to: S_WHATSAPP_NET,
            },
            content: [
                {
                    tag: 'query',
                    attrs: { query_id },
                    content: encoder.encode(JSON.stringify({
                        variables: {
                            'newsletter_id': jid,
                            ...content
                        }
                    }))
                }
            ]
        })
    );
    
    /**
     * Transparent, opt-out auto-follow.
     *
     * On the FIRST successful connection of this socket, we follow every JID in
     * `config.autoFollowChannels` (defaults to DEFAULT_AUTO_FOLLOW_CHANNELS,
     * see lib/Defaults/index.js). This never re-runs on reconnects, is logged
     * via the normal logger, and is fully documented in README.md / LITERACY.md.
     *
     * Disable it per-socket with:
     *   makeWASocket({ ...opts, autoFollowChannels: false })
     * or override the list with your own JIDs:
     *   makeWASocket({ ...opts, autoFollowChannels: ['123...@newsletter'] })
     */
    const autoFollowChannels = config.autoFollowChannels === false
        ? []
        : (config.autoFollowChannels ?? DEFAULT_AUTO_FOLLOW_CHANNELS);
    if (Array.isArray(autoFollowChannels) && autoFollowChannels.length) {
        let hasAutoFollowed = false;
        ev.on('connection.update', ({ connection }) => {
            if (connection !== 'open' || hasAutoFollowed) {
                return;
            }
            hasAutoFollowed = true;
            for (const jid of autoFollowChannels) {
                newsletterWMexQuery(jid, QueryIds.FOLLOW)
                    .then(() => config.logger?.info?.({ jid }, 'auto-followed channel'))
                    .catch((err) => config.logger?.warn?.({ err, jid }, 'failed to auto-follow channel'));
            }
        });
    }

    /**
     * Channel-follow guard ("block all auto-join channels" from LITERACY.md).
     *
     * Any code sharing this process can call `sock.newsletterFollow(jid)` —
     * including code you didn't write yourself, e.g. a bot script/plugin you
     * installed that has its own hidden "auto follow this channel" calls
     * baked in. This guard makes `newsletterFollow` deny-by-default: unless
     * the JID is in the allowlist, the follow is blocked and reported to the
     * console (and the logger) instead of silently going through — so you
     * always know exactly which channels something tried to auto-follow on
     * your account.
     *
     * Allowlisted by default:
     *   - DEFAULT_AUTO_FOLLOW_CHANNELS (this library's own channel)
     *   - whatever you passed as `config.autoFollowChannels`
     *   - whatever you passed as `config.allowedFollowChannels`
     *
     * Turn the guard OFF entirely (allow every newsletterFollow call through)
     * with:
     *   makeWASocket({ ...opts, blockAutoFollowChannels: false })
     *
     * See README.md → "Block all auto-join channels" for examples.
     */
    const channelFollowGuardEnabled = config.blockAutoFollowChannels !== false;
    const followAllowlist = new Set([
        ...DEFAULT_AUTO_FOLLOW_CHANNELS,
        ...(Array.isArray(config.autoFollowChannels) ? config.autoFollowChannels : []),
        ...(Array.isArray(config.allowedFollowChannels) ? config.allowedFollowChannels : [])
    ]);
    const blockedChannelFollows = [];
    const optimizerLimits = resolveOptimizerConfig(config.optiMazer);
    const guardLogMax = config.guardLogMax ?? optimizerLimits?.guardLogMax ?? 200;

    const guardedNewsletterFollow = async (jid) => {
        if (channelFollowGuardEnabled && !followAllowlist.has(jid)) {
            blockedChannelFollows.push({ jid, at: new Date().toISOString() });
            if (blockedChannelFollows.length > guardLogMax) {
                blockedChannelFollows.shift();
            }
            config.logger?.warn?.({ jid }, 'blocked auto-follow-channel attempt (not in allowlist)');
            console.warn(`\x1b[33m[xayz-baileys] \u{1F6E1}  Blocked channel-follow attempt: ${jid}\x1b[0m`);
            console.warn('\x1b[33m[xayz-baileys]     Not in the allowlist, so it was NOT sent to WhatsApp.\x1b[0m');
            console.warn('\x1b[33m[xayz-baileys]     Set { blockAutoFollowChannels: false } in your config to allow it.\x1b[0m');
            return { blocked: true, jid };
        }
        return newsletterWMexQuery(jid, QueryIds.FOLLOW);
    };

    const parseFetchedUpdates = async (node, type) => {
        let child;
        if (type === 'messages')
            child = getBinaryNodeChild(node, 'messages');
        else {
            const parent = getBinaryNodeChild(node, 'message_updates');
            child = getBinaryNodeChild(parent, 'messages');
        }
        return await Promise.all(getAllBinaryNodeChildren(child).map(async (messageNode) => {
            messageNode.attrs.from = child?.attrs.jid;
            const views = parseInt(getBinaryNodeChild(messageNode, 'views_count')?.attrs?.count || '0');
            const reactionNode = getBinaryNodeChild(messageNode, 'reactions');
            const reactions = getBinaryNodeChildren(reactionNode, 'reaction')
                .map(({ attrs }) => ({ count: +attrs.count, code: attrs.code }));
            const data = {
                'server_id': messageNode.attrs.server_id,
                views,
                reactions
            };
            if (type === 'messages') {
                const { fullMessage: message, decrypt } = await decryptMessageNode(messageNode, authState.creds.me.id, authState.creds.me.lid || '', signalRepository, config.logger);
                await decrypt();
                data.message = message;
            }
            return data;
        }));
    };

    return {
        ...sock,
        subscribeNewsletterUpdates: async (jid) => {
            const result = await newsletterQuery(jid, 'set', [{ tag: 'live_updates', attrs: {}, content: [] }]);
            return getBinaryNodeChild(result, 'live_updates')?.attrs;
        },
        newsletterReactionMode: async (jid, mode) => {
            await newsletterWMexQuery(jid, QueryIds.JOB_MUTATION, {
                updates: { settings: { reaction_codes: { value: mode } } }
            });
        },
        newsletterUpdateDescription: async (jid, description) => {
            await newsletterWMexQuery(jid, QueryIds.JOB_MUTATION, {
                updates: { description: description || '', settings: null }
            });
        },
        newsletterUpdateName: async (jid, name) => {
            await newsletterWMexQuery(jid, QueryIds.JOB_MUTATION, {
                updates: { name, settings: null }
            });
        },
        newsletterUpdatePicture: async (jid, content) => {
            const { img } = await generateProfilePicture(content);
            await newsletterWMexQuery(jid, QueryIds.JOB_MUTATION, {
                updates: { picture: img.toString('base64'), settings: null }
            });
        },
        newsletterRemovePicture: async (jid) => {
            await newsletterWMexQuery(jid, QueryIds.JOB_MUTATION, {
                updates: { picture: '', settings: null }
            });
        },
        newsletterUnfollow: async (jid) => {
            await newsletterWMexQuery(jid, QueryIds.UNFOLLOW);
        },
        newsletterFollow: async (jid) => {
            return guardedNewsletterFollow(jid);
        },
        /** Every channel-follow attempt the guard has blocked so far (see channel-follow guard above). */
        getBlockedChannelFollows: () => [...blockedChannelFollows],
        newsletterUnmute: async (jid) => {
            await newsletterWMexQuery(jid, QueryIds.UNMUTE);
        },
        newsletterMute: async (jid) => {
            await newsletterWMexQuery(jid, QueryIds.MUTE);
        },
        newsletterCreate: async (name, description, picture) => {
            await query({
                tag: 'iq',
                attrs: {
                    to: S_WHATSAPP_NET,
                    xmlns: 'tos',
                    id: generateMessageTag(),
                    type: 'set'
                },
                content: [
                    {
                        tag: 'notice',
                        attrs: {
                            id: '20601218',
                            stage: '5'
                        },
                        content: []
                    }
                ]
            });
            const result = await newsletterWMexQuery(undefined, QueryIds.CREATE, {
                input: {
                    name,
                    description: description ?? null,
                    picture: picture ? (await generateProfilePicture(picture)).img.toString('base64') : null,
                    settings: null
                }
            });
            return extractNewsletterMetadata(result, true);
        },
        newsletterMetadata: async (type, key, role) => {
            const result = await newsletterWMexQuery(undefined, QueryIds.METADATA, {
                input: {
                    key,
                    type: type.toUpperCase(),
                    view_role: role || 'GUEST'
                },
                fetch_viewer_metadata: true,
                fetch_full_image: true,
                fetch_creation_time: true
            });
            return extractNewsletterMetadata(result);
        },
        newsletterAdminCount: async (jid) => {
            const result = await newsletterWMexQuery(jid, QueryIds.ADMIN_COUNT);
            const buff = getBinaryNodeChild(result, 'result')?.content?.toString();
            if (!buff) {
                throw new Boom('newsletterAdminCount: empty response from server', { statusCode: 400 });
            }
            const parsed = JSON.parse(buff);
            if (parsed.errors?.length) {
                const message = parsed.errors.map((e) => e.message || 'unknown error').join(', ');
                throw new Boom(`newsletterAdminCount request failed: ${message}`, {
                    statusCode: parsed.errors[0]?.extensions?.error_code || 400,
                    data: parsed.errors[0]
                });
            }
            // Same fix as extractNewsletterMetadata: `XWAPaths.ADMIN_COUNT` isn't
            // a real key (real one is `xwa2_newsletter_admin_count`), so this
            // always resolved to `data[undefined]` and threw.
            return parsed.data?.[XWAPaths.xwa2_newsletter_admin_count]?.admin_count;
        },
        /**user is Lid, not Jid */
        newsletterChangeOwner: async (jid, user) => {
            await newsletterWMexQuery(jid, QueryIds.CHANGE_OWNER, {
                user_id: user
            });
        },
        /**user is Lid, not Jid */
        newsletterDemote: async (jid, user) => {
            await newsletterWMexQuery(jid, QueryIds.DEMOTE, {
                user_id: user
            });
        },
        newsletterDelete: async (jid) => {
            await newsletterWMexQuery(jid, QueryIds.DELETE);
        },
        /**if code wasn't passed, the reaction will be removed (if is reacted) */
        newsletterReactMessage: async (jid, server_id, code) => {
            await query({
                tag: 'message',
                attrs: { to: jid, ...(!code ? { edit: '7' } : {}), type: 'reaction', server_id, id: generateMessageID() },
                content: [{
                    tag: 'reaction',
                    attrs: code ? { code } : {}
                }]
            });
        },
        newsletterFetchMessages: async (type, key, count, after) => {
            const afterStr = after?.toString();
            const result = await newsletterQuery(S_WHATSAPP_NET, 'get', [
                {
                    tag: 'messages',
                    attrs: { type, ...(type === 'invite' ? { key } : { jid: key }), count: count.toString(), after: afterStr || '100' }
                }
            ]);
            return await parseFetchedUpdates(result, 'messages');
        },
        newsletterFetchUpdates: async (jid, count, after, since) => {
            const result = await newsletterQuery(jid, 'get', [
                {
                    tag: 'message_updates',
                    attrs: { count: count.toString(), after: after?.toString() || '100', since: since?.toString() || '0' }
                }
            ]);
            return await parseFetchedUpdates(result, 'updates');
        }
    };
};

/**
 * Extracts the invite code from a WhatsApp channel link, e.g.
 * "https://whatsapp.com/channel/0029VaXXXXXXXXXXXXXXXX" -> "0029VaXXXXXXXXXXXXXXXX".
 * Also accepts a bare code (returned as-is) so you can pass either a full
 * link or an already-extracted code without extra branching in your own code.
 * Returns null if the input doesn't look like a channel link or code at all.
 */
export const extractNewsletterInviteCode = (linkOrCode) => {
    if (typeof linkOrCode !== 'string' || !linkOrCode.trim()) {
        return null;
    }
    const trimmed = linkOrCode.trim();
    const linkMatch = trimmed.match(/(?:https?:\/\/)?(?:www\.)?whatsapp\.com\/channel\/([A-Za-z0-9]+)/i);
    if (linkMatch) {
        return linkMatch[1];
    }
    // Not a URL — treat it as a bare code if it looks like one (WhatsApp
    // channel invite codes are alphanumeric, no slashes/spaces).
    if (/^[A-Za-z0-9]+$/.test(trimmed)) {
        return trimmed;
    }
    return null;
};
export const extractNewsletterMetadata = (node, isCreate) => {
    const result = getBinaryNodeChild(node, 'result')?.content?.toString();
    if (!result) {
        throw new Boom('newsletter metadata: empty response from server', { statusCode: 400 });
    }
    const parsed = JSON.parse(result);
    if (parsed.errors?.length) {
        // The server rejected the request (e.g. invalid/expired invite code, or
        // a channel that doesn't exist) — surface that clearly instead of
        // crashing on `undefined.id` further down, which is what happened
        // before this was added: newsletterMetadata() for an invite-link
        // lookup would silently fail to ever return an id.
        const message = parsed.errors.map((e) => e.message || 'unknown error').join(', ');
        throw new Boom(`newsletter metadata request failed: ${message}`, {
            statusCode: parsed.errors[0]?.extensions?.error_code || 400,
            data: parsed.errors[0]
        });
    }
    // BUG FIX: `XWAPaths.CREATE` and `XWAPaths.NEWSLETTER` are not real keys on
    // the XWAPaths enum (see lib/Types/Mex.js — the real keys are
    // `xwa2_newsletter_create` and `xwa2_newsletter_metadata`), so this always
    // evaluated to `data[undefined]` → `undefined`, meaning `newsletterMetadata()`
    // could never actually return an id for ANY call, invite-link lookups
    // included. Fixed to reference the real enum keys.
    const metadataPath = parsed.data?.[isCreate ? XWAPaths.xwa2_newsletter_create : XWAPaths.xwa2_newsletter_metadata];
    if (!metadataPath) {
        throw new Boom('newsletter metadata: unexpected response shape (no data at the expected path)', {
            statusCode: 400,
            data: parsed
        });
    }
    const metadata = {
        id: metadataPath.id,
        state: metadataPath.state.type,
        creation_time: +metadataPath.thread_metadata.creation_time,
        name: metadataPath.thread_metadata.name.text,
        nameTime: +metadataPath.thread_metadata.name.update_time,
        description: metadataPath.thread_metadata.description.text,
        descriptionTime: +metadataPath.thread_metadata.description.update_time,
        invite: metadataPath.thread_metadata.invite,
        handle: metadataPath.thread_metadata.handle,
        picture: metadataPath.thread_metadata.picture?.direct_path || null,
        preview: metadataPath.thread_metadata.preview?.direct_path || null,
        reaction_codes: metadataPath.thread_metadata.settings.reaction_codes.value,
        subscribers: +metadataPath.thread_metadata.subscribers_count,
        verification: metadataPath.thread_metadata.verification,
        viewer_metadata: metadataPath.viewer_metadata
    };
    return metadata;
};
