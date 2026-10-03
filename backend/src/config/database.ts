import Database from 'better-sqlite3';
import fs from 'fs';
import path from 'path';

const dbPath = path.resolve(__dirname, '../database/db.sqlite');
fs.mkdirSync(path.dirname(dbPath), { recursive: true });
export const db = new Database(dbPath, { verbose: console.log });

// enable foreign key constraints (off by default)
db.pragma('foreign_keys = ON');

function migrateLegacySchema(): void {
    const messageColumns = new Set(
        (db.pragma('table_info(messages)') as { name: string }[]).map((column) => column.name),
    );
    const messageAlterations = [
        !messageColumns.has('message_type')
            ? "ALTER TABLE messages ADD COLUMN message_type VARCHAR(20) NOT NULL DEFAULT 'text'"
            : null,
        !messageColumns.has('negotiation_id')
            ? 'ALTER TABLE messages ADD COLUMN negotiation_id INTEGER'
            : null,
        !messageColumns.has('order_id')
            ? 'ALTER TABLE messages ADD COLUMN order_id INTEGER'
            : null,
        !messageColumns.has('offer_price')
            ? 'ALTER TABLE messages ADD COLUMN offer_price REAL'
            : null,
        !messageColumns.has('offer_quantity')
            ? 'ALTER TABLE messages ADD COLUMN offer_quantity REAL'
            : null,
        !messageColumns.has('read_at')
            ? 'ALTER TABLE messages ADD COLUMN read_at DATETIME'
            : null,
    ];
    for (const statement of messageAlterations) {
        if (statement) db.exec(statement);
    }

    const notificationColumns = db.pragma('table_info(notifications)') as { name: string; notnull: number }[];
    const senderColumn = notificationColumns.find((column) => column.name === 'sender_id');
    if (senderColumn?.notnull) {
        db.exec(`
            ALTER TABLE notifications RENAME TO notifications_legacy;
            CREATE TABLE notifications (
                notification_id INTEGER PRIMARY KEY AUTOINCREMENT,
                recipient_id INTEGER NOT NULL,
                sender_id INTEGER,
                product_id INTEGER,
                title TEXT NOT NULL,
                message TEXT NOT NULL,
                is_read BOOLEAN DEFAULT FALSE,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (recipient_id) REFERENCES users(user_id) ON DELETE CASCADE,
                FOREIGN KEY (sender_id) REFERENCES users(user_id) ON DELETE SET NULL,
                FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE SET NULL
            );
            INSERT INTO notifications (notification_id, recipient_id, sender_id, product_id, title, message, is_read, created_at)
            SELECT notification_id, recipient_id, sender_id, product_id, title, message, is_read, created_at
            FROM notifications_legacy;
            DROP TABLE notifications_legacy;
        `);
    }

    for (const statement of [
        'ALTER TABLE users ADD COLUMN profile_photo_url TEXT',
        "ALTER TABLE users ADD COLUMN bio TEXT NOT NULL DEFAULT ''",
    ]) {
        try {
            db.exec(statement);
        } catch (error) {
            if (!(error instanceof Error) || !error.message.includes('duplicate column name')) {
                throw error;
            }
        }
    }
}

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
            profile_photo_url TEXT,
            bio TEXT NOT NULL DEFAULT '',
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
            negotiation_id INTEGER NOT NULL UNIQUE,
            buyer_id INTEGER NOT NULL,
            seller_id INTEGER NOT NULL,
            drop_off_center_id INTEGER,
            total_amount REAL NOT NULL,
            order_status VARCHAR(20) DEFAULT 'pending' CHECK (order_status IN ('pending', 'in transit', 'delivered', 'cancelled')),
            delivery_method VARCHAR(20) NOT NULL CHECK (delivery_method IN ('courier', 'meetup')),
            order_date DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,

            FOREIGN KEY (negotiation_id) REFERENCES negotiations(negotiation_id) ON DELETE CASCADE,
            FOREIGN KEY (buyer_id) REFERENCES users(user_id) ON DELETE CASCADE,
            FOREIGN KEY (seller_id) REFERENCES users(user_id) ON DELETE CASCADE,
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
            message_type VARCHAR(20) NOT NULL DEFAULT 'text' CHECK (message_type IN ('text', 'offer', 'counter', 'accepted', 'declined', 'order')),
            negotiation_id INTEGER,
            order_id INTEGER,
            offer_price REAL,
            offer_quantity REAL,
            read_at DATETIME,
            sent_at DATETIME DEFAULT CURRENT_TIMESTAMP,

            FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id) ON DELETE CASCADE,
            FOREIGN KEY (sender_id) REFERENCES users(user_id) ON DELETE CASCADE,
            FOREIGN KEY (negotiation_id) REFERENCES negotiations(negotiation_id) ON DELETE SET NULL,
            FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE SET NULL
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

        -- Market Watch: reference prices per area, independent of Kubo listings.
        -- Rows come from two writers: scripts/seed-market.ts (demo fallback,
        -- source = 'seed') and market/market-import.ts, which scrapes DA Bantay
        -- Presyo daily (source = 'da-bantay-presyo'). external_key ties a product
        -- to its DA commodity ('da:<category>:<commodity>') so re-imports find
        -- the same row; seed products that DA also covers carry the same key.
        CREATE TABLE IF NOT EXISTS market_products (
            market_product_id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR(100) UNIQUE NOT NULL,
            classification VARCHAR(30) NOT NULL CHECK (classification IN ('Food Products', 'Fiber Products', 'Fuel Products', 'Raw Materials')),
            product_groups TEXT NOT NULL,
            unit_measurement VARCHAR(20) NOT NULL CHECK (unit_measurement IN ('kg', 'g', 'lb', 'oz', 'liter', 'ml', 'piece')),
            dti_srp REAL,
            crop_keywords TEXT NOT NULL,
            external_key VARCHAR(100) UNIQUE
        );
        -- Two kinds of row share this table (area_type):
        --   'region' - one per product x region x day: avg / lowest / highest
        --              across that region's markets, sample_size = market count,
        --              province_city = '' and lat/lng = the region's centroid.
        --              This is the history the trend arrows compare.
        --   'market' - one per product x market for the LATEST day only (the
        --              importer deletes older market rows): province_city is
        --              the market name, lat/lng from market/market-areas.ts
        --              when known. These are the map pins.
        CREATE TABLE IF NOT EXISTS market_prices (
            market_price_id INTEGER PRIMARY KEY AUTOINCREMENT,
            market_product_id INTEGER NOT NULL,
            region VARCHAR(50) NOT NULL,
            region_name VARCHAR(100) NOT NULL,
            area_type VARCHAR(10) NOT NULL DEFAULT 'market' CHECK (area_type IN ('region', 'market')),
            province_city VARCHAR(100) NOT NULL,
            latitude REAL,
            longitude REAL,
            avg_price REAL NOT NULL,
            lowest_price REAL NOT NULL,
            highest_price REAL NOT NULL,
            sample_size INTEGER NOT NULL DEFAULT 1,
            recorded_at DATE NOT NULL,
            source VARCHAR(50) NOT NULL DEFAULT 'seed',

            FOREIGN KEY (market_product_id) REFERENCES market_products(market_product_id) ON DELETE CASCADE,
            UNIQUE (market_product_id, region, province_city, recorded_at)
        );
        CREATE INDEX IF NOT EXISTS idx_market_prices_product_date ON market_prices (market_product_id, recorded_at);

        -- A buyer's saved (hearted) listings. One row per user x product. The
        -- product row is never hard-deleted (see products.status), so a saved
        -- listing that gets delisted is simply filtered out of the list query.
        CREATE TABLE IF NOT EXISTS saved_listings (
            saved_id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            saved_at DATETIME DEFAULT CURRENT_TIMESTAMP,

            FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
            UNIQUE (user_id, product_id)
        );

        CREATE TABLE IF NOT EXISTS notifications (
            notification_id INTEGER PRIMARY KEY AUTOINCREMENT,

            -- the recipient: owner of the notification feed
            recipient_id INTEGER NOT NULL,
            
            -- the sender: user who triggered the notification
            sender_id INTEGER,

            product_id INTEGER,
            title TEXT NOT NULL,
            message TEXT NOT NULL,
            is_read BOOLEAN DEFAULT FALSE,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

            FOREIGN KEY (recipient_id) REFERENCES users(user_id) ON DELETE CASCADE,
            FOREIGN KEY (sender_id) REFERENCES users(user_id) ON DELETE SET NULL,
            FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE SET NULL
        );

    `);
    migrateLegacySchema();
    console.log('Database tables created')
}

initDb();
