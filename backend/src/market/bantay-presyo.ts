// Client for DA Bantay Presyo (www.bantaypresyo.da.gov.ph).
//
// DA publishes no API. Its price pages (tbl_rice.php etc.) ship an empty
// table and fill it with three jQuery POSTs, which we call directly:
//   POST tbl_rice.php                         action=get_latest_date  -> "September 16, 2026"
//   POST tbl_price_get_comm_header_rice.php   region=&commodity=      -> <tr><th>COMMODITY</th><th>SPECIFICATIONS</th><th>market</th>...
//   POST tbl_price_get_comm_price_rice.php    region=&commodity=      -> <tr><td>Tomato</td><td>15-18 PCS/KG</td><td>80.00</td><td>N/A</td>...
// Despite the "_rice" in the name the endpoints serve every category; the
// commodity parameter picks it. Plain HTTP only - port 443 refuses.
//
// This file only fetches and parses. Aggregation and storage live in
// market-import.ts so the parser can be exercised without a database.

export const BANTAY_PRESYO_BASE = process.env.BANTAY_PRESYO_BASE || 'http://www.bantaypresyo.da.gov.ph';
const USER_AGENT = process.env.BANTAY_PRESYO_USER_AGENT || 'kubo-thesis-market-watch/1.0 (student capstone; price reference import)';
const REQUEST_TIMEOUT_MS = 30_000;

export interface DaRegion {
    // Value of the region <select>: PSGC-style, first two digits identify it.
    code: string;
    // Short label, same style as seed.ts / normalizeRegion ("NCR", "Region III").
    region: string;
    // Long label for the map dropdown.
    regionName: string;
}

// Every option in the region dropdown as of 2026-09.
export const DA_REGIONS: DaRegion[] = [
    { code: '010000000', region: 'Region I', regionName: 'Ilocos Region' },
    { code: '020000000', region: 'Region II', regionName: 'Cagayan Valley' },
    { code: '030000000', region: 'Region III', regionName: 'Central Luzon' },
    { code: '040000000', region: 'Region IV-A', regionName: 'CALABARZON' },
    { code: '170000000', region: 'Region IV-B', regionName: 'MIMAROPA' },
    { code: '050000000', region: 'Region V', regionName: 'Bicol Region' },
    { code: '060000000', region: 'Region VI', regionName: 'Western Visayas' },
    { code: '070000000', region: 'Region VII', regionName: 'Central Visayas' },
    { code: '080000000', region: 'Region VIII', regionName: 'Eastern Visayas' },
    { code: '090000000', region: 'Region IX', regionName: 'Zamboanga Peninsula' },
    { code: '100000000', region: 'Region X', regionName: 'Northern Mindanao' },
    { code: '110000000', region: 'Region XI', regionName: 'Davao Region' },
    { code: '120000000', region: 'Region XII', regionName: 'SOCCSKSARGEN' },
    { code: '160000000', region: 'Region XIII', regionName: 'Caraga' },
    { code: '130000000', region: 'NCR', regionName: 'National Capital Region' },
    { code: '140000000', region: 'CAR', regionName: 'Cordillera Administrative Region' },
    { code: '150000000', region: 'BARMM', regionName: 'Bangsamoro Autonomous Region in Muslim Mindanao' },
];

export interface DaCategory {
    // Value of the commodity <select>.
    id: number;
    // Label as DA shows it; becomes market_products.product_groups.
    label: string;
}

// The commodity categories Kubo imports. DA also has 4 FISH, 8 MEAT AND
// POULTRY and 10 OTHER COMMODITIES (sugar, cooking oil by the bottle); Kubo
// is a crop marketplace and everything below is priced per kg, so those are
// deliberately left out.
export const DA_CATEGORIES: DaCategory[] = [
    { id: 1, label: 'Rice' },
    { id: 2, label: 'Corn' },
    { id: 3, label: 'Legumes' },
    { id: 5, label: 'Fruits' },
    { id: 6, label: 'Highland Vegetables' },
    { id: 7, label: 'Lowland Vegetables' },
    { id: 9, label: 'Spices' },
];

// One commodity row: the price at every market column, null where DA shows N/A.
export interface DaCommodityRow {
    commodity: string;
    specification: string;
    prices: (number | null)[];
}

export interface DaPriceTable {
    region: DaRegion;
    category: DaCategory;
    // ISO date (YYYY-MM-DD) from get_latest_date; null when DA answered blank.
    asOf: string | null;
    markets: string[];
    rows: DaCommodityRow[];
}

async function post(path: string, form: Record<string, string>): Promise<string> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
    try {
        const response = await fetch(`${BANTAY_PRESYO_BASE}/${path}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'User-Agent': USER_AGENT },
            body: new URLSearchParams(form).toString(),
            signal: controller.signal,
        });
        if (!response.ok) throw new Error(`Bantay Presyo ${path} answered ${response.status}`);
        return await response.text();
    } finally {
        clearTimeout(timer);
    }
}

const decodeEntities = (text: string): string =>
    text
        .replace(/&#0*39;|&apos;/g, "'")
        .replace(/&quot;/g, '"')
        .replace(/&amp;/g, '&')
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&nbsp;/g, ' ');

const cellText = (html: string): string => decodeEntities(html.replace(/<[^>]*>/g, ' ')).replace(/\s+/g, ' ').trim();

// Splits a <tr>...</tr> fragment stream into rows of cell texts. The fragments
// are machine-generated (one <tr> per row, <td>/<th> only, no nesting of
// rows), so a regex is enough and saves a dependency.
export function parseRows(fragment: string): string[][] {
    const rows: string[][] = [];
    for (const [, inner] of fragment.matchAll(/<tr[^>]*>([\s\S]*?)<\/tr>/gi)) {
        const cells = [...inner.matchAll(/<t[dh][^>]*>([\s\S]*?)<\/t[dh]>/gi)].map(([, cell]) => cellText(cell));
        if (cells.length) rows.push(cells);
    }
    return rows;
}

// "N/A", "" and anything non-numeric become null.
export function parsePrice(text: string): number | null {
    const cleaned = text.replace(/[^0-9.]/g, '');
    if (!cleaned) return null;
    const value = Number(cleaned);
    return Number.isFinite(value) && value > 0 ? value : null;
}

// "September 16, 2026" -> "2026-09-16"; null when it does not parse.
export function parseAsOfDate(text: string): string | null {
    const parsed = new Date(`${text.trim()} UTC`);
    if (Number.isNaN(parsed.getTime())) return null;
    return parsed.toISOString().slice(0, 10);
}

// Header row: COMMODITY | SPECIFICATIONS | market | market | ...
export function parseMarkets(headerFragment: string): string[] {
    const [header] = parseRows(headerFragment);
    return header ? header.slice(2) : [];
}

export function parseCommodities(priceFragment: string, marketCount: number): DaCommodityRow[] {
    return parseRows(priceFragment)
        .filter((cells) => cells.length >= 2 && cells[0])
        .map((cells) => ({
            commodity: cells[0],
            specification: cells[1] ?? '',
            prices: Array.from({ length: marketCount }, (_, i) => parsePrice(cells[i + 2] ?? '')),
        }));
}

// One region x category table, three requests. Throws on network failure so
// the importer can decide whether to skip the pair or abort the run.
export async function fetchPriceTable(region: DaRegion, category: DaCategory): Promise<DaPriceTable> {
    const form = { region: region.code, commodity: String(category.id) };
    const dateText = await post('tbl_rice.php', { action: 'get_latest_date', ...form });
    const header = await post('tbl_price_get_comm_header_rice.php', form);
    const prices = await post('tbl_price_get_comm_price_rice.php', form);
    const markets = parseMarkets(header);
    return {
        region,
        category,
        asOf: parseAsOfDate(dateText),
        markets,
        rows: parseCommodities(prices, markets.length),
    };
}
