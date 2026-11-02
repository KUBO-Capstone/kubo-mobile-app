import { Request, Response } from "express";
import { DeliveryMethod, Order, OrderModel, OrderStatus } from "#models/order.model";
import { NegotiationModel } from "#models/negotiation.model";
import { ProductListing, ProductModel } from "#models/product.model";
import { BagsakanModel } from "#models/bagsakan.model";
import { ReviewModel } from "#models/review.model";
import { authUserId } from "#middleware/auth.middleware";
import { sendChatMessage } from "#services/chat.service";
import { isUniqueViolation } from "#database/pg";

// Mounted behind requireAuth: the acting user is always authUserId(res).

const statuses = new Set<string>(['pending', 'in transit', 'delivered', 'cancelled']);
const methods = new Set<string>(['courier', 'meetup']);
const actions = new Set<string>(['ship', 'deliver', 'cancel']);

const readId = (value: unknown): number | undefined => {
    const n = Number(value);
    return Number.isInteger(n) && n > 0 ? n : undefined;
};

const readText = (value: unknown): string => (typeof value === 'string' ? value.trim() : '');

// Why the listing cannot take this order, or undefined if it can.
// OrderModel.create checks the same things again in its stock update.
const listingProblem = (product: ProductListing | undefined, method: string, quantity: number): string | undefined => {
    if (!product || product.status === 'delisted') return 'This listing has been removed';
    if (method === 'meetup' && !product.allows_meetup) return 'This seller does not offer bagsakan center pickup for this listing';
    if (method === 'courier' && !product.allows_delivery) return 'This seller does not offer courier delivery for this listing';
    if (quantity > product.available_quantity) return `Only ${product.available_quantity} ${product.unit_measurement} left on this listing`;
    return undefined;
};

const formatAmount = (value: number): string =>
    Number.isInteger(value) ? String(value) : value.toFixed(2);

// Order steps show up in the buyer/seller thread next to the offer events,
// so the chat stays the one place that tells the whole story of a deal.
// The order row is already committed by the time this runs, so a failed
// DynamoDB write is logged rather than failing the request.
const recordOrderEvent = async (order: Order, actorId: number, content: string): Promise<void> => {
    try {
        await sendChatMessage({
            conversation_id: order.conversation_id,
            sender_id: actorId,
            content,
            message_type: 'order',
            negotiation_id: order.negotiation_id,
            order_id: order.order_id,
        });
    } catch (error) {
        console.error(`Could not record event for order ${order.order_id}:`, error);
    }
};

const describeHandover = (order: Order): string =>
    order.delivery_method === 'meetup'
        ? `pickup at ${order.center_name ?? 'a bagsakan center'}`
        : 'courier delivery';

// Orders as the viewer sees them: each plus the review they wrote and the
// one the other party wrote about them, null until written. One reviews
// query covers the whole list.
const presentAll = async (orders: Order[], viewerId: number) => {
    const reviews = await ReviewModel.findForOrders(orders.map((order) => order.order_id));
    const reviewBy = (orderId: number, reviewerId: number) =>
        reviews.find((review) => review.order_id === orderId && review.reviewer_id === reviewerId) ?? null;
    return orders.map((order) => {
        const otherId = order.buyer_id === viewerId ? order.seller_id : order.buyer_id;
        return { ...order, my_review: reviewBy(order.order_id, viewerId), their_review: reviewBy(order.order_id, otherId) };
    });
};

const present = async (order: Order, viewerId: number) => (await presentAll([order], viewerId))[0];

// Someone acted on the order between our read and our write (the other
// party, or a second tap), so it is no longer in the state that was checked.
const changedMeanwhile = (res: Response): void => {
    res.status(409).json({ success: false, message: 'This order was just updated. Refresh to see its status.' });
};

export const getOrders = async (req: Request, res: Response): Promise<void> => {
    const userId = authUserId(res);
    const role = req.query.role === 'buyer' || req.query.role === 'seller' ? req.query.role : undefined;
    const status = typeof req.query.status === 'string' && statuses.has(req.query.status)
        ? (req.query.status as OrderStatus)
        : undefined;
    res.json({ success: true, data: await presentAll(await OrderModel.findForUser(userId, role, status), userId) });
};

export const getOrder = async (req: Request, res: Response): Promise<void> => {
    const userId = authUserId(res);
    const order = await OrderModel.findById(Number(req.params.id));
    if (!order) {
        res.status(404).json({ success: false, message: 'Order not found' });
        return;
    }
    if (order.buyer_id !== userId && order.seller_id !== userId) {
        res.status(403).json({ success: false, message: 'You are not part of this order' });
        return;
    }
    res.json({ success: true, data: await present(order, userId) });
};

// Buyer turns an accepted offer into an order by choosing how to get the
// produce: collect it at a bagsakan center or have it couriered.
export const createOrder = async (req: Request, res: Response): Promise<void> => {
    const buyerId = authUserId(res);
    const negotiationId = readId(req.body.negotiation_id);
    const method = readText(req.body.delivery_method);
    if (!negotiationId || !methods.has(method)) {
        res.status(400).json({ success: false, message: 'negotiation_id and a delivery_method of meetup or courier are required' });
        return;
    }

    const negotiation = await NegotiationModel.findById(negotiationId);
    if (!negotiation) {
        res.status(404).json({ success: false, message: 'Offer not found' });
        return;
    }
    if (negotiation.buyer_id !== buyerId) {
        res.status(403).json({ success: false, message: 'Only the buyer can place this order' });
        return;
    }
    if (negotiation.status !== 'accepted') {
        res.status(409).json({ success: false, message: 'Only an accepted offer can be ordered' });
        return;
    }
    const alreadyOrdered = () => res.status(409).json({ success: false, message: 'This offer has already been ordered' });
    if (await OrderModel.findByNegotiation(negotiationId)) {
        alreadyOrdered();
        return;
    }

    const problem = listingProblem(await ProductModel.findById(negotiation.product_id), method, negotiation.offered_quantity);
    if (problem) {
        res.status(409).json({ success: false, message: problem });
        return;
    }

    let centerId: number | null = null;
    if (method === 'meetup') {
        centerId = readId(req.body.drop_off_center_id) ?? null;
        if (!centerId) {
            res.status(400).json({ success: false, message: 'Pick a bagsakan center for pickup' });
            return;
        }
        if (!(await BagsakanModel.findById(centerId))) {
            res.status(404).json({ success: false, message: 'Bagsakan center not found' });
            return;
        }
    }

    let order: Order | undefined;
    try {
        order = await OrderModel.create({
            negotiation_id: negotiationId,
            buyer_id: buyerId,
            seller_id: negotiation.seller_id,
            product_id: negotiation.product_id,
            quantity: negotiation.offered_quantity,
            negotiated_price: negotiation.offered_price,
            delivery_method: method as DeliveryMethod,
            drop_off_center_id: centerId,
        });
    } catch (error) {
        // A second tap that raced past the "already ordered" check.
        if (isUniqueViolation(error)) {
            alreadyOrdered();
            return;
        }
        throw error;
    }
    if (!order) {
        // The listing changed after the check above: another order took the
        // stock, or the seller delisted it or turned this method off.
        const changed = listingProblem(await ProductModel.findById(negotiation.product_id), method, negotiation.offered_quantity);
        res.status(409).json({ success: false, message: changed ?? 'This listing just changed. Refresh and try again.' });
        return;
    }
    await recordOrderEvent(
        order,
        buyerId,
        `Placed order #${order.order_id}: ${formatAmount(order.quantity)} ${order.unit_measurement} for PHP ${formatAmount(order.total_amount)}, ${describeHandover(order)}`,
    );
    res.status(201).json({ success: true, data: await present(order, buyerId) });
};

// Seller moves it out the door, buyer confirms it arrived, either side can
// cancel while nothing has moved yet.
export const updateOrder = async (req: Request, res: Response): Promise<void> => {
    const userId = authUserId(res);
    const action = readText(req.body.action);
    if (!actions.has(action)) {
        res.status(400).json({ success: false, message: 'An action of ship, deliver, or cancel are required' });
        return;
    }

    const order = await OrderModel.findById(Number(req.params.id));
    if (!order) {
        res.status(404).json({ success: false, message: 'Order not found' });
        return;
    }
    const isBuyer = order.buyer_id === userId;
    const isSeller = order.seller_id === userId;
    if (!isBuyer && !isSeller) {
        res.status(403).json({ success: false, message: 'You are not part of this order' });
        return;
    }

    if (action === 'cancel') {
        if (order.order_status !== 'pending') {
            res.status(409).json({ success: false, message: `An order that is ${order.order_status} can no longer be cancelled` });
            return;
        }
        const cancelled = await OrderModel.cancel(order.order_id);
        if (!cancelled) {
            changedMeanwhile(res);
            return;
        }
        await recordOrderEvent(cancelled, userId, `Cancelled order #${order.order_id}`);
        res.json({ success: true, data: await present(cancelled, userId) });
        return;
    }

    if (action === 'ship') {
        if (!isSeller) {
            res.status(403).json({ success: false, message: 'Only the seller can mark an order as on its way' });
            return;
        }
        if (order.order_status !== 'pending') {
            res.status(409).json({ success: false, message: `This order is already ${order.order_status}` });
            return;
        }
        // Both optional for a courier order: the seller may send the
        // courier's tracking link or details in the chat instead.
        const courierName = order.delivery_method === 'courier' ? readText(req.body.courier_name) : '';
        const trackingNumber = order.delivery_method === 'courier' ? readText(req.body.tracking_number) : '';
        if (courierName.length > 100 || trackingNumber.length > 100) {
            res.status(400).json({ success: false, message: 'courier_name and tracking_number can be at most 100 characters' });
            return;
        }
        const shipped = await OrderModel.ship(order.order_id, {
            courier_name: courierName || null,
            tracking_number: trackingNumber || null,
        });
        if (!shipped) {
            changedMeanwhile(res);
            return;
        }
        await recordOrderEvent(
            shipped,
            userId,
            order.delivery_method === 'courier'
                ? `Order #${order.order_id} ${courierName ? `handed to ${courierName}` : 'is on its way'}${trackingNumber ? ` (tracking ${trackingNumber})` : ''}`
                : `Order #${order.order_id} is ready for pickup at ${shipped.center_name ?? 'the bagsakan center'}`,
        );
        res.json({ success: true, data: await present(shipped, userId) });
        return;
    }

    // deliver
    if (!isBuyer) {
        res.status(403).json({ success: false, message: 'Only the buyer can confirm receipt' });
        return;
    }
    if (order.order_status !== 'in transit') {
        res.status(409).json({
            success: false,
            message: order.order_status === 'pending'
                ? 'The seller has not marked this order as on its way yet'
                : `This order is already ${order.order_status}`,
        });
        return;
    }
    const delivered = await OrderModel.deliver(order.order_id);
    if (!delivered) {
        changedMeanwhile(res);
        return;
    }
    await recordOrderEvent(
        delivered,
        userId,
        order.delivery_method === 'meetup'
            ? `Picked up order #${order.order_id}`
            : `Received order #${order.order_id}`,
    );
    res.json({ success: true, data: await present(delivered, userId) });
};
