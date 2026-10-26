import { db } from "#config/database";
import { NotificationModel } from "#models/notification.model";

// Mirrors the CHECK constraint on messages.message_type in config/database.ts.
// 'text' is a chat line; the rest are offer events written by the negotiation
// controller so the thread doubles as the offer history (a counter overwrites
// the price on the negotiations row, the messages keep every step). 'order'
// is written by the order controller for placed / shipped / delivered /
// cancelled, with `order_id` pointing at the order.
export type MessageType = 'text' | 'offer' | 'counter' | 'accepted' | 'declined' | 'order';

export interface Message {
    message_id: number;
    conversation_id: number;
    sender_id: number;
    sender_name: string;
    content: string;
    message_type: MessageType;
    negotiation_id: number | null;
    order_id: number | null;
    offer_price: number | null;
    offer_quantity: number | null;
    read_at: string | null;
    sent_at: string;
}

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
    product_image: string | null;
    seller_location: string;
    created_at: string;
    last_message: string | null;
    last_message_type: MessageType | null;
    last_message_at: string | null;
    unread_count: number;
    // Latest negotiation on this thread, open or closed; null before any offer.
    negotiation_id: number | null;
    negotiation_status: string | null;
    offered_price: number | null;
    offered_quantity: number | null;
    // The order placed on that latest negotiation, if any.
    order_id: number | null;
    order_status: string | null;
}

const messageQuery = `
    SELECT m.*, u.first_name || ' ' || u.last_name AS sender_name
    FROM messages m
    JOIN users u ON u.user_id = m.sender_id
`;

function mapMessage(row: Record<string, unknown>): Message {
    const num = (value: unknown) => (value === null || value === undefined ? null : Number(value));
    return {
        message_id: Number(row.message_id),
        conversation_id: Number(row.conversation_id),
        sender_id: Number(row.sender_id),
        sender_name: String(row.sender_name),
        content: String(row.content),
        message_type: String(row.message_type) as MessageType,
        negotiation_id: num(row.negotiation_id),
        order_id: num(row.order_id),
        offer_price: num(row.offer_price),
        offer_quantity: num(row.offer_quantity),
        read_at: row.read_at ? String(row.read_at) : null,
        sent_at: String(row.sent_at),
    };
}

// @userId drives unread_count only; every other column is the same for both
// parties. The correlated subqueries are fine at demo scale.
const conversationQuery = `
    SELECT c.*,
           b.first_name || ' ' || b.last_name AS buyer_name,
           s.first_name || ' ' || s.last_name AS seller_name,
           p.crop_name, p.base_price, p.unit_measurement, p.status AS product_status,
           (SELECT pi.image_url FROM product_images pi WHERE pi.product_id = p.product_id ORDER BY pi.display_order LIMIT 1) AS product_image,
           COALESCE(a.city_municipality, 'Philippines') AS seller_location,
           lm.content AS last_message, lm.message_type AS last_message_type, lm.sent_at AS last_message_at,
           (SELECT COUNT(*) FROM messages um WHERE um.conversation_id = c.conversation_id AND um.sender_id != @userId AND um.read_at IS NULL) AS unread_count,
           n.negotiation_id, n.status AS negotiation_status, n.offered_price, n.offered_quantity,
           o.order_id, o.order_status
    FROM conversations c
    JOIN users b ON b.user_id = c.buyer_id
    JOIN users s ON s.user_id = c.seller_id
    JOIN products p ON p.product_id = c.product_id
    LEFT JOIN farmer_profiles fp ON fp.farmer_id = c.seller_id
    LEFT JOIN addresses a ON a.address_id = fp.address_id
    LEFT JOIN messages lm ON lm.message_id = (
        SELECT message_id FROM messages WHERE conversation_id = c.conversation_id ORDER BY message_id DESC LIMIT 1
    )
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
        product_image: str(row.product_image),
        seller_location: String(row.seller_location),
        created_at: String(row.created_at),
        last_message: str(row.last_message),
        last_message_type: str(row.last_message_type) as MessageType | null,
        last_message_at: str(row.last_message_at),
        unread_count: Number(row.unread_count ?? 0),
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
    // sort by creation so they still show up.
    findForUser(userId: number): ConversationSummary[] {
        const rows = db.prepare(`
            ${conversationQuery}
            WHERE c.buyer_id = @userId OR c.seller_id = @userId
            ORDER BY COALESCE(lm.message_id, 0) DESC, c.conversation_id DESC
        `).all({ userId }) as Record<string, unknown>[];
        return rows.map(mapConversation);
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

    messages(conversationId: number): Message[] {
        const rows = db.prepare(`${messageQuery} WHERE m.conversation_id = ? ORDER BY m.message_id ASC`)
            .all(conversationId) as Record<string, unknown>[];
        return rows.map(mapMessage);
    },

    addMessage(input: {
        conversation_id: number;
        sender_id: number;
        content: string;
        message_type?: MessageType;
        negotiation_id?: number;
        order_id?: number;
        offer_price?: number;
        offer_quantity?: number;
    }): Message {
        const result = db.prepare(`
            INSERT INTO messages (conversation_id, sender_id, content, message_type, negotiation_id, order_id, offer_price, offer_quantity)
            VALUES (@conversation_id, @sender_id, @content, @message_type, @negotiation_id, @order_id, @offer_price, @offer_quantity)
        `).run({
            conversation_id: input.conversation_id,
            sender_id: input.sender_id,
            content: input.content,
            message_type: input.message_type ?? 'text',
            negotiation_id: input.negotiation_id ?? null,
            order_id: input.order_id ?? null,
            offer_price: input.offer_price ?? null,
            offer_quantity: input.offer_quantity ?? null,
        });
        const row = db.prepare(`${messageQuery} WHERE m.message_id = ?`).get(result.lastInsertRowid) as Record<string, unknown>;
        const conversation = db.prepare(`
            SELECT buyer_id, seller_id, product_id
            FROM conversations
            WHERE conversation_id = ?
        `).get(input.conversation_id) as { buyer_id: number; seller_id: number; product_id: number | null };
        const recipientId = conversation.buyer_id === input.sender_id ? conversation.seller_id : conversation.buyer_id;
        const title = input.message_type === 'offer' || input.message_type === 'counter'
            ? 'New Offer'
            : input.message_type === 'order'
                && (input.content.startsWith('Received order #') || input.content.startsWith('Picked up order #'))
                ? 'Delivered'
                : 'New Message';
        NotificationModel.create({
            recipientId,
            senderId: input.sender_id,
            productId: conversation.product_id,
            title,
            message: input.content,
        });
        return mapMessage(row);
    },

    // Marks everything the other party sent as read. Returns rows touched.
    markRead(conversationId: number, readerId: number): number {
        return db.prepare(`
            UPDATE messages SET read_at = CURRENT_TIMESTAMP
            WHERE conversation_id = ? AND sender_id != ? AND read_at IS NULL
        `).run(conversationId, readerId).changes;
    },
};
