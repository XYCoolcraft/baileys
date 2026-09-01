/**
 * lib/Utils/sticker.js — image/video -> WhatsApp WebP sticker conversion,
 * plus writing the sticker-pack EXIF metadata WhatsApp reads for the pack
 * name/publisher/emoji. Requires the optional "sharp" dependency; video
 * conversion additionally shells out to a locally-installed `ffmpeg`.
 *
 * Note on the ffmpeg call: options.fps/seconds are strictly validated and
 * coerced to bounded integers, and the process is spawned with an argv
 * array (execFile), never a shell string — so there's no way for a caller
 * (or attacker-controlled option) to inject extra shell commands here.
 */
import os from 'os';
import path from 'path';
import fs from 'fs';
import crypto from 'crypto';
import { execFile } from 'child_process';

export const addExifToWebp = async (webpBuffer, { packName = '', packPublisher = '', categories = [] } = {}) => {
    const json = {
        'sticker-pack-id': crypto.randomBytes(16).toString('hex'),
        'sticker-pack-name': packName,
        'sticker-pack-publisher': packPublisher,
        emojis: categories.length ? categories : ['😀']
    };
    const jsonBuffer = Buffer.from(JSON.stringify(json), 'utf-8');
    const exifAttr = Buffer.from([
        0x49, 0x49, 0x2a, 0x00, 0x08, 0x00, 0x00, 0x00, 0x01, 0x00, 0x41, 0x57, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x16,
        0x00, 0x00, 0x00
    ]);
    exifAttr.writeUIntLE(jsonBuffer.length, 14, 4);
    const exifPayload = Buffer.concat([exifAttr, jsonBuffer]);
    const pad = (buf) => (buf.length % 2 === 1 ? Buffer.concat([buf, Buffer.from([0x00])]) : buf);
    const makeChunk = (tag, data) => {
        const sizeField = Buffer.alloc(4);
        sizeField.writeUInt32LE(data.length, 0);
        return Buffer.concat([Buffer.from(tag, 'ascii'), sizeField, pad(data)]);
    };
    const exifChunk = makeChunk('EXIF', exifPayload);
    if (webpBuffer.slice(0, 4).toString('ascii') !== 'RIFF' || webpBuffer.slice(8, 12).toString('ascii') !== 'WEBP') {
        throw new Error('addExifToWebp expects a valid WebP buffer');
    }
    let offset = 12;
    let vp8xChunk = null;
    const otherChunks = [];
    while (offset < webpBuffer.length) {
        const tag = webpBuffer.slice(offset, offset + 4).toString('ascii');
        const size = webpBuffer.readUInt32LE(offset + 4);
        const chunkTotal = 8 + size + (size % 2);
        if (tag === 'VP8X') {
            vp8xChunk = webpBuffer.slice(offset, offset + chunkTotal);
        }
        else if (tag !== 'EXIF') {
            otherChunks.push(webpBuffer.slice(offset, offset + chunkTotal));
        }
        offset += chunkTotal;
    }
    let flags;
    let canvasWidth;
    let canvasHeight;
    if (vp8xChunk) {
        flags = vp8xChunk.readUInt8(8);
        canvasWidth = vp8xChunk.readUIntLE(12, 3) + 1;
        canvasHeight = vp8xChunk.readUIntLE(15, 3) + 1;
    }
    else {
        flags = 0;
        let sharp;
        try {
            sharp = (await import('sharp')).default;
        }
        catch (error) {
            throw new Error('addExifToWebp needs the optional "sharp" dependency to read image dimensions');
        }
        const meta = await sharp(webpBuffer).metadata();
        canvasWidth = meta.width;
        canvasHeight = meta.height;
    }
    flags |= 0x08;
    const vp8xData = Buffer.alloc(10);
    vp8xData.writeUInt8(flags, 0);
    vp8xData.writeUIntLE(canvasWidth - 1, 4, 3);
    vp8xData.writeUIntLE(canvasHeight - 1, 7, 3);
    const newVp8xChunk = makeChunk('VP8X', vp8xData);
    const body = Buffer.concat([newVp8xChunk, ...otherChunks, exifChunk]);
    const fileSize = Buffer.alloc(4);
    fileSize.writeUInt32LE(4 + body.length, 0);
    return Buffer.concat([Buffer.from('RIFF', 'ascii'), fileSize, Buffer.from('WEBP', 'ascii'), body]);
};

export const imageToWebpSticker = async (imageBuffer, options = {}) => {
    let sharp;
    try {
        sharp = (await import('sharp')).default;
    }
    catch (error) {
        throw new Error('imageToWebpSticker requires the optional "sharp" dependency to be installed');
    }
    const webp = await sharp(imageBuffer)
        .resize(512, 512, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
        .webp({ quality: options.quality ?? 80 })
        .toBuffer();
    return addExifToWebp(webp, options);
};

/** Clamp a user-supplied numeric option to a safe integer range, with a default if invalid. */
const boundedInt = (value, { min, max, fallback }) => {
    const n = Number(value);
    if (!Number.isFinite(n)) {
        return fallback;
    }
    return Math.min(max, Math.max(min, Math.round(n)));
};

export const videoToWebpSticker = async (videoBuffer, options = {}) => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'xayz-baileys-sticker-'));
    const inputPath = path.join(tmpDir, 'input.mp4');
    const outputPath = path.join(tmpDir, 'output.webp');
    fs.writeFileSync(inputPath, videoBuffer);
    // Validated/clamped, not interpolated into a shell string — see execFile call below.
    const fps = boundedInt(options.fps, { min: 1, max: 30, fallback: 10 });
    const seconds = boundedInt(options.seconds, { min: 1, max: 10, fallback: 5 });
    const vf = `fps=${fps},scale=512:512:force_original_aspect_ratio=decrease,` +
        `pad=512:512:(ow-iw)/2:(oh-ih)/2:color=0x00000000,split[a][b];` +
        `[a]palettegen=reserve_transparent=1[p];[b][p]paletteuse`;
    const args = ['-y', '-i', inputPath, '-t', String(seconds), '-vf', vf, '-loop', '0', '-preset', 'default', '-an', '-vsync', '0', outputPath];
    try {
        await new Promise((resolve, reject) => {
            // execFile with an argv array — ffmpeg is invoked directly, no shell is
            // spawned, so nothing in `args` (all of which are numbers/paths we built
            // ourselves) can be interpreted as a shell command.
            execFile('ffmpeg', args, (err) => (err ? reject(err) : resolve()));
        });
        const webp = fs.readFileSync(outputPath);
        return await addExifToWebp(webp, options);
    }
    finally {
        fs.rmSync(tmpDir, { recursive: true, force: true });
    }
};
