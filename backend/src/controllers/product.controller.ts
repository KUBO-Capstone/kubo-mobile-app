import { Request, Response } from "express";
import { ProductModel } from "#models/product.model";

const categories = new Set(['vegetable', 'fruit', 'grain', 'legume', 'herb', 'spice']);
const units = new Set(['kg', 'g', 'lb', 'oz', 'liter', 'ml', 'piece']);

export const getProducts = (req: Request, res: Response): void => {
    const query = typeof req.query.q === 'string' ? req.query.q : '';
    const sellerId = typeof req.query.seller_id === 'string' ? Number(req.query.seller_id) : undefined;
    res.json({ success: true, data: ProductModel.findAll(query, Number.isInteger(sellerId) ? sellerId : undefined) });
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