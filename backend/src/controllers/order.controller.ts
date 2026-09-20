import { Request, Response } from "express";
import { DeliveryMethod, Order, OrderModel, OrderStatus } from "#models/order.model";
import { NegotiationModel } from "#models/negotiation.model";
import { ProductModel } from "#models/product.model";
import { BagsakanModel } from "#models/bagsakan.model";
import { ConversationModel } from "#models/conversation.model";

// KNOWN DEBT: same identity stopgap as negotiations - the acting user is
// `buyer_id` on create and `user_id` on update, trusted from the body until
// PLAN.md Phase 2 puts a token in front of these routes.

const statuses = new Set<string>(['pending', 'in transit', 'delivered', 'cancelled']);
const methods = new Set<string>(['courier', 'meetup']);
const actions = new Set<string>(['ship', 'deliver', 'cancel']);

const readId = (value: unknown): number | undefined => {
    const n = Number(value);
    return Number.isInteger(n) && n > 0 ? n : undefined;
};

const readText = (value: unknown): string => (typeof value === 'string' ? value.trim() : '');

const formatAmount = (value: number): string =>
    Number.isInteger(value) ? String(value) : value.toFixed(2);

// Order steps show up in the buyer/seller thread next to the offer events,
// so the chat stays the one place that tells the whole story of a deal.
const recordOrderEvent = (order: Order, actorId: number, content: string): void => {
    ConversationModel.addMessage({
        conversation_id: order.conversation_id,
        sender_id: actorId,
        content,
        message_type: 'order',
        negotiation_id: order.negotiation_id,
        order_id: order.order_id,
    });
};

const describeHandover = (order: Order): string =>
    order.delivery_method === 'meetup'
        ? `pickup at ${order.center_name ?? 'a bagsakan center'}`
        : 'courier delivery';

export const getOrders = (req: Request, res: Response): void => {
    const userId = readId(req.query.user_id);
    if (!userId) {
        res.status(400).json({ success: false, message: 'user_id is required' });
        return;
    }
    const role = req.query.role === 'buyer' || req.query.role === 'seller' ? req.query.role : undefined;
    const status = typeof req.query.status === 'string' && statuses.has(req.query.status)
        ? (req.query.status as OrderStatus)
        : undefined;
    res.json({ success: true, data: OrderModel.findForUser(userId, role, status) });
};

export const getOrder = (req: Request, res: Response): void => {
    const userId = readId(req.query.user_id);
    if (!userId) {
        res.status(400).json({ success: false, message: 'user_id is required' });
        return;
    }
    const order = OrderModel.findById(Number(req.params.id));
    if (!order) {
        res.status(404).json({ success: false, message: 'Order not found' });
        return;
    }
    if (order.buyer_id !== userId && order.seller_id !== userId) {
        res.status(403).json({ success: false, message: 'You are not part of this order' });
        return;
    }
    res.json({ success: true, data: order });
};

// Buyer turns an accepted offer into an order by choosing how to get the
// produce: collect it at a bagsakan center or have it couriered.
export const createOrder = (req: Request, res: Response): void => {
    const buyerId = readId(req.body.buyer_id);
    const negotiationId = readId(req.body.negotiation_id);
    const method = readText(req.body.delivery_method);
    if (!buyerId || !negotiationId || !methods.has(method)) {
        res.status(400).json({ success: false, message: 'buyer_id, negotiation_id and a delivery_method of meetup or courier are required' });
        return;
    }

    const negotiation = NegotiationModel.findById(negotiationId);
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
    if (OrderModel.findByNegotiation(negotiationId)) {
        res.status(409).json({ success: false, message: 'This offer has already been ordered' });
        return;
    }

    const product = ProductModel.findById(negotiation.product_id);
    if (!product || product.status === 'delisted') {
        res.status(409).json({ success: false, message: 'This listing has been removed' });
        return;
    }
    if (negotiation.offered_quantity > product.available_quantity) {
        res.status(409).json({ success: false, message: `Only ${product.available_quantity} ${product.unit_measurement} left on this listing` });
        return;
    }

    let centerId: number | null = null;
    if (method === 'meetup') {
        centerId = readId(req.body.drop_off_center_id) ?? null;
        if (!centerId) {
            res.status(400).json({ success: false, message: 'Pick a bagsakan center for pickup' });
            return;
        }
        if (!BagsakanModel.findById(centerId)) {
            res.status(404).json({ success: false, message: 'Bagsakan center not found' });
            return;
        }
    }

    const order = OrderModel.create({
        negotiation_id: negotiationId,
        buyer_id: buyerId,
        seller_id: negotiation.seller_id,
        product_id: negotiation.product_id,
        quantity: negotiation.offered_quantity,
        negotiated_price: negotiation.offered_price,
        delivery_method: method as DeliveryMethod,
        drop_off_center_id: centerId,
    });
    recordOrderEvent(
        order,
        buyerId,
        `Placed order #${order.order_id}: ${formatAmount(order.quantity)} ${order.unit_measurement} for PHP ${formatAmount(order.total_amount)}, ${describeHandover(order)}`,
    );
    res.status(201).json({ success: true, data: order });
};

// Seller moves it out the door, buyer confirms it arrived, either side can
// cancel while nothing has moved yet.
export const updateOrder = (req: Request, res: Response): void => {
    const userId = readId(req.body.user_id);
    const action = readText(req.body.action);
    if (!userId || !actions.has(action)) {
        res.status(400).json({ success: false, message: 'user_id and an action of ship, deliver, or cancel are required' });
        return;
    }

    const order = OrderModel.findById(Number(req.params.id));
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
        const cancelled = OrderModel.cancel(order.order_id) as Order;
        recordOrderEvent(cancelled, userId, `Cancelled order #${order.order_id}`);
        res.json({ success: true, data: cancelled });
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
        let courier: { courier_name: string; tracking_number: string } | undefined;
        if (order.delivery_method === 'courier') {
            const courierName = readText(req.body.courier_name);
            const trackingNumber = readText(req.body.tracking_number);
            if (!courierName || !trackingNumber) {
                res.status(400).json({ success: false, message: 'courier_name and tracking_number are required for a courier order' });
                return;
            }
            courier = { courier_name: courierName, tracking_number: trackingNumber };
        }
        const shipped = OrderModel.ship(order.order_id, courier) as Order;
        recordOrderEvent(
            shipped,
            userId,
            courier
                ? `Order #${order.order_id} handed to ${courier.courier_name} (tracking ${courier.tracking_number})`
                : `Order #${order.order_id} is ready for pickup at ${shipped.center_name ?? 'the bagsakan center'}`,
        );
        res.json({ success: true, data: shipped });
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
    const delivered = OrderModel.deliver(order.order_id) as Order;
    recordOrderEvent(
        delivered,
        userId,
        order.delivery_method === 'meetup'
            ? `Picked up order #${order.order_id}`
            : `Received order #${order.order_id}`,
    );
    res.json({ success: true, data: delivered });
};
