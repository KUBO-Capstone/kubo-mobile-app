import { db } from '#config/database';
import { hashPassword } from '#utils/password';

// Shared plaintext for every seeded account, hashed once below. These rows only
// simulate farmers for development; real farmers self-register through the app.
const SEED_PASSWORD = 'seed-password';

// Buyer-side account for exercising login and, later, the consumer half of the
// negotiation flow. Seeded so it survives `npm run db:reset`; before this it was
// created ad hoc by test-query.ts and vanished on every reset.
const CONSUMER = {
    firstName: 'Leonard',
    lastName: 'Perez',
    email: 'leoper@example.com',
    password: 'securepassword',
    contactNumber: '1234567890',
};

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
    latitude: number;
    longitude: number;
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
        latitude: 14.6760,
        longitude: 121.0437,
    },
    {
        firstName: 'Juan',
        lastName: 'Dela Cruz',
        email: 'juan.delacruz@kubo.local',
        contactNumber: '09191234567',
        city: 'Malolos',
        province: 'Bulacan',
        region: 'Region III',
        latitude: 14.8433,
        longitude: 120.8114,
    },
    {
        firstName: 'Ana',
        lastName: 'Reyes',
        email: 'ana.reyes@kubo.local',
        contactNumber: '09201234567',
        city: 'Cabuyao',
        province: 'Laguna',
        region: 'Region IV-A',
        latitude: 14.2726,
        longitude: 121.1256,
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

type SeedCenter = {
    name: string;
    city: string;
    province: string;
    region: string;
    barangay: string;
    zip: string;
    latitude: number;
    longitude: number;
};

// Drop-off points buyers collect from. Real centers would be operator-managed;
// these exist so the explore map has something to plot in bagsakan mode.
const centers: SeedCenter[] = [
    { name: 'Caloocan Kubo Bagsakan Center', city: 'Caloocan', province: 'Metro Manila', region: 'NCR', barangay: 'Caybiga', zip: '1400', latitude: 14.6832, longitude: 120.9902 },
    { name: 'Quezon City Kubo Bagsakan Center', city: 'Quezon City', province: 'Metro Manila', region: 'NCR', barangay: 'Bagong Silangan', zip: '1100', latitude: 14.7008, longitude: 121.0794 },
    { name: 'Malolos Kubo Bagsakan Center', city: 'Malolos', province: 'Bulacan', region: 'Region III', barangay: 'Bulihan', zip: '3000', latitude: 14.8613, longitude: 120.8092 },
    { name: 'Cabuyao Kubo Bagsakan Center', city: 'Cabuyao', province: 'Laguna', region: 'Region IV-A', barangay: 'Pulo', zip: '4025', latitude: 14.2495, longitude: 121.1417 },
];

function seedCenter(center: SeedCenter): number {
    const existing = db.prepare(`SELECT center_id FROM bagsakan_centers WHERE location_name = ?`).get(center.name) as { center_id: number } | undefined;
    if (existing) return existing.center_id;

    const address = db.prepare(`
        INSERT INTO addresses (region, province, city_municipality, barangay, zip_code, street_details, landmark, latitude, longitude)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(center.region, center.province, center.city, center.barangay, center.zip, 'Bagsakan drop-off lane', center.name, center.latitude, center.longitude);

    const result = db.prepare(`INSERT INTO bagsakan_centers (address_id, location_name) VALUES (?, ?)`)
        .run(Number(address.lastInsertRowid), center.name);
    return Number(result.lastInsertRowid);
}

function getOrCreateAddress(user: SeedUser): number {
    const existing = db.prepare(`SELECT address_id FROM addresses WHERE landmark = ?`).get(`${user.firstName} Kubo farm`) as { address_id: number } | undefined;
    if (existing) {
        // Backfill coordinates on rows seeded before the map view needed them.
        db.prepare(`UPDATE addresses SET latitude = ?, longitude = ? WHERE address_id = ?`)
            .run(user.latitude, user.longitude, existing.address_id);
        return existing.address_id;
    }

    const result = db.prepare(`
        INSERT INTO addresses (region, province, city_municipality, barangay, zip_code, street_details, landmark, latitude, longitude)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(user.region, user.province, user.city, 'Central Barangay', '1400', 'Kubo growers lane', `${user.firstName} Kubo farm`, user.latitude, user.longitude);
    return Number(result.lastInsertRowid);
}

function getOrCreateFarmer(user: SeedUser, addressId: number): number {
    db.prepare(`
        INSERT OR IGNORE INTO users (first_name, last_name, email, password_hash, contact_number, role, is_verified)
        VALUES (?, ?, ?, ?, ?, 'farmer', ?)
    `).run(user.firstName, user.lastName, user.email, hashPassword(SEED_PASSWORD), user.contactNumber, 1);
    // INSERT OR IGNORE leaves an existing row untouched, so force the role and
    // the hash: rows seeded before farmer_profiles or password hashing existed
    // would otherwise keep the old role / an unverifiable plaintext hash.
    db.prepare(`UPDATE users SET role = 'farmer', password_hash = ? WHERE email = ?`)
        .run(hashPassword(SEED_PASSWORD), user.email);
    const userId = Number((db.prepare(`SELECT user_id FROM users WHERE email = ?`).get(user.email) as { user_id: number }).user_id);

    // The farm location lives on farmer_profiles; users.preferred_address_id is
    // the consumer-side pickup area and is deliberately left unset here.
    db.prepare(`
        INSERT INTO farmer_profiles (farmer_id, address_id, verification_status)
        VALUES (?, ?, 'verified')
        ON CONFLICT(farmer_id) DO UPDATE SET address_id = excluded.address_id, verification_status = 'verified'
    `).run(userId, addressId);

    return userId;
}

function seedConsumer(): number {
    db.prepare(`
        INSERT OR IGNORE INTO users (first_name, last_name, email, password_hash, contact_number, role)
        VALUES (?, ?, ?, ?, ?, 'consumer')
    `).run(CONSUMER.firstName, CONSUMER.lastName, CONSUMER.email, hashPassword(CONSUMER.password), CONSUMER.contactNumber);
    // Same backfill as farmers: keep the hash verifiable on re-run.
    db.prepare(`UPDATE users SET password_hash = ? WHERE email = ?`)
        .run(hashPassword(CONSUMER.password), CONSUMER.email);
    return Number((db.prepare(`SELECT user_id FROM users WHERE email = ?`).get(CONSUMER.email) as { user_id: number }).user_id);
}

function seedProduct(userId: number, product: SeedProduct): number {
    const existing = db.prepare(`SELECT product_id FROM products WHERE seller_id = ? AND crop_name = ?`).get(userId, product.cropName) as { product_id: number } | undefined;
    if (existing) return existing.product_id;

    const result = db.prepare(`
        INSERT INTO products (seller_id, crop_name, category, base_price, available_quantity, unit_measurement)
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
        latitude: 14.6507,
        longitude: 120.9672,
    };
    const primaryAddressId = getOrCreateAddress({ ...primaryUser });
    const primaryUserId = getOrCreateFarmer(primaryUser, primaryAddressId);
    const primaryProductId = seedProduct(primaryUserId, {
        cropName: 'Fresh tomatoes bundle',
        category: 'vegetable',
        price: 120,
        quantity: 50,
        unit: 'kg',
    });

    const centerIds = centers.map(seedCenter);
    const consumerId = seedConsumer();

    const seededUsers = users.map((user) => {
        const addressId = getOrCreateAddress(user);
        const userId = getOrCreateFarmer(user, addressId);
        const products = productsByEmail[user.email] ?? [];
        const productIds = products.map((product) => seedProduct(userId, product));
        return { userId, email: user.email, productIds };
    });

    return { primaryUserId, primaryProductId, consumerId, centerIds, users: seededUsers };
});

console.log('Seeded Kubo records:', seed());
