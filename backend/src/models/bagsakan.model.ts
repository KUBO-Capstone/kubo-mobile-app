import { db } from "#config/database";

export interface BagsakanCenter {
    center_id: number;
    location_name: string;
    location_label: string;
    region_label: string;
    address_line: string;
    latitude: number | null;
    longitude: number | null;
}

const centerQuery = `
    SELECT c.center_id,
           c.location_name,
           COALESCE(a.city_municipality, 'Philippines') AS location_label,
           COALESCE(a.region, 'NCR') AS region_label,
           TRIM(COALESCE(a.street_details || ', ', '') || COALESCE(a.barangay, '')) AS address_line,
           a.latitude AS latitude,
           a.longitude AS longitude
    FROM bagsakan_centers c
    LEFT JOIN addresses a ON a.address_id = c.address_id
`;

function mapCenter(row: Record<string, unknown>): BagsakanCenter {
    return {
        center_id: Number(row.center_id),
        location_name: String(row.location_name),
        location_label: String(row.location_label),
        region_label: String(row.region_label),
        address_line: String(row.address_line ?? ''),
        latitude: row.latitude === null || row.latitude === undefined ? null : Number(row.latitude),
        longitude: row.longitude === null || row.longitude === undefined ? null : Number(row.longitude),
    };
}

export const BagsakanModel = {
    findAll(query = ''): BagsakanCenter[] {
        const normalizedQuery = query.trim().toLowerCase();
        const where = normalizedQuery
            ? `WHERE LOWER(c.location_name) LIKE @query OR LOWER(a.city_municipality) LIKE @query`
            : '';
        const rows = db.prepare(`${centerQuery} ${where} ORDER BY c.location_name`).all({
            query: `%${normalizedQuery}%`,
        }) as Record<string, unknown>[];
        return rows.map(mapCenter);
    },
};
