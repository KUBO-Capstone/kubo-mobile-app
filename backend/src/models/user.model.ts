import { isRowId, pool, Queryable, withTransaction } from "#database/pg";
import { fromMediaColumn, toMediaColumn } from "#controllers/upload.controller";
import { hashPassword } from "#utils/password";

export type UserRole = 'farmer' | 'consumer' | 'admin';

export interface ProfilePrivacy {
    public_profile: boolean;
    show_bio: boolean;
    show_contact_number: boolean;
    show_location: boolean;
}

export interface User {
    user_id: number;
    first_name: string;
    last_name: string;
    email: string;
    password_hash: string;
    contact_number: string;
    location: string | null;
    business_name: string | null;
    business_type: string | null;
    // jsonb: node-postgres hands it over already parsed.
    profile_privacy: ProfilePrivacy;
    role: UserRole;
    preferred_address_id?: number | null;
    is_verified: boolean;
    profile_photo_url: string | null;
    bio: string;
    created_at: string;
}

export interface AddressInput {
    region: string;
    province: string;
    city_municipality: string;
    barangay: string;
    zip_code: string;
    street_details: string | null;
    landmark: string | null;
    latitude: number | null;
    longitude: number | null;
}

export interface Address extends AddressInput {
    address_id: number;
}

type NewUser = Omit<User, "user_id" | "created_at" | "is_verified" | "password_hash" | "role" | "profile_photo_url" | "bio" | "location" | "business_name" | "business_type" | "profile_privacy"> & {
    password: string;
    role?: UserRole;
};

// users.profile_photo_key holds the S3 object key; the API and the rest of
// the app work with the photo's stored URL.
const mapUser = ({ profile_photo_key, ...row }: Record<string, unknown>): User => ({
    ...row,
    profile_photo_url: typeof profile_photo_key === 'string' ? fromMediaColumn(profile_photo_key) : null,
} as User);

const insertAddress = `
    INSERT INTO addresses (region, province, city_municipality, barangay, zip_code, street_details, landmark, latitude, longitude)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
    RETURNING address_id
`;

const addressValues = (address: AddressInput): unknown[] => [
    address.region, address.province, address.city_municipality, address.barangay, address.zip_code,
    address.street_details, address.landmark, address.latitude, address.longitude,
];

export const UserModel = {
    // to select multiple row
    findAll: async (): Promise<User[]> => {
        const { rows } = await pool.query("SELECT * FROM users");
        return rows.map(mapUser);
    },

    // to find specific user by id
    findById: async (id: number, q: Queryable = pool): Promise<User | undefined> => {
        if (!isRowId(id)) return undefined;
        const { rows } = await q.query('SELECT * FROM users WHERE user_id = $1', [id]);
        return rows[0] ? mapUser(rows[0]) : undefined;
    },

    // Tokens live 7 days with no revocation, so auth must also reject accounts
    // deleted (anonymized) after the token was issued.
    isActive: async (id: number): Promise<boolean> => {
        if (!isRowId(id)) return false;
        const { rowCount } = await pool.query('SELECT 1 FROM users WHERE user_id = $1 AND deleted_at IS NULL', [id]);
        return (rowCount ?? 0) > 0;
    },

    // Matches uq_users_email_lower: emails are unique ignoring case.
    findByEmail: async (email: string): Promise<User | undefined> => {
        const { rows } = await pool.query('SELECT * FROM users WHERE lower(email) = lower($1)', [email]);
        return rows[0] ? mapUser(rows[0]) : undefined;
    },

    findProfile: async (userId: number) => {
        const user = await UserModel.findById(userId);
        if (!user) return undefined;
        const preferred = user.preferred_address_id;
        const { rows: addresses } = await pool.query<Address>(`
            SELECT DISTINCT
                a.address_id,
                a.region,
                a.province,
                a.city_municipality,
                a.barangay,
                a.zip_code,
                NULL AS street_details,
                NULL AS landmark,
                NULL AS latitude,
                NULL AS longitude
            FROM addresses a
            LEFT JOIN user_addresses ua ON ua.address_id = a.address_id
            WHERE ua.user_id = $1 OR a.address_id = $2
            ORDER BY a.address_id
        `, [userId, preferred ?? -1]);
        return { ...user, addresses };
    },

    updateProfile: async (userId: number, input: { first_name: string; last_name: string; contact_number: string; bio: string; location?: string; business_name?: string; business_type?: string; profile_privacy?: ProfilePrivacy }): Promise<User | undefined> => {
        await pool.query(`
            UPDATE users
            SET first_name = $2,
                last_name = $3,
                contact_number = $4,
                bio = $5,
                location = $6,
                business_name = $7,
                business_type = $8,
                profile_privacy = $9
            WHERE user_id = $1
        `, [userId, input.first_name, input.last_name, input.contact_number, input.bio,
            input.location, input.business_name, input.business_type, input.profile_privacy]);
        return UserModel.findById(userId);
    },

    setProfilePhoto: async (userId: number, profilePhotoUrl: string | null): Promise<User | undefined> => {
        await pool.query('UPDATE users SET profile_photo_key = $1 WHERE user_id = $2',
            [profilePhotoUrl === null ? null : toMediaColumn(profilePhotoUrl), userId]);
        return UserModel.findById(userId);
    },

    // to insert a new user; the plaintext password is hashed before storage.
    // profile_privacy takes the column default (everything visible).
    async create(user: NewUser, q: Queryable = pool): Promise<User> {
        const { first_name, last_name, email, password, contact_number } = user;
        const role: UserRole = user.role ?? 'consumer';
        const { rows } = await q.query(`
            INSERT INTO users (first_name, last_name, email, password_hash, contact_number, role, location, business_name, business_type)
            VALUES ($1, $2, $3, $4, $5, $6, '', '', '')
            RETURNING *
        `, [first_name, last_name, email, hashPassword(password), contact_number, role]);
        return mapUser(rows[0]);
    },

    createWithAddress(
        user: NewUser,
        address: Pick<AddressInput, 'region' | 'province' | 'city_municipality' | 'zip_code'>,
    ): Promise<User> {
        return withTransaction(async (client) => {
            const createdUser = await UserModel.create(user, client);
            const { rows: [{ address_id }] } = await client.query(`
                INSERT INTO addresses (region, province, city_municipality, barangay, zip_code)
                VALUES ($1, $2, $3, '', $4)
                RETURNING address_id
            `, [address.region, address.province, address.city_municipality, address.zip_code]);

            await client.query('INSERT INTO user_addresses (user_id, address_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
                [createdUser.user_id, address_id]);
            const { rows } = await client.query('UPDATE users SET preferred_address_id = $1 WHERE user_id = $2 RETURNING *',
                [address_id, createdUser.user_id]);
            return mapUser(rows[0]);
        });
    },

    // to delete a row
    delete: async (id: number): Promise<boolean> => {
        const { rowCount } = await pool.query('DELETE FROM users WHERE user_id = $1', [id]);
        return (rowCount ?? 0) > 0;
    },

    // Consumer-side pickup area. This is NOT a farm location: a farmer's farm
    // address lives in farmer_profiles.address_id.
    setPreferredAddress: (userId: string | number, addressData: AddressInput): Promise<number> => {
        return withTransaction(async (client) => {
            const { rows: [{ address_id }] } = await client.query(insertAddress, addressValues(addressData));
            await client.query('INSERT INTO user_addresses (user_id, address_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
                [userId, address_id]);
            await client.query('UPDATE users SET preferred_address_id = $1 WHERE user_id = $2', [address_id, userId]);
            return Number(address_id);
        });
    },

    updateAddress: async (userId: number, addressId: number, addressData: AddressInput): Promise<boolean> => {
        const { rowCount } = await pool.query(`
            UPDATE addresses
            SET region = $1, province = $2, city_municipality = $3,
                barangay = $4, zip_code = $5, street_details = $6,
                landmark = $7, latitude = $8, longitude = $9
            WHERE address_id = $10
              AND EXISTS (
                SELECT 1 FROM user_addresses
                WHERE user_id = $11 AND address_id = $10
              )
        `, [...addressValues(addressData), addressId, userId]);
        return (rowCount ?? 0) > 0;
    },

    choosePreferredAddress: async (userId: number, addressId: number): Promise<boolean> => {
        const { rowCount } = await pool.query(`
            UPDATE users SET preferred_address_id = $2
            WHERE user_id = $1
              AND EXISTS (SELECT 1 FROM user_addresses WHERE user_id = $1 AND address_id = $2)
        `, [userId, addressId]);
        return (rowCount ?? 0) > 0;
    },

    updatePassword: async (userId: number, password: string): Promise<boolean> => {
        const { rowCount } = await pool.query('UPDATE users SET password_hash = $1 WHERE user_id = $2',
            [hashPassword(password), userId]);
        return (rowCount ?? 0) > 0;
    },

    // Creates or moves a farmer's farm location and promotes them to the
    // farmer role, which is what the explore map plots.
    setFarmAddress: (userId: number, addressData: AddressInput): Promise<number> => {
        return withTransaction(async (client) => {
            const { rows: [{ address_id }] } = await client.query(insertAddress, addressValues(addressData));
            await client.query(`UPDATE users SET role = 'farmer' WHERE user_id = $1`, [userId]);
            await client.query(`
                INSERT INTO farmer_profiles (farmer_id, address_id) VALUES ($1, $2)
                ON CONFLICT (farmer_id) DO UPDATE SET address_id = EXCLUDED.address_id
            `, [userId, address_id]);
            return Number(address_id);
        });
    },
}
