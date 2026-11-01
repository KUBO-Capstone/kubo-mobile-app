import { isRowId, pool, Queryable } from "#database/pg";
import { fromMediaColumn } from "#controllers/upload.controller";

// Conversation metadata only. The messages themselves are in DynamoDB (see
// models/message.model.ts). The inbox reads the denormalized last-message
// and read-cursor columns on conversations (database/migrations/001_init.sql),
// so listing threads never touches DynamoDB.

// One inbox row: the thread plus everything the list and the chat header
// need without a second request.
export interface ConversationSummary {
    conversation_id: number;
    buyer_id: number;
    seller_id: number;
    buyer_name: string;
    seller_name: string;
    product_id: number;
    crop_name: string;
    base_price: number;
    unit_measurement: string;
    product_status: string;
    // The listing's deal methods, so the order page only offers those.
    allows_meetup: boolean;
    allows_delivery: boolean;
    product_image: string | null;
    seller_location: string;
    created_at: string;
    last_message: string | null;
    last_message_at: string | null;
    // The other party sent something after the caller's read cursor.
    is_unread: boolean;
    // Latest negotiation on this thread, open or closed; null before any offer.
    negotiation_id: number | null;
    negotiation_status: string | null;
    offered_price: number | null;
    offered_quantity: number | null;
    // Who accepted that negotiation, and whether the caller has yet to see
    // the "deal closed" screen for it.
    accepted_by: number | null;
    celebration_pending: boolean;
    // The order placed on that latest negotiation, if any.
    order_id: number | null;
    order_status: string | null;
    // The caller's rating of that order, null until they review it.
    my_review_rating: number | null;
    // Both parties' rating summaries, for the block under the listing card.
    buyer_rating: number | null;
    buyer_review_count: number;
    seller_rating: number | null;
    seller_review_count: number;
}

// Same length as conversations.last_message_preview in the RDS schema.
const PREVIEW_LENGTH = 200;

// $1 is the caller: it drives is_unread, celebration_pending and
// my_review_rating; every other column is the same for both parties.
const conversationQuery = `
    SELECT c.*,
           b.first_name || ' ' || b.last_name AS buyer_name,
           s.first_name || ' ' || s.last_name AS seller_name,
           p.crop_name, p.base_price, p.unit_measurement, p.status AS product_status,
           p.allows_meetup, p.allows_delivery,
           (SELECT pi.image_key FROM product_images pi WHERE pi.product_id = p.product_id ORDER BY pi.display_order LIMIT 1) AS product_image,
           COALESCE(a.city_municipality, 'Philippines') AS seller_location,
           c.last_message_preview AS last_message,
           CASE WHEN c.last_message_at IS NOT NULL
                 AND c.last_message_sender_id <> $1
                 AND c.last_message_at > COALESCE(
                     CASE WHEN c.buyer_id = $1 THEN c.buyer_last_read_at ELSE c.seller_last_read_at END, '-infinity')
                THEN 1 ELSE 0 END AS is_unread,
           n.negotiation_id, n.status AS negotiation_status, n.offered_price, n.offered_quantity,
           n.accepted_by,
           CASE WHEN n.status = 'accepted'
                 AND (CASE WHEN c.buyer_id = $1 THEN n.buyer_celebrated_at ELSE n.seller_celebrated_at END) IS NULL
                THEN 1 ELSE 0 END AS celebration_pending,
           o.order_id, o.order_status,
           (SELECT r.rating FROM reviews r WHERE r.order_id = o.order_id AND r.reviewer_id = $1) AS my_review_rating,
           (SELECT ROUND(AVG(r.rating), 1) FROM reviews r WHERE r.reviewee_id = c.buyer_id) AS buyer_rating,
           (SELECT COUNT(*) FROM reviews r WHERE r.reviewee_id = c.buyer_id) AS buyer_review_count,
           (SELECT ROUND(AVG(r.rating), 1) FROM reviews r WHERE r.reviewee_id = c.seller_id) AS seller_rating,
           (SELECT COUNT(*) FROM reviews r WHERE r.reviewee_id = c.seller_id) AS seller_review_count
    FROM conversations c
    JOIN users b ON b.user_id = c.buyer_id
    JOIN users s ON s.user_id = c.seller_id
    JOIN products p ON p.product_id = c.product_id
    LEFT JOIN farmer_profiles fp ON fp.farmer_id = c.seller_id
    LEFT JOIN addresses a ON a.address_id = fp.address_id
    LEFT JOIN negotiations n ON n.negotiation_id = (
        SELECT negotiation_id FROM negotiations WHERE conversation_id = c.conversation_id ORDER BY negotiation_id DESC LIMIT 1
    )
    LEFT JOIN orders o ON o.negotiation_id = n.negotiation_id
`;

function mapConversation(row: Record<string, unknown>): ConversationSummary {
    const num = (value: unknown) => (value === null || value === undefined ? null : Number(value));
    const str = (value: unknown) => (value === null || value === undefined ? null : String(value));
    return {
        conversation_id: Number(row.conversation_id),
        buyer_id: Number(row.buyer_id),
        seller_id: Number(row.seller_id),
        buyer_name: String(row.buyer_name),
        seller_name: String(row.seller_name),
        product_id: Number(row.product_id),
        crop_name: String(row.crop_name),
        base_price: Number(row.base_price),
        unit_measurement: String(row.unit_measurement),
        product_status: String(row.product_status),
        allows_meetup: row.allows_meetup !== false,
        allows_delivery: row.allows_delivery !== false,
        product_image: row.product_image === null || row.product_image === undefined ? null : fromMediaColumn(String(row.product_image)),
        seller_location: String(row.seller_location),
        created_at: String(row.created_at),
        last_message: str(row.last_message),
        last_message_at: str(row.last_message_at),
        is_unread: Number(row.is_unread) === 1,
        negotiation_id: num(row.negotiation_id),
        negotiation_status: str(row.negotiation_status),
        offered_price: num(row.offered_price),
        offered_quantity: num(row.offered_quantity),
        accepted_by: num(row.accepted_by),
        celebration_pending: Number(row.celebration_pending) === 1,
        order_id: num(row.order_id),
        order_status: str(row.order_status),
        my_review_rating: num(row.my_review_rating),
        buyer_rating: num(row.buyer_rating),
        buyer_review_count: Number(row.buyer_review_count ?? 0),
        seller_rating: num(row.seller_rating),
        seller_review_count: Number(row.seller_review_count ?? 0),
    };
}

export const ConversationModel = {
    async findById(conversationId: number, userId: number): Promise<ConversationSummary | undefined> {
        if (!isRowId(conversationId)) return undefined;
        const { rows } = await pool.query(`${conversationQuery} WHERE c.conversation_id = $2`, [userId, conversationId]);
        return rows[0] ? mapConversation(rows[0]) : undefined;
    },

    // Inbox: every thread the user is on, most recently active first. Threads
    // with no messages yet (created by the Message button, never written to)
    // sort by creation so they still show up.
    async findForUser(userId: number): Promise<ConversationSummary[]> {
        const { rows } = await pool.query(`
            ${conversationQuery}
            WHERE c.buyer_id = $1 OR c.seller_id = $1
            ORDER BY COALESCE(c.last_message_at, c.created_at) DESC, c.conversation_id DESC
        `, [userId]);
        return rows.map(mapConversation);
    },

    async parties(conversationId: number): Promise<{ buyer_id: number; seller_id: number; product_id: number | null } | undefined> {
        const { rows } = await pool.query('SELECT buyer_id, seller_id, product_id FROM conversations WHERE conversation_id = $1', [conversationId]);
        return rows[0];
    },

    // One thread per buyer/seller/product. Offers and the Message button both
    // go through here, and uq_conversations_thread settles two arriving at
    // once, so they can never fork into two conversations.
    async findOrCreate(buyerId: number, sellerId: number, productId: number, q: Queryable = pool): Promise<number> {
        const find = async (): Promise<number | undefined> => {
            const { rows } = await q.query(`
                SELECT conversation_id FROM conversations
                WHERE buyer_id = $1 AND seller_id = $2 AND product_id = $3
            `, [buyerId, sellerId, productId]);
            return rows[0]?.conversation_id;
        };
        const existing = await find();
        if (existing !== undefined) return existing;
        const { rows } = await q.query(`
            INSERT INTO conversations (buyer_id, seller_id, product_id) VALUES ($1, $2, $3)
            ON CONFLICT (buyer_id, seller_id, product_id) DO NOTHING
            RETURNING conversation_id
        `, [buyerId, sellerId, productId]);
        return rows[0]?.conversation_id ?? (await find())!;
    },

    // Inbox preview, updated after each DynamoDB write. The guard keeps a
    // slower, older write from overwriting a newer preview.
    async recordLastMessage(conversationId: number, message: { sender_id: number; content: string; sent_at: string }): Promise<void> {
        await pool.query(`
            UPDATE conversations
            SET last_message_at = $2,
                last_message_sender_id = $3,
                last_message_preview = $4
            WHERE conversation_id = $1
              AND (last_message_at IS NULL OR last_message_at <= $2)
        `, [conversationId, message.sent_at, message.sender_id, message.content.slice(0, PREVIEW_LENGTH)]);
    },

    // Moves the reader's cursor up to the newest message in the thread.
    async markRead(conversationId: number, readerId: number): Promise<boolean> {
        const { rowCount } = await pool.query(`
            UPDATE conversations
            SET buyer_last_read_at  = CASE WHEN buyer_id  = $2 THEN last_message_at ELSE buyer_last_read_at END,
                seller_last_read_at = CASE WHEN seller_id = $2 THEN last_message_at ELSE seller_last_read_at END
            WHERE conversation_id = $1
              AND last_message_at IS NOT NULL
        `, [conversationId, readerId]);
        return (rowCount ?? 0) > 0;
    },
};
