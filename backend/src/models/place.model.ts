import { pool } from "#database/pg";
import { sellerPlaceJoins } from "#models/product.model";

// Town-level points for the listing map (place_coordinates in
// database/migrations/005). services/geocoding.service.ts fills the table;
// the listing query in product.model.ts reads it.

/** A city or municipality as an address row names it. */
export interface Place {
    city: string;
    province: string;
    region: string;
}

export interface PlacePoint {
    latitude: number;
    longitude: number;
}

// How long a town OpenStreetMap could not find is left alone before it is
// asked for again (its map data, or the spelling in the address, may change).
const RETRY_MISSES_AFTER_DAYS = 30;

export const PlaceModel = {
    // The towns of sellers with a listing up that have not been looked up
    // yet, or whose last lookup found nothing a while ago.
    async findUnresolved(): Promise<Place[]> {
        const { rows } = await pool.query<Place>(`
            SELECT DISTINCT ON (lower(btrim(a.city_municipality)), lower(btrim(a.province)))
                   btrim(a.city_municipality) AS city,
                   btrim(a.province) AS province,
                   btrim(a.region) AS region
            FROM products p
            JOIN users u ON u.user_id = p.seller_id
            ${sellerPlaceJoins}
            WHERE p.status <> 'delisted'
              AND btrim(a.city_municipality) <> ''
              AND (pc.city IS NULL
                   OR (pc.latitude IS NULL AND pc.looked_up_at < now() - make_interval(days => $1)))
        `, [RETRY_MISSES_AFTER_DAYS]);
        return rows;
    },

    // Records a finished lookup. A null point is a miss: it is kept so the
    // town is not asked for again on every start.
    async save(place: Place, point: PlacePoint | null): Promise<void> {
        await pool.query(`
            INSERT INTO place_coordinates (city, province, latitude, longitude)
            VALUES (lower(btrim($1)), lower(btrim($2)), $3, $4)
            ON CONFLICT (city, province) DO UPDATE
            SET latitude = EXCLUDED.latitude, longitude = EXCLUDED.longitude, looked_up_at = now()
        `, [place.city, place.province, point?.latitude ?? null, point?.longitude ?? null]);
    },
};
