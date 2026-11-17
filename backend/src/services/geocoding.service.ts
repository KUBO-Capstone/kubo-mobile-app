import { DA_REGIONS } from "#market/bantay-presyo";
import { REGION_CENTROIDS } from "#market/market-areas";
import { Place, PlaceModel, PlacePoint } from "#models/place.model";

// Finds where each seller's town is, once, so listings can be plotted on the
// explore map.
//
// A listing is plotted at its seller's farm address when that has
// coordinates. Most sellers only have the town they registered with, so the
// map needs one point per town. Those come from OpenStreetMap's Nominatim
// (the same service the app's location search uses) and are kept in
// place_coordinates, so each town is asked for a single time.
//
// Only the town, the province and "Philippines" are sent: never a street, a
// barangay, or anything about the seller.
//
// Nominatim's usage policy (https://operations.osmfoundation.org/policies/nominatim/)
// allows one request a second and wants a User-Agent that says who is
// calling, hence SPACING_MS and USER_AGENT. GEOCODING_ENABLED=false turns
// the lookups off (offline demos); listings then stay off the map until a
// later run finds their town.

const SEARCH_URL = process.env.GEOCODING_URL || 'https://nominatim.openstreetmap.org/search';
const USER_AGENT = process.env.GEOCODING_USER_AGENT || 'kubo-thesis-listing-map/1.0 (student capstone; town lookup for listing map)';
const REQUEST_TIMEOUT_MS = 15_000;
const SPACING_MS = 1_100;

// Anything outside this box is not a Philippine town, whatever the search said.
const PHILIPPINES = { south: 4.2, north: 21.5, west: 116.0, east: 127.5 };

// A town found without its province must at least be in or near its region.
// Wide enough for the regions that are strings of islands (Palawan is about
// 450 km from MIMAROPA's centre), narrow enough to tell Luzon from Mindanao.
const MAX_KM_FROM_REGION_CENTRE = 600;

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

const isEnabled = (): boolean => (process.env.GEOCODING_ENABLED ?? 'true').toLowerCase() !== 'false';

// One search result that is a settlement inside the Philippines.
interface Candidate extends PlacePoint {
    // Nominatim's place_rank: about 12-18 for a city, municipality or town,
    // 19-22 for a district, quarter or barangay inside one.
    rank: number;
    // "La Trinidad, Benguet, Cordillera Administrative Region, 2601, Philippines"
    name: string;
}

const isTown = (candidate: Candidate): boolean => candidate.rank >= 12 && candidate.rank <= 18;

// Lower-cased with accents dropped, so "Los Baños" matches "LOS BANOS".
const fold = (text: string): string => text.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();

const kmBetween = (a: PlacePoint, b: PlacePoint): number => {
    const rad = Math.PI / 180;
    const dLat = (b.latitude - a.latitude) * rad;
    const dLon = (b.longitude - a.longitude) * rad;
    const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.latitude * rad) * Math.cos(b.latitude * rad) * Math.sin(dLon / 2) ** 2;
    return 6371 * 2 * Math.asin(Math.sqrt(h));
};

// "REGION IV-A" and "Region IV-A - CALABARZON" both mean the short label 'Region IV-A'.
const regionLabel = (region: string): string | undefined => {
    const wanted = region.split(' - ')[0].trim().toUpperCase();
    return Object.keys(REGION_CENTROIDS).find((name) => name.toUpperCase() === wanted);
};

const regionCentre = (region: string): PlacePoint | undefined => {
    const label = regionLabel(region);
    return label ? REGION_CENTROIDS[label] : undefined;
};

// What OpenStreetMap calls a region where that is not the official name,
// or where it files towns under a region the address lists do not use.
const OSM_REGION_NAMES: Record<string, string[]> = {
    'NCR': ['Metro Manila'],
    'BARMM': ['Bangsamoro'],
    // The Negros provinces sit under "Negros Island Region" in OpenStreetMap.
    'Region VI': ['Negros Island Region'],
    'Region VII': ['Negros Island Region'],
};

// The names a result's address may show for the region an address is in.
// Empty when the region is not one we know, which matches nothing.
const regionNames = (region: string): string[] => {
    const label = regionLabel(region);
    if (!label) return [];
    const official = DA_REGIONS.find((entry) => entry.region === label)?.regionName;
    return [...(official ? [official] : []), ...(OSM_REGION_NAMES[label] ?? [])].map(fold);
};

// "Baguio, Cordillera Administrative Region, 2600, Philippines" -> "baguio"
const localityOf = (candidate: Candidate): string => fold(candidate.name.split(',')[0].trim());

/**
 * How a town is asked for. Addresses name towns the way the PSGC lists do,
 * so "BACOOR CITY", "CITY OF MAKATI" and "BALAGTAS (BIGAA)" each also get a
 * plainer spelling. Metro Manila addresses carry no province, so the region
 * stands in for it.
 */
export function spellingsOf(place: Place): { area: string; cities: string[] } {
    const area = place.province || (/^(ncr|national capital region)\b/i.test(place.region) ? 'Metro Manila' : '');
    const plain = place.city
        .replace(/\s*\(.*?\)\s*/g, ' ')
        .replace(/^city of\s+/i, '')
        .replace(/\s+city$/i, '')
        .replace(/\s+/g, ' ')
        .trim();
    const cities = plain && plain.toLowerCase() !== place.city.toLowerCase() ? [place.city, plain] : [place.city];
    return { area, cities };
}

// One search, settlements only (no roads or shops that share the name). An
// empty list means Nominatim answered and had no match; a request that
// failed throws, so a network problem is never recorded as a miss.
async function search(text: string): Promise<Candidate[]> {
    const url = new URL(SEARCH_URL);
    url.search = new URLSearchParams({ q: text, format: 'jsonv2', countrycodes: 'ph', featureType: 'settlement', limit: '10' }).toString();
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
    try {
        const response = await fetch(url, { headers: { 'User-Agent': USER_AGENT, Accept: 'application/json' }, signal: controller.signal });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const results: unknown = await response.json();
        if (!Array.isArray(results)) return [];
        return (results as { lat?: unknown; lon?: unknown; place_rank?: unknown; display_name?: unknown }[])
            .map((result) => ({
                latitude: Number(result.lat),
                longitude: Number(result.lon),
                rank: Number(result.place_rank),
                name: typeof result.display_name === 'string' ? result.display_name : '',
            }))
            .filter((c) => Number.isFinite(c.latitude) && Number.isFinite(c.longitude)
                && c.latitude >= PHILIPPINES.south && c.latitude <= PHILIPPINES.north
                && c.longitude >= PHILIPPINES.west && c.longitude <= PHILIPPINES.east
                && c.rank >= 10 && c.rank <= 22);
    } finally {
        clearTimeout(timer);
        // Spaces every request, including the ones that fail.
        await sleep(SPACING_MS);
    }
}

/**
 * Where a town is, or null when OpenStreetMap does not know it. Throws if it
 * could not be asked.
 *
 *  1. The town in its province. The province is what tells one San Jose from
 *     the next, so a match has to name it.
 *  2. The town on its own, for cities OpenStreetMap does not file under a
 *     province (Baguio, Cebu City). Without the province a name can be
 *     shared, and a search only returns its first few matches, so one
 *     result is not proof there is one such town. A result counts only if
 *     its address names this town and the address's region, it is in or
 *     near that region, and it is the only one that passes. A San Juan in
 *     Metro Manila is never taken for the one in Batangas.
 *  3. Failing both, a district or barangay step 1 found in the right
 *     province: still inside the town, just not its centre.
 */
export async function lookUpPlace(place: Place): Promise<PlacePoint | null> {
    const { area, cities } = spellingsOf(place);
    const toPoint = ({ latitude, longitude }: Candidate): PlacePoint => ({ latitude, longitude });

    let insideTown: Candidate | undefined;
    for (const city of cities) {
        const found = (await search([city, area, 'Philippines'].filter(Boolean).join(', ')))
            .filter((candidate) => !area || fold(candidate.name).includes(fold(area)));
        const town = found.find(isTown);
        if (town) return toPoint(town);
        insideTown ??= found[0];
    }

    const centre = regionCentre(place.region);
    const regions = regionNames(place.region);
    const wantedLocalities = cities.map(fold);
    if (area && centre && regions.length > 0) {
        for (const city of cities) {
            const towns = (await search(`${city}, Philippines`)).filter((candidate) =>
                isTown(candidate)
                && wantedLocalities.includes(localityOf(candidate))
                && regions.some((region) => fold(candidate.name).includes(region))
                && kmBetween(centre, candidate) <= MAX_KM_FROM_REGION_CENTRE);
            if (towns.length === 1) return toPoint(towns[0]);
        }
    }

    return insideTown ? toPoint(insideTown) : null;
}

// A pass cut short (Nominatim or the database out of reach) is tried again
// by itself after these waits, one per failure in a row, then left to the
// next start, listing or address change.
const RETRY_DELAYS_MS = [60_000, 5 * 60_000, 15 * 60_000, 30 * 60_000, 60 * 60_000];

let running: Promise<void> | undefined;
let queuedAgain = false;
let retryTimer: NodeJS.Timeout | undefined;
let failuresInARow = 0;

// True when every unknown town was dealt with; false when the pass was cut
// short and towns are still waiting.
async function resolveUnknownPlaces(log: (line: string) => void): Promise<boolean> {
    const places = await PlaceModel.findUnresolved();
    for (const place of places) {
        try {
            const point = await lookUpPlace(place);
            await PlaceModel.save(place, point);
            log(`Place lookup: ${place.city}${place.province ? `, ${place.province}` : ''} ${point ? `is at ${point.latitude.toFixed(4)}, ${point.longitude.toFixed(4)}` : 'was not found'}`);
        } catch (error) {
            // Nominatim could not be reached, so the rest would fail the same way.
            log(`Place lookup: could not look up ${place.city} - ${error instanceof Error ? error.message : String(error)}`);
            return false;
        }
    }
    return true;
}

// One timer at most, and it only calls queuePlaceLookups, whose own guard
// keeps passes from overlapping.
function retryLater(log: (line: string) => void): void {
    if (retryTimer || failuresInARow >= RETRY_DELAYS_MS.length) return;
    const wait = RETRY_DELAYS_MS[failuresInARow];
    failuresInARow += 1;
    log(`Place lookup: trying again in ${Math.round(wait / 60_000)} min`);
    retryTimer = setTimeout(() => {
        retryTimer = undefined;
        queuePlaceLookups(log);
    }, wait);
    // Never the reason the process stays up.
    retryTimer.unref();
}

/**
 * Looks up, in the background, every town a listing needs that is not known
 * yet. Returns at once and never throws; call it whenever a listing or an
 * address may have brought in a new town. Calls made while a pass is running
 * fold into one more pass after it, and a pass that is cut short retries
 * itself a few times, further apart each time.
 */
export function queuePlaceLookups(log: (line: string) => void = console.log): void {
    if (!isEnabled()) return;
    if (running) {
        queuedAgain = true;
        return;
    }
    // This pass stands in for any retry that was waiting.
    clearTimeout(retryTimer);
    retryTimer = undefined;
    running = resolveUnknownPlaces(log)
        .catch((error) => {
            log(`Place lookup: failed - ${error instanceof Error ? error.message : String(error)}`);
            return false;
        })
        .then((finished) => {
            running = undefined;
            if (finished) failuresInARow = 0;
            if (queuedAgain) {
                queuedAgain = false;
                queuePlaceLookups(log);
            } else if (!finished) {
                retryLater(log);
            }
        });
}
