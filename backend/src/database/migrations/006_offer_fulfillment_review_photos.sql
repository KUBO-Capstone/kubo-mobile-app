-- =====================================================================
-- Kubo PostgreSQL schema  -  v7: fulfillment agreed with the offer,
-- decline reasons, review photos, deal closed on receipt
--
--   * negotiations.delivery_method / drop_off_center_id / courier_name:
--     how the produce changes hands is part of the offer now, agreed with
--     the price and quantity. Accepting an offer creates the order from
--     these terms straight away; there is no separate "arrange pickup"
--     step. Offers from before this migration have no method and keep the
--     old flow (accepted, then the buyer places the order).
--   * negotiations.decline_reason: why an offer was turned down, picked
--     from a short list, so the buyer knows what to change.
--   * seller_bagsakan_centers / seller_couriers: the drop-off centers and
--     couriers a seller can work with. A seller with no rows in a table
--     has not narrowed it down, and buyers may pick any.
--   * reviews.photos: up to five photos with a review, as S3 keys.
--   * The "deal closed" screen now shows when the buyer confirms receipt
--     rather than when the offer is accepted. Deals whose order has not
--     been received yet have their celebrated-at marks cleared so both
--     sides still see the screen at that point.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- Offer terms: how the produce changes hands
-- ---------------------------------------------------------------------
ALTER TABLE negotiations
    ADD COLUMN IF NOT EXISTS delivery_method    varchar(20)
        CHECK (delivery_method IS NULL OR delivery_method IN ('courier', 'meetup')),
    ADD COLUMN IF NOT EXISTS drop_off_center_id integer REFERENCES bagsakan_centers (center_id) ON DELETE RESTRICT,
    ADD COLUMN IF NOT EXISTS courier_name       varchar(100),
    ADD COLUMN IF NOT EXISTS decline_reason     varchar(40)
        CHECK (decline_reason IS NULL OR decline_reason IN ('bagsakan_too_far', 'courier_unavailable', 'price_too_low'));

CREATE INDEX IF NOT EXISTS idx_negotiations_drop_off_center ON negotiations (drop_off_center_id);

-- ---------------------------------------------------------------------
-- What a seller can work with
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS seller_bagsakan_centers (
    seller_id integer NOT NULL,
    center_id integer NOT NULL,

    PRIMARY KEY (seller_id, center_id),
    FOREIGN KEY (seller_id) REFERENCES users (user_id)            ON DELETE CASCADE,
    FOREIGN KEY (center_id) REFERENCES bagsakan_centers (center_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS seller_couriers (
    seller_id integer      NOT NULL,
    courier   varchar(100) NOT NULL,

    PRIMARY KEY (seller_id, courier),
    FOREIGN KEY (seller_id) REFERENCES users (user_id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------
-- Review photos
-- ---------------------------------------------------------------------
ALTER TABLE reviews
    ADD COLUMN IF NOT EXISTS photos jsonb NOT NULL DEFAULT '[]'::jsonb;

-- ---------------------------------------------------------------------
-- The deal closes on receipt, not on acceptance
-- Safe to run again: it only touches deals that are still open, which
-- under the new rule have nothing to have celebrated yet.
-- ---------------------------------------------------------------------
UPDATE negotiations n
SET buyer_celebrated_at = NULL, seller_celebrated_at = NULL
WHERE (n.buyer_celebrated_at IS NOT NULL OR n.seller_celebrated_at IS NOT NULL)
  AND NOT EXISTS (
      SELECT 1 FROM orders o
      WHERE o.negotiation_id = n.negotiation_id AND o.order_status = 'delivered'
  );

COMMIT;
