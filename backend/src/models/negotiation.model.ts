import { isRowId, pool, withTransaction } from "#database/pg";
import { ConversationModel } from "#models/conversation.model";

// Mirrors the CHECK constraint on negotiations.status in database/migrations.
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
    allows_meetup: boolean;
    allows_delivery: boolean;
    accepted_by: number | null;
    buyer_name: string;
    seller_name: string;
}

const negotiationQuery = `
    SELECT n.*,
           p.crop_name, p.unit_measurement, p.base_price, p.status AS product_status,
           p.allows_meetup, p.allows_delivery,
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
        allows_meetup: row.allows_meetup !== false,
        allows_delivery: row.allows_delivery !== false,
        accepted_by: row.accepted_by === null || row.accepted_by === undefined ? null : Number(row.accepted_by),
        buyer_name: String(row.buyer_name),
        seller_name: String(row.seller_name),
    };
}

export const NegotiationModel = {
    async findById(negotiationId: number): Promise<Negotiation | undefined> {
        if (!isRowId(negotiationId)) return undefined;
        const { rows } = await pool.query(`${negotiationQuery} WHERE n.negotiation_id = $1`, [negotiationId]);
        return rows[0] ? mapNegotiation(rows[0]) : undefined;
    },

    // Every negotiation the user is a party to, newest first. `role` narrows
    // to one side so the app can render "received" and "sent" tabs.
    async findForUser(userId: number, role?: 'buyer' | 'seller', status?: NegotiationStatus): Promise<Negotiation[]> {
        const conditions = role === 'buyer'
            ? ['n.buyer_id = $1']
            : role === 'seller'
                ? ['n.seller_id = $1']
                : ['(n.buyer_id = $1 OR n.seller_id = $1)'];
        const params: unknown[] = [userId];
        if (status) {
            params.push(status);
            conditions.push(`n.status = $${params.length}`);
        }
        const { rows } = await pool.query(`${negotiationQuery} WHERE ${conditions.join(' AND ')} ORDER BY n.negotiation_id DESC`, params);
        return rows.map(mapNegotiation);
    },

    // A buyer holds at most one open offer per listing; the controller turns
    // a hit here into a 409 (and uq_negotiations_open_offer catches a race).
    async findOpenForBuyer(buyerId: number, productId: number): Promise<Negotiation | undefined> {
        const { rows } = await pool.query(`${negotiationQuery} WHERE n.buyer_id = $1 AND n.product_id = $2 AND n.status IN ('pending', 'countered')`,
            [buyerId, productId]);
        return rows[0] ? mapNegotiation(rows[0]) : undefined;
    },

    // An offer always lives inside the buyer/seller thread for that listing
    // (negotiations.conversation_id is NOT NULL), so the chat screen can show
    // it as the first message the way Carousell does.
    async create(input: NegotiationInput): Promise<Negotiation> {
        const negotiationId = await withTransaction(async (client) => {
            const conversationId = await ConversationModel.findOrCreate(input.buyer_id, input.seller_id, input.product_id, client);

            const { rows: [row] } = await client.query(`
                INSERT INTO negotiations (conversation_id, product_id, buyer_id, seller_id, offered_price, offered_quantity)
                VALUES ($1, $2, $3, $4, $5, $6)
                RETURNING negotiation_id
            `, [conversationId, input.product_id, input.buyer_id, input.seller_id, input.offered_price, input.offered_quantity]);
            return Number(row.negotiation_id);
        });
        return (await NegotiationModel.findById(negotiationId)) as Negotiation;
    },

    // Accept/decline only move the status (an accept also records who did
    // it); a counter also rewrites the terms. Applies only while the offer is
    // still `from`, the status the caller checked the turn against: undefined
    // means the other party moved first and nothing was changed.
    async update(
        negotiationId: number,
        from: NegotiationStatus,
        changes: { status: NegotiationStatus; offered_price?: number; offered_quantity?: number; accepted_by?: number },
    ): Promise<Negotiation | undefined> {
        const { rowCount } = await pool.query(`
            UPDATE negotiations
            SET status = $3,
                offered_price = COALESCE($4, offered_price),
                offered_quantity = COALESCE($5, offered_quantity),
                accepted_by = COALESCE($6, accepted_by)
            WHERE negotiation_id = $1 AND status = $2
        `, [negotiationId, from, changes.status, changes.offered_price ?? null, changes.offered_quantity ?? null, changes.accepted_by ?? null]);
        return rowCount ? NegotiationModel.findById(negotiationId) : undefined;
    },

    // Records that one side has seen the "deal closed" screen. Only the
    // first call counts, so a second device does not move the timestamp.
    async markCelebrated(negotiationId: number, side: 'buyer' | 'seller'): Promise<void> {
        const column = side === 'buyer' ? 'buyer_celebrated_at' : 'seller_celebrated_at';
        await pool.query(`UPDATE negotiations SET ${column} = COALESCE(${column}, now()) WHERE negotiation_id = $1`, [negotiationId]);
    },
};
