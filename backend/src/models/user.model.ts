import { db } from "#config/database";

export interface User {
    user_id: number;
    first_name: string;
    last_name: string;
    email: string;
    password: string;
    contact_number: string;
    is_verified: boolean;
    created_at: Date;
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

    // to insert a new user
    create(user: Omit<User, "user_id" | "created_at" | "is_verified">): User {
        const { first_name, last_name, email, password, contact_number } = user;
        const query = db.prepare(`
            INSERT INTO users (first_name, last_name, email, password, contact_number)
            VALUES (?, ?, ?, ?, ?)
        `)
        const info = query.run(first_name, last_name, email, password, contact_number);
        return { user_id: info.lastInsertRowid as number, ...user, created_at: new Date(), is_verified: false };
    },

    // to delete a row
    delete: (id: number): boolean => {
        const query = 'DELETE FROM users WHERE user_id = ?';
        const stmt = db.prepare(query);
        const result = stmt.run(id);
        return result.changes > 0;
    }
}