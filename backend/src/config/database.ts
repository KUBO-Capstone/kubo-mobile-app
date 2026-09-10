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
            password TEXT NOT NULL,
            contact_number VARCHAR(15) NOT NULL,
            preferred_address_id INTEGER,
            is_verified BOOLEAN DEFAULT FALSE,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

            FOREIGN KEY (preferred_address_id) REFERENCES addresses(address_id) ON DELETE SET NULL
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
            drop_off_center_id INTEGER NOT NULL,
            total_amount REAL NOT NULL,
            order_status VARCHAR(20) DEFAULT 'pending' CHECK (order_status IN ('pending', 'in transit', 'completed', 'cancelled')),
            delivery_method VARCHAR(20) NOT NULL CHECK (delivery_method IN ('pickup', 'delivery')),
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
            review_date DATETIME DEFAULT CURRENT_TIMESTAMP,

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
            unit_of_measure VARCHAR(20) NOT NULL CHECK (unit_of_measure IN ('kg', 'g', 'lb', 'oz', 'liter', 'ml', 'piece')),
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
            last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,

            FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS conversations (
            conversation_id INTEGER PRIMARY KEY AUTOINCREMENT,
            user1_id INTEGER NOT NULL,
            user2_id INTEGER NOT NULL,
            product_id INTEGER, 
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

            FOREIGN KEY (user1_id) REFERENCES users(user_id) ON DELETE CASCADE,
            FOREIGN KEY (user2_id) REFERENCES users(user_id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS messages (
            message_id INTEGER PRIMARY KEY AUTOINCREMENT,
            conversation_id INTEGER NOT NULL,
            sender_id INTEGER NOT NULL,
            message_text TEXT NOT NULL,
            sent_at DATETIME DEFAULT CURRENT_TIMESTAMP,

            FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id) ON DELETE CASCADE,
            FOREIGN KEY (sender_id) REFERENCES users(user_id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS negotiations (
            negotiation_id INTEGER PRIMARY KEY AUTOINCREMENT,
            conversation_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            buyer_id INTEGER NOT NULL,
            seller_id INTEGER NOT NULL,
            offered_price REAL NOT NULL,
            status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'countered', 'accepted', 'rejected')),
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

            FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
            FOREIGN KEY (buyer_id) REFERENCES users(user_id) ON DELETE CASCADE,
            FOREIGN KEY (seller_id) REFERENCES users(user_id) ON DELETE CASCADE
        );

    `);
    console.log('Database tables created')
}

initDb();

