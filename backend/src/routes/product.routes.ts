import { Router } from "express";
import { requireAuth } from "#middleware/auth.middleware";
import { receiveImages } from "#controllers/upload.controller";
import {
    createProduct,
    deleteProduct,
    getProduct,
    getProducts,
    maxListingImages,
    updateProduct,
    uploadProductImages,
} from "#controllers/product.controller";

const receiveListingImages = receiveImages({
    field: 'images',
    folder: 'products',
    maxFiles: maxListingImages,
    maxBytes: 8 * 1024 * 1024,
    messages: {
        LIMIT_FILE_SIZE: 'Each photo must be 8 MB or smaller',
        LIMIT_FILE_COUNT: `A listing can have up to ${maxListingImages} photos`,
        LIMIT_UNEXPECTED_FILE: `A listing can have up to ${maxListingImages} photos`,
    },
});

const router = Router();
// Browsing is public; changing a listing needs the seller's token.
router.get('/', getProducts);
router.get('/:id', getProduct);
router.post('/images', requireAuth, receiveListingImages, uploadProductImages);
router.post('/', requireAuth, createProduct);
router.patch('/:id', requireAuth, updateProduct);
router.delete('/:id', requireAuth, deleteProduct);

export default router;
