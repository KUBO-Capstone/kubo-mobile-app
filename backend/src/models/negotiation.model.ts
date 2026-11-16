import { isRowId, pool, Queryable, withTransaction } from "#database/pg";
import { ConversationModel } from "#models/conversation.model";
import { ProductModel } from "#models/product.model";

// Mirrors the CHECK constraint on negotiations.status in database/migrations.
// The status also encodes whose turn it is: 'pending' means the buyer moved
// last and the seller must respond; 'countered' means the seller moved last
// and the buyer must respond. A counter overwrites the price on the same row.
// 'declined' closes an offer without a deal: one that was turned down or
// withdrawn, or an accepted one that was cancelled before it was ordered
// (that one still has accepted_by set).
export type NegotiationStatus = 'pending' | 'countered' | 'accepted' | 'declined';
export const OPEN_STATUSES: NegotiationStatus[] = ['pending', 'countered'];

// Why an accept or a cancel wrote nothing.
//   changed     - the offer is no longer what the caller checked
//   unavailable - the listing was removed or has less stock left than the offer
//   ordered     - the deal already has an order, which is cancelled instead
export type DealRefusal = 'changed' | 'unavailable' | 'ordered';
export type DealResult = { negotiation: Negotiation; refused?: undefined } | { negotiation?: undefined; refused: DealRefusal };

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
    // Stock this offer is holding off the listing: set from the moment it is
    // accepted until it is ordered or cancelled. Null otherwise, and for
    // offers accepted before holds existed.
    reserved_quantity: number | null;
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
        reserved_quantity: row.reserved_quantity === null || row.reserved_quantity === undefined ? null : Number(row.reserved_quantity),
        buyer_name: String(row.buyer_name),
        seller_name: String(row.seller_name),
    };
}

export const NegotiationModel = {
    async findById(negotiationId: number, q: Queryable = pool): Promise<Negotiation | undefined> {
        if (!isRowId(negotiationId)) return undefined;
        const { rows } = await q.query(`${negotiationQuery} WHERE n.negotiation_id = $1`, [negotiationId]);
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
    // it as the first message the way Carousell does. Read back inside the
    // transaction, so the offer event records these terms even if the seller
    // counters the moment it commits.
    async create(input: NegotiationInput): Promise<Negotiation> {
        return withTransaction(async (client) => {
            const conversationId = await ConversationModel.findOrCreate(input.buyer_id, input.seller_id, input.product_id, client);

            const { rows: [row] } = await client.query(`
                INSERT INTO negotiations (conversation_id, product_id, buyer_id, seller_id, offered_price, offered_quantity)
                VALUES ($1, $2, $3, $4, $5, $6)
                RETURNING negotiation_id
            `, [conversationId, input.product_id, input.buyer_id, input.seller_id, input.offered_price, input.offered_quantity]);
            return (await NegotiationModel.findById(Number(row.negotiation_id), client)) as Negotiation;
        });
    },

    // A decline only moves the status; a counter also rewrites the terms.
    // Applies only while the offer is still exactly what the caller checked:
    // same status and same terms. The status alone is not enough, since a
    // counter and a counter back return it to the same status with other
    // terms. Undefined means the offer changed meanwhile and nothing was
    // written. The result is read while the row is still locked, so it is
    // this change and not a later one.
    async update(
        negotiationId: number,
        expected: Pick<Negotiation, 'status' | 'offered_price' | 'offered_quantity'>,
        changes: { status: 'pending' | 'countered' | 'declined'; offered_price?: number; offered_quantity?: number },
    ): Promise<Negotiation | undefined> {
        return withTransaction(async (client) => {
            const { rowCount } = await client.query(`
                UPDATE negotiations
                SET status = $3,
                    offered_price = COALESCE($4, offered_price),
                    offered_quantity = COALESCE($5, offered_quantity)
                WHERE negotiation_id = $1 AND status = $2 AND offered_price = $6 AND offered_quantity = $7
            `, [negotiationId, expected.status, changes.status, changes.offered_price ?? null, changes.offered_quantity ?? null,
                expected.offered_price, expected.offered_quantity]);
            return rowCount ? NegotiationModel.findById(negotiationId, client) : undefined;
        });
    },

    // Closes the deal: records who accepted and takes the agreed quantity off
    // the listing in the same transaction, so the listing shows what is left
    // from that moment and a seller cannot accept more than they have. The
    // offer keeps that stock (reserved_quantity) until it is ordered or
    // cancelled. Like update(), it only applies to the offer the caller
    // checked. Nothing is written unless both checks pass: the offer row is
    // locked while it is compared, and the stock is only taken if it is there.
    async accept(
        negotiationId: number,
        expected: Pick<Negotiation, 'status' | 'offered_price' | 'offered_quantity'>,
        acceptedBy: number,
    ): Promise<DealResult> {
        return withTransaction(async (client) => {
            const { rows: [offer] } = await client.query(`
                SELECT product_id, offered_quantity FROM negotiations
                WHERE negotiation_id = $1 AND status = $2 AND offered_price = $3 AND offered_quantity = $4
                FOR UPDATE
            `, [negotiationId, expected.status, expected.offered_price, expected.offered_quantity]);
            if (!offer) return { refused: 'changed' };
            if (!(await ProductModel.takeStock(client, Number(offer.product_id), Number(offer.offered_quantity)))) {
                return { refused: 'unavailable' };
            }
            await client.query(`
                UPDATE negotiations
                SET status = 'accepted', accepted_by = $2, reserved_quantity = offered_quantity
                WHERE negotiation_id = $1
            `, [negotiationId, acceptedBy]);
            return { negotiation: (await NegotiationModel.findById(negotiationId, client)) as Negotiation };
        });
    },

    // Either side calls off an accepted deal that has not been ordered yet,
    // and the stock it was holding goes back on the listing. Once there is an
    // order, the order is what gets cancelled (OrderModel.cancel), so this
    // refuses. The offer row is locked first: an order being placed for it at
    // the same moment waits, then finds the deal gone.
    async cancelDeal(negotiationId: number): Promise<DealResult> {
        return withTransaction(async (client) => {
            const { rows: [deal] } = await client.query(`
                SELECT product_id, reserved_quantity FROM negotiations
                WHERE negotiation_id = $1 AND status = 'accepted'
                FOR UPDATE
            `, [negotiationId]);
            if (!deal) return { refused: 'changed' };
            const { rowCount: ordered } = await client.query('SELECT 1 FROM orders WHERE negotiation_id = $1', [negotiationId]);
            if (ordered) return { refused: 'ordered' };

            await client.query(`UPDATE negotiations SET status = 'declined', reserved_quantity = NULL WHERE negotiation_id = $1`, [negotiationId]);
            if (deal.reserved_quantity !== null) {
                await ProductModel.returnStock(client, Number(deal.product_id), Number(deal.reserved_quantity));
            }
            return { negotiation: (await NegotiationModel.findById(negotiationId, client)) as Negotiation };
        });
    },

    // Records that one side has seen the "deal closed" screen. Only the
    // first call counts, so a second device does not move the timestamp.
    async markCelebrated(negotiationId: number, side: 'buyer' | 'seller'): Promise<void> {
        const column = side === 'buyer' ? 'buyer_celebrated_at' : 'seller_celebrated_at';
        await pool.query(`UPDATE negotiations SET ${column} = COALESCE(${column}, now()) WHERE negotiation_id = $1`, [negotiationId]);
    },
};
