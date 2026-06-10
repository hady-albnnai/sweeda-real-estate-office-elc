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
