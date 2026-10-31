import { RequestHandler, Router } from "express";
import crypto from 'crypto';
import fs from 'fs';
import type { FileHandle } from 'fs/promises';
import multer from 'multer';
import { requireAuth } from "#middleware/auth.middleware";
import {
    createProduct,
    deleteProduct,
    getProduct,
    getProducts,
    maxListingImages,
    productUploadDirectory,
    updateProduct,
    uploadProductImages,
} from "#controllers/product.controller";

fs.mkdirSync(productUploadDirectory, { recursive: true });
const imageUpload = multer({
    storage: multer.diskStorage({
        destination: productUploadDirectory,
        // No extension until receiveImages has checked what the file really is.
        filename: (_req, _file, callback) => callback(null, crypto.randomUUID()),
    }),
    limits: { fileSize: 8 * 1024 * 1024, files: maxListingImages },
});

const jpegSignature = Buffer.from([0xff, 0xd8, 0xff]);
const pngSignature = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

// An animated PNG announces itself with an acTL chunk before the first IDAT.
// Gives up (rejects) after a few hundred chunks rather than walk a crafted file.
const isStillPng = async (handle: FileHandle): Promise<boolean> => {
    const header = Buffer.alloc(8);
    let offset = pngSignature.length;
    for (let chunks = 0; chunks < 256; chunks++) {
        const { bytesRead } = await handle.read(header, 0, header.length, offset);
        if (bytesRead < header.length) return false;
        const type = header.toString('latin1', 4, 8);
        if (type === 'IDAT') return true;
        if (type === 'acTL') return false;
        offset += 12 + header.readUInt32BE(0); // length + type + data + CRC
    }
    return false;
};

// A WebP's first chunk is VP8 (lossy), VP8L (lossless) or VP8X (extended,
// whose flags byte marks animation with 0x02). Anything else is unexpected.
const isStillWebp = (head: Buffer): boolean => {
    const chunk = head.toString('latin1', 12, 16);
    if (chunk === 'VP8 ' || chunk === 'VP8L') return true;
    return chunk === 'VP8X' && head.length > 20 && (head[20] & 0x02) === 0;
};

// The stored extension comes from the file's contents, never from the name
// or MIME type the client sent. Listing photos must be still JPEG, PNG or
// WebP images; animated PNG/WebP and every other format are rejected.
const detectImageExtension = async (filePath: string): Promise<string | undefined> => {
    const handle = await fs.promises.open(filePath, 'r');
    try {
        const buffer = Buffer.alloc(21);
        const { bytesRead } = await handle.read(buffer, 0, buffer.length, 0);
        const head = buffer.subarray(0, bytesRead);
        if (head.subarray(0, 3).equals(jpegSignature)) return '.jpg';
        if (head.subarray(0, 8).equals(pngSignature)) return (await isStillPng(handle)) ? '.png' : undefined;
        if (head.toString('latin1', 0, 4) === 'RIFF' && head.toString('latin1', 8, 12) === 'WEBP') {
            return isStillWebp(head) ? '.webp' : undefined;
        }
        return undefined;
    } finally {
        await handle.close();
    }
};

const removeFiles = (files: Express.Multer.File[]) =>
    Promise.all(files.map((file) => fs.promises.rm(file.path, { force: true })));

const uploadMessages: Partial<Record<multer.ErrorCode, string>> = {
    LIMIT_FILE_SIZE: 'Each photo must be 8 MB or smaller',
    LIMIT_FILE_COUNT: `A listing can have up to ${maxListingImages} photos`,
    LIMIT_UNEXPECTED_FILE: `A listing can have up to ${maxListingImages} photos`,
};

const receiveImages: RequestHandler = (req, res, next) => {
    imageUpload.array('images', maxListingImages)(req, res, async (error: unknown) => {
        if (error instanceof multer.MulterError) {
            res.status(400).json({ success: false, message: uploadMessages[error.code] ?? error.message });
            return;
        }
        if (error) {
            next(error);
            return;
        }
        const files = Array.isArray(req.files) ? req.files : [];
        try {
            const extensions = await Promise.all(files.map((file) => detectImageExtension(file.path)));
            // Rejects the whole upload rather than skipping a file, so the paths
            // returned always line up one-to-one with the photos the app sent.
            if (extensions.some((extension) => extension === undefined)) {
                await removeFiles(files);
                res.status(400).json({ success: false, message: 'Photos must be JPG, PNG, or WebP' });
                return;
            }
            await Promise.all(files.map(async (file, i) => {
                const target = `${file.path}${extensions[i]}`;
                await fs.promises.rename(file.path, target);
                file.path = target;
                file.filename += extensions[i];
            }));
            next();
        } catch (checkError) {
            await removeFiles(files).catch(() => undefined);
            next(checkError);
        }
    });
};

const router = Router();
// Browsing is public; changing a listing needs the seller's token.
router.get('/', getProducts);
router.get('/:id', getProduct);
router.post('/images', requireAuth, receiveImages, uploadProductImages);
router.post('/', requireAuth, createProduct);
router.patch('/:id', requireAuth, updateProduct);
router.delete('/:id', requireAuth, deleteProduct);

export default router;
