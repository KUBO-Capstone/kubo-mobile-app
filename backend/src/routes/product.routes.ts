import { Router } from "express";
import { requireAuth } from "#middleware/auth.middleware";
import { createProduct, deleteProduct, getProduct, getProducts, updateProduct } from "#controllers/product.controller";

const router = Router();
// Browsing is public; changing a listing needs the seller's token.
router.get('/', getProducts);
router.get('/:id', getProduct);
router.post('/', requireAuth, createProduct);
router.patch('/:id', requireAuth, updateProduct);
router.delete('/:id', requireAuth, deleteProduct);

export default router;