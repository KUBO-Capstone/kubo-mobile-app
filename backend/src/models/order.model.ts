import { isRowId, pool, Queryable, withTransaction } from "#database/pg";
import { fromMediaColumn, toMediaColumn } from "#controllers/upload.controller";
import { ProductModel } from "#models/product.model";

// Mirrors the CHECK constraints on orders.order_status / delivery_method in
// database/migrations. 'in transit' covers both methods: for a courier order
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
    // The courier agreed in the offer; the seller adds the tracking number
    // when they hand the parcel over.
    courier_name?: string | null;
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
    // Photos the seller took of the produce as they handed it over.
    handover_photos: string[];
    shipped_at: string | null;
    order_date: string;
    updated_at: string;
}

// Most handover photos one order can carry; matches the upload route's limit.
export const maxHandoverPhotos = 5;

export interface Handover {
    courier_name: string | null;
    tracking_number: string | null;
    handover_photos: string[];
}

// orders.handover_photos is jsonb: an array already, or text from an older
// driver setup.
const parseStrings = (value: unknown): string[] => {
    const list = typeof value === 'string' ? (() => { try { return JSON.parse(value); } catch { return []; } })() : value;
    return Array.isArray(list) ? list.filter((item): item is string => typeof item === 'string') : [];
};

const orderQuery = `
    SELECT o.*,
           n.conversation_id,
           b.first_name || ' ' || b.last_name AS buyer_name,
           s.first_name || ' ' || s.last_name AS seller_name,
           oi.product_id, oi.quantity, oi.negotiated_price,
           -- The snapshots, so an order keeps the name and unit it was placed with.
           oi.product_name AS crop_name, oi.unit_measurement,
           (SELECT pi.image_key FROM product_images pi WHERE pi.product_id = oi.product_id ORDER BY pi.display_order LIMIT 1) AS product_image,
           c.location_name AS center_name,
           a.city_municipality AS center_location,
           TRIM(COALESCE(a.street_details || ', ', '') || COALESCE(a.barangay, '')) AS center_address
    FROM orders o
    JOIN negotiations n ON n.negotiation_id = o.negotiation_id
    JOIN users b ON b.user_id = o.buyer_id
    JOIN users s ON s.user_id = o.seller_id
    JOIN order_items oi ON oi.order_id = o.order_id
    LEFT JOIN bagsakan_centers c ON c.center_id = o.drop_off_center_id
    LEFT JOIN addresses a ON a.address_id = c.address_id
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
        product_image: row.product_image ? fromMediaColumn(String(row.product_image)) : null,
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
        handover_photos: parseStrings(row.handover_photos).map(fromMediaColumn),
        shipped_at: str(row.shipped_at),
        order_date: String(row.order_date),
        updated_at: String(row.updated_at),
    };
}

// Moves an order from one status to the next, only if it is still in
// `from`. Two requests can now run at once (SQLite took them one at a time),
// so the controller's status check alone could let a buyer's cancel and a
// seller's ship both go through.
const moveStatus = async (q: Queryable, orderId: number, from: OrderStatus, to: OrderStatus): Promise<boolean> => {
    const { rowCount } = await q.query(
        `UPDATE orders SET order_status = $3, updated_at = CURRENT_TIMESTAMP WHERE order_id = $1 AND order_status = $2`,
        [orderId, from, to],
    );
    return (rowCount ?? 0) > 0;
};

export const OrderModel = {
    async findById(orderId: number): Promise<Order | undefined> {
        if (!isRowId(orderId)) return undefined;
        const { rows } = await pool.query(`${orderQuery} WHERE o.order_id = $1`, [orderId]);
        return rows[0] ? mapOrder(rows[0]) : undefined;
    },

    // orders.negotiation_id is UNIQUE, so this is how "already ordered" is
    // checked before a second POST for the same accepted offer.
    async findByNegotiation(negotiationId: number): Promise<Order | undefined> {
        const { rows } = await pool.query(`${orderQuery} WHERE o.negotiation_id = $1`, [negotiationId]);
        return rows[0] ? mapOrder(rows[0]) : undefined;
    },

    // Every order the user is a party to, newest first. `role` narrows to
    // purchases (buyer) or sales (seller) for the profile tab.
    async findForUser(userId: number, role?: 'buyer' | 'seller', status?: OrderStatus): Promise<Order[]> {
        const conditions = role === 'buyer'
            ? ['o.buyer_id = $1']
            : role === 'seller'
                ? ['o.seller_id = $1']
                : ['(o.buyer_id = $1 OR o.seller_id = $1)'];
        const params: unknown[] = [userId];
        if (status) {
            params.push(status);
            conditions.push(`o.order_status = $${params.length}`);
        }
        const { rows } = await pool.query(`${orderQuery} WHERE ${conditions.join(' AND ')} ORDER BY o.order_id DESC`, params);
        return rows.map(mapOrder);
    },

    // Writes the order and its single item in one transaction. The quantity
    // came off the listing when the offer was accepted (see
    // NegotiationModel.accept), so placing the order only hands that held
    // stock over to the order; from here on cancel() is what returns it.
    // An offer accepted before holds existed holds nothing, and its stock is
    // taken now instead. Undefined, with nothing written, when the order can
    // no longer go through: the deal was cancelled, the seller delisted the
    // listing or turned the chosen delivery method off after the controller
    // checked, or (old offers only) the stock is gone.
    async create(input: OrderInput): Promise<Order | undefined> {
        const orderId = await withTransaction(async (client) => {
            // Locked so cancelling the deal and ordering it cannot both win.
            const { rows: [deal] } = await client.query(`
                SELECT reserved_quantity FROM negotiations
                WHERE negotiation_id = $1 AND status = 'accepted'
                FOR UPDATE
            `, [input.negotiation_id]);
            if (!deal) return undefined;

            // Locked too, so the listing cannot change under the order.
            const { rowCount: canHandOver } = await client.query(`
                SELECT 1 FROM products
                WHERE product_id = $1 AND status <> 'delisted'
                  AND CASE WHEN $2 = 'meetup' THEN allows_meetup ELSE allows_delivery END
                FOR UPDATE
            `, [input.product_id, input.delivery_method]);
            if (!canHandOver) return undefined;

            if (deal.reserved_quantity === null) {
                if (!(await ProductModel.takeStock(client, input.product_id, input.quantity))) return undefined;
            } else {
                await client.query(`UPDATE negotiations SET reserved_quantity = NULL WHERE negotiation_id = $1`, [input.negotiation_id]);
            }
            return OrderModel.insert(client, input);
        });
        return orderId === undefined ? undefined : OrderModel.findById(orderId);
    },

    // Writes the order and its single item inside the caller's transaction,
    // which has already dealt with the stock. Accepting an offer whose terms
    // include how the produce changes hands goes through here straight from
    // NegotiationModel.accept, so there is no separate "place order" step.
    async insert(q: Queryable, input: OrderInput): Promise<number> {
        // Totals are worked out in numeric, not JS floats, so 2.5 x 33.33 is 83.33.
        const { rows: [order] } = await q.query(`
            INSERT INTO orders (negotiation_id, buyer_id, seller_id, drop_off_center_id, drop_off_location_name, total_amount, delivery_method, courier_name)
            VALUES ($1, $2, $3, $4, (SELECT location_name FROM bagsakan_centers WHERE center_id = $4), $5::numeric * $6::numeric, $7, $8)
            RETURNING order_id
        `, [input.negotiation_id, input.buyer_id, input.seller_id, input.drop_off_center_id,
            input.quantity, input.negotiated_price, input.delivery_method, input.courier_name ?? null]);
        // order_items keeps the name and unit as they were when ordered.
        await q.query(`
            INSERT INTO order_items (order_id, product_id, product_name, unit_measurement, quantity, negotiated_price)
            SELECT $1::int, product_id, crop_name, unit_measurement, $3::numeric, $4::numeric FROM products WHERE product_id = $2
        `, [order.order_id, input.product_id, input.quantity, input.negotiated_price]);
        return Number(order.order_id);
    },

    // Delivered orders the user was on either side of: the public "completed
    // orders" count on a profile.
    async countCompleted(userId: number): Promise<number> {
        if (!isRowId(userId)) return 0;
        const { rows: [row] } = await pool.query(
            `SELECT COUNT(*) AS total FROM orders WHERE order_status = 'delivered' AND (buyer_id = $1 OR seller_id = $1)`, [userId]);
        return Number(row.total);
    },

    // Seller hands a pending order over: marks it in transit and, for a
    // courier order, keeps whichever courier details they gave (both are
    // optional; they may send them in the chat instead). A courier agreed in
    // the offer stays unless the seller names another. Undefined if it was
    // no longer pending.
    // Undefined if the order was no longer pending. The photos column keeps
    // object keys, like product_images; it is sent as JSON text so
    // node-postgres does not turn the array into a Postgres array.
    async ship(orderId: number, handover: Handover = { courier_name: null, tracking_number: null, handover_photos: [] }): Promise<Order | undefined> {
        const { rowCount } = await pool.query(`
            UPDATE orders
            SET order_status = 'in transit', courier_name = COALESCE($2, courier_name), tracking_number = $3,
                handover_photos = $4::jsonb, shipped_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
            WHERE order_id = $1 AND order_status = 'pending'
        `, [orderId, handover.courier_name, handover.tracking_number, JSON.stringify(handover.handover_photos.map(toMediaColumn))]);
        return rowCount ? OrderModel.findById(orderId) : undefined;
    },

    // Undefined if the order was no longer in transit.
    async deliver(orderId: number): Promise<Order | undefined> {
        return (await moveStatus(pool, orderId, 'in transit', 'delivered')) ? OrderModel.findById(orderId) : undefined;
    },

    // Gives the order's quantity back to the listing. A listing that was
    // sold out purely because nothing was left becomes available again; one
    // the seller archived by hand (quantity still > 0) is left alone.
    // Undefined if the order was no longer pending, so stock is never
    // returned twice.
    async cancel(orderId: number): Promise<Order | undefined> {
        const moved = await withTransaction(async (client) => {
            if (!(await moveStatus(client, orderId, 'pending', 'cancelled'))) return false;
            await client.query(`
                UPDATE products p
                SET status = CASE WHEN p.available_quantity = 0 AND p.status = 'out of stock' THEN 'available' ELSE p.status END,
                    available_quantity = p.available_quantity + oi.quantity,
                    updated_at = CURRENT_TIMESTAMP
                FROM order_items oi
                WHERE oi.order_id = $1 AND p.product_id = oi.product_id
            `, [orderId]);
            return true;
        });
        return moved ? OrderModel.findById(orderId) : undefined;
    },
};
