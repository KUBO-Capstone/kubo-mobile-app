import { db } from "#config/database";

export interface ProductInput {
    seller_id: number;
    crop_name: string;
    category: string;
    base_price: number;
    available_quantity: number;
    unit_measurement: string;
}

// Mirrors the CHECK constraint on products.status in config/database.ts.
// 'delisted' is the soft delete: negotiations cascade on a real DELETE, so
// removing a listing must never drop the row.
export type ProductStatus = 'available' | 'out of stock' | 'delisted';

// Fields a seller may change after publishing. Everything is optional so a
// status-only change does not have to resend the whole listing.
export type ProductChanges = Partial<Omit<ProductInput, 'seller_id'> & { status: ProductStatus }>;

export interface ProductListing {
    product_id: number;
    seller_id: number;
    crop_name: string;
    category: string;
    base_price: number;
    available_quantity: number;
    unit_measurement: string;
    status: string;
    created_at: string;
    seller_name: string;
    location_label: string;
    region_label: string;
    latitude: number | null;
    longitude: number | null;
    description: string;
    images: string[];
}

const listingQuery = `
    SELECT p.*, u.first_name || ' ' || u.last_name AS seller_name,
           COALESCE(a.city_municipality, 'Philippines') AS location_label,
           COALESCE(a.region, 'NCR') AS region_label,
           a.latitude AS latitude,
           a.longitude AS longitude,
           GROUP_CONCAT(pi.image_url, '||') AS image_urls
    FROM products p
    JOIN users u ON u.user_id = p.seller_id
    LEFT JOIN farmer_profiles fp ON fp.farmer_id = p.seller_id
    LEFT JOIN addresses a ON a.address_id = fp.address_id
    LEFT JOIN product_images pi ON pi.product_id = p.product_id
`;

function mapListing(row: Record<string, unknown>): ProductListing {
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
        description: String(row.description ?? 'Fresh local produce from a Kubo grower.'),
        images: row.image_urls ? String(row.image_urls).split('||') : [],
    };
}

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
                INSERT INTO products (seller_id, crop_name, category, base_price, available_quantity, unit_measurement)
                VALUES (@seller_id, @crop_name, @category, @base_price, @available_quantity, @unit_measurement)
            `).run(input);
            const productId = Number(product.lastInsertRowid);
            const imageStatement = db.prepare(`INSERT INTO product_images (product_id, image_url, display_order) VALUES (?, ?, ?)`);
            images.forEach((url, index) => imageStatement.run(productId, url, index));
            return productId;
        });
        return ProductModel.findById(transaction()) as ProductListing;
    },

    // Applies only the keys present in changes; images are not editable yet.
    update(productId: number, changes: ProductChanges): ProductListing | undefined {
        const columns = (Object.keys(changes) as (keyof ProductChanges)[]).filter((key) => changes[key] !== undefined);
        if (columns.length === 0) return ProductModel.findById(productId);
        const assignments = columns.map((column) => `${column} = @${column}`).join(', ');
        db.prepare(`UPDATE products SET ${assignments}, updated_at = CURRENT_TIMESTAMP WHERE product_id = @product_id`)
            .run({ ...changes, product_id: productId });
        return ProductModel.findById(productId);
    },
};