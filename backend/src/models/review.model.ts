import { db } from "#config/database";

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
           u.profile_photo_url AS reviewer_photo_url,
           CASE WHEN o.buyer_id = r.reviewer_id THEN 'buyer' ELSE 'seller' END AS reviewer_role,
           oi.product_id, p.crop_name,
           (SELECT pi.image_url FROM product_images pi WHERE pi.product_id = p.product_id ORDER BY pi.display_order LIMIT 1) AS product_image
    FROM reviews r
    JOIN users u ON u.user_id = r.reviewer_id
    JOIN orders o ON o.order_id = r.order_id
    JOIN order_items oi ON oi.order_id = r.order_id
    JOIN products p ON p.product_id = oi.product_id
`;

const parseTags = (value: unknown): string[] => {
    try {
        const parsed = JSON.parse(String(value ?? '[]'));
        return Array.isArray(parsed) ? parsed.filter((tag): tag is string => typeof tag === 'string') : [];
    } catch {
        return [];
    }
};

function mapReview(row: Record<string, unknown>): Review {
    return {
        review_id: Number(row.review_id),
        order_id: Number(row.order_id),
        reviewer_id: Number(row.reviewer_id),
        reviewee_id: Number(row.reviewee_id),
        reviewer_name: String(row.reviewer_name),
        reviewer_photo_url: row.reviewer_photo_url ? String(row.reviewer_photo_url) : null,
        reviewer_role: row.reviewer_role === 'seller' ? 'seller' : 'buyer',
        rating: Number(row.rating),
        comment: row.comment ? String(row.comment) : '',
        tags: parseTags(row.tags),
        product_id: Number(row.product_id),
        crop_name: String(row.crop_name),
        product_image: row.product_image ? String(row.product_image) : null,
        created_at: String(row.created_at),
    };
}

export const ReviewModel = {
    // Newest first: what the profile Reviews tab lists.
    findForUser(revieweeId: number): Review[] {
        const rows = db.prepare(`${reviewQuery} WHERE r.reviewee_id = ? ORDER BY r.created_at DESC, r.review_id DESC`)
            .all(revieweeId) as Record<string, unknown>[];
        return rows.map(mapReview);
    },

    findByOrderAndReviewer(orderId: number, reviewerId: number): Review | undefined {
        const row = db.prepare(`${reviewQuery} WHERE r.order_id = ? AND r.reviewer_id = ?`)
            .get(orderId, reviewerId) as Record<string, unknown> | undefined;
        return row ? mapReview(row) : undefined;
    },

    summaryFor(userId: number): RatingSummary {
        const rows = db.prepare(`SELECT rating, COUNT(*) AS total FROM reviews WHERE reviewee_id = ? GROUP BY rating`)
            .all(userId) as { rating: number; total: number }[];
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

    create(input: ReviewInput): Review {
        const result = db.prepare(`
            INSERT INTO reviews (order_id, reviewer_id, reviewee_id, rating, comment, tags)
            VALUES (@order_id, @reviewer_id, @reviewee_id, @rating, @comment, @tags)
        `).run({ ...input, tags: JSON.stringify(input.tags) });
        const row = db.prepare(`${reviewQuery} WHERE r.review_id = ?`).get(Number(result.lastInsertRowid)) as Record<string, unknown>;
        return mapReview(row);
    },
};
