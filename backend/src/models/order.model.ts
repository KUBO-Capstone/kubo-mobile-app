import { db } from "#config/database";

// Mirrors the CHECK constraints on orders.order_status / delivery_method in
// config/database.ts. 'in transit' covers both methods: for a courier order
// the parcel is on its way, for a meetup order the produce has been dropped
// at the bagsakan center and is waiting for the buyer.
export type OrderStatus = 'pending' | 'in transit' | 'delivered' | 'cancelled';
export type DeliveryMethod = 'courier' | 'meetup';

export interface OrderInput {
    negotiation_id: number;
    buyer_id: number;
    seller_id: number;
    product_id: number;
    quantity: number;
    negotiated_price: number;
    delivery_method: DeliveryMethod;
    drop_off_center_id: number | null;
}

// One order is one accepted negotiation, so it always has exactly one
// order_items row; the item's fields are flattened onto the order.
export interface Order {
    order_id: number;
    negotiation_id: number;
    conversation_id: number;
    buyer_id: number;
    seller_id: number;
    buyer_name: string;
    seller_name: string;
    product_id: number;
    crop_name: string;
    unit_measurement: string;
    product_image: string | null;
    quantity: number;
    negotiated_price: number;
    total_amount: number;
    order_status: OrderStatus;
    delivery_method: DeliveryMethod;
    drop_off_center_id: number | null;
    center_name: string | null;
    center_location: string | null;
    center_address: string | null;
    courier_name: string | null;
    tracking_number: string | null;
    order_date: string;
    updated_at: string;
}

const orderQuery = `
    SELECT o.*,
           n.conversation_id,
           b.first_name || ' ' || b.last_name AS buyer_name,
           s.first_name || ' ' || s.last_name AS seller_name,
           oi.product_id, oi.quantity, oi.negotiated_price,
           p.crop_name, p.unit_measurement,
           (SELECT pi.image_url FROM product_images pi WHERE pi.product_id = p.product_id ORDER BY pi.display_order LIMIT 1) AS product_image,
           c.location_name AS center_name,
           a.city_municipality AS center_location,
           TRIM(COALESCE(a.street_details || ', ', '') || COALESCE(a.barangay, '')) AS center_address,
           ct.courier_name, ct.tracking_number
    FROM orders o
    JOIN negotiations n ON n.negotiation_id = o.negotiation_id
    JOIN users b ON b.user_id = o.buyer_id
    JOIN users s ON s.user_id = o.seller_id
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p ON p.product_id = oi.product_id
    LEFT JOIN bagsakan_centers c ON c.center_id = o.drop_off_center_id
    LEFT JOIN addresses a ON a.address_id = c.address_id
    LEFT JOIN courier_tracking ct ON ct.tracking_id = (
        SELECT tracking_id FROM courier_tracking WHERE order_id = o.order_id ORDER BY tracking_id DESC LIMIT 1
    )
`;

function mapOrder(row: Record<string, unknown>): Order {
    const num = (value: unknown) => (value === null || value === undefined ? null : Number(value));
    const str = (value: unknown) => (value === null || value === undefined || value === '' ? null : String(value));
    return {
        order_id: Number(row.order_id),
        negotiation_id: Number(row.negotiation_id),
        conversation_id: Number(row.conversation_id),
        buyer_id: Number(row.buyer_id),
        seller_id: Number(row.seller_id),
        buyer_name: String(row.buyer_name),
        seller_name: String(row.seller_name),
        product_id: Number(row.product_id),
        crop_name: String(row.crop_name),
        unit_measurement: String(row.unit_measurement),
        product_image: str(row.product_image),
        quantity: Number(row.quantity),
        negotiated_price: Number(row.negotiated_price),
        total_amount: Number(row.total_amount),
        order_status: String(row.order_status) as OrderStatus,
        delivery_method: String(row.delivery_method) as DeliveryMethod,
        drop_off_center_id: num(row.drop_off_center_id),
        center_name: str(row.center_name),
        center_location: str(row.center_location),
        center_address: str(row.center_address),
        courier_name: str(row.courier_name),
        tracking_number: str(row.tracking_number),
        order_date: String(row.order_date),
        updated_at: String(row.updated_at),
    };
}

export const OrderModel = {
    findById(orderId: number): Order | undefined {
        const row = db.prepare(`${orderQuery} WHERE o.order_id = ?`).get(orderId) as Record<string, unknown> | undefined;
        return row ? mapOrder(row) : undefined;
    },

    // orders.negotiation_id is UNIQUE, so this is how "already ordered" is
    // checked before a second POST for the same accepted offer.
    findByNegotiation(negotiationId: number): Order | undefined {
        const row = db.prepare(`${orderQuery} WHERE o.negotiation_id = ?`).get(negotiationId) as Record<string, unknown> | undefined;
        return row ? mapOrder(row) : undefined;
    },

    // Every order the user is a party to, newest first. `role` narrows to
    // purchases (buyer) or sales (seller) for the profile tab.
    findForUser(userId: number, role?: 'buyer' | 'seller', status?: OrderStatus): Order[] {
        const conditions = role === 'buyer'
            ? ['o.buyer_id = @userId']
            : role === 'seller'
                ? ['o.seller_id = @userId']
                : ['(o.buyer_id = @userId OR o.seller_id = @userId)'];
        if (status) conditions.push('o.order_status = @status');
        const rows = db.prepare(`${orderQuery} WHERE ${conditions.join(' AND ')} ORDER BY o.order_id DESC`)
            .all({ userId, status }) as Record<string, unknown>[];
        return rows.map(mapOrder);
    },

    // Writes the order and its single item and takes the quantity off the
    // listing in one transaction. A listing that hits zero is marked
    // 'out of stock' so it drops out of explore; cancel() puts it back.
    create(input: OrderInput): Order {
        const insert = db.transaction(() => {
            const result = db.prepare(`
                INSERT INTO orders (negotiation_id, buyer_id, seller_id, drop_off_center_id, total_amount, delivery_method)
                VALUES (@negotiation_id, @buyer_id, @seller_id, @drop_off_center_id, @total_amount, @delivery_method)
            `).run({
                negotiation_id: input.negotiation_id,
                buyer_id: input.buyer_id,
                seller_id: input.seller_id,
                drop_off_center_id: input.drop_off_center_id,
                total_amount: input.quantity * input.negotiated_price,
                delivery_method: input.delivery_method,
            });
            const orderId = Number(result.lastInsertRowid);
            db.prepare(`
                INSERT INTO order_items (order_id, product_id, quantity, negotiated_price)
                VALUES (?, ?, ?, ?)
            `).run(orderId, input.product_id, input.quantity, input.negotiated_price);
            db.prepare(`
                UPDATE products
                SET available_quantity = MAX(available_quantity - @quantity, 0),
                    status = CASE WHEN available_quantity - @quantity <= 0 AND status = 'available' THEN 'out of stock' ELSE status END,
                    updated_at = CURRENT_TIMESTAMP
                WHERE product_id = @product_id
            `).run({ quantity: input.quantity, product_id: input.product_id });
            return orderId;
        });
        return OrderModel.findById(insert()) as Order;
    },

    // Seller hands a courier order over: records who carries it and marks
    // the order in transit together.
    ship(orderId: number, courier?: { courier_name: string; tracking_number: string }): Order | undefined {
        db.transaction(() => {
            if (courier) {
                db.prepare(`
                    INSERT INTO courier_tracking (order_id, courier_name, tracking_number, status)
                    VALUES (?, ?, ?, 'in transit')
                `).run(orderId, courier.courier_name, courier.tracking_number);
            }
            db.prepare(`UPDATE orders SET order_status = 'in transit', updated_at = CURRENT_TIMESTAMP WHERE order_id = ?`).run(orderId);
        })();
        return OrderModel.findById(orderId);
    },

    deliver(orderId: number): Order | undefined {
        db.transaction(() => {
            db.prepare(`UPDATE courier_tracking SET status = 'delivered', updated_at = CURRENT_TIMESTAMP WHERE order_id = ?`).run(orderId);
            db.prepare(`UPDATE orders SET order_status = 'delivered', updated_at = CURRENT_TIMESTAMP WHERE order_id = ?`).run(orderId);
        })();
        return OrderModel.findById(orderId);
    },

    // Gives the reserved quantity back to the listing. A listing that was
    // sold out purely because of this order becomes available again; one the
    // seller archived by hand (quantity still > 0) is left alone.
    cancel(orderId: number): Order | undefined {
        db.transaction(() => {
            const item = db.prepare(`SELECT product_id, quantity FROM order_items WHERE order_id = ?`).get(orderId) as { product_id: number; quantity: number };
            db.prepare(`
                UPDATE products
                SET status = CASE WHEN available_quantity = 0 AND status = 'out of stock' THEN 'available' ELSE status END,
                    available_quantity = available_quantity + @quantity,
                    updated_at = CURRENT_TIMESTAMP
                WHERE product_id = @product_id
            `).run(item);
            db.prepare(`UPDATE orders SET order_status = 'cancelled', updated_at = CURRENT_TIMESTAMP WHERE order_id = ?`).run(orderId);
        })();
        return OrderModel.findById(orderId);
    },
};
