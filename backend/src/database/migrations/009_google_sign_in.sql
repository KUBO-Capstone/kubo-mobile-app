-- Sign in with Google.
--   * users.google_sub: the Google account's `sub` claim, the one identifier
--     Google promises never changes or gets reused. Kept apart from email,
--     which a Google account can change. NULL for accounts never signed in
--     with Google. Unique, so one Google account is one Kubo account.
--   * A Google-only account has password_hash = '', which verifyPassword
--     always rejects: it cannot be logged into with a password.
--   * anonymize_user() also clears google_sub, so a deleted account can
--     never be signed back into from Google (as in 005, plus that one line).
BEGIN;

ALTER TABLE users ADD COLUMN IF NOT EXISTS google_sub text;

CREATE UNIQUE INDEX IF NOT EXISTS uq_users_google_sub ON users (google_sub) WHERE google_sub IS NOT NULL;

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
        google_sub           = NULL,
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
