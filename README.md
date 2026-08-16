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
- [Auto-follow channel (transparency notice)](#auto-follow-channel-transparency-notice)
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
