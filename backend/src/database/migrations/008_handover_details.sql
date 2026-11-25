-- What the seller records when the produce leaves their hands: optional
-- photos of it as handed over (to the courier, or at the bagsakan center),
-- and when that was. Both sides see them on the order.
--   * orders.handover_photos: object keys under handovers/, like
--     reviews.photos. Empty when the seller added none.
--   * orders.shipped_at: set when the order moves to 'in transit'.
BEGIN;

ALTER TABLE orders
    ADD COLUMN IF NOT EXISTS handover_photos jsonb NOT NULL DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS shipped_at timestamptz;

COMMIT;
