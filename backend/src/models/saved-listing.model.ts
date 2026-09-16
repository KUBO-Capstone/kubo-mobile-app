import { db } from "#config/database";
import { listingQuery, mapListing, ProductListing } from "#models/product.model";

export const SavedListingModel = {
    // The user's saved listings, newest save first. Sold-out rows stay so the
    // buyer can see what happened to something they were tracking; delisted
    // rows drop out because the listing no longer exists anywhere in the app.
    findForUser(userId: number): ProductListing[] {
        const rows = db.prepare(`
            ${listingQuery}
            JOIN saved_listings s ON s.product_id = p.product_id AND s.user_id = @userId
            WHERE p.status IN ('available', 'out of stock')
            GROUP BY p.product_id
            ORDER BY s.saved_at DESC, s.saved_id DESC
        `).all({ userId }) as Record<string, unknown>[];
        return rows.map(mapListing);
    },

    // Just the ids, for painting the hearts on every grid without refetching.
    findIdsForUser(userId: number): number[] {
        const rows = db.prepare(`
            SELECT s.product_id FROM saved_listings s
            JOIN products p ON p.product_id = s.product_id
            WHERE s.user_id = ? AND p.status IN ('available', 'out of stock')
        `).all(userId) as { product_id: number }[];
        return rows.map((row) => Number(row.product_id));
    },

    // Idempotent: saving twice is a no-op thanks to UNIQUE (user_id, product_id).
    save(userId: number, productId: number): void {
        db.prepare(`INSERT OR IGNORE INTO saved_listings (user_id, product_id) VALUES (?, ?)`).run(userId, productId);
    },

    remove(userId: number, productId: number): void {
        db.prepare(`DELETE FROM saved_listings WHERE user_id = ? AND product_id = ?`).run(userId, productId);
    },
};
