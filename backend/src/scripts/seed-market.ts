import { db } from '#config/database';
import { REGION_CENTROIDS } from '#market/market-areas';

// Market Watch placeholder data, in the same shape the DA Bantay Presyo
// importer writes (market/market-import.ts): weekly 'region' rows four weeks
// deep so the +/- trend has a 7-day comparison, plus 'market' rows for the
// newest week so the map has pins. Values are illustrative, not real Bantay
// Presyo figures - the point is that the demo works offline.
//
// Products DA also monitors carry the importer's external_key, so the first
// real import lands on the same product row (keeping these names and Tagalog
// keywords) and replaces the seed prices region by region. Products DA does
// not cover (fiber, fuel, raw materials, coconut) keep their seed prices.
//
// Deterministic: every number derives from a hash of product + area + date,
// so `npm run db:reset` produces the same table each time. Idempotent, and
// never overwrites a row the importer wrote.

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
    // Nationwide base price the area factors and weekly drift scale from.
    basePrice: number;
    // 'da:<category>:<commodity>' as market-import.ts derives it; null when
    // DA does not monitor the product.
    externalKey: string | null;
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
    { name: 'Corn', classification: 'Food Products', groups: ['Grain', 'Vegetable', 'Grass'], unit: 'kg', dtiSrp: 45, keywords: ['corn', 'mais'], basePrice: 42, externalKey: 'da:2:Corn (Yellow)' },
    { name: 'Rice (well-milled)', classification: 'Food Products', groups: ['Grain'], unit: 'kg', dtiSrp: 45, keywords: ['rice', 'bigas', 'jasmine', 'well milled rice', 'rice well milled'], basePrice: 48, externalKey: 'da:1:COMMERCIAL (LOCAL) Well Milled' },
    { name: 'Potatoes', classification: 'Food Products', groups: ['Root', 'Vegetable'], unit: 'kg', dtiSrp: 110, keywords: ['potato', 'patatas'], basePrice: 105, externalKey: 'da:6:White Potato' },
    { name: 'Tomato', classification: 'Food Products', groups: ['Vegetable', 'Fruit'], unit: 'kg', dtiSrp: 80, keywords: ['tomato', 'kamatis'], basePrice: 75, externalKey: 'da:7:Tomato' },
    { name: 'Onion (red)', classification: 'Food Products', groups: ['Vegetable', 'Bulb'], unit: 'kg', dtiSrp: 150, keywords: ['onion', 'sibuyas'], basePrice: 140, externalKey: 'da:9:Red Onion' },
    { name: 'Garlic', classification: 'Food Products', groups: ['Vegetable', 'Bulb'], unit: 'kg', dtiSrp: 180, keywords: ['garlic', 'bawang'], basePrice: 170, externalKey: 'da:9:Garlic(Native)' },
    { name: 'Eggplant', classification: 'Food Products', groups: ['Vegetable'], unit: 'kg', dtiSrp: 70, keywords: ['eggplant', 'talong'], basePrice: 65, externalKey: 'da:7:Eggplant' },
    { name: 'Cabbage', classification: 'Food Products', groups: ['Vegetable', 'Leafy'], unit: 'kg', dtiSrp: 60, keywords: ['cabbage', 'repolyo'], basePrice: 55, externalKey: 'da:6:Cabbage (Scorpio)' },
    { name: 'Banana (saba)', classification: 'Food Products', groups: ['Fruit'], unit: 'kg', dtiSrp: 40, keywords: ['banana', 'saging', 'saba'], basePrice: 38, externalKey: 'da:5:Banana (Saba)' },
    { name: 'Mango (carabao)', classification: 'Food Products', groups: ['Fruit'], unit: 'kg', dtiSrp: 120, keywords: ['mango', 'mangga'], basePrice: 115, externalKey: 'da:5:Mango (Carabao)' },
    { name: 'Mung beans', classification: 'Food Products', groups: ['Legume'], unit: 'kg', dtiSrp: 130, keywords: ['mung', 'munggo'], basePrice: 125, externalKey: 'da:3:Mungbean' },
    { name: 'Coconut', classification: 'Food Products', groups: ['Fruit', 'Nut'], unit: 'piece', dtiSrp: 25, keywords: ['coconut', 'niyog', 'buko'], basePrice: 22, externalKey: null },
    { name: 'Abaca fiber', classification: 'Fiber Products', groups: ['Fiber'], unit: 'kg', dtiSrp: null, keywords: ['abaca'], basePrice: 85, externalKey: null },
    { name: 'Cotton', classification: 'Fiber Products', groups: ['Fiber'], unit: 'kg', dtiSrp: null, keywords: ['cotton', 'bulak'], basePrice: 95, externalKey: null },
    { name: 'Pina fiber', classification: 'Fiber Products', groups: ['Fiber', 'Fruit'], unit: 'kg', dtiSrp: null, keywords: ['pina', 'pineapple fiber'], basePrice: 1500, externalKey: null },
    { name: 'Copra', classification: 'Fuel Products', groups: ['Coconut', 'Oilseed'], unit: 'kg', dtiSrp: null, keywords: ['copra'], basePrice: 38, externalKey: null },
    { name: 'Sugarcane', classification: 'Fuel Products', groups: ['Sugar crop', 'Grass'], unit: 'kg', dtiSrp: null, keywords: ['sugarcane', 'tubo'], basePrice: 3.2, externalKey: null },
    { name: 'Cassava (industrial)', classification: 'Fuel Products', groups: ['Root'], unit: 'kg', dtiSrp: null, keywords: ['cassava', 'kamoteng kahoy'], basePrice: 9, externalKey: null },
    { name: 'Corn starch', classification: 'Raw Materials', groups: ['Grain', 'Industrial'], unit: 'kg', dtiSrp: null, keywords: ['corn starch'], basePrice: 62, externalKey: null },
    { name: 'Rubber (cup lump)', classification: 'Raw Materials', groups: ['Industrial'], unit: 'kg', dtiSrp: null, keywords: ['rubber', 'goma'], basePrice: 45, externalKey: null },
    { name: 'Castor oil', classification: 'Raw Materials', groups: ['Oil', 'Industrial'], unit: 'liter', dtiSrp: null, keywords: ['castor'], basePrice: 180, externalKey: null },
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

// Four weekly snapshots ending today (UTC), oldest first, so the newest one
// is always "current" and the trend always has a row 7 days back.
function snapshotDates(count = 4): string[] {
    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);
    const dates: string[] = [];
    for (let back = count - 1; back >= 0; back -= 1) {
        const d = new Date(today);
        d.setUTCDate(d.getUTCDate() - back * 7);
        dates.push(d.toISOString().slice(0, 10));
    }
    return dates;
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
    const findByKey = db.prepare(`SELECT market_product_id FROM market_products WHERE external_key = ?`);
    const findByName = db.prepare(`SELECT market_product_id FROM market_products WHERE name = ?`);
    const upsertByName = db.prepare(`
        INSERT INTO market_products (name, classification, product_groups, unit_measurement, dti_srp, crop_keywords, external_key)
        VALUES (@name, @classification, @groups, @unit, @dtiSrp, @keywords, @externalKey)
        ON CONFLICT(name) DO UPDATE SET
            classification = excluded.classification,
            product_groups = excluded.product_groups,
            unit_measurement = excluded.unit_measurement,
            dti_srp = excluded.dti_srp,
            crop_keywords = excluded.crop_keywords,
            external_key = excluded.external_key
    `);
    // The importer got here first and owns the row (and its name); the seed
    // only contributes the SRP and the friendlier keywords.
    const updateImported = db.prepare(`
        UPDATE market_products SET classification = @classification, product_groups = @groups, dti_srp = @dtiSrp, crop_keywords = @keywords
        WHERE market_product_id = @id
    `);
    const hasRealRows = db.prepare(`
        SELECT 1 FROM market_prices WHERE market_product_id = ? AND region = ? AND source <> 'seed' LIMIT 1
    `);
    // WHERE on the conflict branch: never overwrite a row the importer wrote.
    const upsertPrice = db.prepare(`
        INSERT INTO market_prices (market_product_id, region, region_name, area_type, province_city, latitude, longitude, avg_price, lowest_price, highest_price, sample_size, recorded_at, source)
        VALUES (@productId, @region, @regionName, @areaType, @provinceCity, @latitude, @longitude, @avg, @lowest, @highest, @sampleSize, @recordedAt, 'seed')
        ON CONFLICT(market_product_id, region, province_city, recorded_at) DO UPDATE SET
            region_name = excluded.region_name,
            area_type = excluded.area_type,
            latitude = excluded.latitude,
            longitude = excluded.longitude,
            avg_price = excluded.avg_price,
            lowest_price = excluded.lowest_price,
            highest_price = excluded.highest_price,
            sample_size = excluded.sample_size
        WHERE market_prices.source = 'seed'
    `);
    // Old seed snapshots (earlier dates, monthly rows from before the DA
    // importer) would otherwise accumulate; the seed owns only its 4 weeks.
    const deleteOtherSeedRows = db.prepare(`
        DELETE FROM market_prices WHERE market_product_id = ? AND source = 'seed' AND recorded_at NOT IN (SELECT value FROM json_each(?))
    `);

    const dates = snapshotDates();
    const latest = dates[dates.length - 1];
    const regions = [...new Map(areas.map((a) => [a.region, a])).values()];
    let priceRows = 0;

    const run = db.transaction(() => {
        for (const product of products) {
            const fields = {
                name: product.name,
                classification: product.classification,
                groups: product.groups.join(', '),
                unit: product.unit,
                dtiSrp: product.dtiSrp,
                keywords: product.keywords.join(','),
                externalKey: product.externalKey,
            };
            const imported = product.externalKey ? (findByKey.get(product.externalKey) as { market_product_id: number } | undefined) : undefined;
            if (imported && !findByName.get(product.name)) {
                updateImported.run({ ...fields, id: imported.market_product_id });
            } else {
                upsertByName.run(fields);
            }
            const { market_product_id: productId } = (imported ?? findByName.get(product.name)) as { market_product_id: number };
            deleteOtherSeedRows.run(productId, JSON.stringify(dates));

            for (const regionSeed of regions) {
                if (hasRealRows.get(productId, regionSeed.region)) continue;
                const regionAreas = areas.filter((a) => a.region === regionSeed.region);
                const centroid = REGION_CENTROIDS[regionSeed.region];

                for (const date of dates) {
                    const areaPrices = regionAreas.map((area) => {
                        // Week-to-week drift of up to +/-15%, different per area so
                        // the same product trends up in one city and down in another.
                        const drift = (unitHash(`${product.name}|${area.provinceCity}|${date}`) - 0.5) * 0.30;
                        const avg = product.basePrice * area.factor * (1 + drift);
                        const spread = 0.05 + unitHash(`spread|${product.name}|${area.provinceCity}|${date}`) * 0.07;
                        return { area, avg: round2(avg), lowest: round2(avg * (1 - spread)), highest: round2(avg * (1 + spread)) };
                    });

                    upsertPrice.run({
                        productId,
                        region: regionSeed.region,
                        regionName: regionSeed.regionName,
                        areaType: 'region',
                        provinceCity: '',
                        latitude: centroid?.latitude ?? null,
                        longitude: centroid?.longitude ?? null,
                        avg: round2(areaPrices.reduce((sum, p) => sum + p.avg, 0) / areaPrices.length),
                        lowest: Math.min(...areaPrices.map((p) => p.lowest)),
                        highest: Math.max(...areaPrices.map((p) => p.highest)),
                        sampleSize: areaPrices.length,
                        recordedAt: date,
                    });
                    priceRows += 1;

                    if (date !== latest) continue;
                    for (const { area, avg, lowest, highest } of areaPrices) {
                        upsertPrice.run({
                            productId,
                            region: area.region,
                            regionName: area.regionName,
                            areaType: 'market',
                            provinceCity: area.provinceCity,
                            latitude: area.latitude,
                            longitude: area.longitude,
                            avg,
                            lowest,
                            highest,
                            sampleSize: 1,
                            recordedAt: date,
                        });
                        priceRows += 1;
                    }
                }
            }
        }
    });
    run();

    return { products: products.length, prices: priceRows };
}
