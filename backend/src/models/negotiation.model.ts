import { isRowId, pool, Queryable, withTransaction } from "#database/pg";
import { ConversationModel } from "#models/conversation.model";
import { DeliveryMethod, OrderModel } from "#models/order.model";
import { ProductModel } from "#models/product.model";

// Mirrors the CHECK constraint on negotiations.status in database/migrations.
// The status also encodes whose turn it is: 'pending' means the buyer moved
// last and the seller must respond; 'countered' means the seller moved last
// and the buyer must respond. A counter overwrites the terms on the same row.
// 'declined' closes an offer without a deal: one that was turned down or
// withdrawn, or an accepted one that was cancelled before it was ordered
// (that one still has accepted_by set).
export type NegotiationStatus = 'pending' | 'countered' | 'accepted' | 'declined';
export const OPEN_STATUSES: NegotiationStatus[] = ['pending', 'countered'];

// Why a seller turned an offer down, so the buyer knows what to change.
// Mirrors the CHECK constraint on negotiations.decline_reason.
export const DECLINE_REASONS = ['bagsakan_too_far', 'courier_unavailable', 'price_too_low'] as const;
export type DeclineReason = typeof DECLINE_REASONS[number];

// How the produce changes hands, agreed as part of the offer: at a bagsakan
// center (drop_off_center_id) or through a courier (courier_name). Offers
// from before migration 006 carry none, and are ordered the old way.
export interface Fulfillment {
    delivery_method: DeliveryMethod;
    drop_off_center_id: number | null;
    courier_name: string | null;
}

export interface NegotiationInput extends Fulfillment {
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
    // Stock this offer is holding off the listing: only for an accepted
    // offer from before migration 006 that has not been ordered yet. Offers
    // with fulfillment terms are ordered the moment they are accepted, and
    // the order holds the stock.
    reserved_quantity: number | null;
    delivery_method: DeliveryMethod | null;
    drop_off_center_id: number | null;
    center_name: string | null;
    courier_name: string | null;
    decline_reason: DeclineReason | null;
    buyer_name: string;
    seller_name: string;
}

// Why an accept or a cancel wrote nothing.
//   changed            - the offer is no longer what the caller checked
//   unavailable        - the listing was removed or has less stock left than the offer
//   method_unavailable - the seller turned the agreed delivery method off
//   ordered            - the deal already has an order, which is cancelled instead
export type DealRefusal = 'changed' | 'unavailable' | 'method_unavailable' | 'ordered';
export type DealResult =
    | { negotiation: Negotiation; order_id?: number; refused?: undefined }
    | { negotiation?: undefined; order_id?: undefined; refused: DealRefusal };

const negotiationQuery = `
    SELECT n.*,
           p.crop_name, p.unit_measurement, p.base_price, p.status AS product_status,
           p.allows_meetup, p.allows_delivery,
           c.location_name AS center_name,
           b.first_name || ' ' || b.last_name AS buyer_name,
           s.first_name || ' ' || s.last_name AS seller_name
    FROM negotiations n
    JOIN products p ON p.product_id = n.product_id
    JOIN users b ON b.user_id = n.buyer_id
    JOIN users s ON s.user_id = n.seller_id
    LEFT JOIN bagsakan_centers c ON c.center_id = n.drop_off_center_id
`;

const num = (value: unknown): number | null => (value === null || value === undefined ? null : Number(value));
const str = (value: unknown): string | null => (value === null || value === undefined || value === '' ? null : String(value));

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
        accepted_by: num(row.accepted_by),
        reserved_quantity: num(row.reserved_quantity),
        delivery_method: str(row.delivery_method) as DeliveryMethod | null,
        drop_off_center_id: num(row.drop_off_center_id),
        center_name: str(row.center_name),
        courier_name: str(row.courier_name),
        decline_reason: str(row.decline_reason) as DeclineReason | null,
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
                INSERT INTO negotiations (conversation_id, product_id, buyer_id, seller_id, offered_price, offered_quantity,
                                          delivery_method, drop_off_center_id, courier_name)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
                RETURNING negotiation_id
            `, [conversationId, input.product_id, input.buyer_id, input.seller_id, input.offered_price, input.offered_quantity,
                input.delivery_method, input.drop_off_center_id, input.courier_name]);
            return (await NegotiationModel.findById(Number(row.negotiation_id), client)) as Negotiation;
        });
    },

    // A decline only moves the status (and records why); a counter also
    // rewrites the terms: the price, the quantity, and how the produce
    // changes hands. Applies only while the offer is still exactly what the
    // caller checked: same status and same terms. The status alone is not
    // enough, since a counter and a counter back return it to the same
    // status with other terms. Undefined means the offer changed meanwhile
    // and nothing was written. The result is read while the row is still
    // locked, so it is this change and not a later one.
    async update(
        negotiationId: number,
        expected: Pick<Negotiation, 'status' | 'offered_price' | 'offered_quantity'>,
        changes: {
            status: 'pending' | 'countered' | 'declined';
            offered_price?: number;
            offered_quantity?: number;
            fulfillment?: Fulfillment;
            decline_reason?: DeclineReason | null;
        },
    ): Promise<Negotiation | undefined> {
        return withTransaction(async (client) => {
            const fulfillment = changes.fulfillment;
            const { rowCount } = await client.query(`
                UPDATE negotiations
                SET status = $3,
                    offered_price = COALESCE($4, offered_price),
                    offered_quantity = COALESCE($5, offered_quantity),
                    delivery_method = CASE WHEN $8 THEN $9 ELSE delivery_method END,
                    drop_off_center_id = CASE WHEN $8 THEN $10 ELSE drop_off_center_id END,
                    courier_name = CASE WHEN $8 THEN $11 ELSE courier_name END,
                    decline_reason = $12
                WHERE negotiation_id = $1 AND status = $2 AND offered_price = $6 AND offered_quantity = $7
            `, [negotiationId, expected.status, changes.status, changes.offered_price ?? null, changes.offered_quantity ?? null,
                expected.offered_price, expected.offered_quantity,
                fulfillment !== undefined, fulfillment?.delivery_method ?? null, fulfillment?.drop_off_center_id ?? null, fulfillment?.courier_name ?? null,
                changes.decline_reason ?? null]);
            return rowCount ? NegotiationModel.findById(negotiationId, client) : undefined;
        });
    },

    // Closes the deal. The agreed quantity comes off the listing in the same
    // transaction, so the listing shows what is left from that moment and a
    // seller cannot accept more than they have. An offer that says how the
    // produce changes hands becomes an order right here, with those terms
    // locked in; an older offer without them keeps holding the stock
    // (reserved_quantity) until the buyer places the order. Like update(),
    // it only applies to the offer the caller checked. Nothing is written
    // unless every check passes: the offer row is locked while it is
    // compared, and the stock is only taken if it is there.
    async accept(
        negotiationId: number,
        expected: Pick<Negotiation, 'status' | 'offered_price' | 'offered_quantity'>,
        acceptedBy: number,
    ): Promise<DealResult> {
        return withTransaction(async (client) => {
            const { rows: [offer] } = await client.query(`
                SELECT product_id, buyer_id, seller_id, offered_price, offered_quantity,
                       delivery_method, drop_off_center_id, courier_name
                FROM negotiations
                WHERE negotiation_id = $1 AND status = $2 AND offered_price = $3 AND offered_quantity = $4
                FOR UPDATE
            `, [negotiationId, expected.status, expected.offered_price, expected.offered_quantity]);
            if (!offer) return { refused: 'changed' };

            const method = offer.delivery_method as DeliveryMethod | null;
            if (method) {
                // The listing row is locked here, and stays so through takeStock.
                const { rows: [product] } = await client.query(
                    `SELECT allows_meetup, allows_delivery FROM products WHERE product_id = $1 AND status <> 'delisted' FOR UPDATE`,
                    [offer.product_id]);
                if (!product) return { refused: 'unavailable' };
                if (method === 'meetup' ? product.allows_meetup === false : product.allows_delivery === false) {
                    return { refused: 'method_unavailable' };
                }
            }
            if (!(await ProductModel.takeStock(client, Number(offer.product_id), Number(offer.offered_quantity)))) {
                return { refused: 'unavailable' };
            }

            let orderId: number | undefined;
            if (method) {
                orderId = await OrderModel.insert(client, {
                    negotiation_id: negotiationId,
                    buyer_id: Number(offer.buyer_id),
                    seller_id: Number(offer.seller_id),
                    product_id: Number(offer.product_id),
                    quantity: Number(offer.offered_quantity),
                    negotiated_price: Number(offer.offered_price),
                    delivery_method: method,
                    drop_off_center_id: num(offer.drop_off_center_id),
                    courier_name: str(offer.courier_name),
                });
            }
            // With an order, the order holds the stock; without one, the offer does.
            await client.query(`
                UPDATE negotiations
                SET status = 'accepted', accepted_by = $2, decline_reason = NULL,
                    reserved_quantity = CASE WHEN $3 THEN NULL ELSE offered_quantity END
                WHERE negotiation_id = $1
            `, [negotiationId, acceptedBy, orderId !== undefined]);
            return { negotiation: (await NegotiationModel.findById(negotiationId, client)) as Negotiation, order_id: orderId };
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

    // Records that one side has seen the "deal closed" screen, which shows
    // once the buyer has confirmed receipt. Only the first call counts, so a
    // second device does not move the timestamp.
    async markCelebrated(negotiationId: number, side: 'buyer' | 'seller'): Promise<void> {
        const column = side === 'buyer' ? 'buyer_celebrated_at' : 'seller_celebrated_at';
        await pool.query(`UPDATE negotiations SET ${column} = COALESCE(${column}, now()) WHERE negotiation_id = $1`, [negotiationId]);
    },
};
