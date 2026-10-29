-- =====================================================================
-- Kubo PostgreSQL schema (RDS)  -  v4: ratings, reviews, closed deals
--
-- Mirrors config/database.ts (SQLite).
--   * reviews.tags: quick tags picked with a rating (keys from
--     models/review.model.ts). reviews already has UNIQUE (order_id,
--     reviewer_id) from 001.
--   * negotiations.accepted_by: who tapped Accept (seller on an offer,
--     buyer on a counter)
--   * negotiations.buyer_celebrated_at / seller_celebrated_at: when each
--     side saw the "deal closed" screen, so it shows once per person.
--     Deals accepted before this migration are marked as already seen.
-- =====================================================================

BEGIN;

ALTER TABLE reviews
    ADD COLUMN IF NOT EXISTS tags jsonb NOT NULL DEFAULT '[]'::jsonb;

CREATE INDEX IF NOT EXISTS idx_reviews_reviewee ON reviews (reviewee_id);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'negotiations' AND column_name = 'buyer_celebrated_at'
    ) THEN
        ALTER TABLE negotiations
            ADD COLUMN IF NOT EXISTS accepted_by integer REFERENCES users (user_id) ON DELETE SET NULL,
            ADD COLUMN buyer_celebrated_at  timestamptz,
            ADD COLUMN seller_celebrated_at timestamptz;
        UPDATE negotiations
            SET buyer_celebrated_at = now(), seller_celebrated_at = now()
            WHERE status = 'accepted';
    END IF;
END $$;

COMMIT;
