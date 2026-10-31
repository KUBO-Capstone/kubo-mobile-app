import { db } from "#config/database";

// Conversation metadata only. The messages themselves are in DynamoDB (see
// models/message.model.ts). The inbox reads the denormalized last-message
// and read-cursor columns, which mirror conversations in the RDS schema
// (database/migrations/001_init.sql), so listing threads never touches
// DynamoDB.

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
    // Deal methods the seller accepts; the order page only offers these.
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
    // The order placed on that latest negotiation, if any.
    order_id: number | null;
    order_status: string | null;
}

// Same length as conversations.last_message_preview in the RDS schema.
const PREVIEW_LENGTH = 200;

// @userId drives is_unread only; every other column is the same for both
// parties. last_message_at and the read cursors are ISO strings written by
// the app, so they compare correctly as text.
const conversationQuery = `
    SELECT c.*,
           b.first_name || ' ' || b.last_name AS buyer_name,
           s.first_name || ' ' || s.last_name AS seller_name,
           p.crop_name, p.base_price, p.unit_measurement, p.status AS product_status,
           p.allows_meetup, p.allows_delivery,
           (SELECT pi.image_url FROM product_images pi WHERE pi.product_id = p.product_id ORDER BY pi.display_order LIMIT 1) AS product_image,
           COALESCE(a.city_municipality, 'Philippines') AS seller_location,
           c.last_message_preview AS last_message,
           CASE WHEN c.last_message_at IS NOT NULL
                 AND c.last_message_sender_id != @userId
                 AND c.last_message_at > COALESCE(
                     CASE WHEN c.buyer_id = @userId THEN c.buyer_last_read_at ELSE c.seller_last_read_at END, '')
                THEN 1 ELSE 0 END AS is_unread,
           n.negotiation_id, n.status AS negotiation_status, n.offered_price, n.offered_quantity,
           o.order_id, o.order_status
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
        allows_meetup: Boolean(Number(row.allows_meetup ?? 1)),
        allows_delivery: Boolean(Number(row.allows_delivery ?? 1)),
        product_image: str(row.product_image),
        seller_location: String(row.seller_location),
        created_at: String(row.created_at),
        last_message: str(row.last_message),
        last_message_at: str(row.last_message_at),
        is_unread: Number(row.is_unread) === 1,
        negotiation_id: num(row.negotiation_id),
        negotiation_status: str(row.negotiation_status),
        offered_price: num(row.offered_price),
        offered_quantity: num(row.offered_quantity),
        order_id: num(row.order_id),
        order_status: str(row.order_status),
    };
}

export const ConversationModel = {
    findById(conversationId: number, userId: number): ConversationSummary | undefined {
        const row = db.prepare(`${conversationQuery} WHERE c.conversation_id = @conversationId`)
            .get({ conversationId, userId }) as Record<string, unknown> | undefined;
        return row ? mapConversation(row) : undefined;
    },

    // Inbox: every thread the user is on, most recently active first. Threads
    // with no messages yet (created by the Message button, never written to)
    // sort by creation so they still show up. created_at is SQLite's
    // 'YYYY-MM-DD HH:MM:SS', so it is converted to ISO to compare with
    // last_message_at.
    findForUser(userId: number): ConversationSummary[] {
        const rows = db.prepare(`
            ${conversationQuery}
            WHERE c.buyer_id = @userId OR c.seller_id = @userId
            ORDER BY COALESCE(c.last_message_at, strftime('%Y-%m-%dT%H:%M:%fZ', c.created_at)) DESC, c.conversation_id DESC
        `).all({ userId }) as Record<string, unknown>[];
        return rows.map(mapConversation);
    },

    parties(conversationId: number): { buyer_id: number; seller_id: number; product_id: number | null } | undefined {
        return db.prepare('SELECT buyer_id, seller_id, product_id FROM conversations WHERE conversation_id = ?')
            .get(conversationId) as { buyer_id: number; seller_id: number; product_id: number | null } | undefined;
    },

    // One thread per buyer/seller/product. Offers and the Message button both
    // go through here so they can never fork into two conversations.
    findOrCreate(buyerId: number, sellerId: number, productId: number): number {
        const existing = db.prepare(`
            SELECT conversation_id FROM conversations
            WHERE buyer_id = ? AND seller_id = ? AND product_id = ?
        `).get(buyerId, sellerId, productId) as { conversation_id: number } | undefined;
        if (existing) return existing.conversation_id;
        return Number(db.prepare(`INSERT INTO conversations (buyer_id, seller_id, product_id) VALUES (?, ?, ?)`)
            .run(buyerId, sellerId, productId).lastInsertRowid);
    },

    // Inbox preview, updated after each DynamoDB write. The guard keeps a
    // slower, older write from overwriting a newer preview.
    recordLastMessage(conversationId: number, message: { sender_id: number; content: string; sent_at: string }): void {
        db.prepare(`
            UPDATE conversations
            SET last_message_at = @sent_at,
                last_message_sender_id = @sender_id,
                last_message_preview = @preview
            WHERE conversation_id = @conversation_id
              AND (last_message_at IS NULL OR last_message_at <= @sent_at)
        `).run({
            conversation_id: conversationId,
            sender_id: message.sender_id,
            sent_at: message.sent_at,
            preview: message.content.slice(0, PREVIEW_LENGTH),
        });
    },

    // Moves the reader's cursor up to the newest message in the thread.
    markRead(conversationId: number, readerId: number): boolean {
        return db.prepare(`
            UPDATE conversations
            SET buyer_last_read_at  = CASE WHEN buyer_id  = @readerId THEN last_message_at ELSE buyer_last_read_at END,
                seller_last_read_at = CASE WHEN seller_id = @readerId THEN last_message_at ELSE seller_last_read_at END
            WHERE conversation_id = @conversationId
              AND last_message_at IS NOT NULL
        `).run({ conversationId, readerId }).changes > 0;
    },
};
