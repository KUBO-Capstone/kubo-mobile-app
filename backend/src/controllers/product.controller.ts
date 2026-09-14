import { Request, Response } from "express";
import { ProductChanges, ProductListing, ProductModel, ProductStatus } from "#models/product.model";

const categories = new Set(['vegetable', 'fruit', 'grain', 'legume', 'herb', 'spice']);
const units = new Set(['kg', 'g', 'lb', 'oz', 'liter', 'ml', 'piece']);
// Statuses a seller may set directly. 'delisted' only happens through DELETE.
const sellerStatuses = new Set<string>(['available', 'out of stock']);

const readId = (value: unknown): number | undefined => {
    const n = Number(value);
    return Number.isInteger(n) && n > 0 ? n : undefined;
};

export const getProducts = (req: Request, res: Response): void => {
    const query = typeof req.query.q === 'string' ? req.query.q : '';
    const sellerId = typeof req.query.seller_id === 'string' ? Number(req.query.seller_id) : undefined;
    // A seller's own tab asks for sold-out rows too; public views never do.
    const includeUnavailable = req.query.include_unavailable === 'true';
    res.json({ success: true, data: ProductModel.findAll(query, Number.isInteger(sellerId) ? sellerId : undefined, includeUnavailable) });
};

export const getProduct = (req: Request, res: Response): void => {
    const product = ProductModel.findById(Number(req.params.id));
    if (!product) {
        res.status(404).json({ success: false, message: 'Listing not found' });
        return;
    }
    res.json({ success: true, data: product });
};

export const createProduct = (req: Request, res: Response): void => {
    const { seller_id, crop_name, category, base_price, available_quantity, unit_measurement, images } = req.body;
    if (!Number.isInteger(seller_id) || !crop_name || !categories.has(category) || !units.has(unit_measurement) || !Number.isFinite(Number(base_price)) || !Number.isFinite(Number(available_quantity)) || Number(base_price) <= 0 || Number(available_quantity) <= 0) {
        res.status(400).json({ success: false, message: 'seller_id, crop_name, category, price, quantity, and unit_measurement are required' });
        return;
    }
    const imageUrls = Array.isArray(images) ? images.filter((image): image is string => typeof image === 'string' && image.startsWith('http')) : [];
    try {
        const product = ProductModel.create({ seller_id, crop_name: crop_name.trim(), category, base_price: Number(base_price), available_quantity: Number(available_quantity), unit_measurement }, imageUrls);
        res.status(201).json({ success: true, data: product });
    } catch (error) {
        res.status(400).json({ success: false, message: error instanceof Error ? error.message : 'Unable to create listing' });
    }
};

// KNOWN DEBT: same stopgap as negotiations - the acting seller is `seller_id`
// in the request and is trusted. PLAN.md Phase 2 replaces it with a token;
// only this helper should have to change when it does.
const loadOwnedProduct = (req: Request, res: Response): ProductListing | undefined => {
    const productId = readId(req.params.id);
    const sellerId = readId(req.body?.seller_id ?? req.query.seller_id);
    if (!productId || !sellerId) {
        res.status(400).json({ success: false, message: 'seller_id is required' });
        return undefined;
    }
    const product = ProductModel.findById(productId);
    if (!product || product.status === 'delisted') {
        res.status(404).json({ success: false, message: 'Listing not found' });
        return undefined;
    }
    if (product.seller_id !== sellerId) {
        res.status(403).json({ success: false, message: 'Only the seller can change this listing' });
        return undefined;
    }
    return product;
};

// Seller edits the listing details and/or marks it sold out or available.
export const updateProduct = (req: Request, res: Response): void => {
    const product = loadOwnedProduct(req, res);
    if (!product) return;

    const { crop_name, category, base_price, available_quantity, unit_measurement, status } = req.body;
    const changes: ProductChanges = {};
    if (crop_name !== undefined) {
        if (typeof crop_name !== 'string' || !crop_name.trim()) {
            res.status(400).json({ success: false, message: 'crop_name cannot be empty' });
            return;
        }
        changes.crop_name = crop_name.trim();
    }
    if (category !== undefined) {
        if (!categories.has(category)) {
            res.status(400).json({ success: false, message: 'Unknown category' });
            return;
        }
        changes.category = category;
    }
    if (unit_measurement !== undefined) {
        if (!units.has(unit_measurement)) {
            res.status(400).json({ success: false, message: 'Unknown unit_measurement' });
            return;
        }
        changes.unit_measurement = unit_measurement;
    }
    if (base_price !== undefined) {
        if (!Number.isFinite(Number(base_price)) || Number(base_price) <= 0) {
            res.status(400).json({ success: false, message: 'base_price must be positive' });
            return;
        }
        changes.base_price = Number(base_price);
    }
    if (available_quantity !== undefined) {
        if (!Number.isFinite(Number(available_quantity)) || Number(available_quantity) < 0) {
            res.status(400).json({ success: false, message: 'available_quantity cannot be negative' });
            return;
        }
        changes.available_quantity = Number(available_quantity);
    }
    if (status !== undefined) {
        if (!sellerStatuses.has(status)) {
            res.status(400).json({ success: false, message: `status must be one of: ${[...sellerStatuses].join(', ')}` });
            return;
        }
        changes.status = status as ProductStatus;
    }

    try {
        res.json({ success: true, data: ProductModel.update(product.product_id, changes) });
    } catch (error) {
        res.status(400).json({ success: false, message: error instanceof Error ? error.message : 'Unable to update listing' });
    }
};

// Soft delete. The row stays so buyers' past offers on it keep resolving;
// it just never appears in any list again.
export const deleteProduct = (req: Request, res: Response): void => {
    const product = loadOwnedProduct(req, res);
    if (!product) return;
    ProductModel.update(product.product_id, { status: 'delisted' });
    res.json({ success: true, data: { product_id: product.product_id, status: 'delisted' } });
};
