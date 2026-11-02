import { pool } from "#database/pg";
import { listingQuery, mapListing, ProductListing } from "#models/product.model";

export const SavedListingModel = {
    // The user's saved listings, newest save first. Sold-out rows stay so the
    // buyer can see what happened to something they were tracking; delisted
    // rows drop out because the listing no longer exists anywhere in the app.
    async findForUser(userId: number): Promise<ProductListing[]> {
        const { rows } = await pool.query(`
            ${listingQuery}
            JOIN saved_listings s ON s.product_id = p.product_id AND s.user_id = $1
            WHERE p.status IN ('available', 'out of stock')
            ORDER BY s.saved_at DESC, s.saved_id DESC
        `, [userId]);
        return rows.map(mapListing);
    },

    // Just the ids, for painting the hearts on every grid without refetching.
    async findIdsForUser(userId: number): Promise<number[]> {
        const { rows } = await pool.query<{ product_id: number }>(`
            SELECT s.product_id FROM saved_listings s
            JOIN products p ON p.product_id = s.product_id
            WHERE s.user_id = $1 AND p.status IN ('available', 'out of stock')
        `, [userId]);
        return rows.map((row) => Number(row.product_id));
    },

    // Idempotent: saving twice is a no-op thanks to UNIQUE (user_id, product_id).
    async save(userId: number, productId: number): Promise<void> {
        await pool.query(`INSERT INTO saved_listings (user_id, product_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`, [userId, productId]);
    },

    async remove(userId: number, productId: number): Promise<void> {
        await pool.query(`DELETE FROM saved_listings WHERE user_id = $1 AND product_id = $2`, [userId, productId]);
    },
};
