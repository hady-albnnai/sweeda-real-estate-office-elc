-- Combined execution file for logic fixes
-- Execute this file in Supabase SQL Editor after taking a backup.
-- Order matters and is preserved below.


-- ============================================================================
-- BEGIN supabase/migrations/2026_06_10_logic_fixes_appointments_offers.sql
-- ============================================================================

-- ════════════════════════════════════════════════════════════════════════════
-- Logic fixes: appointments + offer review alignment
-- Date: 2026-06-10
-- Purpose:
--   - add requester user to appointments
--   - unify appointment statuses to 0..5
--   - align pending offers to sts=1 (review)
--   - harden create_offer_internal with quota + duplicate checks
-- ════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 1) Appointments: requester user + full status range
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE appointments
  ADD COLUMN IF NOT EXISTS req_uid UUID REFERENCES users(id) ON DELETE SET NULL;

UPDATE appointments a
SET req_uid = r.usr_id
FROM requests r
WHERE a.req_uid IS NULL
  AND a.req_id = r.id;

ALTER TABLE appointments
  DROP CONSTRAINT IF EXISTS appointments_sts_check;

ALTER TABLE appointments
  ADD CONSTRAINT appointments_sts_check CHECK (sts BETWEEN 0 AND 5);

CREATE INDEX IF NOT EXISTS idx_appointments_req_uid ON appointments(req_uid, sts);

COMMENT ON COLUMN appointments.req_uid IS
  'Requester user id (the user who booked the appointment). req_id remains optional link to requests table.';

-- ─────────────────────────────────────────────────────────────────────────────
-- 2) Pending offers count = review queue (sts=1)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_pending_offers_count()
RETURNS INTEGER AS $$
DECLARE
  v_cnt INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_cnt
  FROM offers
  WHERE sts = 1
    AND i_del = 0;
  RETURN v_cnt;
END;
$$ LANGUAGE plpgsql;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3) create_offer_internal hardened
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION create_offer_internal(
  p_user_uid UUID,
  p_offer JSONB
)
RETURNS SETOF offers AS $$
DECLARE
  v_user users%ROWTYPE;
  v_config JSONB;
  v_limit INT;
  v_used INT;
  v_recent_deleted INT;
  v_duplicate BOOLEAN;
BEGIN
  SELECT * INTO v_user
  FROM users
  WHERE id = p_user_uid
    AND i_del = 0
    AND sts = 0;

  IF v_user.id IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_ACTIVE_OR_NOT_FOUND';
  END IF;

  IF COALESCE(trim(p_offer->>'ttl'), '') = '' THEN
    RAISE EXCEPTION 'TITLE_REQUIRED';
  END IF;

  IF COALESCE(trim(p_offer->>'contact_ph'), '') = '' THEN
    RAISE EXCEPTION 'CONTACT_PHONE_REQUIRED';
  END IF;

  IF COALESCE((p_offer->>'prc')::NUMERIC, 0) <= 0 THEN
    RAISE EXCEPTION 'INVALID_PRICE';
  END IF;

  -- الإدارة الداخلية غير مقيّدة بحصة
  IF COALESCE(v_user.role, 0) < 2 THEN
    SELECT value INTO v_config
    FROM app_config
    WHERE key = 'main';

    v_limit := COALESCE((v_config->'pkg'->(COALESCE(v_user.b_pkg, 0)::TEXT)->>'o')::INT,
      CASE WHEN COALESCE(v_user.role, 0) = 1 THEN 5 ELSE 1 END);

    SELECT COUNT(*) INTO v_used
    FROM offers
    WHERE usr_id = p_user_uid
      AND i_del = 0
      AND sts IN (0, 1, 2, 5);

    SELECT COUNT(*) INTO v_recent_deleted
    FROM offers
    WHERE usr_id = p_user_uid
      AND i_del = 1
      AND ts_upd >= NOW() - INTERVAL '24 hours';

    v_used := COALESCE(v_used, 0) + COALESCE(v_recent_deleted, 0);

    IF v_used >= v_limit THEN
      RAISE EXCEPTION 'QUOTA_EXCEEDED';
    END IF;
  END IF;

  SELECT check_offer_duplicate(
    COALESCE(p_offer->>'ttl', ''),
    COALESCE((p_offer->>'prc')::NUMERIC, 0),
    COALESCE(p_offer->'loc', '{"r":0,"d":""}'::jsonb),
    p_user_uid
  ) INTO v_duplicate;

  IF v_duplicate THEN
    RAISE EXCEPTION 'DUPLICATE_OFFER';
  END IF;

  RETURN QUERY
  INSERT INTO offers (
    usr_id,
    brk_id,
    brk_pct,
    typ,
    trx,
    cat,
    sub,
    contact_ph,
    ttl,
    prc,
    cur,
    loc,
    descript,
    imgs,
    vdo,
    doc_tp,
    doc_img,
    exact_loc,
    specs,
    com,
    sts,
    rsn,
    vws,
    fvs,
    i_pub,
    i_soc,
    soc_pub,
    soc_txt,
    i_dup,
    dup_of,
    avl,
    i_del,
    ts_crt,
    ts_pub,
    ts_end,
    ts_ren
  ) VALUES (
    p_user_uid,
    NULLIF(p_offer->>'brk_id', '')::UUID,
    COALESCE((p_offer->>'brk_pct')::NUMERIC, 0),
    COALESCE((p_offer->>'typ')::INT, 0),
    COALESCE((p_offer->>'trx')::INT, 0),
    COALESCE((p_offer->>'cat')::INT, 0),
    COALESCE((p_offer->>'sub')::INT, 0),
    COALESCE(p_offer->>'contact_ph', ''),
    COALESCE(p_offer->>'ttl', ''),
    COALESCE((p_offer->>'prc')::NUMERIC, 0),
    COALESCE((p_offer->>'cur')::INT, 1),
    COALESCE(p_offer->'loc', '{"r":0,"d":""}'::jsonb),
    COALESCE(p_offer->>'descript', ''),
    COALESCE(p_offer->'imgs', '[]'::jsonb),
    COALESCE(p_offer->>'vdo', ''),
    COALESCE((p_offer->>'doc_tp')::INT, 0),
    COALESCE(p_offer->>'doc_img', ''),
    COALESCE(p_offer->>'exact_loc', ''),
    COALESCE(p_offer->'specs', '{}'::jsonb),
    COALESCE((p_offer->>'com')::NUMERIC, 0),
    1,
    '',
    0,
    0,
    0,
    COALESCE((p_offer->>'i_soc')::INT, 0),
    0,
    COALESCE(p_offer->>'soc_txt', ''),
    0,
    NULLIF(p_offer->>'dup_of', '')::UUID,
    COALESCE(p_offer->'avl', '{}'::jsonb),
    0,
    NOW(),
    NULL,
    NULL,
    NULL
  )
  RETURNING *;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION create_offer_internal(UUID, JSONB) TO anon, authenticated;

-- END supabase/migrations/2026_06_10_logic_fixes_appointments_offers.sql

-- ============================================================================
-- BEGIN supabase/migrations/2026_06_10_logic_fixes_boosts_payments.sql
-- ============================================================================

-- ════════════════════════════════════════════════════════════════════════════
-- Logic fixes: boosts + payment approval
-- Date: 2026-06-10
-- Purpose:
--   - server calculates boost cost from config
--   - prevent negative/forged boost prices from client
--   - validate payment approval by admin role and pending state
-- ════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 1) Replace purchase_offer_boost signature
-- ─────────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS purchase_offer_boost(UUID, UUID, TEXT, INTEGER);

CREATE OR REPLACE FUNCTION purchase_offer_boost(
  p_uid UUID,
  p_offer_id UUID,
  p_boost_type TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_user_pts INTEGER;
  v_owner_id UUID;
  v_now TIMESTAMPTZ := NOW();
  v_result JSONB;
  v_cost INTEGER;
  v_offer_status INTEGER;
  v_config JSONB;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_uid THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_UID_MISMATCH');
  END IF;

  SELECT usr_id, sts INTO v_owner_id, v_offer_status
  FROM offers
  WHERE id = p_offer_id AND i_del = 0;

  IF v_owner_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'OFFER_NOT_FOUND');
  END IF;
  IF v_owner_id <> p_uid THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_OWNER');
  END IF;

  SELECT value INTO v_config
  FROM app_config
  WHERE key = 'main';

  v_cost := CASE p_boost_type
    WHEN 'ren' THEN COALESCE((v_config->'spd'->>'ren')::INT, 500)
    WHEN 'pin' THEN COALESCE((v_config->'spd'->>'pin')::INT, 2000)
    WHEN 'bst' THEN COALESCE((v_config->'spd'->>'bst')::INT, 4000)
    WHEN 'dsc5' THEN COALESCE((v_config->'spd'->>'dsc5')::INT, 3000)
    WHEN 'fms' THEN COALESCE((v_config->'spd'->>'fms')::INT, 8000)
    ELSE NULL
  END;

  IF v_cost IS NULL OR v_cost <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_BOOST_TYPE');
  END IF;

  SELECT pt INTO v_user_pts FROM users WHERE id = p_uid;
  IF v_user_pts IS NULL OR v_user_pts < v_cost THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'INSUFFICIENT_POINTS',
      'current_points', COALESCE(v_user_pts, 0),
      'required', v_cost
    );
  END IF;

  CASE p_boost_type
    WHEN 'ren' THEN
      IF v_offer_status = 3 THEN
        RETURN jsonb_build_object('success', false, 'error', 'REJECTED_OFFER');
      END IF;

      UPDATE offers SET
        ts_end = GREATEST(COALESCE(ts_end, v_now), v_now) + INTERVAL '30 days',
        ts_ren = v_now,
        sts = CASE WHEN sts = 4 THEN 2 ELSE sts END,
        i_pub = CASE WHEN sts = 4 THEN 1 ELSE i_pub END,
        ts_upd = v_now
      WHERE id = p_offer_id;
      v_result := jsonb_build_object('boost_type', 'ren', 'duration_days', 30);

    WHEN 'pin' THEN
      UPDATE offers SET
        i_pin = 1,
        pin_end = v_now + INTERVAL '7 days',
        ts_upd = v_now
      WHERE id = p_offer_id;
      v_result := jsonb_build_object('boost_type', 'pin', 'duration_days', 7);

    WHEN 'bst' THEN
      UPDATE offers SET
        i_bst = 1,
        bst_end = v_now + INTERVAL '14 days',
        ts_upd = v_now
      WHERE id = p_offer_id;
      v_result := jsonb_build_object('boost_type', 'bst', 'duration_days', 14);

    WHEN 'dsc5' THEN
      UPDATE offers SET
        dsc_pct = 5,
        dsc_end = v_now + INTERVAL '60 days',
        ts_upd = v_now
      WHERE id = p_offer_id;
      v_result := jsonb_build_object('boost_type', 'dsc5', 'discount_pct', 5);

    WHEN 'fms' THEN
      UPDATE offers SET
        i_fms = 1,
        fms_end = v_now + INTERVAL '30 days',
        ts_upd = v_now
      WHERE id = p_offer_id;
      v_result := jsonb_build_object('boost_type', 'fms', 'duration_days', 30);
  END CASE;

  UPDATE users SET
    pt = pt - v_cost,
    ts_upd = v_now
  WHERE id = p_uid;

  INSERT INTO activity_log (uid, action, details, ts_crt)
  VALUES (
    p_uid,
    'offer_boost',
    jsonb_build_object(
      'offer_id', p_offer_id,
      'boost_type', p_boost_type,
      'cost', v_cost
    ),
    v_now
  );

  RETURN jsonb_build_object('success', true, 'result', v_result, 'new_balance', v_user_pts - v_cost);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION purchase_offer_boost(UUID, UUID, TEXT) TO anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2) Payment approval hardened
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION approve_payment_final(
  p_payment_id UUID,
  p_admin_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_pkg_id INT;
  v_pkg_duration INT;
  v_config JSONB;
  v_admin_role INT;
  v_payment_status INT;
  v_payment_type INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_UID_MISMATCH');
  END IF;

  SELECT role INTO v_admin_role
  FROM users
  WHERE id = p_admin_id
    AND i_del = 0;

  IF v_admin_role IS NULL OR v_admin_role < 2 THEN
    RETURN jsonb_build_object('success', false, 'error', 'FORBIDDEN');
  END IF;

  SELECT uid, pkg, sts, tp
    INTO v_user_id, v_pkg_id, v_payment_status, v_payment_type
  FROM payments
  WHERE id = p_payment_id;

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'PAYMENT_NOT_FOUND');
  END IF;

  IF COALESCE(v_payment_status, -1) <> 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'PAYMENT_NOT_PENDING');
  END IF;

  IF COALESCE(v_payment_type, -1) <> 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNSUPPORTED_PAYMENT_TYPE');
  END IF;

  SELECT value INTO v_config FROM app_config WHERE key = 'main';
  v_pkg_duration := (v_config->'pkg'->(v_pkg_id::text)->>'d')::INT;

  IF v_pkg_duration IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'PKG_DURATION_NOT_FOUND');
  END IF;

  UPDATE payments
  SET sts = 1,
      appr_by = p_admin_id,
      ts_upd = NOW()
  WHERE id = p_payment_id
    AND sts = 0;

  UPDATE users
  SET b_pkg = v_pkg_id,
      pkg_end = GREATEST(COALESCE(pkg_end, NOW()), NOW()) + (v_pkg_duration || ' days')::interval,
      ts_upd = NOW()
  WHERE id = v_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Package activated successfully',
    'duration', v_pkg_duration
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION approve_payment_final(UUID, UUID) TO authenticated;

-- END supabase/migrations/2026_06_10_logic_fixes_boosts_payments.sql

-- ============================================================================
-- BEGIN supabase/migrations/2026_06_10_config_package_prices_and_fx.sql
-- ============================================================================

-- ════════════════════════════════════════════════════════════════════════════
-- Config defaults: package prices + FX rate
-- Date: 2026-06-10
-- Purpose:
--   - move package prices to config.pkg.*.pr
--   - move USD/SYP exchange rate to config.fx.usd_syp
-- ════════════════════════════════════════════════════════════════════════════

UPDATE app_config
SET value = jsonb_set(
              jsonb_set(
                jsonb_set(
                  jsonb_set(
                    COALESCE(value, '{}'::jsonb),
                    '{pkg,0,pr}', '0'::jsonb, true
                  ),
                  '{pkg,1,pr}', '10'::jsonb, true
                ),
                '{pkg,2,pr}', '25'::jsonb, true
              ),
              '{fx,usd_syp}', '15000'::jsonb, true
            )
WHERE key = 'main';

-- END supabase/migrations/2026_06_10_config_package_prices_and_fx.sql

-- ============================================================================
-- BEGIN supabase/migrations/2026_06_10_auth_uid_alignment_guards.sql
-- ============================================================================

-- ════════════════════════════════════════════════════════════════════════════
-- Partial auth.uid alignment guards for dev-compatible RPCs
-- Date: 2026-06-10
-- Purpose:
--   If auth.uid() is available, enforce it matches the uid passed from client.
--   This hardens production/real-session mode without breaking current dev fallback
--   where auth.uid() may still be NULL.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION admin_update_user_role(
  p_admin_uid UUID,
  p_target_uid UUID,
  p_role INT
)
RETURNS BOOLEAN AS $$
DECLARE
  v_admin_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  SELECT role INTO v_admin_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_admin_role IS NULL OR v_admin_role < 3 THEN
    RAISE EXCEPTION 'FORBIDDEN: Deputy/admin role required.';
  END IF;
  IF p_role < 0 OR p_role > 4 THEN
    RAISE EXCEPTION 'INVALID_ROLE';
  END IF;

  UPDATE users
  SET role = p_role,
      brk = CASE WHEN p_role = 1 THEN 1 ELSE brk END,
      ts_upd = NOW()
  WHERE id = p_target_uid
    AND i_del = 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_set_user_status(
  p_admin_uid UUID,
  p_target_uid UUID,
  p_status INT,
  p_reason TEXT DEFAULT ''
)
RETURNS BOOLEAN AS $$
DECLARE
  v_admin_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  SELECT role INTO v_admin_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_admin_role IS NULL OR v_admin_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN: Admin role required.';
  END IF;
  IF p_status < 0 OR p_status > 2 THEN
    RAISE EXCEPTION 'INVALID_STATUS';
  END IF;

  UPDATE users
  SET sts = p_status,
      ban_rsn = CASE WHEN p_status = 0 THEN '' ELSE COALESCE(p_reason, '') END,
      ts_upd = NOW()
  WHERE id = p_target_uid
    AND i_del = 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_update_user_permissions_by_admin(
  p_admin_uid UUID,
  p_target_uid UUID,
  p_perm JSONB DEFAULT '[]'::jsonb
)
RETURNS BOOLEAN AS $$
DECLARE
  v_admin_role INT;
  v_item TEXT;
  v_allowed TEXT[] := ARRAY[
    'admin_dashboard','office_operations','manage_users','manage_permissions',
    'review_offers','review_verifications','media_review','photography_management',
    'photographer_tasks','fraud_suspects','manage_appointments','manage_deals',
    'manage_payments','manage_reports','manage_config','view_analytics',
    'broker_dashboard','broker_offers','broker_appointments','broker_deals',
    'broker_stats','user_home','user_offers','user_requests','user_appointments','user_profile'
  ];
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  SELECT role INTO v_admin_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_admin_role IS NULL OR v_admin_role < 3 THEN
    RAISE EXCEPTION 'FORBIDDEN: Deputy/admin role required.';
  END IF;

  IF p_perm IS NULL THEN p_perm := '[]'::jsonb; END IF;
  IF jsonb_typeof(p_perm) <> 'array' THEN
    RAISE EXCEPTION 'INVALID_PERMISSIONS: Expected JSON array.';
  END IF;

  FOR v_item IN SELECT jsonb_array_elements_text(p_perm)
  LOOP
    IF NOT (v_item = ANY(v_allowed)) THEN
      RAISE EXCEPTION 'INVALID_PERMISSION: %', v_item;
    END IF;
  END LOOP;

  UPDATE users
  SET perm = p_perm,
      ts_upd = NOW()
  WHERE id = p_target_uid
    AND i_del = 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_offer_internal(
  p_user_uid UUID,
  p_offer JSONB
)
RETURNS SETOF offers AS $$
DECLARE
  v_user users%ROWTYPE;
  v_config JSONB;
  v_limit INT;
  v_used INT;
  v_recent_deleted INT;
  v_duplicate BOOLEAN;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  SELECT * INTO v_user
  FROM users
  WHERE id = p_user_uid
    AND i_del = 0
    AND sts = 0;

  IF v_user.id IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_ACTIVE_OR_NOT_FOUND';
  END IF;

  SELECT value INTO v_config FROM app_config WHERE key = 'main';

  IF COALESCE(v_user.role, 0) < 2 THEN
    v_limit := COALESCE((v_config->'pkg'->(COALESCE(v_user.b_pkg, 0)::TEXT)->>'o')::INT,
      CASE WHEN COALESCE(v_user.role, 0) = 1 THEN 5 ELSE 1 END);

    SELECT COUNT(*) INTO v_used
    FROM offers
    WHERE usr_id = p_user_uid
      AND i_del = 0
      AND sts IN (0, 1, 2, 5);

    SELECT COUNT(*) INTO v_recent_deleted
    FROM offers
    WHERE usr_id = p_user_uid
      AND i_del = 1
      AND ts_upd >= NOW() - INTERVAL '24 hours';

    IF COALESCE(v_used, 0) + COALESCE(v_recent_deleted, 0) >= v_limit THEN
      RAISE EXCEPTION 'QUOTA_EXCEEDED';
    END IF;
  END IF;

  SELECT check_offer_duplicate(
    COALESCE(p_offer->>'ttl', ''),
    COALESCE((p_offer->>'prc')::NUMERIC, 0),
    COALESCE(p_offer->'loc', '{"r":0,"d":""}'::jsonb),
    p_user_uid
  ) INTO v_duplicate;

  IF v_duplicate THEN
    RAISE EXCEPTION 'DUPLICATE_OFFER';
  END IF;

  RETURN QUERY
  INSERT INTO offers (
    usr_id, brk_id, brk_pct, typ, trx, cat, sub, contact_ph, ttl, prc,
    cur, loc, descript, imgs, vdo, doc_tp, doc_img, exact_loc, specs, com,
    sts, rsn, vws, fvs, i_pub, i_soc, soc_pub, soc_txt, i_dup, dup_of, avl,
    i_del, ts_crt, ts_pub, ts_end, ts_ren
  ) VALUES (
    p_user_uid,
    NULLIF(p_offer->>'brk_id', '')::UUID,
    COALESCE((p_offer->>'brk_pct')::NUMERIC, 0),
    COALESCE((p_offer->>'typ')::INT, 0),
    COALESCE((p_offer->>'trx')::INT, 0),
    COALESCE((p_offer->>'cat')::INT, 0),
    COALESCE((p_offer->>'sub')::INT, 0),
    COALESCE(p_offer->>'contact_ph', ''),
    COALESCE(p_offer->>'ttl', ''),
    COALESCE((p_offer->>'prc')::NUMERIC, 0),
    COALESCE((p_offer->>'cur')::INT, 1),
    COALESCE(p_offer->'loc', '{"r":0,"d":""}'::jsonb),
    COALESCE(p_offer->>'descript', ''),
    COALESCE(p_offer->'imgs', '[]'::jsonb),
    COALESCE(p_offer->>'vdo', ''),
    COALESCE((p_offer->>'doc_tp')::INT, 0),
    COALESCE(p_offer->>'doc_img', ''),
    COALESCE(p_offer->>'exact_loc', ''),
    COALESCE(p_offer->'specs', '{}'::jsonb),
    COALESCE((p_offer->>'com')::NUMERIC, 0),
    1, '', 0, 0, 0,
    COALESCE((p_offer->>'i_soc')::INT, 0),
    0, COALESCE(p_offer->>'soc_txt', ''), 0,
    NULLIF(p_offer->>'dup_of', '')::UUID,
    COALESCE(p_offer->'avl', '{}'::jsonb),
    0, NOW(), NULL, NULL, NULL
  )
  RETURNING *;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_photography_task_internal(
  p_admin_uid UUID,
  p_offer_id UUID,
  p_photographer_id UUID,
  p_notes TEXT DEFAULT '',
  p_ts_scheduled TIMESTAMPTZ DEFAULT NULL
)
RETURNS SETOF photography_tasks AS $$
DECLARE
  v_admin_role INT;
  v_offer offers%ROWTYPE;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  SELECT role INTO v_admin_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_admin_role IS NULL OR v_admin_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN: Admin role required.';
  END IF;
  SELECT * INTO v_offer FROM offers WHERE id = p_offer_id AND i_del = 0;
  IF v_offer.id IS NULL THEN RAISE EXCEPTION 'OFFER_NOT_FOUND'; END IF;

  RETURN QUERY
  INSERT INTO photography_tasks (off_id, photographer_id, requested_by, ttl, notes, loc, sts, ts_scheduled, ts_crt, ts_upd)
  VALUES (p_offer_id, p_photographer_id, p_admin_uid, v_offer.ttl, COALESCE(p_notes, ''), COALESCE(v_offer.loc, '{}'::jsonb), 0, p_ts_scheduled, NOW(), NOW())
  RETURNING *;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION submit_photography_task_internal(
  p_photographer_uid UUID,
  p_task_id UUID,
  p_media JSONB,
  p_photographer_note TEXT DEFAULT ''
)
RETURNS BOOLEAN AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_photographer_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  IF jsonb_typeof(COALESCE(p_media, '[]'::jsonb)) <> 'array' THEN
    RAISE EXCEPTION 'INVALID_MEDIA_ARRAY';
  END IF;

  UPDATE photography_tasks
  SET media = COALESCE(p_media, '[]'::jsonb),
      photographer_note = COALESCE(p_photographer_note, ''),
      sts = 2,
      ts_submit = NOW(),
      ts_upd = NOW()
  WHERE id = p_task_id
    AND photographer_id = p_photographer_uid
    AND sts IN (0, 1, 4);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'TASK_NOT_FOUND_OR_NOT_ALLOWED';
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_photography_task_status_internal(
  p_admin_uid UUID,
  p_task_id UUID,
  p_status INT,
  p_office_note TEXT DEFAULT ''
)
RETURNS BOOLEAN AS $$
DECLARE
  v_admin_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  SELECT role INTO v_admin_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_admin_role IS NULL OR v_admin_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN: Admin role required.';
  END IF;
  IF p_status < 0 OR p_status > 5 THEN
    RAISE EXCEPTION 'INVALID_STATUS';
  END IF;

  UPDATE photography_tasks
  SET sts = p_status,
      office_note = COALESCE(p_office_note, office_note),
      ts_done = CASE WHEN p_status IN (3, 4, 5) THEN NOW() ELSE ts_done END,
      ts_upd = NOW()
  WHERE id = p_task_id;

  IF NOT FOUND THEN RAISE EXCEPTION 'TASK_NOT_FOUND'; END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION attach_photography_media_to_offer_internal(
  p_admin_uid UUID,
  p_task_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  v_admin_role INT;
  v_task photography_tasks%ROWTYPE;
  v_existing JSONB;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  SELECT role INTO v_admin_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_admin_role IS NULL OR v_admin_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN: Admin role required.';
  END IF;

  SELECT * INTO v_task FROM photography_tasks WHERE id = p_task_id;
  IF v_task.id IS NULL THEN RAISE EXCEPTION 'TASK_NOT_FOUND'; END IF;
  IF jsonb_array_length(COALESCE(v_task.media, '[]'::jsonb)) = 0 THEN
    RAISE EXCEPTION 'NO_MEDIA';
  END IF;

  SELECT COALESCE(imgs, '[]'::jsonb) INTO v_existing FROM offers WHERE id = v_task.off_id;

  UPDATE offers
  SET imgs = (
    SELECT jsonb_agg(DISTINCT value)
    FROM jsonb_array_elements(v_existing || v_task.media)
  )
  WHERE id = v_task.off_id;

  UPDATE photography_tasks
  SET sts = 3,
      office_note = 'تم اعتماد التصوير وربط الوسائط بالعرض',
      ts_done = NOW(),
      ts_upd = NOW()
  WHERE id = p_task_id;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- END supabase/migrations/2026_06_10_auth_uid_alignment_guards.sql

-- ============================================================================
-- BEGIN supabase/migrations/2026_06_10_users_public_no_private_img.sql
-- ============================================================================

-- ════════════════════════════════════════════════════════════════════════════
-- users_public: remove private identity path from public view
-- Date: 2026-06-10
-- Purpose:
--   After moving identity images to ids_private, users.img may hold a private
--   storage path. It must not remain exposed in users_public.
-- ════════════════════════════════════════════════════════════════════════════

DROP VIEW IF EXISTS users_public CASCADE;
CREATE VIEW users_public AS
SELECT
  id,
  nm,
  role,
  brk,
  brk_cls,
  brk_nm,
  bg,
  vrf,
  pt,
  ref_cnt,
  ts_crt
FROM users
WHERE i_del = 0;

GRANT SELECT ON users_public TO anon, authenticated;
ALTER VIEW users_public SET (security_invoker = true);

-- END supabase/migrations/2026_06_10_users_public_no_private_img.sql

-- ============================================================================
-- BEGIN supabase/migrations/2026_06_10_verification_dev_auth_rpcs.sql
-- ============================================================================

-- ════════════════════════════════════════════════════════════════════════════
-- Verification RPCs compatible with current dev auth model
-- Date: 2026-06-10
-- Purpose:
--   Keep verification workflow functional when auth.uid() is unavailable in the
--   current dev fallback, while still enforcing auth.uid() alignment whenever a
--   real Supabase Auth session exists.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION request_verification_by_uid(p_user_uid UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_user RECORD;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  SELECT id, sid, img, vrf INTO v_user FROM users WHERE id = p_user_uid AND i_del = 0;
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;
  IF v_user.vrf = 2 THEN
    RAISE EXCEPTION 'ALREADY_VERIFIED';
  END IF;
  IF v_user.vrf = 1 THEN
    RAISE EXCEPTION 'ALREADY_PENDING';
  END IF;
  IF v_user.sid IS NULL OR LENGTH(TRIM(v_user.sid)) = 0
     OR v_user.img IS NULL OR LENGTH(TRIM(v_user.img)) = 0 THEN
    RAISE EXCEPTION 'MISSING_DOCUMENTS';
  END IF;

  UPDATE users SET vrf = 1, ts_upd = NOW() WHERE id = p_user_uid;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_approve_verification_by_admin(
  p_admin_uid UUID,
  p_target_uid UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  v_admin_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  SELECT role INTO v_admin_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_admin_role IS NULL OR v_admin_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN: Admin role required.';
  END IF;

  UPDATE users SET vrf = 2, ts_upd = NOW() WHERE id = p_target_uid AND i_del = 0;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;

  INSERT INTO notifications (uid, tp, ttl, bdy, act)
    VALUES (p_target_uid, 4, '✅ تم اعتماد توثيق حسابك',
            'تهانينا! حسابك أصبح موثقاً رسمياً.', 'verification');
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_reject_verification_by_admin(
  p_admin_uid UUID,
  p_target_uid UUID,
  p_reason TEXT DEFAULT ''
)
RETURNS BOOLEAN AS $$
DECLARE
  v_admin_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  SELECT role INTO v_admin_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_admin_role IS NULL OR v_admin_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN: Admin role required.';
  END IF;

  UPDATE users SET vrf = 0, ts_upd = NOW() WHERE id = p_target_uid AND i_del = 0;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;

  INSERT INTO notifications (uid, tp, ttl, bdy, act)
    VALUES (p_target_uid, 4, '🚫 رفض طلب التوثيق',
            CASE WHEN LENGTH(TRIM(p_reason)) > 0
                 THEN 'السبب: ' || p_reason
                 ELSE 'يرجى التأكد من وضوح صورة الهوية وإعادة المحاولة.'
            END, 'verification');
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION request_verification_by_uid(UUID) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION admin_approve_verification_by_admin(UUID, UUID) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION admin_reject_verification_by_admin(UUID, UUID, TEXT) TO authenticated, anon;

-- END supabase/migrations/2026_06_10_verification_dev_auth_rpcs.sql

-- ============================================================================
-- BEGIN supabase/migrations/2026_06_11_drop_obsolete_verification_rpcs.sql
-- ============================================================================

-- ════════════════════════════════════════════════════════════════════════════
-- Cleanup: drop obsolete verification RPCs
-- Date: 2026-06-11
-- Purpose:
--   Remove old verification RPCs that were replaced by the current
--   dev-compatible versions:
--     - request_verification_by_uid
--     - admin_approve_verification_by_admin
--     - admin_reject_verification_by_admin
-- ════════════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS request_verification();
DROP FUNCTION IF EXISTS admin_approve_verification(UUID);
DROP FUNCTION IF EXISTS admin_reject_verification(UUID, TEXT);

-- END supabase/migrations/2026_06_11_drop_obsolete_verification_rpcs.sql

-- ============================================================================
-- BEGIN supabase/migrations/2026_06_11_drop_obsolete_unused_rpcs.sql
-- ============================================================================

-- ════════════════════════════════════════════════════════════════════════════
-- Cleanup: drop obsolete unused RPCs
-- Date: 2026-06-11
-- Purpose:
--   Remove RPCs that are no longer used by the current app flow and have no
--   internal server dependencies:
--     - admin_update_user_permissions(UUID, JSONB)
--     - verify_otp_safe(TEXT, TEXT)
-- ════════════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS admin_update_user_permissions(UUID, JSONB);
DROP FUNCTION IF EXISTS verify_otp_safe(TEXT, TEXT);

-- END supabase/migrations/2026_06_11_drop_obsolete_unused_rpcs.sql

-- ============================================================================
-- BEGIN supabase/migrations/2026_06_11_real_test_stabilization_internal_rpcs.sql
-- ============================================================================

-- ════════════════════════════════════════════════════════════════════════════
-- Real test stabilization RPCs and policy fixes
-- Date: 2026-06-11
-- Purpose:
--   Replace remaining fragile direct client writes/reads in core flows with
--   SECURITY DEFINER RPCs compatible with the current auth model.
-- ════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 1) Appointments read policy aligned with requester field
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Related users can read appointments" ON appointments;
CREATE POLICY "Related users can read appointments" ON appointments
  FOR SELECT USING (
    auth.uid() = own_id
    OR auth.uid() = bkr_id
    OR auth.uid() = req_uid
    OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role >= 2)
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- 2) Generic role helpers via inline checks inside RPCs
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_offer_by_id_internal(
  p_offer_id UUID,
  p_user_uid UUID DEFAULT NULL
)
RETURNS SETOF offers AS $$
DECLARE
  v_role INT := 0;
BEGIN
  IF p_user_uid IS NOT NULL AND auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  IF p_user_uid IS NOT NULL THEN
    SELECT COALESCE(role, 0) INTO v_role FROM users WHERE id = p_user_uid AND i_del = 0;
  END IF;

  RETURN QUERY
  SELECT *
  FROM offers
  WHERE id = p_offer_id
    AND i_del = 0
    AND (
      i_pub = 1
      OR (p_user_uid IS NOT NULL AND usr_id = p_user_uid)
      OR (p_user_uid IS NOT NULL AND v_role >= 2)
    )
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_user_offers_internal(p_user_uid UUID)
RETURNS SETOF offers AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  RETURN QUERY
  SELECT * FROM offers
  WHERE usr_id = p_user_uid
    AND i_del = 0
  ORDER BY ts_crt DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_user_requests_internal(p_user_uid UUID)
RETURNS SETOF requests AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  RETURN QUERY
  SELECT * FROM requests
  WHERE usr_id = p_user_uid
    AND i_del = 0
  ORDER BY ts_crt DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_user_payments_internal(p_user_uid UUID)
RETURNS SETOF payments AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  RETURN QUERY
  SELECT * FROM payments
  WHERE uid = p_user_uid
  ORDER BY ts_crt DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_user_notifications_internal(p_user_uid UUID)
RETURNS SETOF notifications AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  RETURN QUERY
  SELECT * FROM notifications
  WHERE uid = p_user_uid
    AND i_del = 0
  ORDER BY ts_crt DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_user_appointments_internal(p_user_uid UUID)
RETURNS SETOF appointments AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  RETURN QUERY
  SELECT * FROM appointments
  WHERE req_uid = p_user_uid
  ORDER BY dt ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_owner_appointments_internal(p_owner_uid UUID)
RETURNS SETOF appointments AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_owner_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  RETURN QUERY
  SELECT * FROM appointments
  WHERE own_id = p_owner_uid
  ORDER BY dt ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_broker_offers_internal(p_broker_uid UUID)
RETURNS SETOF offers AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_broker_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  RETURN QUERY
  SELECT * FROM offers
  WHERE i_del = 0
    AND (usr_id = p_broker_uid OR brk_id = p_broker_uid)
  ORDER BY ts_crt DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_broker_appointments_internal(p_broker_uid UUID)
RETURNS SETOF appointments AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_broker_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  RETURN QUERY
  SELECT DISTINCT a.*
  FROM appointments a
  LEFT JOIN offers o ON o.id = a.off_id
  WHERE a.bkr_id = p_broker_uid
     OR a.own_id = p_broker_uid
     OR o.usr_id = p_broker_uid
  ORDER BY dt ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_broker_deals_internal(p_broker_uid UUID)
RETURNS SETOF deals AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_broker_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  RETURN QUERY
  SELECT * FROM deals
  WHERE brk_uid = p_broker_uid
    AND i_del = 0
  ORDER BY ts_crt DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_admin_pending_offers_internal(p_admin_uid UUID)
RETURNS SETOF offers AS $$
DECLARE
  v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  RETURN QUERY
  SELECT * FROM offers
  WHERE sts = 1
    AND i_del = 0
  ORDER BY ts_crt DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_admin_offers_internal(p_admin_uid UUID, p_limit INT DEFAULT 100)
RETURNS SETOF offers AS $$
DECLARE
  v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  RETURN QUERY
  SELECT * FROM offers
  WHERE i_del = 0
  ORDER BY ts_crt DESC
  LIMIT GREATEST(COALESCE(p_limit, 100), 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_admin_appointments_internal(p_admin_uid UUID)
RETURNS SETOF appointments AS $$
DECLARE
  v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  RETURN QUERY SELECT * FROM appointments ORDER BY dt DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_admin_deals_internal(p_admin_uid UUID)
RETURNS SETOF deals AS $$
DECLARE
  v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  RETURN QUERY SELECT * FROM deals WHERE i_del = 0 ORDER BY ts_crt DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_admin_payments_internal(p_admin_uid UUID)
RETURNS SETOF payments AS $$
DECLARE
  v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  RETURN QUERY SELECT * FROM payments ORDER BY ts_crt DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_admin_reports_internal(p_admin_uid UUID)
RETURNS SETOF reports AS $$
DECLARE
  v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  RETURN QUERY SELECT * FROM reports ORDER BY ts_crt DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3) Core write RPCs for stable real testing
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_review_offer_internal(
  p_admin_uid UUID,
  p_offer_id UUID,
  p_approve BOOLEAN,
  p_reason TEXT DEFAULT ''
)
RETURNS BOOLEAN AS $$
DECLARE
  v_role INT;
  v_owner_uid UUID;
  v_now TIMESTAMPTZ := NOW();
  v_rejected_count INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  SELECT usr_id INTO v_owner_uid FROM offers WHERE id = p_offer_id AND i_del = 0;
  IF v_owner_uid IS NULL THEN
    RAISE EXCEPTION 'OFFER_NOT_FOUND';
  END IF;

  UPDATE offers
  SET sts = CASE WHEN p_approve THEN 2 ELSE 3 END,
      i_pub = CASE WHEN p_approve THEN 1 ELSE 0 END,
      rsn = CASE WHEN p_approve THEN '' ELSE COALESCE(p_reason, '') END,
      ts_pub = CASE WHEN p_approve THEN v_now ELSE NULL END,
      ts_upd = v_now
  WHERE id = p_offer_id;

  IF NOT p_approve THEN
    SELECT COUNT(*) INTO v_rejected_count
    FROM offers
    WHERE usr_id = v_owner_uid
      AND sts = 3
      AND ts_upd >= NOW() - INTERVAL '30 days';
    IF v_rejected_count > 0 AND MOD(v_rejected_count, 3) = 0 THEN
      PERFORM add_points(v_owner_uid, -1000);
    END IF;
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_request_internal(
  p_user_uid UUID,
  p_request JSONB
)
RETURNS SETOF requests AS $$
DECLARE
  v_user users%ROWTYPE;
  v_config JSONB;
  v_limit INT;
  v_used INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  SELECT * INTO v_user FROM users WHERE id = p_user_uid AND i_del = 0 AND sts = 0;
  IF v_user.id IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_ACTIVE_OR_NOT_FOUND';
  END IF;

  IF COALESCE(trim(p_request->>'cl_nm'), '') = '' OR COALESCE(trim(p_request->>'cl_ph'), '') = '' THEN
    RAISE EXCEPTION 'MISSING_CLIENT_DATA';
  END IF;

  IF COALESCE(v_user.role, 0) < 2 THEN
    SELECT value INTO v_config FROM app_config WHERE key = 'main';
    v_limit := CASE WHEN COALESCE(v_user.role, 0) = 1
      THEN COALESCE((v_config->'qta'->'b'->>'r')::INT, 5)
      ELSE COALESCE((v_config->'qta'->'u'->>'r')::INT, 3)
    END;

    SELECT COUNT(*) INTO v_used
    FROM requests
    WHERE usr_id = p_user_uid AND i_del = 0;

    IF COALESCE(v_used, 0) >= COALESCE(v_limit, 3) THEN
      RAISE EXCEPTION 'QUOTA_EXCEEDED';
    END IF;
  END IF;

  RETURN QUERY
  INSERT INTO requests (
    typ, elm, cl_nm, cl_ph, prc, cur, notes, specs,
    usr_id, sts, matches, i_del, ts_crt
  ) VALUES (
    COALESCE((p_request->>'typ')::INT, 0),
    COALESCE((p_request->>'elm')::INT, 0),
    COALESCE(p_request->>'cl_nm', ''),
    COALESCE(p_request->>'cl_ph', ''),
    COALESCE((p_request->>'prc')::NUMERIC, 0),
    COALESCE((p_request->>'cur')::INT, 1),
    COALESCE(p_request->>'notes', ''),
    COALESCE(p_request->'specs', '{}'::jsonb),
    p_user_uid,
    0,
    COALESCE(p_request->'matches', '{}'::jsonb),
    0,
    NOW()
  ) RETURNING *;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_request_internal(
  p_user_uid UUID,
  p_request_id UUID,
  p_patch JSONB
)
RETURNS BOOLEAN AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  UPDATE requests
  SET typ = COALESCE((p_patch->>'typ')::INT, typ),
      elm = COALESCE((p_patch->>'elm')::INT, elm),
      cl_nm = COALESCE(NULLIF(p_patch->>'cl_nm', ''), cl_nm),
      cl_ph = COALESCE(NULLIF(p_patch->>'cl_ph', ''), cl_ph),
      prc = COALESCE((p_patch->>'prc')::NUMERIC, prc),
      cur = COALESCE((p_patch->>'cur')::INT, cur),
      notes = COALESCE(p_patch->>'notes', notes),
      specs = COALESCE(p_patch->'specs', specs)
  WHERE id = p_request_id
    AND usr_id = p_user_uid
    AND i_del = 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'REQUEST_NOT_FOUND_OR_NOT_ALLOWED';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION soft_delete_request_internal(
  p_user_uid UUID,
  p_request_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  UPDATE requests
  SET i_del = 1
  WHERE id = p_request_id
    AND usr_id = p_user_uid
    AND i_del = 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'REQUEST_NOT_FOUND_OR_NOT_ALLOWED';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_payment_internal(
  p_user_uid UUID,
  p_payment JSONB
)
RETURNS SETOF payments AS $$
DECLARE
  v_user users%ROWTYPE;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  SELECT * INTO v_user FROM users WHERE id = p_user_uid AND i_del = 0 AND sts = 0;
  IF v_user.id IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_ACTIVE_OR_NOT_FOUND';
  END IF;

  IF COALESCE(trim(p_payment->>'proof'), '') = '' OR COALESCE(trim(p_payment->>'ref'), '') = '' THEN
    RAISE EXCEPTION 'MISSING_PAYMENT_PROOF_OR_REFERENCE';
  END IF;

  RETURN QUERY
  INSERT INTO payments (
    uid, tp, pkg, amt, cur, mtd, channel, proof, ref, sts, appr_by, ts_crt
  ) VALUES (
    p_user_uid,
    COALESCE((p_payment->>'tp')::INT, 0),
    COALESCE((p_payment->>'pkg')::INT, 0),
    COALESCE((p_payment->>'amt')::NUMERIC, 0),
    COALESCE((p_payment->>'cur')::INT, 1),
    COALESCE((p_payment->>'mtd')::INT, 0),
    COALESCE(p_payment->>'channel', ''),
    COALESCE(p_payment->>'proof', ''),
    COALESCE(p_payment->>'ref', ''),
    0,
    NULL,
    NOW()
  ) RETURNING *;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_reject_payment_internal(
  p_admin_uid UUID,
  p_payment_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  UPDATE payments
  SET sts = 2,
      appr_by = p_admin_uid,
      ts_upd = NOW()
  WHERE id = p_payment_id
    AND sts = 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PAYMENT_NOT_PENDING_OR_NOT_FOUND';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_report_internal(
  p_reporter_uid UUID,
  p_report JSONB
)
RETURNS SETOF reports AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_reporter_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  RETURN QUERY
  INSERT INTO reports (
    rep_uid, tgt_uid, tgt_tp, tgt_id, rsn, det, sts, act, act_dur, note, act_by, ts_crt
  ) VALUES (
    p_reporter_uid,
    NULLIF(p_report->>'tgt_uid', '')::UUID,
    COALESCE((p_report->>'tgt_tp')::INT, 0),
    COALESCE(p_report->>'tgt_id', ''),
    COALESCE((p_report->>'rsn')::INT, 0),
    COALESCE(p_report->>'det', ''),
    0,
    0,
    0,
    '',
    NULL,
    NOW()
  ) RETURNING *;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_handle_report_internal(
  p_admin_uid UUID,
  p_report_id UUID,
  p_action INT,
  p_note TEXT DEFAULT '',
  p_duration INT DEFAULT 0
)
RETURNS BOOLEAN AS $$
DECLARE
  v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  UPDATE reports
  SET sts = 1,
      act = COALESCE(p_action, 0),
      act_dur = COALESCE(p_duration, 0),
      note = COALESCE(p_note, ''),
      act_by = p_admin_uid
  WHERE id = p_report_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'REPORT_NOT_FOUND';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION book_appointment_internal(
  p_user_uid UUID,
  p_offer_id UUID,
  p_dt TIMESTAMPTZ,
  p_broker_id UUID DEFAULT NULL,
  p_request_id UUID DEFAULT NULL
)
RETURNS SETOF appointments AS $$
DECLARE
  v_offer offers%ROWTYPE;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  SELECT * INTO v_offer FROM offers WHERE id = p_offer_id AND i_del = 0;
  IF v_offer.id IS NULL THEN
    RAISE EXCEPTION 'OFFER_NOT_FOUND';
  END IF;
  IF p_user_uid = v_offer.usr_id THEN
    RAISE EXCEPTION 'CANNOT_BOOK_OWN_OFFER';
  END IF;
  IF p_dt <= NOW() THEN
    RAISE EXCEPTION 'INVALID_APPOINTMENT_TIME';
  END IF;
  IF EXISTS (
    SELECT 1 FROM appointments
    WHERE off_id = p_offer_id
      AND req_uid = p_user_uid
      AND dt = p_dt
      AND sts IN (0, 1)
  ) THEN
    RAISE EXCEPTION 'DUPLICATE_APPOINTMENT';
  END IF;

  RETURN QUERY
  INSERT INTO appointments (
    off_id, req_id, req_uid, own_id, bkr_id, dt, sts,
    fbk_own, fbk_req, i_force, rmnd_24, rmnd_2, rmnd_qtr, rmnd_end, ts_crt
  ) VALUES (
    p_offer_id,
    p_request_id,
    p_user_uid,
    v_offer.usr_id,
    COALESCE(p_broker_id, NULLIF(v_offer.brk_id, '')),
    p_dt,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    NOW()
  ) RETURNING *;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION cancel_appointment_internal(
  p_requester_uid UUID,
  p_appointment_id UUID,
  p_reason TEXT DEFAULT ''
)
RETURNS BOOLEAN AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_requester_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  UPDATE appointments
  SET sts = 3,
      cnl_by = p_requester_uid,
      cnl_rsn = COALESCE(p_reason, ''),
      dt_end = NOW()
  WHERE id = p_appointment_id
    AND req_uid = p_requester_uid
    AND sts IN (0, 1);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'APPOINTMENT_NOT_FOUND_OR_NOT_ALLOWED';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION broker_handle_appointment_internal(
  p_broker_uid UUID,
  p_appointment_id UUID,
  p_action TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
  v_allowed BOOLEAN := FALSE;
  v_now TIMESTAMPTZ := NOW();
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_broker_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM appointments a
    LEFT JOIN offers o ON o.id = a.off_id
    WHERE a.id = p_appointment_id
      AND (a.bkr_id = p_broker_uid OR a.own_id = p_broker_uid OR o.usr_id = p_broker_uid)
  ) INTO v_allowed;

  IF NOT v_allowed THEN
    RAISE EXCEPTION 'APPOINTMENT_NOT_FOUND_OR_NOT_ALLOWED';
  END IF;

  IF p_action = 'confirm' THEN
    UPDATE appointments
    SET sts = 1,
        fbk_own = 1,
        fbk_own_dt = v_now
    WHERE id = p_appointment_id;
  ELSIF p_action = 'reject' THEN
    UPDATE appointments
    SET sts = 4,
        fbk_own = 2,
        fbk_own_dt = v_now,
        dt_end = v_now
    WHERE id = p_appointment_id;
  ELSIF p_action = 'complete' THEN
    UPDATE appointments
    SET sts = 2,
        dt_end = v_now
    WHERE id = p_appointment_id;
  ELSE
    RAISE EXCEPTION 'INVALID_ACTION';
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_update_appointment_status_internal(
  p_admin_uid UUID,
  p_appointment_id UUID,
  p_status INT,
  p_admin_note TEXT DEFAULT ''
)
RETURNS BOOLEAN AS $$
DECLARE
  v_role INT;
  v_requester_uid UUID;
  v_cancel_count INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  SELECT req_uid INTO v_requester_uid FROM appointments WHERE id = p_appointment_id;

  UPDATE appointments
  SET sts = p_status,
      admin_nt = CASE WHEN COALESCE(trim(p_admin_note), '') = '' THEN admin_nt ELSE p_admin_note END,
      dt_end = CASE WHEN p_status >= 2 THEN NOW() ELSE dt_end END
  WHERE id = p_appointment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'APPOINTMENT_NOT_FOUND';
  END IF;

  IF p_status = 5 AND v_requester_uid IS NOT NULL THEN
    PERFORM add_points(v_requester_uid, -500);
  ELSIF p_status = 3 AND v_requester_uid IS NOT NULL THEN
    SELECT COUNT(*) INTO v_cancel_count
    FROM appointments
    WHERE req_uid = v_requester_uid
      AND sts = 3
      AND ts_crt >= NOW() - INTERVAL '30 days';
    IF v_cancel_count > 0 AND MOD(v_cancel_count, 3) = 0 THEN
      PERFORM add_points(v_requester_uid, -300);
    END IF;
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_force_appointment_internal(
  p_admin_uid UUID,
  p_appointment_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  UPDATE appointments
  SET i_force = 1,
      force_by = p_admin_uid,
      sts = 1
  WHERE id = p_appointment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'APPOINTMENT_NOT_FOUND';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_deal_internal(
  p_admin_uid UUID,
  p_deal JSONB
)
RETURNS SETOF deals AS $$
DECLARE
  v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  RETURN QUERY
  INSERT INTO deals (
    off_id, app_id, sell_uid, buy_uid, brk_uid, fin_prc, cur,
    com_pct, com_val, com_note, form, sts, cmpl_by, i_del, ts_crt, ts_cmpl
  ) VALUES (
    NULLIF(p_deal->>'off_id', '')::UUID,
    NULLIF(p_deal->>'app_id', '')::UUID,
    NULLIF(p_deal->>'sell_uid', '')::UUID,
    NULLIF(p_deal->>'buy_uid', '')::UUID,
    NULLIF(p_deal->>'brk_uid', '')::UUID,
    COALESCE((p_deal->>'fin_prc')::NUMERIC, 0),
    COALESCE((p_deal->>'cur')::INT, 1),
    COALESCE((p_deal->>'com_pct')::NUMERIC, 0),
    COALESCE((p_deal->>'com_val')::NUMERIC, 0),
    NULLIF(p_deal->>'com_note', ''),
    COALESCE(p_deal->'form', '{}'::jsonb),
    COALESCE((p_deal->>'sts')::INT, 0),
    NULL,
    0,
    NOW(),
    NULL
  ) RETURNING *;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION complete_deal_internal(
  p_admin_uid UUID,
  p_deal_id UUID,
  p_commission NUMERIC DEFAULT NULL,
  p_note TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  UPDATE deals
  SET sts = 1,
      cmpl_by = p_admin_uid,
      ts_cmpl = NOW(),
      com_val = COALESCE(p_commission, com_val),
      com_note = COALESCE(p_note, com_note)
  WHERE id = p_deal_id
    AND i_del = 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'DEAL_NOT_FOUND';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION mark_notification_read_internal(
  p_user_uid UUID,
  p_notification_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  UPDATE notifications
  SET i_rd = 1
  WHERE id = p_notification_id
    AND uid = p_user_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'NOTIFICATION_NOT_FOUND_OR_NOT_ALLOWED';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION mark_all_notifications_read_internal(p_user_uid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  UPDATE notifications
  SET i_rd = 1
  WHERE uid = p_user_uid AND i_rd = 0;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_rating_internal(
  p_reviewer_uid UUID,
  p_target_uid UUID,
  p_stars INT,
  p_comment TEXT DEFAULT ''
)
RETURNS BOOLEAN AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_reviewer_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  INSERT INTO ratings (reviewer_uid, target_uid, stars, comment)
  VALUES (p_reviewer_uid, p_target_uid, p_stars, COALESCE(p_comment, ''));
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION register_daily_streak_internal(
  p_user_uid UUID,
  p_points INT DEFAULT 50
)
RETURNS JSONB AS $$
DECLARE
  v_current_streak INT := 0;
  v_last_ts TIMESTAMPTZ;
  v_now TIMESTAMPTZ := NOW();
  v_today TEXT;
  v_last_day TEXT;
  v_new_streak INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  SELECT COALESCE(strk, 0), strk_dt INTO v_current_streak, v_last_ts
  FROM users
  WHERE id = p_user_uid
    AND i_del = 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;

  v_today := to_char((v_now AT TIME ZONE 'UTC' + INTERVAL '3 hours')::date, 'YYYY-MM-DD');
  IF v_last_ts IS NOT NULL THEN
    v_last_day := to_char((v_last_ts AT TIME ZONE 'UTC' + INTERVAL '3 hours')::date, 'YYYY-MM-DD');
  END IF;

  IF v_last_day = v_today THEN
    RETURN jsonb_build_object('streak', v_current_streak, 'changed', false, 'awarded', false);
  END IF;

  v_new_streak := CASE WHEN v_last_day IS NULL THEN 1 ELSE v_current_streak + 1 END;

  UPDATE users
  SET strk = v_new_streak,
      strk_dt = v_now,
      ts_upd = v_now
  WHERE id = p_user_uid;

  PERFORM add_points(p_user_uid, p_points);

  RETURN jsonb_build_object('streak', v_new_streak, 'changed', true, 'awarded', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_user_profile_internal(
  p_user_uid UUID,
  p_payload JSONB
)
RETURNS BOOLEAN AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  UPDATE users
  SET nm = COALESCE(p_payload->>'nm', nm),
      sid = COALESCE(p_payload->>'sid', sid),
      ad = COALESCE(p_payload->>'ad', ad),
      img = COALESCE(p_payload->>'img', img),
      ts_upd = NOW()
  WHERE id = p_user_uid
    AND i_del = 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_user_notification_settings_internal(
  p_user_uid UUID,
  p_ntf JSONB
)
RETURNS BOOLEAN AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  IF jsonb_typeof(COALESCE(p_ntf, '{}'::jsonb)) <> 'object' THEN
    RAISE EXCEPTION 'INVALID_NOTIFICATION_SETTINGS';
  END IF;

  UPDATE users
  SET ntf = p_ntf,
      ts_upd = NOW()
  WHERE id = p_user_uid
    AND i_del = 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION submit_broker_request_internal(
  p_user_uid UUID,
  p_business_name TEXT,
  p_category INT,
  p_experience TEXT DEFAULT '',
  p_about TEXT DEFAULT ''
)
RETURNS BOOLEAN AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  UPDATE users
  SET brk_nm = COALESCE(p_business_name, ''),
      brk_cls = COALESCE(p_category, 0),
      vrf = CASE WHEN vrf = 0 THEN 1 ELSE vrf END,
      ts_upd = NOW()
  WHERE id = p_user_uid
    AND i_del = 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;

  INSERT INTO activity_log (uid, action, details, ts_crt)
  VALUES (
    p_user_uid,
    'broker_request',
    jsonb_build_object(
      'business_name', COALESCE(p_business_name, ''),
      'category', COALESCE(p_category, 0),
      'experience', COALESCE(p_experience, ''),
      'about', COALESCE(p_about, '')
    ),
    NOW()
  );

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION mark_social_published_internal(
  p_user_uid UUID,
  p_offer_id UUID,
  p_text TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  UPDATE offers
  SET soc_pub = 1,
      soc_txt = COALESCE(p_text, ''),
      ts_upd = NOW()
  WHERE id = p_offer_id
    AND usr_id = p_user_uid
    AND i_del = 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'OFFER_NOT_FOUND_OR_NOT_ALLOWED';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION increment_offer_views_internal(p_offer_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE offers
  SET vws = COALESCE(vws, 0) + 1
  WHERE id = p_offer_id
    AND i_del = 0
    AND i_pub = 1;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_offer_by_id_internal(UUID, UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_user_offers_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_user_requests_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_user_payments_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_user_notifications_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_user_appointments_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_owner_appointments_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_broker_offers_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_broker_appointments_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_broker_deals_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_admin_pending_offers_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_admin_offers_internal(UUID, INT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_admin_appointments_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_admin_deals_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_admin_payments_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_admin_reports_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_review_offer_internal(UUID, UUID, BOOLEAN, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION create_request_internal(UUID, JSONB) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION update_request_internal(UUID, UUID, JSONB) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION soft_delete_request_internal(UUID, UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION create_payment_internal(UUID, JSONB) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_reject_payment_internal(UUID, UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION create_report_internal(UUID, JSONB) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_handle_report_internal(UUID, UUID, INT, TEXT, INT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION book_appointment_internal(UUID, UUID, TIMESTAMPTZ, UUID, UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cancel_appointment_internal(UUID, UUID, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION broker_handle_appointment_internal(UUID, UUID, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_update_appointment_status_internal(UUID, UUID, INT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_force_appointment_internal(UUID, UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION create_deal_internal(UUID, JSONB) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION complete_deal_internal(UUID, UUID, NUMERIC, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION mark_notification_read_internal(UUID, UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION mark_all_notifications_read_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION create_rating_internal(UUID, UUID, INT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION register_daily_streak_internal(UUID, INT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION update_user_profile_internal(UUID, JSONB) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION update_user_notification_settings_internal(UUID, JSONB) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION submit_broker_request_internal(UUID, TEXT, INT, TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION mark_social_published_internal(UUID, UUID, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION increment_offer_views_internal(UUID) TO anon, authenticated;

-- END supabase/migrations/2026_06_11_real_test_stabilization_internal_rpcs.sql
