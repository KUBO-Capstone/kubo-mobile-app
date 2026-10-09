import { db } from "#config/database";
import { hashPassword } from "#utils/password";

export type UserRole = 'farmer' | 'consumer' | 'admin';

export interface User {
    user_id: number;
    first_name: string;
    last_name: string;
    email: string;
    password_hash: string;
    contact_number: string;
    role: UserRole;
    preferred_address_id?: number | null;
    is_verified: boolean;
    profile_photo_url: string | null;
    bio: string;
    created_at: Date;
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

export const UserModel = {
    // to select multiple row
    findAll: (): User[] => {
        return db.prepare("SELECT * FROM users").all() as User[];
    },

    // to find specific user by id
    findById: (id: number): User | undefined => {
        const query = 'SELECT * FROM users WHERE user_id = ?';
        const stmt = db.prepare(query);
        return stmt.get(id) as User | undefined;
    },

    findByEmail: (email: string): User | undefined => {
        const query = 'SELECT * FROM users WHERE email = ?';
        return db.prepare(query).get(email) as User | undefined;
    },

    findProfile: (userId: number) => {
        const user = UserModel.findById(userId);
        if (!user) return undefined;
        const preferred = user.preferred_address_id;
        const addresses = db.prepare(`
            SELECT DISTINCT a.*
            FROM addresses a
            LEFT JOIN user_addresses ua ON ua.address_id = a.address_id
            WHERE ua.user_id = ? OR a.address_id = ?
            ORDER BY a.address_id
        `).all(userId, preferred ?? -1) as Address[];
        return { ...user, addresses };
    },

    updateProfile: (userId: number, input: { first_name: string; last_name: string; contact_number: string; bio: string }): User | undefined => {
        db.prepare(`
            UPDATE users
            SET first_name = @first_name,
                last_name = @last_name,
                contact_number = @contact_number,
                bio = @bio
            WHERE user_id = @user_id
        `).run({ ...input, user_id: userId });
        return UserModel.findById(userId);
    },

    setProfilePhoto: (userId: number, profilePhotoUrl: string | null): User | undefined => {
        db.prepare('UPDATE users SET profile_photo_url = ? WHERE user_id = ?').run(profilePhotoUrl, userId);
        return UserModel.findById(userId);
    },

    // to insert a new user; the plaintext password is hashed before storage
    create(
        user: Omit<User, "user_id" | "created_at" | "is_verified" | "password_hash" | "role" | "profile_photo_url" | "bio"> & {
            password: string;
            role?: UserRole;
        },
    ): User {
        const { first_name, last_name, email, password, contact_number } = user;
        const role: UserRole = user.role ?? 'consumer';
        const password_hash = hashPassword(password);
        const query = db.prepare(`
            INSERT INTO users (first_name, last_name, email, password_hash, contact_number, role)
            VALUES (?, ?, ?, ?, ?, ?)
        `)
        const info = query.run(first_name, last_name, email, password_hash, contact_number, role);
        return {
            user_id: info.lastInsertRowid as number,
            first_name,
            last_name,
            email,
            password_hash,
            contact_number,
            role,
            profile_photo_url: null,
            bio: '',
            created_at: new Date(),
            is_verified: false,
        };
    },

    createWithAddress(
        user: Omit<User, "user_id" | "created_at" | "is_verified" | "password_hash" | "role" | "profile_photo_url" | "bio"> & {
            password: string;
            role?: UserRole;
        },
        address: Pick<AddressInput, 'region' | 'province' | 'city_municipality' | 'zip_code'>,
    ): User {
        const createUserWithAddress = db.transaction(() => {
            const createdUser = UserModel.create(user);
            const addressInfo = db.prepare(`
                INSERT INTO addresses (region, province, city_municipality, barangay, zip_code)
                VALUES (@region, @province, @city_municipality, '', @zip_code)
            `).run(address);

            db.prepare('UPDATE users SET preferred_address_id = ? WHERE user_id = ?')
                .run(addressInfo.lastInsertRowid, createdUser.user_id);
            db.prepare('INSERT OR IGNORE INTO user_addresses (user_id, address_id) VALUES (?, ?)')
                .run(createdUser.user_id, addressInfo.lastInsertRowid);

            return createdUser;
        });

        return createUserWithAddress();
    },

    // to delete a row
    delete: (id: number): boolean => {
        const query = 'DELETE FROM users WHERE user_id = ?';
        const stmt = db.prepare(query);
        const result = stmt.run(id);
        return result.changes > 0;
    },

    // Consumer-side pickup area. This is NOT a farm location: a farmer's farm
    // address lives in farmer_profiles.address_id.
    setPreferredAddress: (userId: string | number, addressData: AddressInput) => {
        const insertQuery = db.prepare(`
            INSERT INTO addresses (region, province, city_municipality, barangay, zip_code, street_details, landmark, latitude, longitude)
            VALUES (@region, @province, @city_municipality, @barangay, @zip_code, @street_details, @landmark, @latitude, @longitude)
        `);
        const add = db.transaction(() => {
            const info = insertQuery.run(addressData);
            db.prepare('INSERT OR IGNORE INTO user_addresses (user_id, address_id) VALUES (?, ?)')
                .run(userId, info.lastInsertRowid);
            db.prepare('UPDATE users SET preferred_address_id = ? WHERE user_id = ?')
                .run(info.lastInsertRowid, userId);
            return Number(info.lastInsertRowid);
        });
        return add();
    },

    updateAddress: (userId: number, addressId: number, addressData: AddressInput): boolean => {
        const result = db.prepare(`
            UPDATE addresses
            SET region = @region, province = @province, city_municipality = @city_municipality,
                barangay = @barangay, zip_code = @zip_code, street_details = @street_details,
                landmark = @landmark, latitude = @latitude, longitude = @longitude
            WHERE address_id = @address_id
              AND EXISTS (
                SELECT 1 FROM user_addresses
                WHERE user_id = @user_id AND address_id = @address_id
              )
        `).run({ ...addressData, address_id: addressId, user_id: userId });
        return result.changes > 0;
    },

    choosePreferredAddress: (userId: number, addressId: number): boolean => {
        const owned = db.prepare(
            'SELECT 1 FROM user_addresses WHERE user_id = ? AND address_id = ?',
        ).get(userId, addressId);
        if (!owned) return false;
        return db.prepare('UPDATE users SET preferred_address_id = ? WHERE user_id = ?')
            .run(addressId, userId).changes > 0;
    },

    updatePassword: (userId: number, password: string): boolean => {
        return db.prepare('UPDATE users SET password_hash = ? WHERE user_id = ?')
            .run(hashPassword(password), userId).changes > 0;
    },

    // Creates or moves a farmer's farm location and promotes them to the
    // farmer role, which is what the explore map plots.
    setFarmAddress: (userId: number, addressData: AddressInput) => {
        const upsert = db.transaction(() => {
            const info = db.prepare(`
                INSERT INTO addresses (region, province, city_municipality, barangay, zip_code, street_details, landmark, latitude, longitude)
                VALUES (@region, @province, @city_municipality, @barangay, @zip_code, @street_details, @landmark, @latitude, @longitude)
            `).run(addressData);
            const addressId = Number(info.lastInsertRowid);

            db.prepare(`UPDATE users SET role = 'farmer' WHERE user_id = ?`).run(userId);

            const existing = db.prepare(`SELECT farmer_id FROM farmer_profiles WHERE farmer_id = ?`).get(userId);
            if (existing) {
                db.prepare(`UPDATE farmer_profiles SET address_id = ? WHERE farmer_id = ?`).run(addressId, userId);
            } else {
                db.prepare(`INSERT INTO farmer_profiles (farmer_id, address_id) VALUES (?, ?)`).run(userId, addressId);
            }
            return addressId;
        });
        return upsert();
    },
}
