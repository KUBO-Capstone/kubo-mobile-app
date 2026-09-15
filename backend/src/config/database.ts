import Database from 'better-sqlite3';
import path from 'path';

const dbPath = path.resolve(__dirname, '../database/db.sqlite');
export const db = new Database(dbPath, { verbose: console.log });

// enable foreign key constraints (off by default)
db.pragma('foreign_keys = ON');

export function initDb(): void {

    db.exec(`

        CREATE TABLE IF NOT EXISTS addresses (
            address_id INTEGER PRIMARY KEY AUTOINCREMENT,
            region VARCHAR(100) NOT NULL,
            province VARCHAR(100) NOT NULL,
            city_municipality VARCHAR(100) NOT NULL,
            barangay VARCHAR(100) NOT NULL,
            zip_code VARCHAR(4) NOT NULL,
            street_details VARCHAR(255),
            landmark VARCHAR(255),
            latitude REAL,
            longitude REAL
        );

        CREATE TABLE IF NOT EXISTS users (
            user_id INTEGER PRIMARY KEY AUTOINCREMENT,
            first_name VARCHAR(50) NOT NULL,
            last_name VARCHAR(50) NOT NULL,
            email VARCHAR(100) UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            contact_number VARCHAR(15) NOT NULL,
            role VARCHAR(20) NOT NULL DEFAULT 'consumer' CHECK (role IN ('farmer', 'consumer', 'admin')),
            preferred_address_id INTEGER,
            is_verified BOOLEAN DEFAULT FALSE,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

            FOREIGN KEY (preferred_address_id) REFERENCES addresses(address_id) ON DELETE SET NULL
        );

        -- Farm location and vetting state for users whose role is 'farmer'.
        -- Distinct from users.preferred_address_id, which is the consumer-side
        -- pickup area and must not be used as a farm location.
        CREATE TABLE IF NOT EXISTS farmer_profiles (
            farmer_id INTEGER PRIMARY KEY,
            address_id INTEGER NOT NULL UNIQUE,
            verification_status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (verification_status IN ('pending', 'verified', 'rejected')),

            FOREIGN KEY (farmer_id) REFERENCES users(user_id) ON DELETE CASCADE,
            FOREIGN KEY (address_id) REFERENCES addresses(address_id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS bagsakan_centers (
            center_id INTEGER PRIMARY KEY AUTOINCREMENT,
            address_id INTEGER NOT NULL,
            location_name VARCHAR(100) NOT NULL,

            FOREIGN KEY (address_id) REFERENCES addresses(address_id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS orders (
            order_id INTEGER PRIMARY KEY AUTOINCREMENT,
            buyer_id INTEGER NOT NULL,
            drop_off_center_id INTEGER,
            total_amount REAL NOT NULL,
            order_status VARCHAR(20) DEFAULT 'pending' CHECK (order_status IN ('pending', 'in transit', 'delivered', 'cancelled')),
            delivery_method VARCHAR(20) NOT NULL CHECK (delivery_method IN ('courier', 'meetup')),
            order_date DATETIME DEFAULT CURRENT_TIMESTAMP,

            FOREIGN KEY (buyer_id) REFERENCES users(user_id) ON DELETE CASCADE,
            FOREIGN KEY (drop_off_center_id) REFERENCES bagsakan_centers(center_id)
        );

        CREATE TABLE IF NOT EXISTS reviews (
            review_id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER NOT NULL,
            reviewer_id INTEGER NOT NULL,
            reviewee_id INTEGER NOT NULL,
            rating INTEGER CHECK(rating >= 1 AND rating <= 5),
            comment TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

            FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
            FOREIGN KEY (reviewer_id) REFERENCES users(user_id) ON DELETE CASCADE,
            FOREIGN KEY (reviewee_id) REFERENCES users(user_id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS products (
            product_id INTEGER PRIMARY KEY AUTOINCREMENT,
            seller_id INTEGER NOT NULL,
            crop_name VARCHAR(100) NOT NULL,
            category VARCHAR(20) NOT NULL CHECK (category IN ('vegetable', 'fruit', 'grain', 'legume', 'herb', 'spice')),
            base_price REAL NOT NULL,
            available_quantity REAL NOT NULL,
            unit_measurement VARCHAR(20) NOT NULL CHECK (unit_measurement IN ('kg', 'g', 'lb', 'oz', 'liter', 'ml', 'piece')),
            status VARCHAR(20) DEFAULT 'available' CHECK (status IN ('available', 'out of stock', 'delisted')),
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,

            FOREIGN KEY (seller_id) REFERENCES users(user_id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS product_images (
            image_id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id INTEGER NOT NULL,
            image_url TEXT NOT NULL,
            display_order INTEGER NOT NULL,

            FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS order_items (
            order_item_id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            quantity REAL NOT NULL,
            negotiated_price REAL NOT NULL,

            FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS courier_tracking (
            tracking_id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER NOT NULL,
            courier_name VARCHAR(100) NOT NULL,
            tracking_number VARCHAR(100) NOT NULL,
            status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'in transit', 'delivered', 'failed')),
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,

            FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS conversations (
            conversation_id INTEGER PRIMARY KEY AUTOINCREMENT,
            buyer_id INTEGER NOT NULL,
            seller_id INTEGER NOT NULL,
            product_id INTEGER,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

            FOREIGN KEY (buyer_id) REFERENCES users(user_id) ON DELETE CASCADE,
            FOREIGN KEY (seller_id) REFERENCES users(user_id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS messages (
            message_id INTEGER PRIMARY KEY AUTOINCREMENT,
            conversation_id INTEGER NOT NULL,
            sender_id INTEGER NOT NULL,
            content TEXT NOT NULL,
            message_type VARCHAR(20) NOT NULL DEFAULT 'text' CHECK (message_type IN ('text', 'offer', 'counter', 'accepted', 'declined')),
            negotiation_id INTEGER,
            offer_price REAL,
            offer_quantity REAL,
            read_at DATETIME,
            sent_at DATETIME DEFAULT CURRENT_TIMESTAMP,

            FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id) ON DELETE CASCADE,
            FOREIGN KEY (sender_id) REFERENCES users(user_id) ON DELETE CASCADE,
            FOREIGN KEY (negotiation_id) REFERENCES negotiations(negotiation_id) ON DELETE SET NULL
        );

        CREATE TABLE IF NOT EXISTS negotiations (
            negotiation_id INTEGER PRIMARY KEY AUTOINCREMENT,
            conversation_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            buyer_id INTEGER NOT NULL,
            seller_id INTEGER NOT NULL,
            offered_price REAL NOT NULL,
            offered_quantity REAL NOT NULL,
            status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'countered', 'accepted', 'declined')),
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

            FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
            FOREIGN KEY (buyer_id) REFERENCES users(user_id) ON DELETE CASCADE,
            FOREIGN KEY (seller_id) REFERENCES users(user_id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS system_logs (
            log_id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            action_type VARCHAR(100) NOT NULL,
            description TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

            FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL
        );

    `);
    console.log('Database tables created')
}

initDb();
