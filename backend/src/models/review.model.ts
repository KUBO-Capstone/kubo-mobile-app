import { pool } from "#database/pg";
import { fromMediaColumn } from "#controllers/upload.controller";

// Quick tags a reviewer can pick, by who is being reviewed. Stored as keys;
// the app owns the labels.
export const sellerReviewTags = ['fresh', 'as_described', 'well_packed', 'on_time', 'fair_price', 'friendly'] as const;
export const buyerReviewTags = ['smooth_deal', 'on_time', 'clear_communication', 'friendly'] as const;

export interface Review {
    review_id: number;
    order_id: number;
    reviewer_id: number;
    reviewee_id: number;
    reviewer_name: string;
    reviewer_photo_url: string | null;
    // The reviewer's side of the order: a 'buyer' review is about a seller.
    reviewer_role: 'buyer' | 'seller';
    rating: number;
    comment: string;
    tags: string[];
    product_id: number;
    crop_name: string;
    product_image: string | null;
    created_at: string;
}

export interface RatingSummary {
    // Null until the first review, so the app can say "No reviews yet".
    average: number | null;
    count: number;
    // Count per star, keyed '1'..'5'.
    breakdown: Record<string, number>;
}

export interface ReviewInput {
    order_id: number;
    reviewer_id: number;
    reviewee_id: number;
    rating: number;
    comment: string;
    tags: string[];
}

const reviewQuery = `
    SELECT r.*,
           u.first_name || ' ' || u.last_name AS reviewer_name,
           u.profile_photo_key AS reviewer_photo_url,
           CASE WHEN o.buyer_id = r.reviewer_id THEN 'buyer' ELSE 'seller' END AS reviewer_role,
           oi.product_id, p.crop_name,
           (SELECT pi.image_key FROM product_images pi WHERE pi.product_id = p.product_id ORDER BY pi.display_order LIMIT 1) AS product_image
    FROM reviews r
    JOIN users u ON u.user_id = r.reviewer_id
    JOIN orders o ON o.order_id = r.order_id
    JOIN order_items oi ON oi.order_id = r.order_id
    JOIN products p ON p.product_id = oi.product_id
`;

// reviews.tags is jsonb, so node-postgres hands over the parsed array.
const parseTags = (value: unknown): string[] =>
    Array.isArray(value) ? value.filter((tag): tag is string => typeof tag === 'string') : [];

function mapReview(row: Record<string, unknown>): Review {
    return {
        review_id: Number(row.review_id),
        order_id: Number(row.order_id),
        reviewer_id: Number(row.reviewer_id),
        reviewee_id: Number(row.reviewee_id),
        reviewer_name: String(row.reviewer_name),
        reviewer_photo_url: row.reviewer_photo_url ? fromMediaColumn(String(row.reviewer_photo_url)) : null,
        reviewer_role: row.reviewer_role === 'seller' ? 'seller' : 'buyer',
        rating: Number(row.rating),
        comment: row.comment ? String(row.comment) : '',
        tags: parseTags(row.tags),
        product_id: Number(row.product_id),
        crop_name: String(row.crop_name),
        product_image: row.product_image ? fromMediaColumn(String(row.product_image)) : null,
        created_at: String(row.created_at),
    };
}

export const ReviewModel = {
    // Newest first: what the profile Reviews tab lists.
    async findForUser(revieweeId: number): Promise<Review[]> {
        const { rows } = await pool.query(`${reviewQuery} WHERE r.reviewee_id = $1 ORDER BY r.created_at DESC, r.review_id DESC`, [revieweeId]);
        return rows.map(mapReview);
    },

    async findByOrderAndReviewer(orderId: number, reviewerId: number): Promise<Review | undefined> {
        const { rows } = await pool.query(`${reviewQuery} WHERE r.order_id = $1 AND r.reviewer_id = $2`, [orderId, reviewerId]);
        return rows[0] ? mapReview(rows[0]) : undefined;
    },

    // Both sides' reviews of each order, in one query for an order list.
    async findForOrders(orderIds: number[]): Promise<Review[]> {
        if (orderIds.length === 0) return [];
        const { rows } = await pool.query(`${reviewQuery} WHERE r.order_id = ANY($1::int[])`, [orderIds]);
        return rows.map(mapReview);
    },

    async summaryFor(userId: number): Promise<RatingSummary> {
        const { rows } = await pool.query<{ rating: number; total: number }>(
            `SELECT rating, COUNT(*) AS total FROM reviews WHERE reviewee_id = $1 GROUP BY rating`, [userId]);
        const breakdown: Record<string, number> = { '1': 0, '2': 0, '3': 0, '4': 0, '5': 0 };
        let count = 0;
        let sum = 0;
        for (const row of rows) {
            breakdown[String(row.rating)] = Number(row.total);
            count += Number(row.total);
            sum += Number(row.rating) * Number(row.total);
        }
        return { average: count === 0 ? null : Math.round((sum / count) * 10) / 10, count, breakdown };
    },

    // tags is sent as JSON text: node-postgres would turn a JS array into a
    // Postgres array literal, which jsonb does not accept.
    async create(input: ReviewInput): Promise<Review> {
        const { rows: [created] } = await pool.query(`
            INSERT INTO reviews (order_id, reviewer_id, reviewee_id, rating, comment, tags)
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING review_id
        `, [input.order_id, input.reviewer_id, input.reviewee_id, input.rating, input.comment, JSON.stringify(input.tags)]);
        const { rows } = await pool.query(`${reviewQuery} WHERE r.review_id = $1`, [created.review_id]);
        return mapReview(rows[0]);
    },
};
