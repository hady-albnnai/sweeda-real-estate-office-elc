-- ════════════════════════════════════════════════════════════════════════════
-- QA System Check v3 — maximum safe read-only coverage
-- Date: 2026-06-10
-- Notes:
--   - Uses severity: critical / warning / info.
--   - Overall ok fails only on critical checks with ok=false.
--   - Avoids writing test data.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION qa_system_check(p_admin_uid UUID)
RETURNS JSONB AS $$
DECLARE
  v_admin_role INT;
  v_admin_perm JSONB := '[]'::jsonb;
  v_checks JSONB := '[]'::jsonb;
  v_ok BOOLEAN;
  v_name TEXT;
  v_count INT := 0;
  v_count2 INT := 0;
  v_config JSONB := '{}'::jsonb;
  v_duplicate_phones INT := 0;
  v_total_users INT := 0;
  v_total_offers INT := 0;
  v_total_photo_tasks INT := 0;
  v_pending_offers INT := 0;
  v_pending_payments INT := 0;
  v_open_reports INT := 0;
  v_pending_verifications INT := 0;
  v_critical_failed INT := 0;
  v_warning_failed INT := 0;
  v_info_count INT := 0;
BEGIN
  SELECT role, COALESCE(perm, '[]'::jsonb)
  INTO v_admin_role, v_admin_perm
  FROM users
  WHERE id = p_admin_uid
    AND i_del = 0;

  v_checks := v_checks || jsonb_build_object(
    'name', 'auth/admin: current admin identity',
    'ok', COALESCE(v_admin_role >= 2, FALSE),
    'severity', 'critical',
    'category', 'auth',
    'details', COALESCE('role=' || v_admin_role::TEXT || ', perm_items=' || jsonb_array_length(v_admin_perm)::TEXT, 'admin user not found')
  );

  -- Tables
  FOREACH v_name IN ARRAY ARRAY[
    'users', 'offers', 'requests', 'appointments', 'notifications', 'payments',
    'reports', 'deals', 'activity_log', 'stats', 'app_config', 'otp_codes',
    'user_devices', 'photography_tasks', 'ratings'
  ]
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = v_name
    ) INTO v_ok;
    v_checks := v_checks || jsonb_build_object(
      'name', 'schema/table: ' || v_name,
      'ok', v_ok,
      'severity', 'critical',
      'category', 'schema',
      'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- Columns
  FOREACH v_name IN ARRAY ARRAY[
    'users.id', 'users.nm', 'users.ph', 'users.eml', 'users.role', 'users.sts',
    'users.i_del', 'users.perm', 'users.vrf', 'users.device_id', 'users.stats',
    'offers.id', 'offers.usr_id', 'offers.typ', 'offers.trx', 'offers.ttl',
    'offers.prc', 'offers.cur', 'offers.loc', 'offers.imgs', 'offers.vdo', 'offers.doc_img',
    'offers.exact_loc', 'offers.specs', 'offers.sts', 'offers.i_pub', 'offers.i_del',
    'appointments.id', 'appointments.off_id', 'appointments.own_id', 'appointments.bkr_id',
    'appointments.dt', 'appointments.sts', 'appointments.cnl_rsn',
    'payments.id', 'payments.uid', 'payments.sts', 'payments.channel', 'payments.proof',
    'reports.id', 'reports.rep_uid', 'reports.tgt_uid', 'reports.tgt_id', 'reports.sts',
    'photography_tasks.id', 'photography_tasks.off_id', 'photography_tasks.photographer_id',
    'photography_tasks.media', 'photography_tasks.sts', 'photography_tasks.ts_submit', 'photography_tasks.office_note',
    'notifications.id', 'notifications.uid', 'notifications.i_rd', 'notifications.i_del'
  ]
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = split_part(v_name, '.', 1)
        AND column_name = split_part(v_name, '.', 2)
    ) INTO v_ok;
    v_checks := v_checks || jsonb_build_object(
      'name', 'schema/column: ' || v_name,
      'ok', v_ok,
      'severity', 'critical',
      'category', 'schema',
      'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- Functions
  FOREACH v_name IN ARRAY ARRAY[
    'normalize_sy_phone',
    'generate_otp',
    'verify_otp',
    'generate_otp_v2',
    'verify_otp_v2',
    'upsert_user_after_otp',
    'get_user_full_by_id',
    'get_user_by_phone',
    'get_user_by_email',
    'create_user_from_phone',
    'admin_update_user_role',
    'admin_set_user_status',
    'admin_update_user_permissions',
    'admin_update_user_permissions_by_admin',
    'create_offer_internal',
    'check_offer_duplicate',
    'add_points',
    'award_points_safe',
    'update_user_badge',
    'register_weekly_login',
    'apply_referral',
    'purchase_offer_boost',
    'expire_offer_boosts',
    'approve_payment_final',
    'notify_user',
    'get_user_device_tokens',
    'send_push_notification',
    'admin_approve_verification',
    'admin_reject_verification',
    'admin_fraud_suspects',
    'request_verification',
    'register_device',
    'create_photography_task_internal',
    'submit_photography_task_internal',
    'update_photography_task_status_internal',
    'attach_photography_media_to_offer_internal',
    'qa_system_check'
  ]
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proname = v_name
    ) INTO v_ok;
    v_checks := v_checks || jsonb_build_object(
      'name', 'rpc/function: ' || v_name,
      'ok', v_ok,
      'severity', CASE WHEN v_name IN ('generate_otp_v2','verify_otp_v2','send_push_notification') THEN 'warning' ELSE 'critical' END,
      'category', 'rpc',
      'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- Function content checks
  SELECT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'upsert_user_after_otp'
      AND pg_get_functiondef(p.oid) ILIKE '%normalize_sy_phone%'
  ) INTO v_ok;
  v_checks := v_checks || jsonb_build_object(
    'name', 'rpc/content: upsert_user_after_otp normalizes phone',
    'ok', v_ok,
    'severity', 'critical',
    'category', 'rpc',
    'details', CASE WHEN v_ok THEN 'uses normalize_sy_phone' ELSE 'does not normalize phone' END
  );

  SELECT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'admin_update_user_permissions'
      AND pg_get_functiondef(p.oid) ILIKE '%photographer_tasks%'
      AND pg_get_functiondef(p.oid) ILIKE '%photography_management%'
  ) INTO v_ok;
  v_checks := v_checks || jsonb_build_object(
    'name', 'rpc/content: permissions include photography keys',
    'ok', v_ok,
    'severity', 'critical',
    'category', 'rpc',
    'details', CASE WHEN v_ok THEN 'photography keys present' ELSE 'photography keys missing' END
  );

  SELECT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'create_offer_internal'
      AND pg_get_functiondef(p.oid) ILIKE '%SECURITY DEFINER%'
  ) INTO v_ok;
  v_checks := v_checks || jsonb_build_object(
    'name', 'rpc/security: create_offer_internal security definer',
    'ok', v_ok,
    'severity', 'critical',
    'category', 'security',
    'details', CASE WHEN v_ok THEN 'security definer' ELSE 'not security definer / missing' END
  );

  -- RLS
  FOREACH v_name IN ARRAY ARRAY[
    'users', 'offers', 'requests', 'appointments', 'notifications', 'payments',
    'reports', 'deals', 'activity_log', 'app_config', 'photography_tasks', 'ratings', 'user_devices'
  ]
  LOOP
    SELECT COALESCE(c.relrowsecurity, FALSE)
    INTO v_ok
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = v_name;

    v_checks := v_checks || jsonb_build_object(
      'name', 'security/rls: ' || v_name,
      'ok', COALESCE(v_ok, FALSE),
      'severity', CASE WHEN v_name IN ('stats') THEN 'warning' ELSE 'critical' END,
      'category', 'security',
      'details', CASE WHEN COALESCE(v_ok, FALSE) THEN 'enabled' ELSE 'disabled/missing' END
    );
  END LOOP;

  -- Policy counts per sensitive table
  FOREACH v_name IN ARRAY ARRAY['users', 'offers', 'payments', 'reports', 'photography_tasks', 'notifications', 'ratings', 'user_devices']
  LOOP
    SELECT COUNT(*) INTO v_count
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = v_name;

    v_checks := v_checks || jsonb_build_object(
      'name', 'security/policies: ' || v_name,
      'ok', v_count > 0,
      'severity', 'critical',
      'category', 'security',
      'details', 'policies=' || v_count::TEXT
    );
  END LOOP;

  -- Indexes
  FOREACH v_name IN ARRAY ARRAY[
    'ux_users_normalized_phone_active',
    'idx_users_role',
    'idx_users_sts',
    'idx_users_iDel',
    'idx_offers_usr',
    'idx_offers_sts',
    'idx_offers_ipub',
    'idx_offers_typ',
    'idx_offers_trx',
    'idx_requests_usr',
    'idx_requests_sts',
    'idx_photo_tasks_offer',
    'idx_photo_tasks_photographer',
    'idx_photo_tasks_status'
  ]
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM pg_indexes
      WHERE schemaname = 'public' AND lower(indexname) = lower(v_name)
    ) INTO v_ok;
    v_checks := v_checks || jsonb_build_object(
      'name', 'performance/index: ' || v_name,
      'ok', v_ok,
      'severity', CASE WHEN v_name IN ('idx_photo_tasks_offer','idx_photo_tasks_photographer','idx_photo_tasks_status') THEN 'critical' ELSE 'warning' END,
      'category', 'performance',
      'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- Storage buckets
  FOREACH v_name IN ARRAY ARRAY['offer_images', 'config_assets', 'payment_proofs', 'ids_private']
  LOOP
    SELECT EXISTS (SELECT 1 FROM storage.buckets WHERE id = v_name) INTO v_ok;
    v_checks := v_checks || jsonb_build_object(
      'name', 'storage/bucket: ' || v_name,
      'ok', v_ok,
      'severity', 'critical',
      'category', 'storage',
      'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- Storage public/private expectations
  FOREACH v_name IN ARRAY ARRAY['offer_images:true', 'config_assets:true', 'payment_proofs:false', 'ids_private:false']
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM storage.buckets
      WHERE id = split_part(v_name, ':', 1)
        AND public = (split_part(v_name, ':', 2))::BOOLEAN
    ) INTO v_ok;
    v_checks := v_checks || jsonb_build_object(
      'name', 'storage/visibility: ' || split_part(v_name, ':', 1),
      'ok', v_ok,
      'severity', 'warning',
      'category', 'storage',
      'details', 'expected public=' || split_part(v_name, ':', 2)
    );
  END LOOP;

  -- Config main
  SELECT value INTO v_config FROM app_config WHERE key = 'main' LIMIT 1;
  v_ok := v_config IS NOT NULL;
  v_checks := v_checks || jsonb_build_object(
    'name', 'config: app_config/main exists',
    'ok', v_ok,
    'severity', 'critical',
    'category', 'config',
    'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
  );

  FOREACH v_name IN ARRAY ARRAY[
    'pts', 'pen', 'spd', 'bdg', 'pkg', 'com', 'qta', 'soc', 'ads',
    'rptRsn', 'txts', 'catProp', 'catVeh', 'docTp', 'locs', 'brnds',
    'clrs', 'roles', 'payChannels'
  ]
  LOOP
    v_ok := v_config ? v_name;
    v_checks := v_checks || jsonb_build_object(
      'name', 'config/key: ' || v_name,
      'ok', COALESCE(v_ok, FALSE),
      'severity', CASE WHEN v_name = 'locs' THEN 'warning' ELSE 'critical' END,
      'category', 'config',
      'details', CASE WHEN COALESCE(v_ok, FALSE) THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- Config deep checks
  FOREACH v_name IN ARRAY ARRAY[
    'pkg.0', 'pkg.1', 'pkg.2',
    'qta.u', 'qta.b',
    'pts.sgn', 'pts.addO', 'pts.wkL',
    'catProp', 'catVeh', 'docTp', 'payChannels'
  ]
  LOOP
    IF v_name = 'catProp' THEN
      v_ok := jsonb_typeof(v_config->'catProp') = 'object' AND (SELECT COUNT(*) FROM jsonb_object_keys(v_config->'catProp')) > 0;
    ELSIF v_name = 'catVeh' THEN
      v_ok := jsonb_typeof(v_config->'catVeh') = 'object' AND (SELECT COUNT(*) FROM jsonb_object_keys(v_config->'catVeh')) > 0;
    ELSIF v_name = 'docTp' THEN
      v_ok := jsonb_typeof(v_config->'docTp') = 'object' AND (SELECT COUNT(*) FROM jsonb_object_keys(v_config->'docTp')) > 0;
    ELSIF v_name = 'payChannels' THEN
      v_ok := jsonb_typeof(v_config->'payChannels') = 'object' AND (SELECT COUNT(*) FROM jsonb_object_keys(v_config->'payChannels')) > 0;
    ELSE
      v_ok := v_config #> string_to_array(v_name, '.') IS NOT NULL;
    END IF;

    v_checks := v_checks || jsonb_build_object(
      'name', 'config/deep: ' || v_name,
      'ok', COALESCE(v_ok, FALSE),
      'severity', 'warning',
      'category', 'config',
      'details', CASE WHEN COALESCE(v_ok, FALSE) THEN 'valid/present' ELSE 'missing/empty' END
    );
  END LOOP;

  -- Duplicate normalized phones
  SELECT COUNT(*) INTO v_duplicate_phones
  FROM (
    SELECT normalize_sy_phone(ph)
    FROM users
    WHERE i_del = 0 AND COALESCE(ph, '') <> ''
    GROUP BY normalize_sy_phone(ph)
    HAVING COUNT(*) > 1
  ) d;
  v_checks := v_checks || jsonb_build_object(
    'name', 'data/users: duplicate normalized phones',
    'ok', v_duplicate_phones = 0,
    'severity', 'critical',
    'category', 'data',
    'details', 'duplicates=' || v_duplicate_phones::TEXT
  );

  -- Core counts
  SELECT COUNT(*) INTO v_total_users FROM users WHERE i_del = 0;
  SELECT COUNT(*) INTO v_total_offers FROM offers WHERE i_del = 0;
  SELECT COUNT(*) INTO v_total_photo_tasks FROM photography_tasks;
  SELECT COUNT(*) INTO v_pending_offers FROM offers WHERE i_del = 0 AND sts IN (0, 1);
  SELECT COUNT(*) INTO v_pending_payments FROM payments WHERE sts = 0;
  SELECT COUNT(*) INTO v_open_reports FROM reports WHERE sts = 0;
  SELECT COUNT(*) INTO v_pending_verifications FROM users WHERE i_del = 0 AND vrf = 1;

  v_checks := v_checks || jsonb_build_object('name', 'data/count: active users', 'ok', v_total_users >= 0, 'severity', 'info', 'category', 'data', 'details', v_total_users::TEXT);
  v_checks := v_checks || jsonb_build_object('name', 'data/count: active offers', 'ok', v_total_offers >= 0, 'severity', 'info', 'category', 'data', 'details', v_total_offers::TEXT);
  v_checks := v_checks || jsonb_build_object('name', 'data/count: photography tasks', 'ok', v_total_photo_tasks >= 0, 'severity', 'info', 'category', 'data', 'details', v_total_photo_tasks::TEXT);

  -- User data integrity
  SELECT COUNT(*) INTO v_count
  FROM users
  WHERE i_del = 0
    AND COALESCE(ph, '') = ''
    AND COALESCE(eml, '') = '';
  v_checks := v_checks || jsonb_build_object('name', 'data/users: no contact method', 'ok', v_count = 0, 'severity', 'warning', 'category', 'data', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM users
  WHERE i_del = 0
    AND (role < 0 OR role > 4);
  v_checks := v_checks || jsonb_build_object('name', 'data/users: invalid role range', 'ok', v_count = 0, 'severity', 'critical', 'category', 'data', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM users
  WHERE i_del = 0
    AND (sts < 0 OR sts > 2);
  v_checks := v_checks || jsonb_build_object('name', 'data/users: invalid status range', 'ok', v_count = 0, 'severity', 'critical', 'category', 'data', 'details', 'count=' || v_count::TEXT);

  -- Unknown permission keys
  SELECT COUNT(*) INTO v_count
  FROM users u,
       jsonb_array_elements_text(COALESCE(u.perm, '[]'::jsonb)) perm_key
  WHERE u.i_del = 0
    AND perm_key NOT IN (
      'admin_dashboard','office_operations','manage_users','manage_permissions',
      'review_offers','review_verifications','media_review','photography_management',
      'photographer_tasks','fraud_suspects','manage_appointments','manage_deals',
      'manage_payments','manage_reports','manage_config','view_analytics',
      'broker_dashboard','broker_offers','broker_appointments','broker_deals','broker_stats',
      'user_home','user_offers','user_requests','user_appointments','user_profile'
    );
  v_checks := v_checks || jsonb_build_object('name', 'data/users: unknown permission keys', 'ok', v_count = 0, 'severity', 'critical', 'category', 'permissions', 'details', 'count=' || v_count::TEXT);

  -- Offers integrity
  SELECT COUNT(*) INTO v_count
  FROM offers o
  LEFT JOIN users u ON u.id = o.usr_id
  WHERE o.i_del = 0
    AND (o.usr_id IS NULL OR u.id IS NULL OR u.i_del = 1);
  v_checks := v_checks || jsonb_build_object('name', 'data/offers: orphan owner', 'ok', v_count = 0, 'severity', 'critical', 'category', 'data', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM offers
  WHERE i_del = 0
    AND (sts < 0 OR sts > 6);
  v_checks := v_checks || jsonb_build_object('name', 'data/offers: invalid status range', 'ok', v_count = 0, 'severity', 'critical', 'category', 'data', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM offers
  WHERE i_del = 0
    AND i_pub = 1
    AND jsonb_array_length(COALESCE(imgs, '[]'::jsonb)) = 0;
  v_checks := v_checks || jsonb_build_object('name', 'data/offers: published without images', 'ok', v_count = 0, 'severity', 'warning', 'category', 'media', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM offers
  WHERE i_del = 0
    AND i_pub = 1
    AND (loc IS NULL OR COALESCE(loc->>'d', '') = '');
  v_checks := v_checks || jsonb_build_object('name', 'data/offers: published without location text', 'ok', v_count = 0, 'severity', 'warning', 'category', 'data', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM offers,
       jsonb_array_elements_text(COALESCE(imgs, '[]'::jsonb)) img_url
  WHERE i_del = 0
    AND (img_url IS NULL OR length(trim(img_url)) = 0 OR img_url NOT ILIKE 'http%');
  v_checks := v_checks || jsonb_build_object('name', 'data/offers: invalid image URLs', 'ok', v_count = 0, 'severity', 'warning', 'category', 'media', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM offers
  WHERE i_del = 0
    AND COALESCE(vdo, '') <> ''
    AND vdo NOT ILIKE 'http%';
  v_checks := v_checks || jsonb_build_object('name', 'data/offers: invalid video URLs', 'ok', v_count = 0, 'severity', 'warning', 'category', 'media', 'details', 'count=' || v_count::TEXT);

  -- Appointments integrity
  SELECT COUNT(*) INTO v_count
  FROM appointments a
  LEFT JOIN offers o ON o.id = a.off_id
  WHERE a.off_id IS NOT NULL
    AND (o.id IS NULL OR o.i_del = 1);
  v_checks := v_checks || jsonb_build_object('name', 'data/appointments: orphan offer', 'ok', v_count = 0, 'severity', 'critical', 'category', 'data', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM appointments
  WHERE sts < 0 OR sts > 5;
  v_checks := v_checks || jsonb_build_object('name', 'data/appointments: invalid status range', 'ok', v_count = 0, 'severity', 'critical', 'category', 'data', 'details', 'count=' || v_count::TEXT);

  -- Payments/reports integrity
  SELECT COUNT(*) INTO v_count
  FROM payments p
  LEFT JOIN users u ON u.id = p.uid
  WHERE p.uid IS NOT NULL
    AND (u.id IS NULL OR u.i_del = 1);
  v_checks := v_checks || jsonb_build_object('name', 'data/payments: orphan user', 'ok', v_count = 0, 'severity', 'warning', 'category', 'data', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM payments
  WHERE sts < 0 OR sts > 3;
  v_checks := v_checks || jsonb_build_object('name', 'data/payments: invalid status range', 'ok', v_count = 0, 'severity', 'critical', 'category', 'data', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM reports
  WHERE sts < 0 OR sts > 1;
  v_checks := v_checks || jsonb_build_object('name', 'data/reports: invalid status range', 'ok', v_count = 0, 'severity', 'critical', 'category', 'data', 'details', 'count=' || v_count::TEXT);

  -- Photography integrity
  SELECT COUNT(*) INTO v_count
  FROM photography_tasks pt
  LEFT JOIN offers o ON o.id = pt.off_id
  WHERE o.id IS NULL OR o.i_del = 1;
  v_checks := v_checks || jsonb_build_object('name', 'data/photography: orphan offer', 'ok', v_count = 0, 'severity', 'critical', 'category', 'photography', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM photography_tasks pt
  LEFT JOIN users u ON u.id = pt.photographer_id
  WHERE pt.photographer_id IS NOT NULL
    AND (u.id IS NULL OR u.i_del = 1);
  v_checks := v_checks || jsonb_build_object('name', 'data/photography: missing photographer user', 'ok', v_count = 0, 'severity', 'critical', 'category', 'photography', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM photography_tasks
  WHERE sts < 0 OR sts > 5;
  v_checks := v_checks || jsonb_build_object('name', 'data/photography: invalid status range', 'ok', v_count = 0, 'severity', 'critical', 'category', 'photography', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM photography_tasks
  WHERE sts = 2
    AND jsonb_array_length(COALESCE(media, '[]'::jsonb)) = 0;
  v_checks := v_checks || jsonb_build_object('name', 'data/photography: submitted without media', 'ok', v_count = 0, 'severity', 'warning', 'category', 'photography', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM photography_tasks,
       jsonb_array_elements_text(COALESCE(media, '[]'::jsonb)) media_url
  WHERE media_url IS NULL OR length(trim(media_url)) = 0 OR media_url NOT ILIKE 'http%';
  v_checks := v_checks || jsonb_build_object('name', 'data/photography: invalid media URLs', 'ok', v_count = 0, 'severity', 'warning', 'category', 'photography', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM photography_tasks pt
  JOIN users u ON u.id = pt.photographer_id
  WHERE pt.photographer_id IS NOT NULL
    AND u.i_del = 0
    AND NOT (COALESCE(u.perm, '[]'::jsonb) ? 'photographer_tasks');
  v_checks := v_checks || jsonb_build_object('name', 'data/photography: assigned user lacks photographer_tasks', 'ok', v_count = 0, 'severity', 'warning', 'category', 'permissions', 'details', 'count=' || v_count::TEXT);

  -- Queues as info
  SELECT COUNT(*) INTO v_count FROM payments WHERE sts = 0;
  v_checks := v_checks || jsonb_build_object('name', 'queue/payments: pending approvals', 'ok', TRUE, 'severity', 'info', 'category', 'queue', 'details', 'pending=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count FROM reports WHERE sts = 0;
  v_checks := v_checks || jsonb_build_object('name', 'queue/reports: open reports', 'ok', TRUE, 'severity', 'info', 'category', 'queue', 'details', 'open=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count FROM offers WHERE i_del = 0 AND sts IN (0, 1);
  v_checks := v_checks || jsonb_build_object('name', 'queue/offers: pending review', 'ok', TRUE, 'severity', 'info', 'category', 'queue', 'details', 'pending=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count FROM users WHERE i_del = 0 AND vrf = 1;
  v_checks := v_checks || jsonb_build_object('name', 'queue/verifications: pending review', 'ok', TRUE, 'severity', 'info', 'category', 'queue', 'details', 'pending=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count FROM photography_tasks WHERE sts = 2;
  SELECT COUNT(*) INTO v_count2 FROM photography_tasks WHERE sts = 4;
  v_checks := v_checks || jsonb_build_object('name', 'queue/photography: submitted and rejected', 'ok', TRUE, 'severity', 'info', 'category', 'queue', 'details', 'submitted=' || v_count::TEXT || ', rejected=' || v_count2::TEXT);

  -- Severity summary
  SELECT COUNT(*) INTO v_critical_failed
  FROM jsonb_array_elements(v_checks) item
  WHERE COALESCE((item->>'ok')::BOOLEAN, FALSE) = FALSE
    AND COALESCE(item->>'severity', 'critical') = 'critical';

  SELECT COUNT(*) INTO v_warning_failed
  FROM jsonb_array_elements(v_checks) item
  WHERE COALESCE((item->>'ok')::BOOLEAN, FALSE) = FALSE
    AND COALESCE(item->>'severity', 'critical') = 'warning';

  SELECT COUNT(*) INTO v_info_count
  FROM jsonb_array_elements(v_checks) item
  WHERE COALESCE(item->>'severity', 'critical') = 'info';

  RETURN jsonb_build_object(
    'ok', v_critical_failed = 0,
    'generated_at', NOW(),
    'summary', jsonb_build_object(
      'users', v_total_users,
      'offers', v_total_offers,
      'photography_tasks', v_total_photo_tasks,
      'pending_offers', v_pending_offers,
      'pending_payments', v_pending_payments,
      'open_reports', v_open_reports,
      'pending_verifications', v_pending_verifications,
      'duplicate_phones', v_duplicate_phones,
      'critical_failed', v_critical_failed,
      'warning_failed', v_warning_failed,
      'info_count', v_info_count,
      'total_checks', jsonb_array_length(v_checks)
    ),
    'checks', v_checks
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION qa_system_check(UUID) TO anon, authenticated;
