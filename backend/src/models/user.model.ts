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
    location: string | null;
    business_name: string | null;
    business_type: string | null;
    profile_privacy: string;
    role: UserRole;
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

    updateProfile: (userId: number, input: { first_name: string; last_name: string; contact_number: string; bio: string; location?: string; business_name?: string; business_type?: string; profile_privacy?: string }): User | undefined => {
        db.prepare(`
            UPDATE users
            SET first_name = @first_name,
                last_name = @last_name,
                contact_number = @contact_number,
                bio = @bio,
                location = @location,
                business_name = @business_name,
                business_type = @business_type,
                profile_privacy = @profile_privacy
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
        user: Omit<User, "user_id" | "created_at" | "is_verified" | "password_hash" | "role" | "profile_photo_url" | "bio" | "location" | "business_name" | "business_type" | "profile_privacy"> & {
            password: string;
            role?: UserRole;
        },
    ): User {
        const { first_name, last_name, email, password, contact_number } = user;
        const role: UserRole = user.role ?? 'consumer';
        const password_hash = hashPassword(password);
        const defaultPrivacy = JSON.stringify({
            public_profile: true,
            show_bio: true,
            show_contact_number: true,
            show_location: true,
        });
        const query = db.prepare(`
            INSERT INTO users (first_name, last_name, email, password_hash, contact_number, role, location, business_name, business_type, profile_privacy)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `)
        const info = query.run(first_name, last_name, email, password_hash, contact_number, role, '', '', '', defaultPrivacy);
        return {
            user_id: info.lastInsertRowid as number,
            first_name,
            last_name,
            email,
            password_hash,
            contact_number,
            location: '',
            business_name: '',
            business_type: '',
            profile_privacy: defaultPrivacy,
            role,
            profile_photo_url: null,
            bio: '',
            created_at: new Date(),
            is_verified: false,
        };
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
        const info = insertQuery.run(addressData);

        const updateUserQuery = db.prepare(`UPDATE users SET preferred_address_id = ? WHERE user_id = ?`);
        updateUserQuery.run(info.lastInsertRowid, userId);

        return info.lastInsertRowid;
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
