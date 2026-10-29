import { db } from "#config/database";

// Mirror the CHECK constraints on products in config/database.ts.
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

// Mirrors the CHECK constraint on products.status in config/database.ts.
// 'delisted' is the soft delete: negotiations cascade on a real DELETE, so
// removing a listing must never drop the row.
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
}

const booleanColumns = new Set<string>(['is_preorder', 'allows_meetup', 'allows_delivery']);

// better-sqlite3 cannot bind JS booleans; the columns hold 0 / 1.
const toRow = (values: Record<string, unknown>): Record<string, unknown> =>
    Object.fromEntries(Object.entries(values).map(([key, value]) => [key, booleanColumns.has(key) ? (value ? 1 : 0) : value]));

// Exported so other models (saved listings) can list products in exactly the
// shape the explore grid gets; keep the two in step.
export const listingQuery = `
    SELECT p.*, u.first_name || ' ' || u.last_name AS seller_name,
           COALESCE(a.city_municipality, 'Philippines') AS location_label,
           COALESCE(a.region, 'NCR') AS region_label,
           a.latitude AS latitude,
           a.longitude AS longitude,
           GROUP_CONCAT(pi.image_url, '||' ORDER BY pi.display_order) AS image_urls
    FROM products p
    JOIN users u ON u.user_id = p.seller_id
    LEFT JOIN farmer_profiles fp ON fp.farmer_id = p.seller_id
    LEFT JOIN addresses a ON a.address_id = fp.address_id
    LEFT JOIN product_images pi ON pi.product_id = p.product_id
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
        is_preorder: Boolean(Number(row.is_preorder ?? 0)),
        allows_meetup: Boolean(Number(row.allows_meetup ?? 1)),
        allows_delivery: Boolean(Number(row.allows_delivery ?? 1)),
        images: row.image_urls ? String(row.image_urls).split('||') : [],
    };
}

const insertImages = (productId: number, images: string[]): void => {
    const statement = db.prepare(`INSERT INTO product_images (product_id, image_url, display_order) VALUES (?, ?, ?)`);
    images.forEach((url, index) => statement.run(productId, url, index));
};

export const ProductModel = {
    // includeUnavailable adds 'out of stock' rows for a seller's own tab;
    // delisted rows never come back from a list query.
    findAll(query = '', sellerId?: number, includeUnavailable = false): ProductListing[] {
        const normalizedQuery = query.trim().toLowerCase();
        const conditions = [includeUnavailable ? `p.status IN ('available', 'out of stock')` : `p.status = 'available'`];
        if (normalizedQuery) {
            conditions.push(`(LOWER(p.crop_name) LIKE @query OR LOWER(u.first_name || ' ' || u.last_name) LIKE @query OR LOWER(a.city_municipality) LIKE @query)`);
        }
        if (sellerId !== undefined) {
            conditions.push(`p.seller_id = @sellerId`);
        }
        const where = `WHERE ${conditions.join(' AND ')}`;
        const rows = db.prepare(`${listingQuery} ${where} GROUP BY p.product_id ORDER BY p.created_at DESC`).all({
            query: `%${normalizedQuery}%`,
            sellerId,
        }) as Record<string, unknown>[];
        return rows.map(mapListing);
    },

    findById(productId: number): ProductListing | undefined {
        const rows = db.prepare(`${listingQuery} WHERE p.product_id = ? GROUP BY p.product_id`).all(productId) as Record<string, unknown>[];
        return rows[0] ? mapListing(rows[0]) : undefined;
    },

    create(input: ProductInput, images: string[]): ProductListing {
        const transaction = db.transaction(() => {
            const product = db.prepare(`
                INSERT INTO products (seller_id, crop_name, category, base_price, available_quantity, unit_measurement,
                                      description, quality_grade, farming_method, harvest_date, is_preorder, allows_meetup, allows_delivery)
                VALUES (@seller_id, @crop_name, @category, @base_price, @available_quantity, @unit_measurement,
                        @description, @quality_grade, @farming_method, @harvest_date, @is_preorder, @allows_meetup, @allows_delivery)
            `).run(toRow({ ...input }));
            const productId = Number(product.lastInsertRowid);
            insertImages(productId, images);
            return productId;
        });
        return ProductModel.findById(transaction()) as ProductListing;
    },

    // Applies only the keys present in changes. A non-null images list
    // replaces the listing's photos in the given order.
    update(productId: number, changes: ProductChanges, images?: string[]): ProductListing | undefined {
        const columns = (Object.keys(changes) as (keyof ProductChanges)[]).filter((key) => changes[key] !== undefined);
        db.transaction(() => {
            if (columns.length > 0) {
                const assignments = columns.map((column) => `${column} = @${column}`).join(', ');
                db.prepare(`UPDATE products SET ${assignments}, updated_at = CURRENT_TIMESTAMP WHERE product_id = @product_id`)
                    .run(toRow({ ...changes, product_id: productId }));
            }
            if (images) {
                db.prepare(`DELETE FROM product_images WHERE product_id = ?`).run(productId);
                insertImages(productId, images);
            }
        })();
        return ProductModel.findById(productId);
    },

    // Whether any listing still points at this photo, so an uploaded file is
    // only deleted from disk once nothing shows it.
    isImageInUse(imageUrl: string): boolean {
        return db.prepare(`SELECT 1 FROM product_images WHERE image_url = ? LIMIT 1`).get(imageUrl) !== undefined;
    },
};
