import { Request, Response } from "express";
import { NegotiationModel, NegotiationStatus, OPEN_STATUSES } from "#models/negotiation.model";
import { ProductModel } from "#models/product.model";

// KNOWN DEBT: there is no auth middleware yet, so the acting user is taken
// from the request (`buyer_id` on create, `user_id` on respond) and trusted.
// PLAN.md Phase 2 replaces this with a token; nothing else should have to
// change here when it does.

const statuses = new Set<string>(['pending', 'countered', 'accepted', 'declined']);
const actions = new Set<string>(['accept', 'decline', 'counter']);

const positiveNumber = (value: unknown): number | undefined => {
    const n = Number(value);
    return Number.isFinite(n) && n > 0 ? n : undefined;
};

const readId = (value: unknown): number | undefined => {
    const n = Number(value);
    return Number.isInteger(n) && n > 0 ? n : undefined;
};

export const getNegotiations = (req: Request, res: Response): void => {
    const userId = readId(req.query.user_id);
    if (!userId) {
        res.status(400).json({ success: false, message: 'user_id is required' });
        return;
    }
    const role = req.query.role === 'buyer' || req.query.role === 'seller' ? req.query.role : undefined;
    const status = typeof req.query.status === 'string' && statuses.has(req.query.status)
        ? (req.query.status as NegotiationStatus)
        : undefined;
    res.json({ success: true, data: NegotiationModel.findForUser(userId, role, status) });
};

export const getNegotiation = (req: Request, res: Response): void => {
    const negotiation = NegotiationModel.findById(Number(req.params.id));
    if (!negotiation) {
        res.status(404).json({ success: false, message: 'Offer not found' });
        return;
    }
    res.json({ success: true, data: negotiation });
};

// Buyer opens a negotiation on a listing.
export const createNegotiation = (req: Request, res: Response): void => {
    const buyerId = readId(req.body.buyer_id);
    const productId = readId(req.body.product_id);
    const offeredPrice = positiveNumber(req.body.offered_price);
    const offeredQuantity = positiveNumber(req.body.offered_quantity);
    if (!buyerId || !productId || !offeredPrice || !offeredQuantity) {
        res.status(400).json({ success: false, message: 'buyer_id, product_id, offered_price, and offered_quantity are required and must be positive' });
        return;
    }

    const product = ProductModel.findById(productId);
    if (!product) {
        res.status(404).json({ success: false, message: 'Listing not found' });
        return;
    }
    if (product.status !== 'available') {
        res.status(409).json({ success: false, message: 'This listing is no longer available' });
        return;
    }
    if (product.seller_id === buyerId) {
        res.status(400).json({ success: false, message: 'You cannot make an offer on your own listing' });
        return;
    }
    if (offeredQuantity > product.available_quantity) {
        res.status(400).json({ success: false, message: `Only ${product.available_quantity} ${product.unit_measurement} available` });
        return;
    }
    if (NegotiationModel.findOpenForBuyer(buyerId, productId)) {
        res.status(409).json({ success: false, message: 'You already have an open offer on this listing' });
        return;
    }

    const negotiation = NegotiationModel.create({
        product_id: productId,
        buyer_id: buyerId,
        seller_id: product.seller_id,
        offered_price: offeredPrice,
        offered_quantity: offeredQuantity,
    });
    res.status(201).json({ success: true, data: negotiation });
};

// Either party moves the negotiation along. Who may do what depends on whose
// turn it is: 'pending' waits on the seller, 'countered' waits on the buyer.
// Declining is allowed from either side at any point while the offer is open.
export const respondToNegotiation = (req: Request, res: Response): void => {
    const userId = readId(req.body.user_id);
    const action = typeof req.body.action === 'string' ? req.body.action : '';
    if (!userId || !actions.has(action)) {
        res.status(400).json({ success: false, message: 'user_id and an action of accept, decline, or counter are required' });
        return;
    }

    const negotiation = NegotiationModel.findById(Number(req.params.id));
    if (!negotiation) {
        res.status(404).json({ success: false, message: 'Offer not found' });
        return;
    }
    const isBuyer = negotiation.buyer_id === userId;
    const isSeller = negotiation.seller_id === userId;
    if (!isBuyer && !isSeller) {
        res.status(403).json({ success: false, message: 'You are not part of this offer' });
        return;
    }
    if (!OPEN_STATUSES.includes(negotiation.status)) {
        res.status(409).json({ success: false, message: `This offer was already ${negotiation.status}` });
        return;
    }

    const awaitingSeller = negotiation.status === 'pending';
    const isMyTurn = awaitingSeller ? isSeller : isBuyer;

    if (action === 'decline') {
        res.json({ success: true, data: NegotiationModel.update(negotiation.negotiation_id, { status: 'declined' }) });
        return;
    }
    if (!isMyTurn) {
        res.status(409).json({ success: false, message: awaitingSeller ? 'Waiting for the seller to respond' : 'Waiting for the buyer to respond' });
        return;
    }
    if (action === 'accept') {
        res.json({ success: true, data: NegotiationModel.update(negotiation.negotiation_id, { status: 'accepted' }) });
        return;
    }

    // counter
    const offeredPrice = positiveNumber(req.body.offered_price);
    const offeredQuantity = req.body.offered_quantity === undefined ? negotiation.offered_quantity : positiveNumber(req.body.offered_quantity);
    if (!offeredPrice || !offeredQuantity) {
        res.status(400).json({ success: false, message: 'A counter needs a positive offered_price (and optionally offered_quantity)' });
        return;
    }
    const product = ProductModel.findById(negotiation.product_id);
    if (product && offeredQuantity > product.available_quantity) {
        res.status(400).json({ success: false, message: `Only ${product.available_quantity} ${product.unit_measurement} available` });
        return;
    }
    const updated = NegotiationModel.update(negotiation.negotiation_id, {
        status: isSeller ? 'countered' : 'pending',
        offered_price: offeredPrice,
        offered_quantity: offeredQuantity,
    });
    res.json({ success: true, data: updated });
};
