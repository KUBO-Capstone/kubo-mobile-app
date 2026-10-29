import { RequestHandler, Router } from "express";
import crypto from 'crypto';
import fs from 'fs';
import multer from 'multer';
import path from 'path';
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
        filename: (_req, file, callback) => callback(null, `${crypto.randomUUID()}${path.extname(file.originalname).toLowerCase()}`),
    }),
    limits: { fileSize: 8 * 1024 * 1024, files: maxListingImages },
    // Rejects the whole upload rather than skipping a file, so the paths
    // returned always line up one-to-one with the photos the app sent.
    fileFilter: (_req, file, callback) => {
        const extension = path.extname(file.originalname).toLowerCase();
        const allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
        const allowedMimeTypes = ['image/jpeg', 'image/png', 'image/webp', 'application/octet-stream'];
        if (allowedExtensions.includes(extension) && allowedMimeTypes.includes(file.mimetype)) {
            callback(null, true);
            return;
        }
        callback(Object.assign(new Error('Photos must be JPG, PNG, or WebP'), { status: 400 }));
    },
});

const uploadMessages: Partial<Record<multer.ErrorCode, string>> = {
    LIMIT_FILE_SIZE: 'Each photo must be 8 MB or smaller',
    LIMIT_FILE_COUNT: `A listing can have up to ${maxListingImages} photos`,
    LIMIT_UNEXPECTED_FILE: `A listing can have up to ${maxListingImages} photos`,
};

const receiveImages: RequestHandler = (req, res, next) => {
    imageUpload.array('images', maxListingImages)(req, res, (error: unknown) => {
        if (error instanceof multer.MulterError) {
            res.status(400).json({ success: false, message: uploadMessages[error.code] ?? error.message });
            return;
        }
        next(error);
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
