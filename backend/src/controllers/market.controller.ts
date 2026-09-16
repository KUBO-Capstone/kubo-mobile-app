import { Request, Response } from "express";
import { CLASSIFICATIONS, MarketClassification, MarketModel } from "#models/market.model";

// Read-only reference data; no identity involved, so nothing to trust here.

export const getMarketProducts = (req: Request, res: Response): void => {
    const query = typeof req.query.q === 'string' ? req.query.q : '';
    const raw = typeof req.query.classification === 'string' ? req.query.classification : '';
    if (raw && !CLASSIFICATIONS.includes(raw as MarketClassification)) {
        res.status(400).json({ success: false, message: `classification must be one of: ${CLASSIFICATIONS.join(', ')}` });
        return;
    }
    res.json({ success: true, data: MarketModel.listProducts(query, raw ? (raw as MarketClassification) : undefined) });
};

export const getMarketProduct = (req: Request, res: Response): void => {
    const product = MarketModel.findProduct(Number(req.params.id));
    if (!product) {
        res.status(404).json({ success: false, message: 'Market product not found' });
        return;
    }
    res.json({ success: true, data: product });
};

// Reference price for a listing: `crop` is the listing's crop_name, `region`
// the seller's region label in either short or long form. 404 when no market
// product matches, so the listing page can simply show nothing.
export const getMarketReference = (req: Request, res: Response): void => {
    const crop = typeof req.query.crop === 'string' ? req.query.crop : '';
    const region = typeof req.query.region === 'string' ? req.query.region : undefined;
    if (!crop.trim()) {
        res.status(400).json({ success: false, message: 'crop is required' });
        return;
    }
    const reference = MarketModel.findReference(crop, region);
    if (!reference) {
        res.status(404).json({ success: false, message: 'No market reference price for this crop' });
        return;
    }
    res.json({ success: true, data: reference });
};
