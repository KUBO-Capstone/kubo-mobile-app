import { db } from "#config/database";

export interface TopEarningListing {
    product_id: number;
    crop_name: string;
    unit_measurement: string;
    product_image: string | null;
    product_status: string;
    earned: number;
    quantity_sold: number;
    orders: number;
}

// A seller's own estimate. Payment happens in person at handover, so a
// delivered order is the closest thing Kubo has to "paid".
export interface EarningsSummary {
    total_earned: number;
    completed_orders: number;
    // Orders still pending / in transit, plus accepted offers the buyer has
    // not turned into an order yet.
    in_progress_total: number;
    in_progress_deals: number;
    first_sale_at: string | null;
    top_listings: TopEarningListing[];
}

export const EarningsModel = {
    forSeller(sellerId: number, topLimit = 10): EarningsSummary {
        const delivered = db.prepare(`
            SELECT COALESCE(SUM(total_amount), 0) AS total, COUNT(*) AS orders, MIN(order_date) AS first_sale_at
            FROM orders WHERE seller_id = ? AND order_status = 'delivered'
        `).get(sellerId) as { total: number; orders: number; first_sale_at: string | null };

        const openOrders = db.prepare(`
            SELECT COALESCE(SUM(total_amount), 0) AS total, COUNT(*) AS deals
            FROM orders WHERE seller_id = ? AND order_status IN ('pending', 'in transit')
        `).get(sellerId) as { total: number; deals: number };

        const acceptedOffers = db.prepare(`
            SELECT COALESCE(SUM(n.offered_price * n.offered_quantity), 0) AS total, COUNT(*) AS deals
            FROM negotiations n
            LEFT JOIN orders o ON o.negotiation_id = n.negotiation_id
            WHERE n.seller_id = ? AND n.status = 'accepted' AND o.order_id IS NULL
        `).get(sellerId) as { total: number; deals: number };

        const top = db.prepare(`
            SELECT oi.product_id, p.crop_name, p.unit_measurement, p.status AS product_status,
                   (SELECT pi.image_url FROM product_images pi WHERE pi.product_id = p.product_id ORDER BY pi.display_order LIMIT 1) AS product_image,
                   SUM(o.total_amount) AS earned, SUM(oi.quantity) AS quantity_sold, COUNT(*) AS orders
            FROM orders o
            JOIN order_items oi ON oi.order_id = o.order_id
            JOIN products p ON p.product_id = oi.product_id
            WHERE o.seller_id = ? AND o.order_status = 'delivered'
            GROUP BY oi.product_id
            ORDER BY earned DESC, orders DESC
            LIMIT ?
        `).all(sellerId, topLimit) as Record<string, unknown>[];

        return {
            total_earned: Number(delivered.total),
            completed_orders: Number(delivered.orders),
            in_progress_total: Number(openOrders.total) + Number(acceptedOffers.total),
            in_progress_deals: Number(openOrders.deals) + Number(acceptedOffers.deals),
            first_sale_at: delivered.first_sale_at ? String(delivered.first_sale_at) : null,
            top_listings: top.map((row) => ({
                product_id: Number(row.product_id),
                crop_name: String(row.crop_name),
                unit_measurement: String(row.unit_measurement),
                product_image: row.product_image ? String(row.product_image) : null,
                product_status: String(row.product_status),
                earned: Number(row.earned),
                quantity_sold: Number(row.quantity_sold),
                orders: Number(row.orders),
            })),
        };
    },
};
