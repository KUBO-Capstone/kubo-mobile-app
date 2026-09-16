import { Request, Response } from "express";
import { ProductModel } from "#models/product.model";
import { SavedListingModel } from "#models/saved-listing.model";
import { UserModel } from "#models/user.model";

// KNOWN DEBT: same identity stopgap as negotiations and conversations -
// `user_id` comes from the request and is trusted until Phase 2 auth.

const readId = (value: unknown): number | undefined => {
    const n = Number(value);
    return Number.isInteger(n) && n > 0 ? n : undefined;
};

// GET /api/saved-listings?user_id=&ids_only=true
export const getSavedListings = (req: Request, res: Response): void => {
    const userId = readId(req.query.user_id);
    if (!userId) {
        res.status(400).json({ success: false, message: 'user_id is required' });
        return;
    }
    if (req.query.ids_only === 'true') {
        res.json({ success: true, data: SavedListingModel.findIdsForUser(userId) });
        return;
    }
    res.json({ success: true, data: SavedListingModel.findForUser(userId) });
};

// POST /api/saved-listings { user_id, product_id }
export const saveListing = (req: Request, res: Response): void => {
    const userId = readId(req.body?.user_id);
    const productId = readId(req.body?.product_id);
    if (!userId || !productId) {
        res.status(400).json({ success: false, message: 'user_id and product_id are required' });
        return;
    }
    if (!UserModel.findById(userId)) {
        res.status(404).json({ success: false, message: 'User not found' });
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

// DELETE /api/saved-listings/:productId { user_id }
export const unsaveListing = (req: Request, res: Response): void => {
    const userId = readId(req.body?.user_id ?? req.query.user_id);
    const productId = readId(req.params.productId);
    if (!userId || !productId) {
        res.status(400).json({ success: false, message: 'user_id and product_id are required' });
        return;
    }
    SavedListingModel.remove(userId, productId);
    res.json({ success: true, data: { user_id: userId, product_id: productId, saved: false } });
};
