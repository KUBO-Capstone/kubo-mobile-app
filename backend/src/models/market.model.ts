import { db } from "#config/database";

// Market Watch: reference prices per product per area, as seeded by
// scripts/seed-market.ts. Nothing here reads Kubo listings - it is the
// "what does this cost at the market" table buyers compare a farmer's asking
// price against. Aggregation happens in JS: the whole table is a few hundred
// rows and the per-product / per-area / per-month grouping reads better here
// than as nested window functions.

export type MarketClassification = 'Food Products' | 'Fiber Products' | 'Fuel Products' | 'Raw Materials';
export const CLASSIFICATIONS: MarketClassification[] = ['Food Products', 'Fiber Products', 'Fuel Products', 'Raw Materials'];

export interface MarketProductRow {
    market_product_id: number;
    name: string;
    classification: MarketClassification;
    product_groups: string;
    unit_measurement: string;
    dti_srp: number | null;
    crop_keywords: string;
}

interface PriceRow {
    market_product_id: number;
    region: string;
    region_name: string;
    province_city: string;
    latitude: number | null;
    longitude: number | null;
    avg_price: number;
    lowest_price: number;
    highest_price: number;
    recorded_at: string;
}

// One line of the Market tab table.
export interface MarketProductSummary {
    market_product_id: number;
    name: string;
    classification: MarketClassification;
    groups: string[];
    unit_measurement: string;
    dti_srp: number | null;
    as_of: string | null;
    nationwide_avg: number | null;
    // % change of the nationwide average vs the previous snapshot; null when
    // there is only one snapshot.
    change_pct: number | null;
}

// One line of the product dashboard table / one map pin.
export interface MarketAreaPrice {
    region: string;
    region_name: string;
    province_city: string;
    latitude: number | null;
    longitude: number | null;
    avg_price: number;
    lowest_price: number;
    highest_price: number;
    unit_measurement: string;
    as_of: string;
    change_pct: number | null;
}

export interface MarketProductDetail extends MarketProductSummary {
    highest_price: number | null;
    lowest_price: number | null;
    areas: MarketAreaPrice[];
}

// What the listing page shows under the farmer's asking price.
export interface MarketReference {
    market_product_id: number;
    name: string;
    unit_measurement: string;
    as_of: string | null;
    region: string | null;
    region_avg: number | null;
    nationwide_avg: number | null;
    dti_srp: number | null;
}

const round2 = (n: number) => Math.round(n * 100) / 100;
const mean = (values: number[]) => (values.length ? values.reduce((a, b) => a + b, 0) / values.length : null);
const pctChange = (current: number | null, previous: number | null): number | null =>
    current === null || previous === null || previous === 0 ? null : round2(((current - previous) / previous) * 100);

// Region labels differ between sources ("Region III" vs "Region III - Central
// Luzon"); compare on the part before " - ", same rule as the explore filter.
export const normalizeRegion = (label: string): string => {
    const cut = label.indexOf(' - ');
    return (cut === -1 ? label : label.slice(0, cut)).trim().toUpperCase();
};

function mapProduct(row: MarketProductRow) {
    return {
        market_product_id: row.market_product_id,
        name: row.name,
        classification: row.classification,
        groups: row.product_groups.split(',').map((g) => g.trim()).filter(Boolean),
        unit_measurement: row.unit_measurement,
        dti_srp: row.dti_srp === null ? null : Number(row.dti_srp),
    };
}

function pricesFor(productId: number): PriceRow[] {
    return db.prepare(`SELECT * FROM market_prices WHERE market_product_id = ? ORDER BY recorded_at DESC`)
        .all(productId) as PriceRow[];
}

// The two most recent snapshot dates present for a product.
function latestMonths(rows: PriceRow[]): [string | null, string | null] {
    const months = [...new Set(rows.map((r) => r.recorded_at))].sort().reverse();
    return [months[0] ?? null, months[1] ?? null];
}

function summarize(product: MarketProductRow, rows: PriceRow[]): MarketProductSummary {
    const [latest, previous] = latestMonths(rows);
    const current = mean(rows.filter((r) => r.recorded_at === latest).map((r) => r.avg_price));
    const prior = mean(rows.filter((r) => r.recorded_at === previous).map((r) => r.avg_price));
    return {
        ...mapProduct(product),
        as_of: latest,
        nationwide_avg: current === null ? null : round2(current),
        change_pct: pctChange(current, prior),
    };
}

export const MarketModel = {
    // Table for the Market tab, optionally narrowed by search and classification.
    listProducts(query = '', classification?: MarketClassification): MarketProductSummary[] {
        const conditions: string[] = [];
        const params: Record<string, unknown> = {};
        if (query.trim()) {
            conditions.push(`(LOWER(name) LIKE @q OR LOWER(product_groups) LIKE @q OR LOWER(crop_keywords) LIKE @q)`);
            params.q = `%${query.trim().toLowerCase()}%`;
        }
        if (classification) {
            conditions.push(`classification = @classification`);
            params.classification = classification;
        }
        const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
        const products = db.prepare(`SELECT * FROM market_products ${where} ORDER BY classification, name`).all(params) as MarketProductRow[];
        return products.map((product) => summarize(product, pricesFor(product.market_product_id)));
    },

    // Product dashboard: nationwide summary plus one row per area at the latest
    // snapshot, each with its own month-over-month change.
    findProduct(productId: number): MarketProductDetail | undefined {
        const product = db.prepare(`SELECT * FROM market_products WHERE market_product_id = ?`).get(productId) as MarketProductRow | undefined;
        if (!product) return undefined;
        const rows = pricesFor(productId);
        const summary = summarize(product, rows);
        const [latest, previous] = latestMonths(rows);
        const current = rows.filter((r) => r.recorded_at === latest);
        const priorByArea = new Map(
            rows.filter((r) => r.recorded_at === previous).map((r) => [`${r.region}|${r.province_city}`, r.avg_price]),
        );
        const areas: MarketAreaPrice[] = current
            .map((r) => ({
                region: r.region,
                region_name: r.region_name,
                province_city: r.province_city,
                latitude: r.latitude,
                longitude: r.longitude,
                avg_price: r.avg_price,
                lowest_price: r.lowest_price,
                highest_price: r.highest_price,
                unit_measurement: product.unit_measurement,
                as_of: r.recorded_at,
                change_pct: pctChange(r.avg_price, priorByArea.get(`${r.region}|${r.province_city}`) ?? null),
            }))
            .sort((a, b) => a.region.localeCompare(b.region) || a.province_city.localeCompare(b.province_city));
        return {
            ...summary,
            highest_price: current.length ? Math.max(...current.map((r) => r.highest_price)) : null,
            lowest_price: current.length ? Math.min(...current.map((r) => r.lowest_price)) : null,
            areas,
        };
    },

    // Reference price for a Kubo listing: match the crop name against each
    // product's keywords (longest keyword wins so "corn starch" beats "corn"),
    // then average the latest snapshot inside the seller's region.
    findReference(cropName: string, region?: string): MarketReference | undefined {
        const needle = cropName.trim().toLowerCase();
        if (!needle) return undefined;
        const products = db.prepare(`SELECT * FROM market_products`).all() as MarketProductRow[];
        let best: { product: MarketProductRow; keyword: string } | undefined;
        for (const product of products) {
            for (const keyword of product.crop_keywords.split(',').map((k) => k.trim().toLowerCase()).filter(Boolean)) {
                if (needle.includes(keyword) && (!best || keyword.length > best.keyword.length)) {
                    best = { product, keyword };
                }
            }
        }
        if (!best) return undefined;

        const rows = pricesFor(best.product.market_product_id);
        const [latest] = latestMonths(rows);
        const current = rows.filter((r) => r.recorded_at === latest);
        const wanted = region ? normalizeRegion(region) : null;
        const inRegion = wanted ? current.filter((r) => normalizeRegion(r.region) === wanted) : [];
        const regionAvg = mean(inRegion.map((r) => r.avg_price));
        const nationwide = mean(current.map((r) => r.avg_price));
        return {
            market_product_id: best.product.market_product_id,
            name: best.product.name,
            unit_measurement: best.product.unit_measurement,
            as_of: latest,
            region: inRegion.length ? inRegion[0].region : null,
            region_avg: regionAvg === null ? null : round2(regionAvg),
            nationwide_avg: nationwide === null ? null : round2(nationwide),
            dti_srp: best.product.dti_srp === null ? null : Number(best.product.dti_srp),
        };
    },
};
