import { DEFAULT_CONNECTION_CONFIG } from '../Defaults/index.js';
import { OptiMazer } from '../Utils/optimizer.js';
import { makeCommunitiesSocket } from './communities.js';
import { makeAIGroupsSocket } from './aigroups.js';
import { makeGraphQLSocket } from './graphql.js';
import { makeInteropSocket } from './interop.js';
import { makeManagedAccountSocket } from './managed-account.js';
import { makePrivacySocket } from './privacy.js';
import { makeRegistrationSocket } from './registration.js';
import { attachTextRouter } from './text-router.js';
import { wrapSocket } from '../antiban.js';
import { makeMessageBuilderSocket } from './message-builder.js';
// export the last socket layer
const makeWASocket = (config) => {
    const newConfig = {
        ...DEFAULT_CONNECTION_CONFIG,
        ...config
    };
    let sock = makeCommunitiesSocket(newConfig);
    // Extra first-party feature layers (account privacy/registration, Meta AI
    // groups, cross-app interop, GraphQL-based account/payments surface),
    // each a `sock => sock` wrapper adding methods on top of what's already
    // there — see LITERACY.md for what each one covers.
    sock = makeAIGroupsSocket(sock);
    sock = makePrivacySocket(sock);
    sock = makeRegistrationSocket(sock);
    sock = makeManagedAccountSocket(sock);
    sock = makeInteropSocket(sock);
    sock = makeGraphQLSocket(sock);
    // AntiBan — ON by default (preset 'aggressive'), disable with `antiban: false`.
    // Wraps sendMessage with rate-limiting/warm-up/health checks and hooks
    // connection/message events for disconnect & retry tracking.
    // See lib/antiban.js. Access at runtime via sock.antiban (stats, destroy, etc)
    // — sock.antiban is undefined only if you explicitly opt out.
    if (newConfig.antiban !== false) {
        sock = wrapSocket(sock, newConfig.antiban && newConfig.antiban !== true ? newConfig.antiban : 'aggressive');
    }
    // Extra send-helper convenience methods (sendActionPoll, sendAlbumMessage,
    // sendCarouselMessage, forwardMessage, sendVCard, broadcastMessage, ...).
    // Placed after the antiban wrap above so these helpers' internal
    // sendMessage() calls go through antiban when it's enabled. See
    // lib/Socket/message-builder.js.
    sock = makeMessageBuilderSocket(sock);
    // Optional convenience router: sock.onText/hears/command. Doesn't touch
    // anything unless you actually register a route.
    sock = attachTextRouter(sock);
    // optiMazer — opt-in resource-usage tuning, OFF unless `optiMazer` is set
    // (true or a config object). See lib/Utils/optimizer.js and README.md.
    if (newConfig.optiMazer) {
        const optimizerConfig = typeof newConfig.optiMazer === 'object' ? newConfig.optiMazer : {};
        const optimizer = new OptiMazer(optimizerConfig).attach(sock);
        sock = { ...sock, optiMazer: optimizer, getOptimizerStats: () => optimizer.getStats() };
    }
    return sock;
};
export default makeWASocket;
//# sourceMappingURL=index.js.map