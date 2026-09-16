import { db } from "#config/database";
import { DA_CATEGORIES, DA_REGIONS, DaCategory, DaPriceTable, DaRegion, fetchPriceTable } from "#market/bantay-presyo";
import { MARKET_AREAS, REGION_CENTROIDS, displayMarketName } from "#market/market-areas";

// Turns DA Bantay Presyo tables into market_prices rows.
//
// Per region x category (one table, three requests):
//   - every commodity row becomes / finds a market_products row via
//     external_key 'da:<category>:<commodity>';
//   - one 'region' row per product: avg / lowest / highest across the markets
//     that had a price, sample_size = how many;
//   - one 'market' row per market with a price, for that date only - older
//     market rows for the product+region are deleted, so the table keeps
//     region history but only the latest market snapshot;
//   - seed rows for that product+region are deleted: real data replaces the
//     placeholder rather than sitting next to it.
// Every run is written to system_logs so a broken scrape is visible.

export const DA_SOURCE = 'da-bantay-presyo';

export interface ImportOptions {
    // Short region labels ("NCR", "Region III"); default every region.
    regions?: string[];
    // DA category ids; default every crop category.
    categories?: number[];
    // Pause between tables so a full run stays around one request a second.
    delayMs?: number;
    log?: (line: string) => void;
}

export interface ImportSummary {
    startedAt: string;
    finishedAt: string;
    tables: number;
    failedTables: { region: string; category: string; error: string }[];
    productsCreated: number;
    regionRows: number;
    marketRows: number;
    // Newest as-of date seen across every table.
    latestAsOf: string | null;
}

const round2 = (n: number) => Math.round(n * 100) / 100;
const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

export const externalKeyFor = (category: DaCategory, commodity: string): string => `da:${category.id}:${commodity}`;

// "COMMERCIAL (IMPORTED) Premium (Yellow tagged)" -> "Rice, Imported Premium";
// "Garlic(Imported)" -> "Garlic (Imported)"; everything else as DA writes it.
export function productNameFor(category: DaCategory, commodity: string): string {
    if (category.id === 1) {
        const origin = /\((IMPORTED|LOCAL)\)/i.exec(commodity)?.[1];
        const grade = commodity
            .replace(/COMMERCIAL/i, '')
            .replace(/\((IMPORTED|LOCAL)\)/i, '')
            .replace(/\((Yellow|Blue) tagged\)/i, '')
            .replace(/\s+/g, ' ')
            .trim();
        const originLabel = origin ? origin.charAt(0) + origin.slice(1).toLowerCase() : '';
        return ['Rice,', originLabel, grade].filter(Boolean).join(' ');
    }
    return commodity.replace(/\s*\(\s*/g, ' (').replace(/\s*\)\s*/g, ')').replace(/\s+/g, ' ').trim();
}

// Qualifiers that describe rather than name a crop: never a keyword on their
// own, or "Imported rice" would match Garlic (Imported) before Rice.
const DESCRIPTIVE_QUALIFIERS = new Set(['native', 'imported', 'local', 'red', 'white', 'green', 'yellow', 'baguio', 'feed grade', 'food grade']);

// Lower-cased fragments findReference() matches listing titles against.
// "Banana (Lakatan)" -> banana lakatan, lakatan banana, lakatan. A product
// without a qualifier keeps its bare name ("tomato"); qualified ones do not,
// so a listing titled just "Banana" is left to whichever product owns the
// bare keyword (the seed gives it to Banana (Saba)).
export function keywordsFor(category: DaCategory, commodity: string): string[] {
    // crop_keywords is comma-separated, so a comma inside a keyword would split it.
    const name = productNameFor(category, commodity).toLowerCase().replace(/,\s*/g, ' ');
    if (category.id === 1) {
        const grade = name.replace(/^rice\s*/, '');
        const withoutOrigin = grade.replace(/^(imported|local)\s*/, '');
        // Kubo's farmers sell local rice, so the bare grade ("premium rice")
        // points at the local variant; imported keeps the full phrase.
        const bare = grade.startsWith('local') && withoutOrigin ? [`${withoutOrigin} rice`, `rice ${withoutOrigin}`] : [];
        return [...new Set([`${grade} rice`, `rice ${grade}`, ...bare])];
    }
    const match = /^(.*?)\s*\((.*?)\)\s*(.*)$/.exec(name);
    if (!match) return [name];
    const base = [match[1], match[3]].filter(Boolean).join(' ').trim();
    const qualifier = match[2].trim();
    const alone = qualifier.length >= 4 && !DESCRIPTIVE_QUALIFIERS.has(qualifier) ? qualifier : '';
    return [...new Set([`${base} ${qualifier}`, `${qualifier} ${base}`, alone])].filter(Boolean);
}

const findProductByKey = db.prepare(`SELECT market_product_id FROM market_products WHERE external_key = ?`);
const productNameTaken = db.prepare(`SELECT 1 FROM market_products WHERE name = ?`);
const insertProduct = db.prepare(`
    INSERT INTO market_products (name, classification, product_groups, unit_measurement, dti_srp, crop_keywords, external_key)
    VALUES (@name, 'Food Products', @groups, 'kg', NULL, @keywords, @externalKey)
`);
const upsertPrice = db.prepare(`
    INSERT INTO market_prices (market_product_id, region, region_name, area_type, province_city, latitude, longitude, avg_price, lowest_price, highest_price, sample_size, recorded_at, source)
    VALUES (@productId, @region, @regionName, @areaType, @provinceCity, @latitude, @longitude, @avg, @lowest, @highest, @sampleSize, @recordedAt, '${DA_SOURCE}')
    ON CONFLICT(market_product_id, region, province_city, recorded_at) DO UPDATE SET
        region_name = excluded.region_name,
        area_type = excluded.area_type,
        latitude = excluded.latitude,
        longitude = excluded.longitude,
        avg_price = excluded.avg_price,
        lowest_price = excluded.lowest_price,
        highest_price = excluded.highest_price,
        sample_size = excluded.sample_size,
        source = excluded.source
`);
const deleteStaleMarketRows = db.prepare(`
    DELETE FROM market_prices
    WHERE market_product_id = ? AND region = ? AND area_type = 'market' AND recorded_at < ?
`);
const deleteSeedRows = db.prepare(`DELETE FROM market_prices WHERE market_product_id = ? AND region = ? AND source = 'seed'`);
const insertLog = db.prepare(`INSERT INTO system_logs (action_type, description) VALUES (?, ?)`);

// Ensures the product row exists; DA never overwrites a name or keywords the
// seed chose, only fills in what is missing.
function ensureProduct(category: DaCategory, commodity: string, created: { count: number }): number {
    const externalKey = externalKeyFor(category, commodity);
    const existing = findProductByKey.get(externalKey) as { market_product_id: number } | undefined;
    if (existing) return existing.market_product_id;
    let name = productNameFor(category, commodity);
    // name is UNIQUE; a seed product without an external_key could already own it.
    if (productNameTaken.get(name)) name = `${name} (DA)`;
    const result = insertProduct.run({
        name,
        groups: category.label,
        keywords: keywordsFor(category, commodity).join(','),
        externalKey,
    });
    created.count += 1;
    return Number(result.lastInsertRowid);
}

// Writes one fetched table. Returns how many rows of each kind it stored.
export const storePriceTable = db.transaction((table: DaPriceTable, created: { count: number }): { regionRows: number; marketRows: number } => {
    let regionRows = 0;
    let marketRows = 0;
    if (!table.asOf) return { regionRows, marketRows };
    const centroid = REGION_CENTROIDS[table.region.region];

    for (const row of table.rows) {
        const priced = row.prices
            .map((price, i) => ({ market: table.markets[i], price }))
            .filter((entry): entry is { market: string; price: number } => entry.price !== null && !!entry.market);
        if (!priced.length) continue;

        const productId = ensureProduct(table.category, row.commodity, created);
        const values = priced.map((p) => p.price);
        const base = { productId, region: table.region.region, regionName: table.region.regionName, recordedAt: table.asOf };

        upsertPrice.run({
            ...base,
            areaType: 'region',
            provinceCity: '',
            latitude: centroid?.latitude ?? null,
            longitude: centroid?.longitude ?? null,
            avg: round2(values.reduce((a, b) => a + b, 0) / values.length),
            lowest: Math.min(...values),
            highest: Math.max(...values),
            sampleSize: values.length,
        });
        regionRows += 1;

        deleteStaleMarketRows.run(productId, table.region.region, table.asOf);
        for (const { market, price } of priced) {
            const area = MARKET_AREAS[market];
            upsertPrice.run({
                ...base,
                areaType: 'market',
                provinceCity: displayMarketName(market),
                latitude: area?.latitude ?? null,
                longitude: area?.longitude ?? null,
                avg: price,
                lowest: price,
                highest: price,
                sampleSize: 1,
            });
            marketRows += 1;
        }
        deleteSeedRows.run(productId, table.region.region);
    }
    return { regionRows, marketRows };
});

export async function importMarketPrices(options: ImportOptions = {}): Promise<ImportSummary> {
    const log = options.log ?? (() => undefined);
    const delayMs = options.delayMs ?? 1000;
    const regions = DA_REGIONS.filter((r) => !options.regions || options.regions.includes(r.region));
    const categories = DA_CATEGORIES.filter((c) => !options.categories || options.categories.includes(c.id));
    const summary: ImportSummary = {
        startedAt: new Date().toISOString(),
        finishedAt: '',
        tables: 0,
        failedTables: [],
        productsCreated: 0,
        regionRows: 0,
        marketRows: 0,
        latestAsOf: null,
    };
    const created = { count: 0 };

    for (const region of regions) {
        for (const category of categories) {
            let table: DaPriceTable | undefined;
            try {
                table = await fetchTableWithRetry(region, category);
            } catch (error) {
                const message = error instanceof Error ? error.message : String(error);
                summary.failedTables.push({ region: region.region, category: category.label, error: message });
                log(`  ! ${region.region} / ${category.label}: ${message}`);
                await sleep(delayMs);
                continue;
            }
            const stored = storePriceTable(table, created);
            summary.tables += 1;
            summary.regionRows += stored.regionRows;
            summary.marketRows += stored.marketRows;
            if (table.asOf && (!summary.latestAsOf || table.asOf > summary.latestAsOf)) summary.latestAsOf = table.asOf;
            log(`  ${region.region} / ${category.label}: ${table.rows.length} commodities x ${table.markets.length} markets, as of ${table.asOf ?? 'unknown'}`);
            await sleep(delayMs);
        }
    }

    summary.productsCreated = created.count;
    summary.finishedAt = new Date().toISOString();
    insertLog.run(summary.tables === 0 ? 'market_import_failed' : 'market_import', JSON.stringify(summary));
    return summary;
}

async function fetchTableWithRetry(region: DaRegion, category: DaCategory): Promise<DaPriceTable> {
    try {
        return await fetchPriceTable(region, category);
    } catch {
        await sleep(3000);
        return fetchPriceTable(region, category);
    }
}

// Runs the import once a day at MARKET_IMPORT_HOUR (local time, default 06:00)
// for as long as the server is up. No dependency: a timer to the next slot,
// then every 24 h. MARKET_IMPORT_ENABLED=false turns it off (tests, offline
// demos); MARKET_IMPORT_ON_START=true also runs it right after boot.
export function scheduleMarketImport(log: (line: string) => void = console.log): void {
    if ((process.env.MARKET_IMPORT_ENABLED ?? 'true').toLowerCase() === 'false') {
        log('Market import: disabled (MARKET_IMPORT_ENABLED=false)');
        return;
    }
    const hour = Number(process.env.MARKET_IMPORT_HOUR ?? 6);
    const run = async () => {
        log('Market import: starting');
        try {
            const summary = await importMarketPrices({ log });
            log(`Market import: ${summary.tables} tables, ${summary.regionRows} region rows, ${summary.marketRows} market rows, ${summary.failedTables.length} failed, as of ${summary.latestAsOf}`);
        } catch (error) {
            log(`Market import: failed - ${error instanceof Error ? error.message : String(error)}`);
        }
    };
    const msUntilNext = () => {
        const next = new Date();
        next.setHours(hour, 0, 0, 0);
        if (next.getTime() <= Date.now()) next.setDate(next.getDate() + 1);
        return next.getTime() - Date.now();
    };
    const arm = () => {
        const wait = msUntilNext();
        log(`Market import: next run in ${Math.round(wait / 60000)} min`);
        setTimeout(() => { void run().finally(arm); }, wait).unref();
    };
    arm();
    if ((process.env.MARKET_IMPORT_ON_START ?? 'false').toLowerCase() === 'true') void run();
}
