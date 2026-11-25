import { Request, Response } from "express";
import {
    DECLINE_REASONS,
    DeclineReason,
    Fulfillment,
    Negotiation,
    NegotiationModel,
    NegotiationStatus,
    OPEN_STATUSES,
} from "#models/negotiation.model";
import { ProductListing, ProductModel } from "#models/product.model";
import { BagsakanModel } from "#models/bagsakan.model";
import { FulfillmentModel, isCourier } from "#models/fulfillment.model";
import { OrderModel } from "#models/order.model";
import { MessageType } from "#models/message.model";
import { authUserId } from "#middleware/auth.middleware";
import { sendChatMessage } from "#services/chat.service";
import { isUniqueViolation } from "#database/pg";

// Mounted behind requireAuth: the acting user is always authUserId(res).

const statuses = new Set<string>(['pending', 'countered', 'accepted', 'declined']);
const actions = new Set<string>(['accept', 'decline', 'counter', 'cancel']);
const declineReasons = new Set<string>(DECLINE_REASONS);

// What each reason reads as in the thread.
export const declineReasonText: Record<DeclineReason, string> = {
    bagsakan_too_far: 'Selected bagsakan is too far',
    courier_unavailable: 'Courier not available in my area',
    price_too_low: 'Price too low',
};

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

// "Pickup at Malolos Kubo Bagsakan Center" / "Lalamove delivery"; empty for
// an offer from before terms carried this.
const fulfillmentText = (negotiation: Pick<Negotiation, 'delivery_method' | 'center_name' | 'courier_name'>): string => {
    if (negotiation.delivery_method === 'meetup') return `Pickup at ${negotiation.center_name ?? 'a bagsakan center'}`;
    if (negotiation.delivery_method === 'courier') return `${negotiation.courier_name ?? 'Courier'} delivery`;
    return '';
};

// Every offer step is also a message in the thread, so the chat reads as the
// negotiation history even though the negotiations row only keeps the latest
// terms. `content` is a plain-text fallback for clients that ignore the type.
// The negotiations row is already committed by the time this runs, so a
// failed DynamoDB write is logged rather than failing the request.
const recordOfferEvent = async (negotiation: Negotiation, actorId: number, type: MessageType): Promise<void> => {
    const terms = `PHP ${formatAmount(negotiation.offered_price)}/${negotiation.unit_measurement} x ${formatAmount(negotiation.offered_quantity)} ${negotiation.unit_measurement}`;
    const details = fulfillmentText(negotiation);
    const reason = type === 'declined' && negotiation.decline_reason ? declineReasonText[negotiation.decline_reason] : '';
    const content = type === 'offer' ? `Offered ${terms}${details ? `, ${details.toLowerCase()}` : ''}`
        : type === 'counter' ? `Countered ${terms}${details ? `, ${details.toLowerCase()}` : ''}`
        : type === 'accepted' ? `Accepted the offer of ${terms}`
        : type === 'cancelled' ? `Cancelled the deal for ${terms}`
        : `Declined the offer of ${terms}${reason ? ` (${reason})` : ''}`;
    try {
        await sendChatMessage({
            conversation_id: negotiation.conversation_id,
            sender_id: actorId,
            content,
            message_type: type,
            negotiation_id: negotiation.negotiation_id,
            offer_price: negotiation.offered_price,
            offer_quantity: negotiation.offered_quantity,
            ...(details ? { offer_details: details } : {}),
            ...(negotiation.decline_reason && type === 'declined' ? { decline_reason: negotiation.decline_reason } : {}),
        });
    } catch (error) {
        console.error(`Could not record ${type} event for negotiation ${negotiation.negotiation_id}:`, error);
    }
};

// The order an accept created shows up in the thread like one the buyer
// placed, so the chat still tells the whole story of the deal.
const recordOrderCreated = async (negotiation: Negotiation, actorId: number, orderId: number): Promise<void> => {
    const order = await OrderModel.findById(orderId);
    if (!order) return;
    const handover = order.delivery_method === 'meetup'
        ? `pickup at ${order.center_name ?? 'a bagsakan center'}`
        : `${order.courier_name ?? 'courier'} delivery`;
    try {
        await sendChatMessage({
            conversation_id: negotiation.conversation_id,
            sender_id: actorId,
            content: `Order #${order.order_id} placed: ${formatAmount(order.quantity)} ${order.unit_measurement} for PHP ${formatAmount(order.total_amount)}, ${handover}`,
            message_type: 'order',
            negotiation_id: negotiation.negotiation_id,
            order_id: order.order_id,
        });
    } catch (error) {
        console.error(`Could not record the order for negotiation ${negotiation.negotiation_id}:`, error);
    }
};

// The other party acted between our read and our write, so the offer is no
// longer in the state this request was checked against.
const changedMeanwhile = (res: Response): void => {
    res.status(409).json({ success: false, message: 'This offer was just updated. Refresh to see the latest.' });
};

// Why the listing cannot cover an offer someone tried to accept. Accepting
// takes the quantity off the listing, and other accepted offers may have
// taken stock since this one was made.
const cannotCover = (product: ProductListing | undefined): string => {
    if (!product || product.status === 'delisted') return 'This listing has been removed, so the offer can no longer be accepted';
    if (product.available_quantity <= 0) return 'Nothing is left on this listing, so the offer can no longer be accepted';
    return `Only ${formatAmount(product.available_quantity)} ${product.unit_measurement} left on this listing. Counter with a smaller quantity instead.`;
};

type Parsed<T> = { value: T; error?: undefined; status?: undefined } | { value?: undefined; error: string; status: number };

// Reads how the produce would change hands from a request body and checks
// it against the listing and, for a buyer, against what the seller can do
// on this listing (its own choices, or the profile's). A seller countering
// may name any center or courier: it is their own reach they are deciding
// about.
const readFulfillment = async (body: Record<string, unknown>, product: ProductListing, actorIsBuyer: boolean): Promise<Parsed<Fulfillment>> => {
    const method = body.delivery_method;
    if (method !== 'meetup' && method !== 'courier') {
        return { error: 'Choose pickup at a bagsakan center or courier delivery', status: 400 };
    }
    if (method === 'meetup' && !product.allows_meetup) return { error: 'This seller does not offer bagsakan center pickup for this listing', status: 400 };
    if (method === 'courier' && !product.allows_delivery) return { error: 'This seller does not offer courier delivery for this listing', status: 400 };

    const reach = actorIsBuyer ? await FulfillmentModel.forProduct(product.product_id) : undefined;
    if (method === 'meetup') {
        const centerId = readId(body.drop_off_center_id);
        if (!centerId) return { error: 'Pick a bagsakan center for pickup', status: 400 };
        const center = await BagsakanModel.findById(centerId);
        if (!center) return { error: 'Bagsakan center not found', status: 404 };
        if (reach && !reach.centers.some((entry) => entry.center_id === centerId && entry.supported)) {
            return { error: `${center.location_name} is not serviceable in the seller's area. Pick one of the centers the seller supports.`, status: 400 };
        }
        return { value: { delivery_method: 'meetup', drop_off_center_id: centerId, courier_name: null } };
    }
    const courier = body.courier_name;
    if (!isCourier(courier)) return { error: 'Choose a courier Kubo works with', status: 400 };
    if (reach && !reach.couriers.some((entry) => entry.name === courier && entry.supported)) {
        return { error: `${courier} is not available in the seller's area. Pick one of the couriers the seller can book.`, status: 400 };
    }
    return { value: { delivery_method: 'courier', drop_off_center_id: null, courier_name: courier } };
};

export const getNegotiations = async (req: Request, res: Response): Promise<void> => {
    const userId = authUserId(res);
    const role = req.query.role === 'buyer' || req.query.role === 'seller' ? req.query.role : undefined;
    const status = typeof req.query.status === 'string' && statuses.has(req.query.status)
        ? (req.query.status as NegotiationStatus)
        : undefined;
    res.json({ success: true, data: await NegotiationModel.findForUser(userId, role, status) });
};

export const getNegotiation = async (req: Request, res: Response): Promise<void> => {
    const negotiation = await NegotiationModel.findById(Number(req.params.id));
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

// Buyer opens a negotiation on a listing: a price, a quantity, and how they
// want the produce handed over.
export const createNegotiation = async (req: Request, res: Response): Promise<void> => {
    const buyerId = authUserId(res);
    const body: Record<string, unknown> = req.body ?? {};
    const productId = readId(body.product_id);
    const offeredPrice = positiveNumber(body.offered_price);
    const offeredQuantity = positiveNumber(body.offered_quantity);
    if (!productId || !offeredPrice || !offeredQuantity) {
        res.status(400).json({ success: false, message: 'product_id, offered_price, and offered_quantity are required and must be positive' });
        return;
    }

    const product = await ProductModel.findById(productId);
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
    const fulfillment = await readFulfillment(body, product, true);
    if (fulfillment.error !== undefined) {
        res.status(fulfillment.status).json({ success: false, message: fulfillment.error });
        return;
    }
    const alreadyOpen = () => res.status(409).json({ success: false, message: 'You already have an open offer on this listing' });
    if (await NegotiationModel.findOpenForBuyer(buyerId, productId)) {
        alreadyOpen();
        return;
    }

    let negotiation: Negotiation;
    try {
        negotiation = await NegotiationModel.create({
            product_id: productId,
            buyer_id: buyerId,
            seller_id: product.seller_id,
            offered_price: offeredPrice,
            offered_quantity: offeredQuantity,
            ...fulfillment.value,
        });
    } catch (error) {
        // A second tap that raced past the check above.
        if (isUniqueViolation(error, 'uq_negotiations_open_offer')) {
            alreadyOpen();
            return;
        }
        throw error;
    }
    await recordOfferEvent(negotiation, buyerId, 'offer');
    res.status(201).json({ success: true, data: negotiation });
};

// Either party moves the negotiation along. Who may do what depends on whose
// turn it is: 'pending' waits on the seller, 'countered' waits on the buyer.
// Declining is allowed from either side at any point while the offer is open,
// and cancelling from either side once it is accepted, until it is ordered.
export const respondToNegotiation = async (req: Request, res: Response): Promise<void> => {
    const userId = authUserId(res);
    const body: Record<string, unknown> = req.body ?? {};
    const action = typeof body.action === 'string' ? body.action : '';
    if (!actions.has(action)) {
        res.status(400).json({ success: false, message: 'An action of accept, decline, counter, or cancel is required' });
        return;
    }

    const negotiation = await NegotiationModel.findById(Number(req.params.id));
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

    // Calls off an accepted deal that has no order yet; the stock it was
    // holding goes back on the listing.
    if (action === 'cancel') {
        if (negotiation.status !== 'accepted') {
            res.status(409).json({
                success: false,
                message: OPEN_STATUSES.includes(negotiation.status)
                    ? 'This offer has not been accepted yet. Decline it instead.'
                    : `This offer was already ${negotiation.status}`,
            });
            return;
        }
        const cancelled = await NegotiationModel.cancelDeal(negotiation.negotiation_id);
        if (cancelled.refused === 'ordered') {
            res.status(409).json({ success: false, message: 'This deal already has an order. Cancel the order instead.' });
            return;
        }
        if (cancelled.refused) {
            changedMeanwhile(res);
            return;
        }
        await recordOfferEvent(cancelled.negotiation, userId, 'cancelled');
        res.json({ success: true, data: cancelled.negotiation });
        return;
    }

    if (!OPEN_STATUSES.includes(negotiation.status)) {
        res.status(409).json({ success: false, message: `This offer was already ${negotiation.status}` });
        return;
    }

    const awaitingSeller = negotiation.status === 'pending';
    const isMyTurn = awaitingSeller ? isSeller : isBuyer;

    if (action === 'decline') {
        // A seller picks why from a short list so the buyer knows what to
        // change; a buyer withdrawing or turning a counter down gives none.
        let reason: DeclineReason | null = null;
        if (body.reason !== undefined && body.reason !== null && body.reason !== '') {
            if (!isSeller || typeof body.reason !== 'string' || !declineReasons.has(body.reason)) {
                res.status(400).json({ success: false, message: `reason must be one of: ${DECLINE_REASONS.join(', ')}` });
                return;
            }
            reason = body.reason as DeclineReason;
        }
        const declined = await NegotiationModel.update(negotiation.negotiation_id, negotiation, { status: 'declined', decline_reason: reason });
        if (!declined) {
            changedMeanwhile(res);
            return;
        }
        await recordOfferEvent(declined, userId, 'declined');
        res.json({ success: true, data: declined });
        return;
    }
    if (!isMyTurn) {
        res.status(409).json({ success: false, message: awaitingSeller ? 'Waiting for the seller to respond' : 'Waiting for the buyer to respond' });
        return;
    }
    if (action === 'accept') {
        // Accepting locks the terms: the quantity comes off the listing and,
        // when the offer says how the produce changes hands, the order is
        // created from those terms there and then.
        const accepted = await NegotiationModel.accept(negotiation.negotiation_id, negotiation, userId);
        if (accepted.refused === 'unavailable') {
            res.status(409).json({ success: false, message: cannotCover(await ProductModel.findById(negotiation.product_id)) });
            return;
        }
        if (accepted.refused === 'method_unavailable') {
            res.status(409).json({
                success: false,
                message: negotiation.delivery_method === 'meetup'
                    ? 'Bagsakan center pickup is turned off on this listing. Counter with courier delivery instead.'
                    : 'Courier delivery is turned off on this listing. Counter with bagsakan center pickup instead.',
            });
            return;
        }
        if (accepted.refused) {
            changedMeanwhile(res);
            return;
        }
        await recordOfferEvent(accepted.negotiation, userId, 'accepted');
        if (accepted.order_id !== undefined) await recordOrderCreated(accepted.negotiation, userId, accepted.order_id);
        res.json({ success: true, data: { ...accepted.negotiation, order_id: accepted.order_id ?? null } });
        return;
    }

    // counter: new price, optionally a new quantity, optionally a new way to
    // hand the produce over (a seller moving the pickup to a center they can
    // reach, or pricing a farther one in).
    const offeredPrice = positiveNumber(body.offered_price);
    const offeredQuantity = body.offered_quantity === undefined ? negotiation.offered_quantity : positiveNumber(body.offered_quantity);
    if (!offeredPrice || !offeredQuantity) {
        res.status(400).json({ success: false, message: 'A counter needs a positive offered_price (and optionally offered_quantity)' });
        return;
    }
    const product = await ProductModel.findById(negotiation.product_id);
    if (product && offeredQuantity > product.available_quantity) {
        res.status(400).json({ success: false, message: `Only ${product.available_quantity} ${product.unit_measurement} available` });
        return;
    }
    let fulfillment: Fulfillment | undefined;
    if (body.delivery_method !== undefined && product) {
        const parsed = await readFulfillment(body, product, isBuyer);
        if (parsed.error !== undefined) {
            res.status(parsed.status).json({ success: false, message: parsed.error });
            return;
        }
        fulfillment = parsed.value;
    }
    const updated = await NegotiationModel.update(negotiation.negotiation_id, negotiation, {
        status: isSeller ? 'countered' : 'pending',
        offered_price: offeredPrice,
        offered_quantity: offeredQuantity,
        fulfillment,
    });
    if (!updated) {
        changedMeanwhile(res);
        return;
    }
    await recordOfferEvent(updated, userId, 'counter');
    res.json({ success: true, data: updated });
};

// The app calls this once it has shown the caller the "deal closed" screen,
// which comes when the buyer has confirmed receipt, so each side sees it
// exactly once.
export const markNegotiationCelebrated = async (req: Request, res: Response): Promise<void> => {
    const userId = authUserId(res);
    const negotiation = await NegotiationModel.findById(Number(req.params.id));
    if (!negotiation) {
        res.status(404).json({ success: false, message: 'Offer not found' });
        return;
    }
    const isBuyer = negotiation.buyer_id === userId;
    if (!isBuyer && negotiation.seller_id !== userId) {
        res.status(403).json({ success: false, message: 'You are not part of this offer' });
        return;
    }
    const order = await OrderModel.findByNegotiation(negotiation.negotiation_id);
    if (order?.order_status !== 'delivered') {
        res.status(409).json({ success: false, message: 'The deal closes once the buyer has confirmed receipt' });
        return;
    }
    await NegotiationModel.markCelebrated(negotiation.negotiation_id, isBuyer ? 'buyer' : 'seller');
    res.json({ success: true, data: { negotiation_id: negotiation.negotiation_id, celebrated: true } });
};
