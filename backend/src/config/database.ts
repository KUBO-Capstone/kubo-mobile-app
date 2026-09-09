import Database from 'better-sqlite3';
import path from 'path';

const dbPath = path.resolve(__dirname, '../database/db.sqlite');
export const db = new Database(dbPath, { verbose: console.log });

// enable foreign key constraints (off by default)
db.pragma('foreign_keys = ON');

export function initDb(): void {
    // add later preferred_address_id INTEGER FOREIGN KEY REFERENCES address()
    db.exec(`
        CREATE TABLE IF NOT EXISTS users (
            user_id INTEGER PRIMARY KEY AUTOINCREMENT,
            first_name VARCHAR(50) NOT NULL, 
            last_name VARCHAR(50) NOT NULL, 
            email VARCHARR(100) UNIQUE NOT NULL,
            password TEXT NOT NULL,
            contact_number VARCHAR(15) NOT NULL,
            is_verified BOOLEAN DEFAULT FALSE,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
    `);
    console.log('Database tables created')
}

initDb();

