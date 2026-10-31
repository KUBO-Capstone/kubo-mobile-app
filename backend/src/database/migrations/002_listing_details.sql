-- =====================================================================
-- Kubo PostgreSQL schema (RDS)  -  v3: listing details
--
-- Produce details collected by the create listing form. Mirrors the
-- products columns in config/database.ts (SQLite).
--   * description, quality_grade, farming_method
--   * harvest_date + is_preorder: a pre-order lists a crop before it is
--     picked, so its harvest_date is the expected harvest and is required
--   * allows_meetup / allows_delivery: deal methods the seller accepts,
--     matching orders.delivery_method ('meetup' / 'courier')
-- =====================================================================

BEGIN;

ALTER TABLE products
    ADD COLUMN IF NOT EXISTS description     text        NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS quality_grade   varchar(20) NOT NULL DEFAULT 'standard'
                             CHECK (quality_grade IN ('premium', 'standard', 'imperfect')),
    ADD COLUMN IF NOT EXISTS farming_method  varchar(20) NOT NULL DEFAULT 'conventional'
                             CHECK (farming_method IN ('conventional', 'organic', 'pesticide-free')),
    ADD COLUMN IF NOT EXISTS harvest_date    date,
    ADD COLUMN IF NOT EXISTS is_preorder     boolean     NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS allows_meetup   boolean     NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS allows_delivery boolean     NOT NULL DEFAULT true;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'products_deal_method_check') THEN
        ALTER TABLE products ADD CONSTRAINT products_deal_method_check
            CHECK (allows_meetup OR allows_delivery);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'products_preorder_harvest_check') THEN
        ALTER TABLE products ADD CONSTRAINT products_preorder_harvest_check
            CHECK (NOT is_preorder OR harvest_date IS NOT NULL);
    END IF;
END $$;

COMMIT;
