import 'dotenv/config'; // must stay first: database/pg reads PG* when imported
import { PoolClient } from 'pg';
import { pool, withTransaction } from '#database/pg';
import { hashPassword } from '#utils/password';
import { seedMarketWatch } from './seed-market';

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

async function seedCenter(client: PoolClient, center: SeedCenter): Promise<number> {
    const { rows: [existing] } = await client.query(`SELECT center_id FROM bagsakan_centers WHERE location_name = $1`, [center.name]);
    if (existing) return existing.center_id;

    const { rows: [address] } = await client.query(`
        INSERT INTO addresses (region, province, city_municipality, barangay, zip_code, street_details, landmark, latitude, longitude)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        RETURNING address_id
    `, [center.region, center.province, center.city, center.barangay, center.zip, 'Bagsakan drop-off lane', center.name, center.latitude, center.longitude]);

    const { rows: [created] } = await client.query(`INSERT INTO bagsakan_centers (address_id, location_name) VALUES ($1, $2) RETURNING center_id`,
        [address.address_id, center.name]);
    return created.center_id;
}

async function getOrCreateAddress(client: PoolClient, user: SeedUser): Promise<number> {
    const { rows: [existing] } = await client.query(`SELECT address_id FROM addresses WHERE landmark = $1`, [`${user.firstName} Kubo farm`]);
    if (existing) {
        // Backfill coordinates on rows seeded before the map view needed them.
        await client.query(`UPDATE addresses SET latitude = $1, longitude = $2 WHERE address_id = $3`,
            [user.latitude, user.longitude, existing.address_id]);
        return existing.address_id;
    }

    const { rows: [created] } = await client.query(`
        INSERT INTO addresses (region, province, city_municipality, barangay, zip_code, street_details, landmark, latitude, longitude)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        RETURNING address_id
    `, [user.region, user.province, user.city, 'Central Barangay', '1400', 'Kubo growers lane', `${user.firstName} Kubo farm`, user.latitude, user.longitude]);
    return created.address_id;
}

async function getOrCreateFarmer(client: PoolClient, user: SeedUser, addressId: number): Promise<number> {
    await client.query(`
        INSERT INTO users (first_name, last_name, email, password_hash, contact_number, role, is_verified)
        VALUES ($1, $2, $3, $4, $5, 'farmer', true)
        ON CONFLICT DO NOTHING
    `, [user.firstName, user.lastName, user.email, hashPassword(SEED_PASSWORD), user.contactNumber]);
    // ON CONFLICT DO NOTHING leaves an existing row untouched, so force the
    // role and the hash: rows seeded before farmer_profiles or password
    // hashing existed would otherwise keep the old role / an unverifiable hash.
    const { rows: [farmer] } = await client.query(`UPDATE users SET role = 'farmer', password_hash = $1 WHERE email = $2 RETURNING user_id`,
        [hashPassword(SEED_PASSWORD), user.email]);
    const userId = Number(farmer.user_id);

    // The farm location lives on farmer_profiles; users.preferred_address_id is
    // the consumer-side pickup area and is deliberately left unset here.
    await client.query(`
        INSERT INTO farmer_profiles (farmer_id, address_id, verification_status)
        VALUES ($1, $2, 'verified')
        ON CONFLICT (farmer_id) DO UPDATE SET address_id = EXCLUDED.address_id, verification_status = 'verified'
    `, [userId, addressId]);

    return userId;
}

async function seedConsumer(client: PoolClient): Promise<number> {
    await client.query(`
        INSERT INTO users (first_name, last_name, email, password_hash, contact_number, role)
        VALUES ($1, $2, $3, $4, $5, 'consumer')
        ON CONFLICT DO NOTHING
    `, [CONSUMER.firstName, CONSUMER.lastName, CONSUMER.email, hashPassword(CONSUMER.password), CONSUMER.contactNumber]);
    // Same backfill as farmers: keep the hash verifiable on re-run.
    const { rows: [consumer] } = await client.query(`UPDATE users SET password_hash = $1 WHERE email = $2 RETURNING user_id`,
        [hashPassword(CONSUMER.password), CONSUMER.email]);
    return Number(consumer.user_id);
}

async function seedProduct(client: PoolClient, userId: number, product: SeedProduct): Promise<number> {
    const { rows: [existing] } = await client.query(`SELECT product_id FROM products WHERE seller_id = $1 AND crop_name = $2`, [userId, product.cropName]);
    if (existing) return existing.product_id;

    const { rows: [created] } = await client.query(`
        INSERT INTO products (seller_id, crop_name, category, base_price, available_quantity, unit_measurement)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING product_id
    `, [userId, product.cropName, product.category, product.price, product.quantity, product.unit]);
    const productId = Number(created.product_id);
    // Absolute URLs, not S3 keys: the app shows them as they are.
    for (const [index, url] of imageUrls.entries()) {
        await client.query(`INSERT INTO product_images (product_id, image_key, display_order) VALUES ($1, $2, $3)`, [productId, url, index]);
    }
    return productId;
}

async function seedKubo(client: PoolClient) {
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
    const primaryAddressId = await getOrCreateAddress(client, { ...primaryUser });
    const primaryUserId = await getOrCreateFarmer(client, primaryUser, primaryAddressId);
    const primaryProductId = await seedProduct(client, primaryUserId, {
        cropName: 'Fresh tomatoes bundle',
        category: 'vegetable',
        price: 120,
        quantity: 50,
        unit: 'kg',
    });

    const centerIds: number[] = [];
    for (const center of centers) centerIds.push(await seedCenter(client, center));
    const consumerId = await seedConsumer(client);

    const seededUsers = [];
    for (const user of users) {
        const addressId = await getOrCreateAddress(client, user);
        const userId = await getOrCreateFarmer(client, user, addressId);
        const productIds: number[] = [];
        for (const product of productsByEmail[user.email] ?? []) productIds.push(await seedProduct(client, userId, product));
        seededUsers.push({ userId, email: user.email, productIds });
    }

    return { primaryUserId, primaryProductId, consumerId, centerIds, users: seededUsers };
}

/** Demo accounts, listings, bagsakan centers and Market Watch prices. Idempotent. */
export async function seed(): Promise<void> {
    console.log('Seeded Kubo records:', await withTransaction(seedKubo));
    console.log('Seeded Market Watch reference prices:', await seedMarketWatch());
}

if (require.main === module) {
    seed()
        .catch((error) => {
            console.error(error);
            process.exitCode = 1;
        })
        .finally(() => pool.end());
}
