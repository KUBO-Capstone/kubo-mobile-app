import { Request, Response } from "express";
import { Negotiation, NegotiationModel, NegotiationStatus, OPEN_STATUSES } from "#models/negotiation.model";
import { ProductModel } from "#models/product.model";
import { MessageType } from "#models/message.model";
import { authUserId } from "#middleware/auth.middleware";
import { sendChatMessage } from "#services/chat.service";

// Mounted behind requireAuth: the acting user is always authUserId(res).

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

const formatAmount = (value: number): string =>
    Number.isInteger(value) ? String(value) : value.toFixed(2);

// Every offer step is also a message in the thread, so the chat reads as the
// negotiation history even though the negotiations row only keeps the latest
// terms. `content` is a plain-text fallback for clients that ignore the type.
// The negotiations row is already committed by the time this runs, so a
// failed DynamoDB write is logged rather than failing the request.
const recordOfferEvent = async (negotiation: Negotiation, actorId: number, type: MessageType): Promise<void> => {
    const terms = `PHP ${formatAmount(negotiation.offered_price)}/${negotiation.unit_measurement} x ${formatAmount(negotiation.offered_quantity)} ${negotiation.unit_measurement}`;
    const content = type === 'offer' ? `Offered ${terms}`
        : type === 'counter' ? `Countered ${terms}`
        : type === 'accepted' ? `Accepted the offer of ${terms}`
        : `Declined the offer of ${terms}`;
    try {
        await sendChatMessage({
            conversation_id: negotiation.conversation_id,
            sender_id: actorId,
            content,
            message_type: type,
            negotiation_id: negotiation.negotiation_id,
            offer_price: negotiation.offered_price,
            offer_quantity: negotiation.offered_quantity,
        });
    } catch (error) {
        console.error(`Could not record ${type} event for negotiation ${negotiation.negotiation_id}:`, error);
    }
};

export const getNegotiations = (req: Request, res: Response): void => {
    const userId = authUserId(res);
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
    const userId = authUserId(res);
    if (negotiation.buyer_id !== userId && negotiation.seller_id !== userId) {
        res.status(403).json({ success: false, message: 'You are not part of this offer' });
        return;
    }
    res.json({ success: true, data: negotiation });
};

// Buyer opens a negotiation on a listing.
export const createNegotiation = async (req: Request, res: Response): Promise<void> => {
    const buyerId = authUserId(res);
    const productId = readId(req.body.product_id);
    const offeredPrice = positiveNumber(req.body.offered_price);
    const offeredQuantity = positiveNumber(req.body.offered_quantity);
    if (!productId || !offeredPrice || !offeredQuantity) {
        res.status(400).json({ success: false, message: 'product_id, offered_price, and offered_quantity are required and must be positive' });
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
    await recordOfferEvent(negotiation, buyerId, 'offer');
    res.status(201).json({ success: true, data: negotiation });
};

// Either party moves the negotiation along. Who may do what depends on whose
// turn it is: 'pending' waits on the seller, 'countered' waits on the buyer.
// Declining is allowed from either side at any point while the offer is open.
export const respondToNegotiation = async (req: Request, res: Response): Promise<void> => {
    const userId = authUserId(res);
    const action = typeof req.body.action === 'string' ? req.body.action : '';
    if (!actions.has(action)) {
        res.status(400).json({ success: false, message: 'An action of accept, decline, or counter is required' });
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
        const declined = NegotiationModel.update(negotiation.negotiation_id, { status: 'declined' }) as Negotiation;
        await recordOfferEvent(declined, userId, 'declined');
        res.json({ success: true, data: declined });
        return;
    }
    if (!isMyTurn) {
        res.status(409).json({ success: false, message: awaitingSeller ? 'Waiting for the seller to respond' : 'Waiting for the buyer to respond' });
        return;
    }
    if (action === 'accept') {
        const accepted = NegotiationModel.update(negotiation.negotiation_id, { status: 'accepted' }) as Negotiation;
        await recordOfferEvent(accepted, userId, 'accepted');
        res.json({ success: true, data: accepted });
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
    }) as Negotiation;
    await recordOfferEvent(updated, userId, 'counter');
    res.json({ success: true, data: updated });
};
