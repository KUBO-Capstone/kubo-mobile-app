import { db } from '#config/database';

const imageUrls = [
    'https://picsum.photos/id/1018/600/400',
    'https://picsum.photos/id/1015/600/400',
    'https://picsum.photos/id/1016/600/400',
];

type SeedUser = {
    firstName: string;
    lastName: string;
    email: string;
    contactNumber: string;
    city: string;
    province: string;
    region: string;
};

type SeedProduct = {
    cropName: string;
    category: string;
    price: number;
    quantity: number;
    unit: string;
};

const users: SeedUser[] = [
    {
        firstName: 'Maria',
        lastName: 'Santos',
        email: 'maria.santos@kubo.local',
        contactNumber: '09181234567',
        city: 'Quezon City',
        province: 'Metro Manila',
        region: 'NCR',
    },
    {
        firstName: 'Juan',
        lastName: 'Dela Cruz',
        email: 'juan.delacruz@kubo.local',
        contactNumber: '09191234567',
        city: 'Malolos',
        province: 'Bulacan',
        region: 'Region III',
    },
    {
        firstName: 'Ana',
        lastName: 'Reyes',
        email: 'ana.reyes@kubo.local',
        contactNumber: '09201234567',
        city: 'Cabuyao',
        province: 'Laguna',
        region: 'Region IV-A',
    },
];

const productsByEmail: Record<string, SeedProduct[]> = {
    'maria.santos@kubo.local': [
        { cropName: 'Organic eggplant basket', category: 'vegetable', price: 155, quantity: 30, unit: 'kg' },
        { cropName: 'Sweet mango harvest box', category: 'fruit', price: 190, quantity: 24, unit: 'kg' },
    ],
    'juan.delacruz@kubo.local': [
        { cropName: 'Premium jasmine rice', category: 'grain', price: 260, quantity: 80, unit: 'kg' },
        { cropName: 'Fresh saba bananas', category: 'fruit', price: 110, quantity: 45, unit: 'kg' },
        { cropName: 'Green mung beans', category: 'legume', price: 175, quantity: 35, unit: 'kg' },
    ],
};

function getOrCreateAddress(user: SeedUser): number {
    const existing = db.prepare(`SELECT address_id FROM addresses WHERE landmark = ?`).get(`${user.firstName} Kubo farm`) as { address_id: number } | undefined;
    if (existing) return existing.address_id;

    const result = db.prepare(`
        INSERT INTO addresses (region, province, city_municipality, barangay, zip_code, street_details, landmark)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(user.region, user.province, user.city, 'Central Barangay', '1400', 'Kubo growers lane', `${user.firstName} Kubo farm`);
    return Number(result.lastInsertRowid);
}

function getOrCreateUser(user: SeedUser, addressId: number): number {
    db.prepare(`
        INSERT OR IGNORE INTO users (first_name, last_name, email, password, contact_number, preferred_address_id, is_verified)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(user.firstName, user.lastName, user.email, 'seed-password', user.contactNumber, addressId, 1);
    return Number((db.prepare(`SELECT user_id FROM users WHERE email = ?`).get(user.email) as { user_id: number }).user_id);
}

function seedProduct(userId: number, product: SeedProduct): number {
    const existing = db.prepare(`SELECT product_id FROM products WHERE seller_id = ? AND crop_name = ?`).get(userId, product.cropName) as { product_id: number } | undefined;
    if (existing) return existing.product_id;

    const result = db.prepare(`
        INSERT INTO products (seller_id, crop_name, category, base_price, available_quantity, unit_of_measure)
        VALUES (?, ?, ?, ?, ?, ?)
    `).run(userId, product.cropName, product.category, product.price, product.quantity, product.unit);
    const productId = Number(result.lastInsertRowid);
    const image = db.prepare(`INSERT INTO product_images (product_id, image_url, display_order) VALUES (?, ?, ?)`);
    imageUrls.forEach((url, index) => image.run(productId, url, index));
    return productId;
}

const seed = db.transaction(() => {
    const primaryUser: SeedUser = {
        firstName: 'Kubo',
        lastName: 'Grower',
        email: 'grower@kubo.local',
        contactNumber: '09171234567',
        city: 'Caloocan',
        province: 'Metro Manila',
        region: 'NCR',
    };
    const primaryAddressId = getOrCreateAddress({ ...primaryUser });
    const primaryUserId = getOrCreateUser(primaryUser, primaryAddressId);
    const primaryProductId = seedProduct(primaryUserId, {
        cropName: 'Fresh tomatoes bundle',
        category: 'vegetable',
        price: 120,
        quantity: 50,
        unit: 'kg',
    });

    db.prepare(`INSERT OR IGNORE INTO bagsakan_centers (address_id, location_name) VALUES (?, ?)`)
        .run(primaryAddressId, 'Caloocan Kubo Bagsakan Center');

    const seededUsers = users.map((user) => {
        const addressId = getOrCreateAddress(user);
        const userId = getOrCreateUser(user, addressId);
        const products = productsByEmail[user.email] ?? [];
        const productIds = products.map((product) => seedProduct(userId, product));
        return { userId, email: user.email, productIds };
    });

    return { primaryUserId, primaryProductId, users: seededUsers };
});

console.log('Seeded Kubo records:', seed());
