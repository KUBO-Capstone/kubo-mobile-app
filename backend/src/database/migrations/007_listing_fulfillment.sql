-- =====================================================================
-- Kubo PostgreSQL schema  -  v8: pickup and delivery per listing
--
-- A seller sets the bagsakan centers and couriers they work with on their
-- profile (seller_bagsakan_centers / seller_couriers, migration 006). A
-- listing follows those unless the seller sets its own for it:
--   * products.custom_fulfillment: true when this listing has its own
--     choices. False (the default) means it follows the profile.
--   * product_bagsakan_centers / product_couriers: the listing's own
--     choices, only read while custom_fulfillment is true. As on the
--     profile, an empty list means buyers may pick any.
-- A listing's choices never change the profile's.
-- =====================================================================

BEGIN;

ALTER TABLE products
    ADD COLUMN IF NOT EXISTS custom_fulfillment boolean NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS product_bagsakan_centers (
    product_id integer NOT NULL,
    center_id  integer NOT NULL,

    PRIMARY KEY (product_id, center_id),
    FOREIGN KEY (product_id) REFERENCES products (product_id)       ON DELETE CASCADE,
    FOREIGN KEY (center_id)  REFERENCES bagsakan_centers (center_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS product_couriers (
    product_id integer      NOT NULL,
    courier    varchar(100) NOT NULL,

    PRIMARY KEY (product_id, courier),
    FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE CASCADE
);

COMMIT;
