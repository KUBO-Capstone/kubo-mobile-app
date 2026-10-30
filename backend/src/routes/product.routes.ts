import { RequestHandler, Router } from "express";
import crypto from 'crypto';
import fs from 'fs';
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

// The stored extension comes from the file's leading bytes, never from the
// name or MIME type the client sent.
const imageSignatures: { extension: string; matches: (head: Buffer) => boolean }[] = [
    { extension: '.jpg', matches: (head) => head.subarray(0, 3).equals(Buffer.from([0xff, 0xd8, 0xff])) },
    { extension: '.png', matches: (head) => head.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) },
    { extension: '.webp', matches: (head) => head.toString('latin1', 0, 4) === 'RIFF' && head.toString('latin1', 8, 12) === 'WEBP' },
];

const detectImageExtension = async (filePath: string): Promise<string | undefined> => {
    const handle = await fs.promises.open(filePath, 'r');
    try {
        const head = Buffer.alloc(12);
        const { bytesRead } = await handle.read(head, 0, head.length, 0);
        return imageSignatures.find((signature) => signature.matches(head.subarray(0, bytesRead)))?.extension;
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
