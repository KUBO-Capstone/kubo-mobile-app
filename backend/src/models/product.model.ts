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
}

// Exported so other models (saved listings) can list products in exactly the
// shape the explore grid gets; keep the two in step.
export const listingQuery = `
    SELECT p.*, u.first_name || ' ' || u.last_name AS seller_name,
           COALESCE(a.city_municipality, 'Philippines') AS location_label,
           COALESCE(a.region, 'NCR') AS region_label,
           a.latitude AS latitude,
           a.longitude AS longitude,
           ARRAY(SELECT pi.image_key FROM product_images pi WHERE pi.product_id = p.product_id ORDER BY pi.display_order) AS images,
           (SELECT ROUND(AVG(r.rating), 1) FROM reviews r WHERE r.reviewee_id = p.seller_id) AS seller_rating,
           (SELECT COUNT(*) FROM reviews r WHERE r.reviewee_id = p.seller_id) AS seller_review_count
    FROM products p
    JOIN users u ON u.user_id = p.seller_id
    LEFT JOIN farmer_profiles fp ON fp.farmer_id = p.seller_id
    LEFT JOIN addresses a ON a.address_id = fp.address_id
`;

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
    // includeUnavailable adds 'out of stock' rows for a seller's own tab;
    // delisted rows never come back from a list query.
    async findAll(query = '', sellerId?: number, includeUnavailable = false): Promise<ProductListing[]> {
        const normalizedQuery = query.trim().toLowerCase();
        const conditions = [includeUnavailable ? `p.status IN ('available', 'out of stock')` : `p.status = 'available'`];
        const params: unknown[] = [];
        if (normalizedQuery) {
            params.push(`%${normalizedQuery}%`);
            const n = `$${params.length}`;
            conditions.push(`(LOWER(p.crop_name) LIKE ${n} OR LOWER(u.first_name || ' ' || u.last_name) LIKE ${n} OR LOWER(a.city_municipality) LIKE ${n})`);
        }
        if (sellerId !== undefined) {
            if (!isRowId(sellerId)) return [];
            params.push(sellerId);
            conditions.push(`p.seller_id = $${params.length}`);
        }
        const where = `WHERE ${conditions.join(' AND ')}`;
        const { rows } = await pool.query(`${listingQuery} ${where} ORDER BY p.created_at DESC`, params);
        return rows.map(mapListing);
    },

    async findById(productId: number): Promise<ProductListing | undefined> {
        if (!isRowId(productId)) return undefined;
        const { rows } = await pool.query(`${listingQuery} WHERE p.product_id = $1`, [productId]);
        return rows[0] ? mapListing(rows[0]) : undefined;
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
    async update(productId: number, changes: ProductChanges, images?: string[]): Promise<ProductListing | undefined> {
        const columns = (Object.keys(changes) as (keyof ProductChanges)[]).filter((key) => changes[key] !== undefined);
        await withTransaction(async (client) => {
            // Runs even for a photo-only edit: it locks the product row, so two
            // edits replacing the photos at once take turns instead of
            // leaving both new photo lists behind.
            const assignments = columns.map((column, i) => `${column} = $${i + 2}, `).join('');
            await client.query(`UPDATE products SET ${assignments}updated_at = CURRENT_TIMESTAMP WHERE product_id = $1`,
                [productId, ...columns.map((column) => changes[column])]);
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
