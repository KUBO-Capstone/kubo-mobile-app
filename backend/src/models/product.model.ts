import { isRowId, pool, Queryable, withTransaction } from "#database/pg";
import { fromMediaColumn, toMediaColumn } from "#controllers/upload.controller";

// Mirror the CHECK constraints on products in database/migrations.
export const productCategories = ['vegetable', 'fruit', 'grain', 'legume', 'herb', 'spice'] as const;
export const productUnits = ['kg', 'g', 'lb', 'oz', 'liter', 'ml', 'piece'] as const;
export const qualityGrades = ['premium', 'standard', 'imperfect'] as const;
export const farmingMethods = ['conventional', 'organic', 'pesticide-free'] as const;

export type QualityGrade = typeof qualityGrades[number];
export type FarmingMethod = typeof farmingMethods[number];

export interface ProductDetails {
    crop_name: string;
    category: string;
    base_price: number;
    available_quantity: number;
    unit_measurement: string;
    description: string;
    quality_grade: QualityGrade;
    farming_method: FarmingMethod;
    harvest_date: string | null;
    is_preorder: boolean;
    allows_meetup: boolean;
    allows_delivery: boolean;
}

export interface ProductInput extends ProductDetails {
    seller_id: number;
}

// Mirrors the CHECK constraint on products.status in database/migrations.
// 'delisted' is the soft delete: negotiations and orders keep pointing at the
// row (the schema refuses a real DELETE), so removing a listing never drops it.
export type ProductStatus = 'available' | 'out of stock' | 'delisted';

// Fields a seller may change after publishing. Everything is optional so a
// status-only change does not have to resend the whole listing.
export type ProductChanges = Partial<ProductDetails & { status: ProductStatus }>;

export interface ProductListing extends ProductDetails {
    product_id: number;
    seller_id: number;
    status: string;
    created_at: string;
    seller_name: string;
    location_label: string;
    region_label: string;
    latitude: number | null;
    longitude: number | null;
    images: string[];
    // The seller's average rating across every review they received.
    seller_rating: number | null;
    seller_review_count: number;
    // The seller's profile photo, for the seller card; null when they have none.
    seller_photo: string | null;
}

// Where a seller's produce is. `u` is the seller's users row; `a` comes out as
// their farm address when they have a farmer profile, otherwise the address
// they registered with, and `pc` as the looked-up point for that town (see
// services/geocoding.service.ts). Exported so every query that shows a
// seller's location places them the same way.
export const sellerPlaceJoins = `
    LEFT JOIN farmer_profiles fp ON fp.farmer_id = u.user_id
    LEFT JOIN addresses a ON a.address_id = COALESCE(fp.address_id, u.preferred_address_id)
    LEFT JOIN place_coordinates pc ON pc.city = lower(btrim(a.city_municipality))
                                  AND pc.province = lower(btrim(a.province))
`;

// A farm address is plotted where it is. A seller without one is plotted at
// their town's point, never at the coordinates of their own address.
const hasFarmPoint = `fp.farmer_id IS NOT NULL AND a.latitude IS NOT NULL AND a.longitude IS NOT NULL`;

// Exported so other models (saved listings) can list products in exactly the
// shape the explore grid gets; keep the two in step.
export const listingQuery = `
    SELECT p.*, u.first_name || ' ' || u.last_name AS seller_name, u.profile_photo_key AS seller_photo,
           COALESCE(a.city_municipality, 'Philippines') AS location_label,
           COALESCE(a.region, 'NCR') AS region_label,
           CASE WHEN ${hasFarmPoint} THEN a.latitude ELSE pc.latitude END AS latitude,
           CASE WHEN ${hasFarmPoint} THEN a.longitude ELSE pc.longitude END AS longitude,
           ARRAY(SELECT pi.image_key FROM product_images pi WHERE pi.product_id = p.product_id ORDER BY pi.display_order) AS images,
           (SELECT ROUND(AVG(r.rating), 1) FROM reviews r WHERE r.reviewee_id = p.seller_id) AS seller_rating,
           (SELECT COUNT(*) FROM reviews r WHERE r.reviewee_id = p.seller_id) AS seller_review_count
    FROM products p
    JOIN users u ON u.user_id = p.seller_id
    ${sellerPlaceJoins}
`;

// One line of search help: a listing title, a town or a seller that has
// listings up right now, so picking it always finds something.
export interface ListingSuggestion {
    text: string;
    type: 'listing' | 'place' | 'seller';
    listing_count: number;
    // Cover photo of the newest matching listing; only listing rows have one.
    image: string | null;
}

// LIKE treats % and _ as wildcards; typed text has to match them literally.
const escapeLike = (text: string): string => text.replace(/[\\%_]/g, '\\$&');
const likePattern = (text: string): string => `%${escapeLike(text)}%`;

/** An edit that would leave a listing's status at odds with its stock. */
export class StockRuleError extends Error {}

export function mapListing(row: Record<string, unknown>): ProductListing {
    return {
        product_id: Number(row.product_id),
        seller_id: Number(row.seller_id),
        crop_name: String(row.crop_name),
        category: String(row.category),
        base_price: Number(row.base_price),
        available_quantity: Number(row.available_quantity),
        unit_measurement: String(row.unit_measurement),
        status: String(row.status),
        created_at: String(row.created_at),
        seller_name: String(row.seller_name),
        location_label: String(row.location_label),
        region_label: String(row.region_label),
        latitude: row.latitude === null || row.latitude === undefined ? null : Number(row.latitude),
        longitude: row.longitude === null || row.longitude === undefined ? null : Number(row.longitude),
        // Empty when the seller wrote none; the app shows its own fallback.
        description: typeof row.description === 'string' ? row.description : '',
        quality_grade: (row.quality_grade ?? 'standard') as QualityGrade,
        farming_method: (row.farming_method ?? 'conventional') as FarmingMethod,
        harvest_date: row.harvest_date ? String(row.harvest_date) : null,
        is_preorder: row.is_preorder === true,
        allows_meetup: row.allows_meetup !== false,
        allows_delivery: row.allows_delivery !== false,
        images: ((row.images ?? []) as string[]).map(fromMediaColumn),
        seller_rating: row.seller_rating === null || row.seller_rating === undefined ? null : Number(row.seller_rating),
        seller_review_count: Number(row.seller_review_count ?? 0),
        seller_photo: typeof row.seller_photo === 'string' && row.seller_photo ? fromMediaColumn(row.seller_photo) : null,
    };
}

function toSuggestion(row: Record<string, unknown>, type: ListingSuggestion['type']): ListingSuggestion {
    return {
        text: String(row.text),
        type,
        listing_count: Number(row.listing_count),
        image: typeof row.image === 'string' && row.image ? fromMediaColumn(row.image) : null,
    };
}

// One statement for the whole list; display_order follows the array.
const insertImages = async (q: Queryable, productId: number, images: string[]): Promise<void> => {
    if (images.length === 0) return;
    await q.query(`
        INSERT INTO product_images (product_id, image_key, display_order)
        SELECT $1::int, image.key, image.position - 1
        FROM unnest($2::text[]) WITH ORDINALITY AS image(key, position)
    `, [productId, images.map(toMediaColumn)]);
};

export const ProductModel = {
    // includeUnavailable adds 'out of stock' rows, listed after the ones still
    // for sale; delisted rows never come back from a list query.
    async findAll(query = '', sellerId?: number, includeUnavailable = false): Promise<ProductListing[]> {
        const normalizedQuery = query.trim().toLowerCase();
        const conditions = [includeUnavailable ? `p.status IN ('available', 'out of stock')` : `p.status = 'available'`];
        const params: unknown[] = [];
        if (normalizedQuery) {
            params.push(likePattern(normalizedQuery));
            const n = `$${params.length}`;
            conditions.push(`(LOWER(p.crop_name) LIKE ${n} OR LOWER(u.first_name || ' ' || u.last_name) LIKE ${n} OR LOWER(a.city_municipality) LIKE ${n})`);
        }
        if (sellerId !== undefined) {
            if (!isRowId(sellerId)) return [];
            params.push(sellerId);
            conditions.push(`p.seller_id = $${params.length}`);
        }
        const where = `WHERE ${conditions.join(' AND ')}`;
        const { rows } = await pool.query(`${listingQuery} ${where} ORDER BY (p.status = 'available') DESC, p.created_at DESC`, params);
        return rows.map(mapListing);
    },

    async findById(productId: number): Promise<ProductListing | undefined> {
        if (!isRowId(productId)) return undefined;
        const { rows } = await pool.query(`${listingQuery} WHERE p.product_id = $1`, [productId]);
        return rows[0] ? mapListing(rows[0]) : undefined;
    },

    // Search help drawn from the listings that are up right now. With text,
    // the titles, towns and sellers matching it (the same three things
    // findAll searches), titles that start with it first. Without, the most
    // listed produce, for the search page before anything is typed.
    async suggest(query: string, limit: number): Promise<ListingSuggestion[]> {
        const text = query.trim().toLowerCase();
        const cover = `(SELECT pi.image_key FROM product_images pi WHERE pi.product_id = p.product_id ORDER BY pi.display_order LIMIT 1)`;
        // `prefixFirst` goes ahead of the usual ranking, so the rows LIMIT
        // keeps are the ones the merged list below would put on top.
        const listings = (match: string, prefixFirst: string, params: unknown[]) => pool.query(`
            SELECT MIN(btrim(p.crop_name)) AS text, COUNT(*) AS listing_count,
                   (ARRAY_AGG(${cover} ORDER BY p.created_at DESC))[1] AS image
            FROM products p
            WHERE p.status = 'available' ${match}
            GROUP BY lower(btrim(p.crop_name))
            ORDER BY ${prefixFirst} COUNT(*) DESC, MAX(p.created_at) DESC
            LIMIT $1
        `, params);

        if (!text) {
            const { rows } = await listings('', '', [limit]);
            return rows.map((row) => toSuggestion(row, 'listing'));
        }

        // $2 matches the text anywhere, $3 only at the start.
        const params = [limit, likePattern(text), `${escapeLike(text)}%`];
        const [titles, places, sellers] = await Promise.all([
            listings(`AND lower(p.crop_name) LIKE $2`, `(lower(btrim(p.crop_name)) LIKE $3) DESC,`, params),
            pool.query(`
                SELECT MIN(btrim(a.city_municipality)) AS text, COUNT(*) AS listing_count
                FROM products p
                JOIN users u ON u.user_id = p.seller_id
                ${sellerPlaceJoins}
                WHERE p.status = 'available' AND lower(a.city_municipality) LIKE $2
                GROUP BY lower(btrim(a.city_municipality))
                ORDER BY (lower(btrim(a.city_municipality)) LIKE $3) DESC, COUNT(*) DESC
                LIMIT $1
            `, params),
            pool.query(`
                SELECT u.first_name || ' ' || u.last_name AS text, COUNT(*) AS listing_count
                FROM products p
                JOIN users u ON u.user_id = p.seller_id
                WHERE p.status = 'available' AND lower(u.first_name || ' ' || u.last_name) LIKE $2
                GROUP BY u.user_id
                ORDER BY (lower(u.first_name || ' ' || u.last_name) LIKE $3) DESC, COUNT(*) DESC
                LIMIT $1
            `, params),
        ]);

        const typeOrder = { listing: 0, place: 1, seller: 2 };
        const startsWithText = (suggestion: ListingSuggestion) => suggestion.text.toLowerCase().startsWith(text);
        const ranked = [
            ...titles.rows.map((row) => toSuggestion(row, 'listing')),
            ...places.rows.map((row) => toSuggestion(row, 'place')),
            ...sellers.rows.map((row) => toSuggestion(row, 'seller')),
        ].sort((x, y) =>
            Number(startsWithText(y)) - Number(startsWithText(x))
            || typeOrder[x.type] - typeOrder[y.type]
            || y.listing_count - x.listing_count
            || x.text.localeCompare(y.text));

        // A town and a listing can share a name; the search they run is the same.
        const seen = new Set<string>();
        return ranked.filter((suggestion) => {
            const key = suggestion.text.toLowerCase();
            if (seen.has(key)) return false;
            seen.add(key);
            return true;
        }).slice(0, limit);
    },

    // Takes `quantity` off a listing, inside the caller's transaction. A
    // listing that reaches zero reads 'out of stock', which is what drops it
    // out of explore; that is the only way stock changes a status. False,
    // with nothing written, when the listing was removed or has less than
    // that left.
    async takeStock(q: Queryable, productId: number, quantity: number): Promise<boolean> {
        const { rowCount } = await q.query(`
            UPDATE products
            SET available_quantity = available_quantity - $2,
                status = CASE WHEN available_quantity - $2 <= 0 AND status = 'available' THEN 'out of stock' ELSE status END,
                updated_at = CURRENT_TIMESTAMP
            WHERE product_id = $1 AND available_quantity >= $2 AND status = 'available'
        `, [productId, quantity]);
        return (rowCount ?? 0) > 0;
    },

    // Puts `quantity` back, inside the caller's transaction. A listing that
    // was sold out only because nothing was left becomes available again;
    // one the seller archived by hand (stock still above zero) is left alone.
    async returnStock(q: Queryable, productId: number, quantity: number): Promise<void> {
        await q.query(`
            UPDATE products
            SET status = CASE WHEN available_quantity = 0 AND status = 'out of stock' THEN 'available' ELSE status END,
                available_quantity = available_quantity + $2,
                updated_at = CURRENT_TIMESTAMP
            WHERE product_id = $1
        `, [productId, quantity]);
    },

    async create(input: ProductInput, images: string[]): Promise<ProductListing> {
        const productId = await withTransaction(async (client) => {
            const { rows: [product] } = await client.query(`
                INSERT INTO products (seller_id, crop_name, category, base_price, available_quantity, unit_measurement,
                                      description, quality_grade, farming_method, harvest_date, is_preorder, allows_meetup, allows_delivery)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
                RETURNING product_id
            `, [input.seller_id, input.crop_name, input.category, input.base_price, input.available_quantity, input.unit_measurement,
                input.description, input.quality_grade, input.farming_method, input.harvest_date,
                input.is_preorder, input.allows_meetup, input.allows_delivery]);
            await insertImages(client, product.product_id, images);
            return Number(product.product_id);
        });
        return (await ProductModel.findById(productId)) as ProductListing;
    },

    // Applies only the keys present in changes. A non-null images list
    // replaces the listing's photos in the given order.
    //
    // Stock and "sold out" are kept in step here, against the row as it is
    // once this edit holds its lock, not as the controller read it: an offer
    // accepted in between has already changed both. A listing edited down to
    // nothing reads sold out, and one that had run out is back up once it is
    // restocked. One the seller marked sold out by hand (stock still above
    // zero) stays that way until they mark it available again, and nothing
    // can be marked available with no stock: that throws StockRuleError and
    // writes nothing.
    async update(productId: number, changes: ProductChanges, images?: string[]): Promise<ProductListing | undefined> {
        await withTransaction(async (client) => {
            // Taken even for a photo-only edit: with the row locked, two
            // edits replacing the photos at once take turns instead of
            // leaving both new photo lists behind.
            const { rows: [current] } = await client.query(
                `SELECT available_quantity, status FROM products WHERE product_id = $1 FOR UPDATE`, [productId]);
            if (!current) return;

            const applied: ProductChanges = { ...changes };
            const stockBefore = Number(current.available_quantity);
            const stockAfter = applied.available_quantity ?? stockBefore;
            if (applied.status === 'available' && stockAfter <= 0) {
                throw new StockRuleError('Add stock before marking this listing as available');
            }
            if (applied.status === undefined && applied.available_quantity !== undefined) {
                if (stockAfter <= 0 && current.status === 'available') applied.status = 'out of stock';
                if (stockAfter > 0 && stockBefore <= 0 && current.status === 'out of stock') applied.status = 'available';
            }

            const columns = (Object.keys(applied) as (keyof ProductChanges)[]).filter((key) => applied[key] !== undefined);
            const assignments = columns.map((column, i) => `${column} = $${i + 2}, `).join('');
            await client.query(`UPDATE products SET ${assignments}updated_at = CURRENT_TIMESTAMP WHERE product_id = $1`,
                [productId, ...columns.map((column) => applied[column])]);
            if (images) {
                await client.query(`DELETE FROM product_images WHERE product_id = $1`, [productId]);
                await insertImages(client, productId, images);
            }
        });
        return ProductModel.findById(productId);
    },

    // Whether any listing still points at this photo, so an uploaded file is
    // only deleted from S3 once nothing shows it.
    async isImageInUse(imageUrl: string): Promise<boolean> {
        const { rowCount } = await pool.query(`SELECT 1 FROM product_images WHERE image_key = $1 LIMIT 1`, [toMediaColumn(imageUrl)]);
        return (rowCount ?? 0) > 0;
    },
};
