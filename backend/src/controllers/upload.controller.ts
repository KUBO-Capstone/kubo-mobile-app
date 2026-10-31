import { DeleteObjectCommand, GetObjectCommand, HeadObjectCommand, PutObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import crypto from "crypto";
import { RequestHandler } from "express";
import multer from "multer";
import { requireEnv, s3 } from "#config/aws";

// Photos (listing images and profile pictures) live in the S3 bucket named by
// S3_BUCKET, under products/ and profiles/. The database stores each one as
// its plain S3 URL, https://<bucket>.s3.<region>.amazonaws.com/<key>, which a
// private bucket will not serve. So every JSON response swaps it for a URL
// the app can load (viewableMediaUrl, applied by middleware/media.middleware.ts),
// and requests that send one of those back are mapped to the stored form
// with toStoredMediaUrl. See docs/media_storage.md for the bucket setup.

export type MediaFolder = 'products' | 'profiles';

type ImageType = { extension: string; contentType: string };

// .jpeg only appears on photos copied over from the old disk storage.
const keyPattern = /^(products|profiles)\/[0-9a-f-]{36}\.(jpg|jpeg|png|webp)$/;
const cacheControl = 'public, max-age=86400, immutable';
const presignedLifetimeSeconds = 7 * 24 * 60 * 60; // the longest SigV4 allows
const dayMs = 24 * 60 * 60 * 1000;

// Read lazily: dotenv may not have run yet when this module is imported.
const bucket = (): string => requireEnv('S3_BUCKET');

// Undefined until S3 is configured, so checking a string never throws.
const s3Origin = (): string | undefined => {
    const name = process.env.S3_BUCKET;
    const region = process.env.AWS_REGION;
    return name && region ? `https://${name}.s3.${region}.amazonaws.com` : undefined;
};

// Optional public base for photos, e.g. a CloudFront distribution in front of
// the bucket. Unset means the bucket is private and URLs are presigned.
const publicBase = (): string | undefined => process.env.MEDIA_BASE_URL?.replace(/\/+$/, '') || undefined;

/** The stored URL for an object key. */
export const mediaUrlForKey = (key: string): string =>
    `https://${bucket()}.s3.${requireEnv('AWS_REGION')}.amazonaws.com/${key}`;

/**
 * The object key behind a photo URL this server hands out: the stored S3
 * URL, a presigned copy of it, or its MEDIA_BASE_URL form. Undefined for
 * anything else, including keys outside `folder` when one is given.
 */
export const mediaKeyOf = (url: string, folder?: MediaFolder): string | undefined => {
    if (!url.startsWith('https://')) return undefined;
    const bare = url.split(/[?#]/)[0];
    for (const base of [s3Origin(), publicBase()]) {
        if (!base || !bare.startsWith(`${base}/`)) continue;
        const key = bare.slice(base.length + 1);
        return keyPattern.test(key) && (!folder || key.startsWith(`${folder}/`)) ? key : undefined;
    }
    return undefined;
};

/** The stored form of a photo URL the app sent back, if it is one of ours in `folder`. */
export const toStoredMediaUrl = (url: string, folder: MediaFolder): string | undefined => {
    const key = mediaKeyOf(url, folder);
    return key ? mediaUrlForKey(key) : undefined;
};

/**
 * A URL the app can load for a stored photo URL: its MEDIA_BASE_URL form when
 * that is set, otherwise a presigned GET. Signing from the start of the UTC
 * day keeps the URL the same all day, so the app's image cache still hits,
 * and leaves it valid for at least six more days.
 */
export const viewableMediaUrl = async (storedUrl: string): Promise<string> => {
    const key = mediaKeyOf(storedUrl);
    if (!key) return storedUrl;
    const base = publicBase();
    if (base) return `${base}/${key}`;
    const signingDate = new Date(Math.floor(Date.now() / dayMs) * dayMs);
    return getSignedUrl(s3, new GetObjectCommand({ Bucket: bucket(), Key: key }), {
        expiresIn: presignedLifetimeSeconds,
        signingDate,
    });
};

// The app role has object access but not s3:ListBucket, and without it S3
// answers a missing key with 403 instead of 404, so both mean "not there".
const isMissing = (error: unknown): boolean => {
    const status = (error as { $metadata?: { httpStatusCode?: number } }).$metadata?.httpStatusCode;
    return status === 404 || status === 403;
};

const jpegSignature = Buffer.from([0xff, 0xd8, 0xff]);
const pngSignature = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

// An animated PNG announces itself with an acTL chunk before the first IDAT.
const isStillPng = (data: Buffer): boolean => {
    let offset = pngSignature.length;
    while (offset + 8 <= data.length) {
        const type = data.toString('latin1', offset + 4, offset + 8);
        if (type === 'IDAT') return true;
        if (type === 'acTL') return false;
        offset += 12 + data.readUInt32BE(offset); // length + type + data + CRC
    }
    return false;
};

// A WebP's first chunk is VP8 (lossy), VP8L (lossless) or VP8X (extended,
// whose flags byte marks animation with 0x02). Anything else is unexpected.
const isStillWebp = (data: Buffer): boolean => {
    const chunk = data.toString('latin1', 12, 16);
    if (chunk === 'VP8 ' || chunk === 'VP8L') return true;
    return chunk === 'VP8X' && data.length > 20 && (data[20] & 0x02) === 0;
};

/**
 * What a photo really is, from its bytes; the name and MIME type the client
 * sent are never trusted. Only still JPEG, PNG and WebP images are accepted,
 * so animated PNG/WebP and every other format come back undefined.
 */
export const detectImageType = (data: Buffer): ImageType | undefined => {
    if (data.subarray(0, 3).equals(jpegSignature)) return { extension: '.jpg', contentType: 'image/jpeg' };
    if (data.subarray(0, 8).equals(pngSignature)) {
        return isStillPng(data) ? { extension: '.png', contentType: 'image/png' } : undefined;
    }
    if (data.toString('latin1', 0, 4) === 'RIFF' && data.toString('latin1', 8, 12) === 'WEBP') {
        return isStillWebp(data) ? { extension: '.webp', contentType: 'image/webp' } : undefined;
    }
    return undefined;
};

/** Writes a checked photo to `key`. */
export const putImage = async (key: string, data: Buffer, type: ImageType): Promise<void> => {
    await s3.send(new PutObjectCommand({
        Bucket: bucket(),
        Key: key,
        Body: data,
        ContentType: type.contentType,
        // Names are never reused, so a copy never goes stale.
        CacheControl: cacheControl,
    }));
};

/** Whether an object key exists in the bucket. */
export const objectExists = async (key: string): Promise<boolean> => {
    try {
        await s3.send(new HeadObjectCommand({ Bucket: bucket(), Key: key }));
        return true;
    } catch (error) {
        if (isMissing(error)) return false;
        throw error;
    }
};

/** Whether a stored photo URL points at an object that exists. */
export const storedImageExists = async (storedUrl: string): Promise<boolean> => {
    const key = mediaKeyOf(storedUrl);
    return key !== undefined && objectExists(key);
};

/**
 * Removes a stored photo from the bucket, but only if it is one of ours in
 * `folder`. Failures are logged rather than thrown: nothing points at the
 * photo any more either way.
 */
export const deleteStoredImage = async (storedUrl: string, folder: MediaFolder): Promise<void> => {
    const key = mediaKeyOf(storedUrl, folder);
    if (!key) return;
    try {
        await s3.send(new DeleteObjectCommand({ Bucket: bucket(), Key: key }));
    } catch (error) {
        console.error(`Could not delete photo ${key}:`, error);
    }
};

// Saves one photo under a fresh name and returns its stored URL.
const storeImage = async (folder: MediaFolder, data: Buffer, type: ImageType): Promise<string> => {
    const key = `${folder}/${crypto.randomUUID()}${type.extension}`;
    await putImage(key, data, type);
    return mediaUrlForKey(key);
};

type ReceiveImagesOptions = {
    /** Multipart field the photos arrive in. */
    field: string;
    folder: MediaFolder;
    maxFiles: number;
    maxBytes: number;
    /** Replies for multer's limit errors, shown to the user as is. */
    messages: Partial<Record<multer.ErrorCode, string>>;
};

/**
 * Reads up to `maxFiles` photos into memory (nothing touches the disk),
 * checks each one is a still JPEG, PNG or WebP image, uploads them to the
 * bucket and leaves their stored URLs, in upload order, in
 * res.locals.uploadedImages. Rejects the whole upload rather than skipping a
 * file, so the URLs always line up one-to-one with the photos sent.
 */
export const receiveImages = ({ field, folder, maxFiles, maxBytes, messages }: ReceiveImagesOptions): RequestHandler => {
    const upload = multer({
        storage: multer.memoryStorage(),
        limits: { fileSize: maxBytes, files: maxFiles },
    }).array(field, maxFiles);

    return (req, res, next) => {
        upload(req, res, async (error: unknown) => {
            if (error instanceof multer.MulterError) {
                res.status(400).json({ success: false, message: messages[error.code] ?? error.message });
                return;
            }
            if (error) {
                next(error);
                return;
            }
            const files = Array.isArray(req.files) ? req.files : [];
            const types = files.map((file) => detectImageType(file.buffer));
            if (!types.every((type): type is ImageType => type !== undefined)) {
                res.status(400).json({ success: false, message: 'Photos must be JPG, PNG, or WebP' });
                return;
            }
            const stored = await Promise.allSettled(files.map((file, i) => storeImage(folder, file.buffer, types[i])));
            const failed = stored.find((result) => result.status === 'rejected');
            if (failed) {
                // Keep the all-or-nothing promise: drop the ones that made it.
                for (const result of stored) {
                    if (result.status === 'fulfilled') void deleteStoredImage(result.value, folder);
                }
                next(failed.reason);
                return;
            }
            res.locals.uploadedImages = stored.map((result) => (result as PromiseFulfilledResult<string>).value);
            next();
        });
    };
};
