import 'dotenv/config'; // must stay first: database/pg reads PG* when imported
import { PoolClient } from 'pg';
import { pool, withTransaction } from '#database/pg';
import { seedMarketWatch } from './seed-market';

// Reference data the app needs before anyone signs up: the bagsakan centers
// buyers pick up from and the Market Watch prices. There are no demo
// accounts or listings; people register through the app and farmers post
// their own listings.

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
// these exist so pickup orders have somewhere to go and the explore map has
// something to plot in bagsakan mode.
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

/** Bagsakan centers and Market Watch reference prices. Idempotent. */
export async function seed(): Promise<void> {
    const centerIds = await withTransaction(async (client) => {
        const ids: number[] = [];
        for (const center of centers) ids.push(await seedCenter(client, center));
        return ids;
    });
    console.log('Seeded bagsakan centers:', centerIds);
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
