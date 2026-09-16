import { Router } from "express";
import { getMarketProduct, getMarketProducts, getMarketReference } from "#controllers/market.controller";

const router = Router();
router.get('/products', getMarketProducts);
router.get('/products/:id', getMarketProduct);
router.get('/reference', getMarketReference);

export default router;
