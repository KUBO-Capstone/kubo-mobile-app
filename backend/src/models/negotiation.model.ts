import { db } from "#config/database";
import { ConversationModel } from "#models/conversation.model";

// Mirrors the CHECK constraint on negotiations.status in config/database.ts.
// The status also encodes whose turn it is: 'pending' means the buyer moved
// last and the seller must respond; 'countered' means the seller moved last
// and the buyer must respond. A counter overwrites the price on the same row.
export type NegotiationStatus = 'pending' | 'countered' | 'accepted' | 'declined';
export const OPEN_STATUSES: NegotiationStatus[] = ['pending', 'countered'];

export interface NegotiationInput {
    product_id: number;
    buyer_id: number;
    seller_id: number;
    offered_price: number;
    offered_quantity: number;
}

export interface Negotiation {
    negotiation_id: number;
    conversation_id: number;
    product_id: number;
    buyer_id: number;
    seller_id: number;
    offered_price: number;
    offered_quantity: number;
    status: NegotiationStatus;
    created_at: string;
    crop_name: string;
    unit_measurement: string;
    base_price: number;
    product_status: string;
    buyer_name: string;
    seller_name: string;
}

const negotiationQuery = `
    SELECT n.*,
           p.crop_name, p.unit_measurement, p.base_price, p.status AS product_status,
           b.first_name || ' ' || b.last_name AS buyer_name,
           s.first_name || ' ' || s.last_name AS seller_name
    FROM negotiations n
    JOIN products p ON p.product_id = n.product_id
    JOIN users b ON b.user_id = n.buyer_id
    JOIN users s ON s.user_id = n.seller_id
`;

function mapNegotiation(row: Record<string, unknown>): Negotiation {
    return {
        negotiation_id: Number(row.negotiation_id),
        conversation_id: Number(row.conversation_id),
        product_id: Number(row.product_id),
        buyer_id: Number(row.buyer_id),
        seller_id: Number(row.seller_id),
        offered_price: Number(row.offered_price),
        offered_quantity: Number(row.offered_quantity),
        status: String(row.status) as NegotiationStatus,
        created_at: String(row.created_at),
        crop_name: String(row.crop_name),
        unit_measurement: String(row.unit_measurement),
        base_price: Number(row.base_price),
        product_status: String(row.product_status),
        buyer_name: String(row.buyer_name),
        seller_name: String(row.seller_name),
    };
}

export const NegotiationModel = {
    findById(negotiationId: number): Negotiation | undefined {
        const row = db.prepare(`${negotiationQuery} WHERE n.negotiation_id = ?`).get(negotiationId) as Record<string, unknown> | undefined;
        return row ? mapNegotiation(row) : undefined;
    },

    // Every negotiation the user is a party to, newest first. `role` narrows
    // to one side so the app can render "received" and "sent" tabs.
    findForUser(userId: number, role?: 'buyer' | 'seller', status?: NegotiationStatus): Negotiation[] {
        const conditions = role === 'buyer'
            ? ['n.buyer_id = @userId']
            : role === 'seller'
                ? ['n.seller_id = @userId']
                : ['(n.buyer_id = @userId OR n.seller_id = @userId)'];
        if (status) conditions.push('n.status = @status');
        const rows = db.prepare(`${negotiationQuery} WHERE ${conditions.join(' AND ')} ORDER BY n.negotiation_id DESC`)
            .all({ userId, status }) as Record<string, unknown>[];
        return rows.map(mapNegotiation);
    },

    // A buyer holds at most one open offer per listing; the controller turns
    // a hit here into a 409.
    findOpenForBuyer(buyerId: number, productId: number): Negotiation | undefined {
        const row = db.prepare(`${negotiationQuery} WHERE n.buyer_id = ? AND n.product_id = ? AND n.status IN ('pending', 'countered')`)
            .get(buyerId, productId) as Record<string, unknown> | undefined;
        return row ? mapNegotiation(row) : undefined;
    },

    // An offer always lives inside the buyer/seller thread for that listing
    // (negotiations.conversation_id is NOT NULL), so the chat screen can show
    // it as the first message the way Carousell does.
    create(input: NegotiationInput): Negotiation {
        const insert = db.transaction(() => {
            const conversationId = ConversationModel.findOrCreate(input.buyer_id, input.seller_id, input.product_id);

            const result = db.prepare(`
                INSERT INTO negotiations (conversation_id, product_id, buyer_id, seller_id, offered_price, offered_quantity)
                VALUES (@conversation_id, @product_id, @buyer_id, @seller_id, @offered_price, @offered_quantity)
            `).run({ ...input, conversation_id: conversationId });
            return Number(result.lastInsertRowid);
        });
        return NegotiationModel.findById(insert()) as Negotiation;
    },

    // Accept/decline only move the status; a counter also rewrites the terms.
    update(negotiationId: number, changes: { status: NegotiationStatus; offered_price?: number; offered_quantity?: number }): Negotiation | undefined {
        db.prepare(`
            UPDATE negotiations
            SET status = @status,
                offered_price = COALESCE(@offered_price, offered_price),
                offered_quantity = COALESCE(@offered_quantity, offered_quantity)
            WHERE negotiation_id = @negotiationId
        `).run({
            negotiationId,
            status: changes.status,
            offered_price: changes.offered_price ?? null,
            offered_quantity: changes.offered_quantity ?? null,
        });
        return NegotiationModel.findById(negotiationId);
    },
};
