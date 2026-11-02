import { isRowId, pool } from "#database/pg";

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
    async findAll(query = ''): Promise<BagsakanCenter[]> {
        const normalizedQuery = query.trim().toLowerCase();
        const { rows } = normalizedQuery
            ? await pool.query(`${centerQuery} WHERE LOWER(c.location_name) LIKE $1 OR LOWER(a.city_municipality) LIKE $1 ORDER BY c.location_name`,
                [`%${normalizedQuery}%`])
            : await pool.query(`${centerQuery} ORDER BY c.location_name`);
        return rows.map(mapCenter);
    },

    async findById(centerId: number): Promise<BagsakanCenter | undefined> {
        if (!isRowId(centerId)) return undefined;
        const { rows } = await pool.query(`${centerQuery} WHERE c.center_id = $1`, [centerId]);
        return rows[0] ? mapCenter(rows[0]) : undefined;
    },
};
