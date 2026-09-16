import { db } from "#config/database";
import { DA_REGIONS } from "#market/bantay-presyo";

// Market Watch: reference prices per product per area. Nothing here reads
// Kubo listings - it is the "what does this cost at the market" table buyers
// compare a farmer's asking price against.
//
// market_prices holds two kinds of row (config/database.ts): 'region' rows are
// the daily history (one per product x region x date, aggregated across that
// region's markets) and 'market' rows are the latest per-market snapshot (the
// map pins). Trends compare a region's latest row with its row from at least
// TREND_DAYS earlier; "nationwide" is the mean of every region's latest row.
// Regions record on different days (NCR may be a day behind Region III), so
// "latest" is decided per region, not per product. Aggregation happens in
// JS: a product has at most a few thousand rows and the per-region grouping
// reads better here than as nested window functions.

export type MarketClassification = 'Food Products' | 'Fiber Products' | 'Fuel Products' | 'Raw Materials';
export const CLASSIFICATIONS: MarketClassification[] = ['Food Products', 'Fiber Products', 'Fuel Products', 'Raw Materials'];

// How far back the arrow looks. Seed rows are weekly, DA rows daily; both
// have a row this far back once the importer has run for a week.
const TREND_DAYS = 7;
// A region whose newest row is older than this (vs the product's newest
// anywhere) has dropped out of DA's monitoring; leave it off the dashboard.
const STALE_DAYS = 30;

export interface MarketProductRow {
    market_product_id: number;
    name: string;
    classification: MarketClassification;
    product_groups: string;
    unit_measurement: string;
    dti_srp: number | null;
    crop_keywords: string;
    external_key: string | null;
}

interface PriceRow {
    market_product_id: number;
    region: string;
    region_name: string;
    area_type: 'region' | 'market';
    province_city: string;
    latitude: number | null;
    longitude: number | null;
    avg_price: number;
    lowest_price: number;
    highest_price: number;
    sample_size: number;
    recorded_at: string;
    source: string;
}

// One line of the Market tab table.
export interface MarketProductSummary {
    market_product_id: number;
    name: string;
    classification: MarketClassification;
    groups: string[];
    unit_measurement: string;
    dti_srp: number | null;
    // Newest recorded_at across regions.
    as_of: string | null;
    // 'da-bantay-presyo' when the current figures come from the DA import,
    // 'seed' when they are still the illustrative placeholder.
    source: string | null;
    nationwide_avg: number | null;
    // % change of the nationwide average vs TREND_DAYS earlier; null when
    // no region has a row that far back.
    change_pct: number | null;
}

// One dashboard table row (area_type 'region') or one map pin ('market').
export interface MarketAreaPrice {
    region: string;
    region_name: string;
    area_type: 'region' | 'market';
    // Market name for market rows; '' for region rows.
    province_city: string;
    latitude: number | null;
    longitude: number | null;
    avg_price: number;
    lowest_price: number;
    highest_price: number;
    // Markets behind a region row; 1 for a market row.
    sample_size: number;
    unit_measurement: string;
    as_of: string;
    source: string;
    change_pct: number | null;
}

export interface MarketProductDetail extends MarketProductSummary {
    highest_price: number | null;
    lowest_price: number | null;
    // One per region with current data, each with its own trend.
    areas: MarketAreaPrice[];
    // Every market with a price at its region's latest date.
    markets: MarketAreaPrice[];
}

// What the listing page shows under the farmer's asking price.
export interface MarketReference {
    market_product_id: number;
    name: string;
    unit_measurement: string;
    as_of: string | null;
    source: string | null;
    region: string | null;
    region_avg: number | null;
    nationwide_avg: number | null;
    dti_srp: number | null;
}

const round2 = (n: number) => Math.round(n * 100) / 100;
// Region I ... Region XIII, NCR, CAR, BARMM - the order DA lists them, so the
// dashboard does not sort "Region IX" before "Region V". Unknown labels last.
const regionRank = new Map(DA_REGIONS.map((r, i) => [r.region.toUpperCase(), i]));
const compareRegions = (a: string, b: string): number =>
    (regionRank.get(a.toUpperCase()) ?? 99) - (regionRank.get(b.toUpperCase()) ?? 99) || a.localeCompare(b);
const mean = (values: number[]) => (values.length ? values.reduce((a, b) => a + b, 0) / values.length : null);
const pctChange = (current: number | null, previous: number | null): number | null =>
    current === null || previous === null || previous === 0 ? null : round2(((current - previous) / previous) * 100);
const daysBefore = (isoDate: string, days: number): string => {
    const d = new Date(`${isoDate}T00:00:00Z`);
    d.setUTCDate(d.getUTCDate() - days);
    return d.toISOString().slice(0, 10);
};

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

// Each region's newest region row (within STALE_DAYS of the product's newest)
// paired with its row from at least TREND_DAYS earlier, if any.
interface RegionState {
    current: PriceRow;
    prior: PriceRow | null;
}

function regionStates(rows: PriceRow[]): RegionState[] {
    const regionRows = rows.filter((r) => r.area_type === 'region');
    if (!regionRows.length) return [];
    // rows arrive newest first, so the first row per region is its latest.
    const newest = regionRows[0].recorded_at;
    const cutoff = daysBefore(newest, STALE_DAYS);
    const states = new Map<string, RegionState>();
    for (const row of regionRows) {
        if (!states.has(row.region)) {
            if (row.recorded_at >= cutoff) states.set(row.region, { current: row, prior: null });
            continue;
        }
        const state = states.get(row.region)!;
        if (state.prior === null && row.recorded_at <= daysBefore(state.current.recorded_at, TREND_DAYS)) {
            state.prior = row;
        }
    }
    return [...states.values()].sort((a, b) => compareRegions(a.current.region, b.current.region));
}

function summarize(product: MarketProductRow, states: RegionState[]): MarketProductSummary {
    const current = mean(states.map((s) => s.current.avg_price));
    const withPrior = states.filter((s) => s.prior !== null);
    // Compare like with like: the prior mean only over regions that have one.
    const prior = mean(withPrior.map((s) => s.prior!.avg_price));
    const currentOfPriored = mean(withPrior.map((s) => s.current.avg_price));
    const asOf = states.reduce<string | null>((max, s) => (max === null || s.current.recorded_at > max ? s.current.recorded_at : max), null);
    return {
        ...mapProduct(product),
        as_of: asOf,
        // Any real row outranks the placeholder in the label.
        source: states.length ? (states.find((s) => s.current.source !== 'seed')?.current.source ?? 'seed') : null,
        nationwide_avg: current === null ? null : round2(current),
        change_pct: pctChange(currentOfPriored, prior),
    };
}

function toArea(row: PriceRow, unit: string, changePct: number | null): MarketAreaPrice {
    return {
        region: row.region,
        region_name: row.region_name,
        area_type: row.area_type,
        province_city: row.province_city,
        latitude: row.latitude,
        longitude: row.longitude,
        avg_price: row.avg_price,
        lowest_price: row.lowest_price,
        highest_price: row.highest_price,
        sample_size: row.sample_size,
        unit_measurement: unit,
        as_of: row.recorded_at,
        source: row.source,
        change_pct: changePct,
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
        return products.map((product) => summarize(product, regionStates(pricesFor(product.market_product_id))));
    },

    // Product dashboard: nationwide summary, one row per region with its own
    // trend, and the latest per-market prices for the map.
    findProduct(productId: number): MarketProductDetail | undefined {
        const product = db.prepare(`SELECT * FROM market_products WHERE market_product_id = ?`).get(productId) as MarketProductRow | undefined;
        if (!product) return undefined;
        const rows = pricesFor(productId);
        const states = regionStates(rows);
        const unit = product.unit_measurement;

        const areas = states.map((s) => toArea(s.current, unit, pctChange(s.current.avg_price, s.prior?.avg_price ?? null)));
        const latestByRegion = new Map(states.map((s) => [s.current.region, s.current.recorded_at]));
        const markets = rows
            .filter((r) => r.area_type === 'market' && latestByRegion.get(r.region) === r.recorded_at)
            .map((r) => toArea(r, unit, null))
            .sort((a, b) => compareRegions(a.region, b.region) || a.province_city.localeCompare(b.province_city));

        return {
            ...summarize(product, states),
            highest_price: areas.length ? Math.max(...areas.map((a) => a.highest_price)) : null,
            lowest_price: areas.length ? Math.min(...areas.map((a) => a.lowest_price)) : null,
            areas,
            markets,
        };
    },

    // Reference price for a Kubo listing: match the crop name against each
    // product's keywords (longest keyword wins so "corn starch" beats "corn"),
    // then take the seller's region's latest aggregate.
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

        const states = regionStates(pricesFor(best.product.market_product_id));
        const summary = summarize(best.product, states);
        const wanted = region ? normalizeRegion(region) : null;
        const inRegion = wanted ? states.find((s) => normalizeRegion(s.current.region) === wanted) : undefined;
        return {
            market_product_id: best.product.market_product_id,
            name: best.product.name,
            unit_measurement: best.product.unit_measurement,
            as_of: inRegion?.current.recorded_at ?? summary.as_of,
            source: inRegion?.current.source ?? summary.source,
            region: inRegion?.current.region ?? null,
            region_avg: inRegion ? round2(inRegion.current.avg_price) : null,
            nationwide_avg: summary.nationwide_avg,
            dti_srp: best.product.dti_srp === null ? null : Number(best.product.dti_srp),
        };
    },
};
