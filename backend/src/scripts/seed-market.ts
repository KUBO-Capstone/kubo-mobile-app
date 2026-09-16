import { db } from '#config/database';

// Market Watch reference data: DA/DTI-style prevailing prices per product per
// area, three monthly snapshots deep so the +/- trend has something to compare
// against. Values are illustrative, not real Bantay Presyo figures - the point
// is the shape of the data, which a real DA feed would replace row for row.
//
// Deterministic: every number derives from a hash of product + area + month,
// so `npm run db:reset` produces the same table each time and the writeup can
// quote it. Idempotent: both tables upsert on their unique keys.

type MarketProductSeed = {
    name: string;
    classification: 'Food Products' | 'Fiber Products' | 'Fuel Products' | 'Raw Materials';
    groups: string[];
    unit: string;
    // Suggested retail price where DTI publishes one; null for commodities it does not cover.
    dtiSrp: number | null;
    // Lower-cased fragments matched against Kubo listings' crop_name so the
    // listing page can find its reference price ("Premium jasmine rice" -> rice).
    keywords: string[];
    // Nationwide base price the area factors and monthly drift scale from.
    basePrice: number;
};

type AreaSeed = {
    region: string;       // short label, same style as seed.ts / _normalizeRegion ("NCR", "Region III")
    regionName: string;   // long label for the map dropdown
    provinceCity: string;
    latitude: number;
    longitude: number;
    // Areas near Metro Manila trade above the national base; producing regions below it.
    factor: number;
};

const products: MarketProductSeed[] = [
    { name: 'Corn', classification: 'Food Products', groups: ['Grain', 'Vegetable', 'Grass'], unit: 'kg', dtiSrp: 45, keywords: ['corn', 'mais'], basePrice: 42 },
    { name: 'Rice (well-milled)', classification: 'Food Products', groups: ['Grain'], unit: 'kg', dtiSrp: 45, keywords: ['rice', 'bigas', 'jasmine'], basePrice: 48 },
    { name: 'Potatoes', classification: 'Food Products', groups: ['Root', 'Vegetable'], unit: 'kg', dtiSrp: 110, keywords: ['potato', 'patatas'], basePrice: 105 },
    { name: 'Tomato', classification: 'Food Products', groups: ['Vegetable', 'Fruit'], unit: 'kg', dtiSrp: 80, keywords: ['tomato', 'kamatis'], basePrice: 75 },
    { name: 'Onion (red)', classification: 'Food Products', groups: ['Vegetable', 'Bulb'], unit: 'kg', dtiSrp: 150, keywords: ['onion', 'sibuyas'], basePrice: 140 },
    { name: 'Garlic', classification: 'Food Products', groups: ['Vegetable', 'Bulb'], unit: 'kg', dtiSrp: 180, keywords: ['garlic', 'bawang'], basePrice: 170 },
    { name: 'Eggplant', classification: 'Food Products', groups: ['Vegetable'], unit: 'kg', dtiSrp: 70, keywords: ['eggplant', 'talong'], basePrice: 65 },
    { name: 'Cabbage', classification: 'Food Products', groups: ['Vegetable', 'Leafy'], unit: 'kg', dtiSrp: 60, keywords: ['cabbage', 'repolyo'], basePrice: 55 },
    { name: 'Banana (saba)', classification: 'Food Products', groups: ['Fruit'], unit: 'kg', dtiSrp: 40, keywords: ['banana', 'saging', 'saba'], basePrice: 38 },
    { name: 'Mango (carabao)', classification: 'Food Products', groups: ['Fruit'], unit: 'kg', dtiSrp: 120, keywords: ['mango', 'mangga'], basePrice: 115 },
    { name: 'Mung beans', classification: 'Food Products', groups: ['Legume'], unit: 'kg', dtiSrp: 130, keywords: ['mung', 'munggo'], basePrice: 125 },
    { name: 'Coconut', classification: 'Food Products', groups: ['Fruit', 'Nut'], unit: 'piece', dtiSrp: 25, keywords: ['coconut', 'niyog', 'buko'], basePrice: 22 },
    { name: 'Abaca fiber', classification: 'Fiber Products', groups: ['Fiber'], unit: 'kg', dtiSrp: null, keywords: ['abaca'], basePrice: 85 },
    { name: 'Cotton', classification: 'Fiber Products', groups: ['Fiber'], unit: 'kg', dtiSrp: null, keywords: ['cotton', 'bulak'], basePrice: 95 },
    { name: 'Pina fiber', classification: 'Fiber Products', groups: ['Fiber', 'Fruit'], unit: 'kg', dtiSrp: null, keywords: ['pina', 'pineapple fiber'], basePrice: 1500 },
    { name: 'Copra', classification: 'Fuel Products', groups: ['Coconut', 'Oilseed'], unit: 'kg', dtiSrp: null, keywords: ['copra'], basePrice: 38 },
    { name: 'Sugarcane', classification: 'Fuel Products', groups: ['Sugar crop', 'Grass'], unit: 'kg', dtiSrp: null, keywords: ['sugarcane', 'tubo'], basePrice: 3.2 },
    { name: 'Cassava (industrial)', classification: 'Fuel Products', groups: ['Root'], unit: 'kg', dtiSrp: null, keywords: ['cassava', 'kamoteng kahoy'], basePrice: 9 },
    { name: 'Corn starch', classification: 'Raw Materials', groups: ['Grain', 'Industrial'], unit: 'kg', dtiSrp: null, keywords: ['corn starch'], basePrice: 62 },
    { name: 'Rubber (cup lump)', classification: 'Raw Materials', groups: ['Industrial'], unit: 'kg', dtiSrp: null, keywords: ['rubber', 'goma'], basePrice: 45 },
    { name: 'Castor oil', classification: 'Raw Materials', groups: ['Oil', 'Industrial'], unit: 'liter', dtiSrp: null, keywords: ['castor'], basePrice: 180 },
];

const areas: AreaSeed[] = [
    { region: 'NCR', regionName: 'National Capital Region', provinceCity: 'Caloocan', latitude: 14.6507, longitude: 120.9672, factor: 1.05 },
    { region: 'NCR', regionName: 'National Capital Region', provinceCity: 'Manila', latitude: 14.5995, longitude: 120.9842, factor: 1.08 },
    { region: 'NCR', regionName: 'National Capital Region', provinceCity: 'Quezon City', latitude: 14.6760, longitude: 121.0437, factor: 1.06 },
    { region: 'NCR', regionName: 'National Capital Region', provinceCity: 'Paranaque', latitude: 14.4793, longitude: 121.0198, factor: 1.07 },
    { region: 'Region III', regionName: 'Central Luzon', provinceCity: 'Bulacan', latitude: 14.7942, longitude: 120.8799, factor: 0.95 },
    { region: 'Region III', regionName: 'Central Luzon', provinceCity: 'Pampanga', latitude: 15.0794, longitude: 120.6200, factor: 0.93 },
    { region: 'Region III', regionName: 'Central Luzon', provinceCity: 'Nueva Ecija', latitude: 15.5784, longitude: 121.1113, factor: 0.88 },
    { region: 'Region IV-A', regionName: 'CALABARZON', provinceCity: 'Cavite', latitude: 14.2456, longitude: 120.8786, factor: 0.98 },
    { region: 'Region IV-A', regionName: 'CALABARZON', provinceCity: 'Laguna', latitude: 14.1407, longitude: 121.4692, factor: 0.96 },
    { region: 'Region IV-A', regionName: 'CALABARZON', provinceCity: 'Batangas', latitude: 13.7565, longitude: 121.0583, factor: 0.97 },
    { region: 'CAR', regionName: 'Cordillera Administrative Region', provinceCity: 'Benguet', latitude: 16.4023, longitude: 120.5960, factor: 0.90 },
    { region: 'Region VII', regionName: 'Central Visayas', provinceCity: 'Cebu', latitude: 10.3157, longitude: 123.8854, factor: 1.02 },
    { region: 'Region X', regionName: 'Northern Mindanao', provinceCity: 'Cagayan de Oro', latitude: 8.4542, longitude: 124.6319, factor: 0.92 },
    { region: 'Region XI', regionName: 'Davao Region', provinceCity: 'Davao City', latitude: 7.1907, longitude: 125.4553, factor: 0.90 },
];

// Three monthly snapshots ending on the most recent first-of-month, so the
// newest one is always "current" no matter when the seed runs.
function snapshotMonths(count = 3): string[] {
    const now = new Date();
    const months: string[] = [];
    for (let back = count - 1; back >= 0; back -= 1) {
        const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - back, 1));
        months.push(d.toISOString().slice(0, 10));
    }
    return months;
}

// FNV-1a folded to [0, 1): stable across runs and platforms.
function unitHash(key: string): number {
    let h = 0x811c9dc5;
    for (let i = 0; i < key.length; i += 1) {
        h ^= key.charCodeAt(i);
        h = Math.imul(h, 0x01000193) >>> 0;
    }
    return (h % 10000) / 10000;
}

const round2 = (n: number) => Math.round(n * 100) / 100;

export function seedMarketWatch(): { products: number; prices: number } {
    const upsertProduct = db.prepare(`
        INSERT INTO market_products (name, classification, product_groups, unit_measurement, dti_srp, crop_keywords)
        VALUES (@name, @classification, @groups, @unit, @dtiSrp, @keywords)
        ON CONFLICT(name) DO UPDATE SET
            classification = excluded.classification,
            product_groups = excluded.product_groups,
            unit_measurement = excluded.unit_measurement,
            dti_srp = excluded.dti_srp,
            crop_keywords = excluded.crop_keywords
    `);
    const findProduct = db.prepare(`SELECT market_product_id FROM market_products WHERE name = ?`);
    const upsertPrice = db.prepare(`
        INSERT INTO market_prices (market_product_id, region, region_name, province_city, latitude, longitude, avg_price, lowest_price, highest_price, recorded_at, source)
        VALUES (@productId, @region, @regionName, @provinceCity, @latitude, @longitude, @avg, @lowest, @highest, @recordedAt, 'seed')
        ON CONFLICT(market_product_id, region, province_city, recorded_at) DO UPDATE SET
            region_name = excluded.region_name,
            latitude = excluded.latitude,
            longitude = excluded.longitude,
            avg_price = excluded.avg_price,
            lowest_price = excluded.lowest_price,
            highest_price = excluded.highest_price
    `);

    const months = snapshotMonths();
    let priceRows = 0;

    const run = db.transaction(() => {
        for (const product of products) {
            upsertProduct.run({
                name: product.name,
                classification: product.classification,
                groups: product.groups.join(', '),
                unit: product.unit,
                dtiSrp: product.dtiSrp,
                keywords: product.keywords.join(','),
            });
            const { market_product_id: productId } = findProduct.get(product.name) as { market_product_id: number };

            for (const area of areas) {
                for (const month of months) {
                    // Month-to-month drift of up to +/-15%, different per area so
                    // the same product trends up in one city and down in another.
                    const drift = (unitHash(`${product.name}|${area.provinceCity}|${month}`) - 0.5) * 0.30;
                    const avg = product.basePrice * area.factor * (1 + drift);
                    const spread = 0.05 + unitHash(`spread|${product.name}|${area.provinceCity}|${month}`) * 0.07;
                    upsertPrice.run({
                        productId,
                        region: area.region,
                        regionName: area.regionName,
                        provinceCity: area.provinceCity,
                        latitude: area.latitude,
                        longitude: area.longitude,
                        avg: round2(avg),
                        lowest: round2(avg * (1 - spread)),
                        highest: round2(avg * (1 + spread)),
                        recordedAt: month,
                    });
                    priceRows += 1;
                }
            }
        }
    });
    run();

    return { products: products.length, prices: priceRows };
}
