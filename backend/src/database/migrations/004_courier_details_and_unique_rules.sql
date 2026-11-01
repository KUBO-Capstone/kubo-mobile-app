-- =====================================================================
-- Kubo PostgreSQL schema (RDS)  -  v5: what the app needs on Postgres
--
-- The backend moved from SQLite to this schema.
--   * orders.courier_name / orders.tracking_number: optional details the
--     seller can add when handing a courier order over. There is no
--     courier_tracking table (see 001); a seller can just as well send the
--     courier's tracking link or details in the order's conversation.
--   * One conversation per buyer x seller x listing, and at most one open
--     offer per buyer x listing. SQLite ran one request at a time, so the
--     app's "find it, else create it" checks were enough; on Postgres two
--     requests can pass the check together, and these indexes stop the
--     second one.
-- =====================================================================

BEGIN;

ALTER TABLE orders ADD COLUMN IF NOT EXISTS courier_name    varchar(100);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS tracking_number varchar(100);

CREATE UNIQUE INDEX IF NOT EXISTS uq_conversations_thread
    ON conversations (buyer_id, seller_id, product_id);

CREATE UNIQUE INDEX IF NOT EXISTS uq_negotiations_open_offer
    ON negotiations (buyer_id, product_id) WHERE status IN ('pending', 'countered');

COMMIT;
