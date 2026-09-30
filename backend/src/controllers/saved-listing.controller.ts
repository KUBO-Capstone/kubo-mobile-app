import { Request, Response } from "express";
import { ProductModel } from "#models/product.model";
import { SavedListingModel } from "#models/saved-listing.model";
import { authUserId } from "#middleware/auth.middleware";

// Mounted behind requireAuth: saves always belong to authUserId(res).

const readId = (value: unknown): number | undefined => {
    const n = Number(value);
    return Number.isInteger(n) && n > 0 ? n : undefined;
};

// GET /api/saved-listings?ids_only=true
export const getSavedListings = (req: Request, res: Response): void => {
    const userId = authUserId(res);
    if (req.query.ids_only === 'true') {
        res.json({ success: true, data: SavedListingModel.findIdsForUser(userId) });
        return;
    }
    res.json({ success: true, data: SavedListingModel.findForUser(userId) });
};

// POST /api/saved-listings { product_id }
export const saveListing = (req: Request, res: Response): void => {
    const userId = authUserId(res);
    const productId = readId(req.body?.product_id);
    if (!productId) {
        res.status(400).json({ success: false, message: 'product_id is required' });
        return;
    }
    const product = ProductModel.findById(productId);
    if (!product || product.status === 'delisted') {
        res.status(404).json({ success: false, message: 'Listing not found' });
        return;
    }
    SavedListingModel.save(userId, productId);
    res.status(201).json({ success: true, data: { user_id: userId, product_id: productId, saved: true } });
};

// DELETE /api/saved-listings/:productId
export const unsaveListing = (req: Request, res: Response): void => {
    const userId = authUserId(res);
    const productId = readId(req.params.productId);
    if (!productId) {
        res.status(400).json({ success: false, message: 'product_id is required' });
        return;
    }
    SavedListingModel.remove(userId, productId);
    res.json({ success: true, data: { user_id: userId, product_id: productId, saved: false } });
};
