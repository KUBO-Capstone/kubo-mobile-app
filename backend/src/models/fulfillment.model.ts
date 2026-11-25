import { isRowId, pool, withTransaction } from "#database/pg";
import { BagsakanCenter, BagsakanModel } from "#models/bagsakan.model";
import { sellerPlaceJoins } from "#models/product.model";

// How a seller can hand produce over: which bagsakan centers they can drop
// at and which couriers they can book, plus where they ship from. The
// buyer's offer form only lets them pick what the seller can do, so no
// offer asks for a center the seller cannot reach.
//
// The seller sets this once on their profile. A listing follows the
// profile unless the seller gives it its own choices; those never change
// the profile's.

// Couriers a Kubo order can go through. The courier a buyer picks and the
// couriers a seller marks as available both come from this list.
export const COURIERS = [
    'Lalamove',
    'Grab Express',
    'J&T Express',
    'LBC Express',
    'Ninja Van',
    'Flash Express',
    'Transportify',
] as const;

export type Courier = typeof COURIERS[number];

export const isCourier = (value: unknown): value is Courier => typeof value === 'string' && (COURIERS as readonly string[]).includes(value);

export interface SellerFulfillment {
    seller_id: number;
    // Set when this answer is for one listing.
    product_id: number | null;
    // 'listing' when the listing has its own choices, 'profile' otherwise.
    source: 'profile' | 'listing';
    // Where the produce starts from: the seller's farm address, or the town
    // they registered with. Shown to buyers as "Pickup from ...".
    origin_label: string;
    origin_region: string;
    // Every center, flagged with whether it can be picked.
    centers: (BagsakanCenter & { supported: boolean })[];
    couriers: { name: Courier; supported: boolean }[];
    // False until the choices are narrowed down; everything counts as
    // supported until then.
    configured_centers: boolean;
    configured_couriers: boolean;
}

// "LOS BAÑOS, LAGUNA" / "CITY OF MAKATI, NCR" / "" when the seller has no address.
const originLabel = (row: { city: string; province: string; region: string }): string => {
    if (!row.city) return '';
    const area = row.province || row.region.split(' - ')[0].trim();
    return area ? `${row.city}, ${area}` : row.city;
};

// Builds the answer from the chosen center ids and courier names; an empty
// set means "any".
const describe = async (
    sellerId: number,
    productId: number | null,
    source: 'profile' | 'listing',
    chosenCenters: Set<number>,
    chosenCouriers: Set<string>,
): Promise<SellerFulfillment | undefined> => {
    const [{ rows: [place] }, centers] = await Promise.all([
        pool.query<{ city: string; province: string; region: string }>(`
            SELECT COALESCE(a.city_municipality, '') AS city,
                   COALESCE(a.province, '') AS province,
                   COALESCE(a.region, '') AS region
            FROM users u
            ${sellerPlaceJoins}
            WHERE u.user_id = $1
        `, [sellerId]),
        BagsakanModel.findAll(),
    ]);
    if (!place) return undefined;
    return {
        seller_id: sellerId,
        product_id: productId,
        source,
        origin_label: originLabel(place),
        origin_region: place.region,
        centers: centers.map((center) => ({ ...center, supported: chosenCenters.size === 0 || chosenCenters.has(center.center_id) })),
        couriers: COURIERS.map((name) => ({ name, supported: chosenCouriers.size === 0 || chosenCouriers.has(name) })),
        configured_centers: chosenCenters.size > 0,
        configured_couriers: chosenCouriers.size > 0,
    };
};

const profileChoices = async (sellerId: number): Promise<[Set<number>, Set<string>]> => {
    const [{ rows: centers }, { rows: couriers }] = await Promise.all([
        pool.query<{ center_id: number }>('SELECT center_id FROM seller_bagsakan_centers WHERE seller_id = $1', [sellerId]),
        pool.query<{ courier: string }>('SELECT courier FROM seller_couriers WHERE seller_id = $1', [sellerId]),
    ]);
    return [new Set(centers.map((row) => Number(row.center_id))), new Set(couriers.map((row) => row.courier))];
};

export const FulfillmentModel = {
    // The seller's profile choices.
    async forSeller(sellerId: number): Promise<SellerFulfillment | undefined> {
        if (!isRowId(sellerId)) return undefined;
        const [centers, couriers] = await profileChoices(sellerId);
        return describe(sellerId, null, 'profile', centers, couriers);
    },

    // What a buyer can pick on one listing: the listing's own choices when
    // the seller set them, the profile's otherwise. Undefined for a listing
    // that does not exist.
    async forProduct(productId: number): Promise<SellerFulfillment | undefined> {
        if (!isRowId(productId)) return undefined;
        const { rows: [product] } = await pool.query<{ seller_id: number; custom_fulfillment: boolean }>(
            `SELECT seller_id, custom_fulfillment FROM products WHERE product_id = $1`, [productId]);
        if (!product) return undefined;
        const sellerId = Number(product.seller_id);
        if (!product.custom_fulfillment) {
            const [centers, couriers] = await profileChoices(sellerId);
            return describe(sellerId, productId, 'profile', centers, couriers);
        }
        const [{ rows: centers }, { rows: couriers }] = await Promise.all([
            pool.query<{ center_id: number }>('SELECT center_id FROM product_bagsakan_centers WHERE product_id = $1', [productId]),
            pool.query<{ courier: string }>('SELECT courier FROM product_couriers WHERE product_id = $1', [productId]),
        ]);
        return describe(sellerId, productId, 'listing',
            new Set(centers.map((row) => Number(row.center_id))), new Set(couriers.map((row) => row.courier)));
    },

    // Replaces the seller's profile lists. An empty list means "not narrowed
    // down": buyers may pick any center or courier again. Listings with
    // their own choices are not touched.
    async save(sellerId: number, centerIds: number[], couriers: Courier[]): Promise<void> {
        await withTransaction(async (client) => {
            await client.query('DELETE FROM seller_bagsakan_centers WHERE seller_id = $1', [sellerId]);
            await client.query('DELETE FROM seller_couriers WHERE seller_id = $1', [sellerId]);
            if (centerIds.length > 0) {
                await client.query(`
                    INSERT INTO seller_bagsakan_centers (seller_id, center_id)
                    SELECT $1, unnest($2::int[])
                    ON CONFLICT DO NOTHING
                `, [sellerId, centerIds]);
            }
            if (couriers.length > 0) {
                await client.query(`
                    INSERT INTO seller_couriers (seller_id, courier)
                    SELECT $1, unnest($2::text[])
                    ON CONFLICT DO NOTHING
                `, [sellerId, couriers]);
            }
        });
    },

    // Gives one listing its own choices (custom true), or sends it back to
    // following the profile (custom false, which drops its own lists). The
    // profile's lists are never touched.
    async saveForProduct(productId: number, custom: boolean, centerIds: number[], couriers: Courier[]): Promise<void> {
        await withTransaction(async (client) => {
            await client.query('UPDATE products SET custom_fulfillment = $2 WHERE product_id = $1', [productId, custom]);
            await client.query('DELETE FROM product_bagsakan_centers WHERE product_id = $1', [productId]);
            await client.query('DELETE FROM product_couriers WHERE product_id = $1', [productId]);
            if (!custom) return;
            if (centerIds.length > 0) {
                await client.query(`
                    INSERT INTO product_bagsakan_centers (product_id, center_id)
                    SELECT $1, unnest($2::int[])
                    ON CONFLICT DO NOTHING
                `, [productId, centerIds]);
            }
            if (couriers.length > 0) {
                await client.query(`
                    INSERT INTO product_couriers (product_id, courier)
                    SELECT $1, unnest($2::text[])
                    ON CONFLICT DO NOTHING
                `, [productId, couriers]);
            }
        });
    },
};
