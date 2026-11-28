import { before, test } from "node:test";
import assert from "node:assert/strict";

type UploadModule = typeof import("#controllers/upload.controller");
let detectImageType: UploadModule['detectImageType'];
let detectVideoType: UploadModule['detectVideoType'];
let isVideoUrl: UploadModule['isVideoUrl'];

before(async () => {
    // The upload module builds its S3 client on import, which wants a region.
    // Nothing here talks to AWS; any value will do.
    process.env.AWS_REGION ??= 'ap-southeast-1';
    ({ detectImageType, detectVideoType, isVideoUrl } = await import("#controllers/upload.controller"));
});

// What the chat and review uploads accept is decided from the bytes, never
// the file name. Videos: MP4, QuickTime and WebM. HEIC/AVIF photos are ISO
// media files too and must not pass as video.

const isoMedia = (brand: string) => Buffer.concat([
    Buffer.from([0, 0, 0, 0x18]), Buffer.from('ftyp', 'latin1'), Buffer.from(brand, 'latin1'), Buffer.alloc(12),
]);

test('MP4 and QuickTime are recognised from their ftyp brand', () => {
    assert.deepEqual(detectVideoType(isoMedia('isom')), { extension: '.mp4', contentType: 'video/mp4', isVideo: true });
    assert.deepEqual(detectVideoType(isoMedia('mp42')), { extension: '.mp4', contentType: 'video/mp4', isVideo: true });
    assert.deepEqual(detectVideoType(isoMedia('qt  ')), { extension: '.mov', contentType: 'video/quicktime', isVideo: true });
});

test('WebM is recognised from its EBML header', () => {
    const webm = Buffer.concat([Buffer.from([0x1a, 0x45, 0xdf, 0xa3]), Buffer.alloc(20)]);
    assert.equal(detectVideoType(webm)?.contentType, 'video/webm');
});

test('HEIC / AVIF photos and other files are not videos', () => {
    assert.equal(detectVideoType(isoMedia('heic')), undefined);
    assert.equal(detectVideoType(isoMedia('avif')), undefined);
    assert.equal(detectVideoType(Buffer.from('not a video at all')), undefined);
    assert.equal(detectImageType(isoMedia('isom')), undefined, 'an MP4 is not a photo');
});

test('isVideoUrl reads the extension and ignores a presigned query', () => {
    assert.equal(isVideoUrl('https://b.s3.ap-southeast-1.amazonaws.com/chats/0b1c.mp4?X-Amz-Signature=x'), true);
    assert.equal(isVideoUrl('https://b.s3.ap-southeast-1.amazonaws.com/reviews/0b1c.MOV'), true);
    assert.equal(isVideoUrl('https://b.s3.ap-southeast-1.amazonaws.com/chats/0b1c.jpg'), false);
});
