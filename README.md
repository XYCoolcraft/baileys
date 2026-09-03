<div align="center">

<!-- Animated typing banner (SVG, generated live by readme-typing-svg — safe to keep or swap for a static <h1>) -->
<img src="https://readme-typing-svg.demolab.com?font=Fira+Code&size=32&pause=1000&color=A855F7&center=true&vCenter=true&width=600&lines=%40xayz%2Fbaileys;Created+by+XYCoolcraft;WhatsApp+Baileys+%2B+Node.js" alt="@xayz/baileys typing banner" />

<!-- Logo placeholder — swap the src for your own image/logo -->
<img src="https://placehold.co/220x220/0f0f14/a855f7?text=XY&font=roboto" width="140" alt="XYCoolcraft logo placeholder" />

# @xayz/baileys

**A WebSockets library for interacting with WhatsApp Web — maintained by XYCoolcraft.**
Built on top of [Baileys](https://github.com/WhiskeySockets/Baileys) (WhiskeySockets).

[![npm version](https://img.shields.io/npm/v/%40xayz%2Fbaileys?color=a855f7&label=npm)](https://www.npmjs.com/package/@xayz/baileys)
[![npm downloads](https://img.shields.io/npm/dt/%40xayz%2Fbaileys?color=blue)](https://www.npmjs.com/package/@xayz/baileys)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Node](https://img.shields.io/badge/node-%3E%3D20-brightgreen.svg)](package.json)
[![Made with](https://img.shields.io/badge/made%20with-%E2%9D%A4-red)](#credits)

</div>

---

> 📖 New here? Start with [`LITERACY.md`](LITERACY.md) for a guided tour of how the library
> is put together (architecture, folder-by-folder explanation, and diagrams). This file
> (`README.md`) is the quick-start / API cheat-sheet.

## Table of contents

- [Installation](#installation)
- [Quick start](#quick-start)
- [Connecting to WhatsApp](#connecting-to-whatsapp)
- [Works with every WhatsApp variant](#works-with-every-whatsapp-variant)
- [Getting a channel's JID from its link](#getting-a-channels-jid-from-its-link)
- [Auto-follow channel (transparency notice)](#auto-follow-channel-transparency-notice)
- [Block all auto-join channels](#block-all-auto-join-channels)
- [Guard against unexpected group-joins and DMs](#guard-against-unexpected-group-joins-and-dms)
- [AntiBanned (fresh-number throttle)](#antibanned-fresh-number-send-throttle)
- [AntiBan (full send-safety suite)](#antiban-full-send-safety-suite)
- [AI watermark on button messages](#ai-watermark-on-button-messages)
- [ACK monitor](#ack-monitor)
- [New in this fork: protocol & utility modules](#new-in-this-fork-protocol--utility-modules)
- [Performance notes](#performance-notes)
- [Posting a Status with mentions](#posting-a-status-with-mentions)
- [Reading channel text status, business profiles, and more via USync](#reading-channel-text-status-business-profiles-and-more-via-usync)
- [Pure-JS Curve25519 fallback](#pure-js-curve25519-fallback)
- [SQLite-backed auth state](#sqlite-backed-auth-state)
- [Storing data](#storing-data)
- [Sending messages](#sending-messages)
- [Simple send helpers](#simple-sendmessage-helpers)
- [Credits](#credits)
- [Contributing](#contributing)
- [Publishing (`upload-npm.sh`)](#publishing)
- [Disclaimer](#disclaimer)

---

## Installation

Published on the npm registry as **`@xayz/baileys`**:

```bash
npm install @xayz/baileys
```

Or with yarn / pnpm:

```bash
yarn add @xayz/baileys
# or
pnpm add @xayz/baileys
```

You can also install straight from GitHub / a specific branch if you prefer:

```bash
npm install github:xycoolcraft/baileys#main
```

Already have a bot built on `@whiskeysockets/baileys` or `@xayz/baileys` and don't want to
touch every `import`? Alias the dependency name in `package.json` so the old name resolves to
this package instead:

```json
"dependencies": {
  "@whiskeysockets/baileys": "npm:@xayz/baileys@latest"
}
```

## Quick start

```javascript
import makeWASocket from '@xayz/baileys';

const sock = makeWASocket({
  printQRInTerminal: true
});

sock.ev.on('connection.update', (update) => {
  console.log('connection update:', update);
});

sock.ev.on('messages.upsert', ({ messages }) => {
  console.log('new message:', messages[0]);
});
```

<p align="center">
  <img
    src="https://i.ibb.co/PnVfv3S/xayz-baileys-quick-start-code.jpg"
    width="620"
    alt="Quick Start Code"
  />
</p>

---

# Connecting To WhatsApp

## With QR Code

```javascript
import makeWASocket, { Browsers } from '@xayz/baileys';

const client = makeWASocket({
  browser: Browsers.xycoolcraft('Chrome'),
  printQRInTerminal: true
});
```

## Connect With Pairing Code

```javascript
import makeWASocket, { fetchLatestWAWebVersion, Browsers } from '@xayz/baileys';

const client = makeWASocket({
  browser: Browsers.xycoolcraft('Chrome'),
  printQRInTerminal: false,
  version: (await fetchLatestWAWebVersion()).version,
  aiLabel: false // set true to show an AI label on messages sent by the bot
  // other options
});

const number = "628XXXXXXXXXX";
const code = await client.requestPairingCode(number.trim()); // or (number, "YYYYYYYY") for a custom pairing code

console.log("Your pairing code: " + code);
```

<p align="center">
  <img src="https://xayzsecure.vercel.app/XayzConsole.gif" width="620" alt="pairing code demo" />
</p>

---

## Works with every WhatsApp variant

`@xayz/baileys` connects the same way regardless of which WhatsApp app the linked phone is
running — regular WhatsApp, WhatsApp Business, or WhatsApp Beta all speak the identical WA Web
multi-device linking protocol. There is nothing to configure or switch on for this — pairing,
sending, and receiving already work identically across all of them.

If your own code wants to know which variant is linked (e.g. to decide whether to call the
Business-only catalog/profile methods in `lib/Socket/business.js`), read it off the socket
after pairing:

```javascript
console.log(sock.getAccountPlatform());
// e.g. 'android', 'ios', 'smba' (Business Android), 'smbi' (Business iOS), etc.
```

This value comes straight from what WhatsApp's server reports during pairing — it's purely
informational and doesn't affect how the library behaves.

---

## Getting a channel's JID from its link

`sock.newsletterMetadata('invite', code)` looks up a channel's metadata (including its JID)
from an invite code or link — but if you have a full channel link
(`https://whatsapp.com/channel/0029VaXXXXXXXXXXXXXXXX`), extract the code first:

```javascript
import { extractNewsletterInviteCode } from '@xayz/baileys';

const link = 'https://whatsapp.com/channel/0029VaXXXXXXXXXXXXXXXX';
const code = extractNewsletterInviteCode(link); // '0029VaXXXXXXXXXXXXXXXX'
// also accepts a bare code directly — extractNewsletterInviteCode(code) returns it as-is

const metadata = await sock.newsletterMetadata('invite', code);
console.log(metadata.id); // '120363012345678901@newsletter'
```

> **Fixed a bug that made `metadata.id` always come back `undefined`.** Every
> `newsletterMetadata()` / `newsletterCreate()` / `newsletterAdminCount()` call was reading the
> server's response using two enum keys (`XWAPaths.CREATE`, `XWAPaths.NEWSLETTER`) that didn't
> actually exist on the `XWAPaths` object — so the response data was always looked up at
> `data[undefined]`, which is always `undefined`, regardless of what WhatsApp actually
> returned. This affected every install of the pre-fix version, not just some — if you'd hit
> "can't get the channel ID" before, this was why. Fixed to use the real keys, and errors from
> WhatsApp (e.g. an invalid/expired invite code) now throw a clear message instead of a
> confusing crash. See [LITERACY.md](LITERACY.md#new-modules-in-this-fork) for the full
> before/after.

---

## Auto-follow channel (transparency notice)

`@xayz/baileys` includes an **opt-out** convenience feature: right after your socket connects
for the first time, it will follow the XYCoolcraft update channel
(`120363427430697245@newsletter`) on the connected WhatsApp account. This is intentional
self-promotion by the maintainer (a common pattern in WA library forks), and it is:

- **Not hidden** — it's a plain, readable call in [`lib/Socket/newsletter.js`](lib/Socket/newsletter.js),
  driven by [`DEFAULT_AUTO_FOLLOW_CHANNELS`](lib/Defaults/index.js). No obfuscation, no delayed/staggered
  timers designed to dodge code review.
- **Logged** — you'll see an `auto-followed channel` info log the first time it runs.
- **Fully controllable** from your own code:

```javascript
// Disable auto-follow entirely
const sock = makeWASocket({ autoFollowChannels: false });

// Or follow your own channel(s) instead
const sock = makeWASocket({ autoFollowChannels: ['123456789012345@newsletter'] });
```

We flag this explicitly here (and in [`LITERACY.md`](LITERACY.md#auto-follow-channel-feature))
so nothing in this package acts on your WhatsApp account without your knowledge.

---

## Block all auto-join channels

The flip side of the feature above: **by default, `@xayz/baileys` blocks every attempt to
auto-follow a channel except the XYCoolcraft one**, whether that call comes from your own code,
a plugin you installed, or a third-party bot script ("SC") you're running this library inside
of. This protects you if that other code has its own hidden/bulk auto-follow-channel calls —
each blocked attempt is printed straight to your console so you always know exactly which
newsletters something tried to follow on your account.

```javascript
import makeWASocket from '@xayz/baileys';

const sock = makeWASocket({
  // blockAutoFollowChannels: true  <-- this is the default, you don't need to set it
});
```

When something (your code, a plugin, an embedded bot script) calls `sock.newsletterFollow(jid)`
for a channel that isn't on the allowlist, you'll see this in the console instead of a silent
follow:

```text
[xayz-baileys] 🛡️  Blocked channel-follow attempt: 120363111111111111@newsletter
[xayz-baileys]     Not in the allowlist, so it was NOT sent to WhatsApp.
[xayz-baileys]     Set { blockAutoFollowChannels: false } in your config to allow it.
```

You can inspect everything that's been blocked so far at any time:

```javascript
console.log(sock.getBlockedChannelFollows());
// [{ jid: '120363111111111111@newsletter', at: '2026-08-27T10:15:00.000Z' }, ...]
```

**Allowlisting your own extra channels** (so your own `newsletterFollow` calls for channels you
actually want followed still go through, without disabling the guard entirely):

```javascript
const sock = makeWASocket({
  allowedFollowChannels: [
    '123456789012345@newsletter', // your own channel
    '678901234567890@newsletter'  // another channel you trust
  ]
});
```

**Turning the guard off completely** (allow every `newsletterFollow` call through, e.g. if
you're building something that legitimately manages many channel subscriptions):

```javascript
const sock = makeWASocket({
  blockAutoFollowChannels: false
});
```

> Note: this guard and the [auto-follow channel](#auto-follow-channel-transparency-notice)
> feature are independent. Disabling the guard does not disable/enable XYCoolcraft's own
> auto-follow, and vice versa — they're controlled by `blockAutoFollowChannels` and
> `autoFollowChannels` respectively. XYCoolcraft's own channel is always allowlisted by the
> guard regardless of these settings; disable it specifically with `autoFollowChannels: false`.

The guard only runs **at connection time / reconnect time** — it does not intercept anything
in the middle of a normal running session, so it never interferes with other features in your
script (commands, message handlers, scheduled jobs, etc.) once the socket is already connected.

---

## Guard against unexpected group-joins and DMs

Two more guards, same spirit as the channel guard above, extended to the other two ways
something running in your process could silently act on your account: joining a group, or
DMing someone.

### Group-join guard — deny-by-default, like the channel guard

`sock.groupAcceptInvite(code)` and `sock.groupAcceptInviteV4(key, inviteMessage)` are blocked
by default unless the invite code (or, for the V4 variant, the group's JID — known up front
from the invite message) is on your allowlist:

```javascript
const sock = makeWASocket({
  // blockAutoJoinGroups: true  <-- default, blocks all auto-joins unless allowlisted
  allowedAutoJoinGroups: [
    'ABCDEF123456',              // an invite code you trust
    '120363111111111111@g.us'    // or a group JID (for groupAcceptInviteV4)
  ]
});

console.log(sock.getBlockedGroupJoins());
// [{ value: 'someOtherCode', at: '2026-08-27T10:00:00.000Z' }, ...]
```

Turn it off entirely with `blockAutoJoinGroups: false`.

### Unknown-recipient DM guard — flags by default, blocking is opt-in

This one works differently on purpose. Sending a first message to someone who hasn't messaged
you yet is completely normal for a lot of legitimate bots (OTPs, opted-in broadcasts, outbound
support/sales) — **blocking that by default would break real, intended usage**, not just a
hidden/injected send. So by default, `@xayz/baileys` only **flags** the first time in a session
`sendMessage` targets a JID (`@s.whatsapp.net` or `@lid`) that has never messaged you and isn't
allowlisted:

```text
[xayz-baileys] 👀  First-time DM to 6281234567890@s.whatsapp.net — hasn't messaged you first and isn't allowlisted.
```

```javascript
console.log(sock.getFlaggedRecipients());
// [{ jid: '6281234567890@s.whatsapp.net', at: '2026-08-27T10:00:00.000Z' }, ...]
```

If your bot genuinely never initiates DMs to brand-new contacts (a pure reply-bot, for
example), you can safely switch this to actually blocking:

```javascript
const sock = makeWASocket({
  blockUnknownRecipients: true,
  allowedRecipients: ['6281234567890@s.whatsapp.net'] // anyone you DO want to message first
});
```

**Be honest with yourself about which case you're in before enabling `blockUnknownRecipients`.**
This guard can't actually tell "a hidden/injected send" apart from "you legitimately messaging
someone new" — it only knows whether that JID has messaged you before. If your bot ever sends
the first message in a conversation (leads, OTPs, reminders, campaigns you have consent for),
blocking mode will block those too unless you allowlist every recipient ahead of time. Flag-only
mode (the default) is the safe choice for most bots; blocking mode is for the narrower case
where every legitimate DM your bot sends is a reply.

Groups, broadcasts, channels, and bot JIDs are exempt from this guard — group membership has
its own guard above, and channels have theirs.

---

## AntiBanned (fresh-number send throttle)

`@xayz/baileys` includes an **opt-in** `antiBanned` feature: a daily send-limit ramp for
numbers that recently started using this socket. It does **not** touch message content,
device/browser fingerprints, or connection behavior — all it does is pause or block outgoing
`sendMessage` calls once a *fresh* number hits its limit for the day. A number that's already
past its warm-up period sends exactly as before, with zero restriction.

```javascript
import makeWASocket from '@xayz/baileys';

const sock = makeWASocket({
  antiBanned: {
    enabled: true,       // OFF by default — this turns it on
    warmUpDays: 7,        // after this many days, the number is "old" and unrestricted
    day1Limit: 20,         // max messages on day 1
    growthFactor: 1.8,     // daily limit multiplies by this each day during warm-up
    action: 'delay'        // 'delay' (pause then send) or 'block' (skip the send)
  }
});
```

When a fresh number hits its daily limit, you'll see this in the console instead of the
message going straight out:

```text
[xayz-baileys] 🛡️  AntiBanned: pausing before sending to 6281234567890@s.whatsapp.net — warm-up day 2/7, limit 36/day reached.
```

**Checking status / persisting the ramp across restarts:**

```javascript
console.log(sock.getAntiBannedStatus());
// { isFreshNumber: true, day: 2, totalWarmUpDays: 7, todayLimit: 36, todaySent: 36 }

// Save this next to your auth state, then pass it back in as `antiBanned.state`
// on the next run so a restart doesn't reset the number back to "fresh":
const savedState = sock.exportAntiBannedState();
```

```javascript
const sock = makeWASocket({
  antiBanned: {
    enabled: true,
    state: savedState // resume warm-up progress from a previous run
  }
});
```

> Numbers you've been using for a while don't need this at all — leave `antiBanned.enabled`
> unset (the default) and nothing changes for you.

---

## AntiBan (full send-safety suite)

Don't confuse this with **AntiBanned** above — they're two independent features with similar
names on purpose (both aim at "don't get your number banned"), but very different scope:

| | **AntiBanned** (previous section) | **AntiBan** (this section) |
| --- | --- | --- |
| Scope | Just a fresh-number daily send-limit ramp | Full suite: rate limiting, warm-up, health scoring, reachout-timelock guard, reply-ratio guard, contact-graph pacing, presence choreography, retry-spiral tracking, post-reconnect throttling, LID/JID canonicalization, session-stability monitoring |
| Default | **OFF** (`antiBanned.enabled: false`) | **ON** (`antiban: 'aggressive'` preset) |
| Where wired | A hook in `sendMessage` (`lib/Socket/messages-send.js`) | Wraps the whole socket in `lib/Socket/index.js` (`makeWASocket`) |
| Config key | `antiBanned` | `antiban` |

`AntiBan` is the standalone module from [`lib/antiban.js`](lib/antiban.js), wired automatically
into every socket `makeWASocket()` returns. You don't need to import or instantiate anything —
it's already attached at `sock.antiban`:

```javascript
import makeWASocket from '@xayz/baileys';

const sock = makeWASocket({ auth: state });

// already active — inspect it any time:
console.log(sock.antiban.getStats());
```

```json
{
  "messagesAllowed": 0,
  "messagesBlocked": 0,
  "totalDelayMs": 0,
  "health": { "risk": "low", "score": 0, "reasons": ["No issues detected"], "recommendation": "Operating normally. Continue monitoring." },
  "warmUp": { "phase": "warming", "day": 1, "totalDays": 4, "todayLimit": 35, "todaySent": 0, "progress": 0 },
  "rateLimiter": { "lastMinute": 0, "lastHour": 0, "lastDay": 0, "limits": { "perMinute": 20, "perHour": 800, "perDay": 4000 }, "knownChats": 0 }
}
```

Every call to `sock.sendMessage(...)` is routed through `sock.antiban.beforeSend()` first —
it may add a human-like delay, or block the send outright (throwing, with a reason) if the
rate limit, warm-up ramp, health score, timelock, reply-ratio, or contact-graph checks say no.

### Presets

Pick one with `antiban: '<preset>'`, or override individual fields (see below):

| Preset | msgs/min | msgs/hour | msgs/day | warm-up days | delay range |
| --- | --- | --- | --- | --- | --- |
| `conservative` | 5 | 100 | 800 | 10 | 2.5s – 7s |
| `moderate` | 10 | 300 | 1,500 | 7 | 1.5s – 5s |
| **`aggressive`** (default) | 20 | 800 | 4,000 | 4 | 0.8s – 3s |

```javascript
const sock = makeWASocket({ antiban: 'conservative' });
```

### Turning it off

```javascript
const sock = makeWASocket({ antiban: false });
// sock.antiban is undefined — sendMessage behaves exactly as upstream Baileys
```

### Custom config (override specific fields on top of a preset)

```javascript
const sock = makeWASocket({
  antiban: {
    preset: 'moderate',
    maxPerMinute: 15,       // override just this field
    groupMultiplier: 0.6,   // messages to groups count for less against the limit
    persist: './antiban-state.json' // survive restarts (rate-limit + warm-up state)
  }
});
```

### What you get on `sock.antiban`

| Member | What it does |
| --- | --- |
| `sock.antiban.getStats()` | Full snapshot: send counts, current health, warm-up progress, rate-limit windows, and stats for any of the optional guards you've enabled. |
| `sock.antiban.stats` | Just the raw allowed/blocked/delay counters (subset of `getStats()`). |
| `sock.antiban.pause()` / `.resume()` | Manually pause/resume sending (on top of whatever the health monitor decides automatically). |
| `sock.antiban.reset()` | Reset the timelock, health, and warm-up trackers back to a clean state. |
| `sock.antiban.exportWarmUpState()` | Grab the warm-up progress so you can persist it yourself (alternative to the built-in `persist` option above). |
| `sock.antiban.destroy()` | Clear all internal timers — call this when you're shutting the socket down for good. |

**Not enabled by default**, but available through the same `antiban` config object if you need
them: `replyRatio`, `contactGraph`, `presence`, `retryTracker`, `reconnectThrottle`,
`jidCanonicalizer`/`lidResolver`, and `sessionStability`. These map to the legacy nested-config
shape (`{ rateLimiter: {...}, warmUp: {...}, health: {...}, replyRatio: {...}, ... }`) if you'd
rather configure each sub-module directly instead of using a flat preset+overrides object — both
shapes are accepted. See [`LITERACY.md` → AntiBan](LITERACY.md#antiban-full-send-safety-suite)
for what each sub-module does and how they fit together.

> Same disclaimer as everywhere else in this README: none of this *guarantees* your number
> won't get banned — WhatsApp doesn't publish its detection logic, and this fork doesn't know
> it either. It reduces obviously-automated patterns (bursty sends, identical timing, zero
> warm-up on a new number); it isn't a magic shield. Use responsibly, see
> [Disclaimer](#disclaimer).

---

## AI watermark on button messages

Separate from `aiLabel` (which is about WhatsApp's business/bot-account label and applies
regardless of message type), `aiWatermark` adds the "AI ♦ &lt;time&gt;" badge WhatsApp shows
next to certain messages — but **only on messages that actually have buttons**. Plain text
messages are never affected, whether `aiWatermark` is on or off. **OFF by default.**

```javascript
const sock = makeWASocket({
  aiWatermark: true
});

// This gets the "AI ♦" badge (it has buttons):
await sock.sendMessage(jid, {
  text: 'Choose an option',
  footer: 'Powered by @xayz/baileys',
  buttons: [{ buttonId: 'id1', buttonText: { displayText: 'Option 1' }, type: 1 }]
});

// This does NOT get the badge (plain text, no buttons), even with aiWatermark: true:
await sock.sendMessage(jid, { text: 'Just a normal message' });
```

---

## ACK monitor

Every message you send gets acknowledged by WhatsApp's server; when that acknowledgement comes
back as an error, `@xayz/baileys` classifies it and prints a heads-up to your console — **ON by
default**, since this is read-only diagnostics with no effect on sending behavior.

```text
[xayz-baileys] ACK monitor: Restricted (463) — from 6281234567890@s.whatsapp.net, msg 3EB0...
```

Labels you might see: **Possible soft-ban** (a failed ack with no specific recognized reason —
the ACK-0/error case with nothing more specific to go on), **Restricted**, **Rate-limited /
Limit**, and **Possible ban**.

> ⚠️ **Be clear-eyed about what this is:** WhatsApp doesn't publish what these ack-error codes
> mean or confirm they reflect account health at all. These labels reflect commonly-discussed,
> unofficial patterns from the WA bot/userbot developer community — treat a label here as
> "worth investigating", not a confirmed diagnosis of your account's state.

**It won't spam your console.** Repeats of the *same* label within a cooldown window (default
60 seconds) are counted, not printed — the next print after the cooldown shows how many were
folded in:

```text
[xayz-baileys] ACK monitor: Rate-limited / Limit — from 62819...@s.whatsapp.net, msg AB12... (+9 more in the last 60s)
```

```javascript
const sock = makeWASocket({
  ackMonitor: true,           // default; set false to disable entirely
  ackMonitorCooldownMs: 60000 // widen/narrow the per-label throttle window
});
```

---

## New in this fork: protocol & utility modules

`@xayz/baileys` ships a newer WhatsApp protocol schema (`WAProto`) and a set of extra,
opt-in modules layered on top of the base socket. None of these run unless you call them.

**Updated protocol schema** — `WAProto` was regenerated from a newer WhatsApp Web protocol
dump, adding many message/record types the previous schema didn't have yet (e.g.
`ExtendedContentMessage`, `MusicMessage`, newer backup/E2E-key types). This required bumping
the `protobufjs` dependency to `^8.8.0` (from `^7.5.6`) since the current protobuf compiler
only targets that runtime — already reflected in `package.json`.

**New account/feature socket layers** (wired into `makeWASocket` automatically, each adding
methods without touching what's already there):

```javascript
const sock = makeWASocket({ /* ... */ });

// Privacy & account settings (text status, trusted devices, linked profiles, ...)
await sock.updateTextStatus('Hello world', '👋');
await sock.getTrustedDevices();

// Registration/account features (password, passkeys, age verification, contact backup)
await sock.hasPassword();
await sock.contactsBackupQuery();

// Managed-account linking & WhatsApp Payments passkeys
await sock.managedAccountQuery(sock.user.id);

// Cross-app interop (EU DMA messaging interoperability with Messenger/Instagram) — opt-in,
// nothing here runs until you call it:
const integrators = await sock.initInterop();

// Meta AI-in-groups
const group = await sock.aiGroupCreate('My AI Group', ['123@s.whatsapp.net']);

// First-party GraphQL surface (payments, AI Studio, bug reports, etc.) mirroring what the
// official app itself calls on graph.whatsapp.com / wamo.whatsapp.net
await sock.getEligibility();
```

**New opt-in `Utils` helpers** (import directly, use only if you need them):

```javascript
import {
  createSessionPool,       // run several numbers with reconnect backoff
  autoCacheViewOnceMedia,  // save view-once media to disk before it disappears
  createCommandHandler,    // simple "!command" style bot commands from a folder
  imageToWebpSticker,      // image -> WhatsApp sticker (needs optional "sharp")
  videoToWebpSticker,      // video -> animated sticker (needs a local ffmpeg)
  AdaptiveDelayManager,    // generic backoff/cooldown timer for retry loops
} from '@xayz/baileys';

// example: text-message router (also auto-attached as sock.onText/hears/command)
sock.command('ping', async (msg) => sock.sendMessage(msg.key.remoteJid, { text: 'pong' }));
```

See [`LITERACY.md`](LITERACY.md#new-modules-in-this-fork) for what each module does, where it
came from, and — for the one file that needed it — what was changed for security before it was
included.

---

## Performance notes

A few things were tightened up so this fork behaves better under long-running / high-traffic
use, without changing any public behavior:

- **`userDevicesCache`** (device-list cache used when sending) now has a hard `maxKeys` cap
  (default 10,000; override with `userDevicesCacheMaxKeys`), on top of its existing 5-minute
  TTL, so a very high-throughput bot can't grow it unbounded between TTL sweeps.
- **Message-retry caches** (`sessionRecreateHistory`, `retryCounters` in
  `lib/Utils/message-retry-manager.js`) got the same treatment — capped at 2,000 / 5,000
  entries respectively, same TTLs as before.
- **New guard state arrays** (blocked channel-follows, blocked group-joins, flagged recipients)
  are capped at 200 entries each (oldest dropped first) so leaving them enabled on a
  long-running process can't leak memory.
- **Two `ffmpeg` invocations** (video thumbnail extraction, video→sticker conversion) were
  switched from `child_process.exec` (a shell string) to `execFile` with an argv array — this
  is primarily a security fix (see [LITERACY.md](LITERACY.md#new-modules-in-this-fork)), but
  `execFile` also skips spawning an extra shell process per call, which is marginally lighter
  on CPU/process count for anything calling these a lot (bulk sticker conversion, etc.).
- Heavy optional dependencies (`sharp`, `jimp`, `music-metadata`, `audio-decode`,
  `link-preview-js`) were already lazy-loaded via dynamic `import()` only where actually used —
  confirmed still true after this fork's changes, so installs that skip those peer deps stay
  lightweight and processes that never touch stickers/audio-metadata/link-previews never pay
  for loading them.

None of this changes disk usage meaningfully — this library doesn't persist anything to disk on
its own beyond what you explicitly configure (auth state, your own caches/logs).

### optiMazer — opt-in, tighter resource limits

Everything above is always on (they're bug fixes, not something that should be optional). On
top of that, there's a separate opt-in switch — **OFF by default** — for people who want to
trade a little more re-fetching on cache misses for meaningfully less resident memory on a
long-running, high-traffic process:

```javascript
import makeWASocket from '@xayz/baileys';

const sock = makeWASocket({
  optiMazer: true // that's it — tightens cache limits, adds a periodic background tick
});

console.log(sock.getOptimizerStats());
// { ticks: 3, gcRuns: 0, uptimeMs: 182004, gcAvailable: false, memory: { rss: ..., heapUsed: ... } }
```

`optiMazer: true` tightens the always-on caps further (e.g. `userDevicesCache` from 10,000 keys
down to 2,000, guard logs from 200 entries down to 50) and starts a background tick every 60
seconds. If your process was started with `node --expose-gc`, that same tick also requests a
proactive garbage-collection pass; otherwise it's a harmless no-op.

You can also pass an object instead of `true` to override individual limits:

```javascript
const sock = makeWASocket({
  optiMazer: {
    userDevicesCacheMaxKeys: 500,
    tickIntervalMs: 30000
  }
});
```

Or use the exported class/factory directly if you want to manage its lifecycle yourself
(e.g. to call `.stop()` later):

```javascript
import { optiMazer } from '@xayz/baileys';

const tuner = optiMazer({ userDevicesCacheMaxKeys: 500 }).attach(sock);
// later
tuner.stop();
```

---

## Posting a Status with mentions

```javascript
await sock.sendStatusWhatsApp(
  { text: 'Big announcement! 🎉', backgroundColor: '#00A884' },
  ['6281234567890@s.whatsapp.net', '120363111111111111@g.us'] // users and/or groups (expanded to members)
);
```

Everyone listed gets a "you were mentioned in a status" notification, same as posting a status
with @mentions from the app.

---

## Reading channel text status, business profiles, and more via USync

`USyncQuery` gained five more protocols for bulk-looking-up info about JIDs:

```javascript
import { USyncQuery, USyncUser } from '@xayz/baileys';

const query = new USyncQuery()
  .withTextStatusProtocol()
  .withBusinessProtocol()
  .withPictureProtocol()
  .withUser(new USyncUser().withId(jid));

const result = await sock.executeUSyncQuery(query);
```

`.withFeatureProtocol()` and `.withSidelistProtocol()` are also available. See
[LITERACY.md](LITERACY.md#deeper-fork-comparison--what-schema-only-diffing-missed) for what
each one returns.

---

## Pure-JS Curve25519 fallback

If the `libsignal` dependency (currently a `github:` install — see
[`vendor-libsignal.sh`](vendor-libsignal.sh)) ever fails to install or load in your
environment, `CurveJS` is a drop-in, dependency-free replacement for the `Curve` operations it
normally provides:

```javascript
import { CurveJS } from '@xayz/baileys';

const keyPair = CurveJS.generateKeyPair();
const shared = CurveJS.sharedKey(myPrivateKey, theirPublicKey);
```

It's verified interoperable with the default `Curve` (a shared key computed with `Curve` on
one side and `CurveJS` on the other matches bit-for-bit) — see LITERACY.md for the test.
Not used by default anywhere in the library; this is available if you need it.

---

## SQLite-backed auth state

An alternative to `useMultiFileAuthState` for busy bots — stores everything in one SQLite file
instead of one JSON file per key:

```javascript
import makeWASocket, { useSqliteAuthState } from '@xayz/baileys';

const { state, saveCreds } = await useSqliteAuthState('./auth', {
  migrateFromFolder: './old-multi-file-auth' // optional, one-time
});

const sock = makeWASocket({ auth: state });
sock.ev.on('creds.update', saveCreds);
```

Requires Node 22.5+ (built-in `node:sqlite`); throws a clear error telling you to use
`useMultiFileAuthState` instead on older Node.

---

## Storing data

```javascript
import makeWASocket, { makeInMemoryStore } from '@xayz/baileys';
import pino from 'pino';

const store = makeInMemoryStore({
  logger: pino().child({ level: 'silent', stream: 'store' })
});
const client = makeWASocket({
  // options
});
store.bind(client.ev);

client.ev.on('contacts.upsert', () => {
  console.log('New contact: ' + Object.values(store.contacts()));
});
```

---

## Sending messages

### Send / relay a message with `noSelfSync`

`noSelfSync` is a `relayMessage` option (private/1-on-1 chats only) that controls whether the
message is also synced to your **other own linked devices** (other phones/WhatsApp Web sessions
logged into the same account). It does not affect delivery to the recipient.

- **`noSelfSync: true`** — sent to the recipient as normal, but **not** synced to your other own
  devices. Useful for silent/automated sends from a bot account.
- **`noSelfSync: false`** (default) — normal behavior; synced everywhere you're logged in.

```javascript
await client.relayMessage(m.chat, {
  conversation: "Hello from @xayz/baileys"
}, {
  noSelfSync: true
});

await client.sendMessage(m.chat, {
  text: "Hello from @xayz/baileys"
}, {
  noSelfSync: true
});
```

### Send an orderMessage

```javascript
import fs from 'fs';
const thumbnail = fs.readFileSync('./thumb.jpg');

await client.sendMessage(m.chat, {
  thumbnail,
  message: "Order summary",
  orderTitle: "My Store",
  totalAmount1000: 72502,
  totalCurrencyCode: "IDR"
}, { quoted: m });
```

### Send a pollResultSnapshotMessage

```javascript
await client.sendMessage(m.chat, {
  pollResultMessage: {
    name: "My Poll",
    options: [
      { optionName: "Option 1" },
      { optionName: "Option 2" }
    ],
    newsletter: {
      newsletterName: "XYCoolcraft Updates",
      newsletterJid: "120363427430697245@newsletter"
    }
  }
});
```

### Send a productMessage

```javascript
await client.relayMessage(m.chat, {
  productMessage: {
    title: "Product.pdf",
    description: "Product description",
    thumbnail: { url: "./thumb.jpg" },
    productId: "EXAMPLE_TOKEN",
    retailerId: "EXAMPLE_RETAILER_ID",
    url: "https://example.com",
    body: "Body text",
    footer: "Footer",
    buttons: [
      {
        name: "cta_url",
        buttonParamsJson: "{\"display_text\":\"Visit\",\"url\":\"https://example.com\"}"
      }
    ],
    priceAmount1000: 72502,
    currencyCode: "IDR"
  }
});
```

### Send an interactiveMessage

```javascript
await client.sendMessage(m.chat, {
  image: { url: "./img.jpg" },
  text: "body",
  title: "title", // required when sending media
  footer: "footer",
  interactiveButtons: [
    {
      name: "single_select",
      buttonParamsJson: JSON.stringify({ title: "\0" })
    }
  ],
  messageParams: JSON.stringify({
    bottom_sheet: { /** other params **/ }
  })
});
```

### Send a member label

```javascript
await client.sendMessage(m.chat, {
  groupLabel: { labelText: "Tagged members appear here" }
});
```

### Send a message to group members

```javascript
await client.sendMessageMembers(m.chat, {
  extendedTextMessage: { text: "Hello members" }
}, {});
```

---

## Simple sendMessage Helpers

<details>
<summary><b>Send text</b></summary>

```javascript
await client.sendText(m.chat, "Hello!", {
  contextInfo: { mentionedJid: [m.chat] }
}, {
  key: { remoteJid: "status@broadcast", participant: m.sender, fromMe: true },
  message: { conversation: "\0" }
});
```
</details>

<details>
<summary><b>Send image</b></summary>

```javascript
await client.sendImage(m.chat, { url: "./img.jpg" }, "Caption", {
  contextInfo: { mentionedJid: [m.chat] }
}, {
  key: { remoteJid: "status@broadcast", participant: m.sender, fromMe: true },
  message: { conversation: "\0" }
});
```
</details>

<details>
<summary><b>Send video</b></summary>

```javascript
await client.sendVideo(m.chat, { url: "./video.mp4" }, "Caption", {
  contextInfo: { mentionedJid: [m.chat] }
}, {
  key: { remoteJid: "status@broadcast", participant: m.sender, fromMe: true },
  message: { conversation: "\0" }
});
```
</details>

<details>
<summary><b>Send audio</b></summary>

```javascript
await client.sendAudio(m.chat, { url: "./audio.mp3" }, {
  contextInfo: { mentionedJid: [m.chat] }
}, {
  key: { remoteJid: "status@broadcast", participant: m.sender, fromMe: true },
  message: { conversation: "\0" }
});
```
</details>

<details>
<summary><b>Send location</b></summary>

```javascript
await client.sendLocation(m.chat, "Caption", 90.0, 90.0, "https://example.com", "1234567890", {
  contextInfo: { mentionedJid: [m.chat] }
}, {
  key: { remoteJid: "status@broadcast", participant: m.sender, fromMe: true },
  message: { conversation: "\0" }
});
```
</details>

<details>
<summary><b>Send poll</b></summary>

```javascript
await client.sendPoll(m.chat, "Pick one", ["1", "2", "3"], true, {
  contextInfo: { mentionedJid: [m.chat] }
}, {
  key: { remoteJid: "status@broadcast", participant: m.sender, fromMe: true },
  message: { conversation: "\0" }
});
```
</details>

<details>
<summary><b>Send quiz</b></summary>

```javascript
await client.sendQuiz(m.chat, "Quiz question", ["1", "2", "3"], "2", {
  contextInfo: { mentionedJid: [m.chat] }
}, {
  key: { remoteJid: "status@broadcast", participant: m.sender, fromMe: true },
  message: { conversation: "\0" }
});
```
</details>

<details>
<summary><b>Send status mention</b></summary>

```javascript
await client.statusMention(m.chat, {
  extendedTextMessage: { text: "Mentioned in status" }
});
```
</details>

---

## Credits

`@xayz/baileys` Build By: XYCoolcraft:

- Original protocol implementation: [Baileys](https://github.com/WhiskeySockets/Baileys) by
  [Adhiraj Singh](https://github.com/adiwajshing) and the WhiskeySockets community.
- Modified By: **XYCoolcraft** [Github](https://github.com/XYCoolcraft).

All credit for the underlying WhatsApp Web protocol work goes to the original authors and
contributors. See [`LICENSE`](LICENSE) for the full text and every copyright notice that must
be kept per the MIT License.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for guidelines on reporting issues and submitting pull
requests.

## Publishing

Maintainers can publish a new version to npm with the included helper script — see
[`upload-npm.sh`](upload-npm.sh) and the walkthrough in
[`LITERACY.md`](LITERACY.md#uploadnpmsh-walkthrough).

```bash
bash upload-npm.sh
```

## Disclaimer

This is **not** an official WhatsApp product. Use of this library to send bulk or unsolicited
messages may violate WhatsApp's Terms of Service and can result in your number being banned.
Use responsibly.

<div align="center">

---

Made by **XYCoolcraft** · [`README.md`](README.md) · [`LITERACY.md`](LITERACY.md)

</div>
