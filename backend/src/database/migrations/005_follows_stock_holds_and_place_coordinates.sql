-- =====================================================================
-- Kubo PostgreSQL schema  -  v6: follows, stock held by accepted offers,
-- and coordinates for the places sellers are in
--
--   * user_follows: who follows whom. The Following / Followers counts on a
--     profile are counted from here.
--   * negotiations.reserved_quantity: stock an accepted offer is holding.
--     Accepting an offer now takes its quantity off the listing straight
--     away, so the listing shows what is really left and only reads
--     'out of stock' at zero. The column is set while the offer is accepted
--     and not yet ordered. It is cleared when the buyer places the order
--     (the order then owns the stock, and cancelling the order returns it)
--     or when the deal is cancelled before an order (which returns it too).
--     Offers accepted before this migration hold nothing (NULL): their stock
--     is still taken when the order is placed, as before.
--   * place_coordinates: one point per city or municipality, looked up once
--     from OpenStreetMap by services/geocoding.service.ts. Listings are
--     plotted at their seller's farm address when it has coordinates, and
--     at this town-level point otherwise, so a personal address is never
--     put on the map.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- Follows
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_follows (
    follower_id integer     NOT NULL,
    followee_id integer     NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),

    PRIMARY KEY (follower_id, followee_id),
    CHECK (follower_id <> followee_id),
    FOREIGN KEY (follower_id) REFERENCES users (user_id) ON DELETE CASCADE,
    FOREIGN KEY (followee_id) REFERENCES users (user_id) ON DELETE CASCADE
);

-- The primary key covers "who do I follow"; this covers "who follows me".
CREATE INDEX IF NOT EXISTS idx_user_follows_followee ON user_follows (followee_id);

-- ---------------------------------------------------------------------
-- Stock held by an accepted offer
-- ---------------------------------------------------------------------
ALTER TABLE negotiations
    ADD COLUMN IF NOT EXISTS reserved_quantity numeric(12,3)
        CHECK (reserved_quantity IS NULL OR reserved_quantity > 0);

-- ---------------------------------------------------------------------
-- Town-level coordinates
-- city and province are stored lower-cased and trimmed, the way the listing
-- query looks them up. latitude / longitude stay NULL when OpenStreetMap had
-- no match, so the same place is not asked for again on every start.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS place_coordinates (
    city         varchar(100) NOT NULL,
    province     varchar(100) NOT NULL DEFAULT '',
    latitude     double precision,
    longitude    double precision,
    looked_up_at timestamptz  NOT NULL DEFAULT now(),

    PRIMARY KEY (city, province),
    CHECK ((latitude IS NULL) = (longitude IS NULL))
);

-- ---------------------------------------------------------------------
-- Account deletion also drops the user's follows, in both directions.
-- Same function as in 001 with that one DELETE added.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION anonymize_user(p_user_id integer)
RETURNS void AS $$
DECLARE
    v_address_ids integer[];
BEGIN
    -- Capture before the UPDATE below clears preferred_address_id
    SELECT array_agg(DISTINCT a.address_id) INTO v_address_ids
    FROM (
        SELECT preferred_address_id AS address_id FROM users WHERE user_id = p_user_id
        UNION SELECT address_id FROM user_addresses  WHERE user_id = p_user_id
        UNION SELECT address_id FROM farmer_profiles WHERE farmer_id = p_user_id
    ) a
    WHERE a.address_id IS NOT NULL;

    UPDATE users
    SET first_name           = 'Deleted',
        last_name            = 'User',
        email                = 'deleted_' || user_id || '@invalid.local',
        password_hash        = '',
        contact_number       = '',
        location             = NULL,
        business_name        = NULL,
        business_type        = NULL,
        profile_privacy      = '{"public_profile":false,"show_bio":false,"show_contact_number":false,"show_location":false}'::jsonb,
        bio                  = '',
        profile_photo_key    = NULL,
        preferred_address_id = NULL,
        is_verified          = FALSE,
        deleted_at           = now()
    WHERE user_id = p_user_id
      AND deleted_at IS NULL;

    -- Personal-only data that nobody else depends on
    DELETE FROM user_addresses  WHERE user_id = p_user_id;
    DELETE FROM farmer_profiles WHERE farmer_id = p_user_id;
    DELETE FROM saved_listings  WHERE user_id = p_user_id;
    DELETE FROM notifications   WHERE recipient_id = p_user_id;
    DELETE FROM user_follows    WHERE follower_id = p_user_id OR followee_id = p_user_id;

    -- Drop the now-unlinked addresses unless something else still uses them
    DELETE FROM addresses ad
    WHERE ad.address_id = ANY (v_address_ids)
      AND NOT EXISTS (SELECT 1 FROM users            u WHERE u.preferred_address_id = ad.address_id)
      AND NOT EXISTS (SELECT 1 FROM user_addresses  ua WHERE ua.address_id = ad.address_id)
      AND NOT EXISTS (SELECT 1 FROM farmer_profiles fp WHERE fp.address_id = ad.address_id)
      AND NOT EXISTS (SELECT 1 FROM bagsakan_centers bc WHERE bc.address_id = ad.address_id);

    -- Stop selling; existing orders are unaffected
    UPDATE products SET status = 'delisted'
    WHERE seller_id = p_user_id AND status <> 'delisted';
END;
$$ LANGUAGE plpgsql;

COMMIT;
