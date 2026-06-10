-- ════════════════════════════════════════════════════════════════════════════
-- Extended QA system check RPC
-- Date: 2026-06-10
-- Purpose:
--   Expands /admin/qa to cover schema, functions, RLS, storage, config,
--   and data-integrity checks.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION qa_system_check(p_admin_uid UUID)
RETURNS JSONB AS $$
DECLARE
  v_admin_role INT;
  v_checks JSONB := '[]'::jsonb;
  v_ok BOOLEAN;
  v_name TEXT;
  v_count INT := 0;
  v_text TEXT;
  v_config JSONB := '{}'::jsonb;
  v_duplicate_phones INT := 0;
  v_total_users INT := 0;
  v_total_offers INT := 0;
  v_total_photo_tasks INT := 0;
  v_pending_offers INT := 0;
  v_pending_payments INT := 0;
  v_open_reports INT := 0;
  v_pending_verifications INT := 0;
BEGIN
  SELECT role INTO v_admin_role
  FROM users
  WHERE id = p_admin_uid
    AND i_del = 0;

  v_checks := v_checks || jsonb_build_object(
    'name', 'auth/admin: current admin identity',
    'ok', COALESCE(v_admin_role >= 2, FALSE),
    'details', COALESCE('role=' || v_admin_role::TEXT, 'admin user not found')
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
      'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- Columns
  FOREACH v_name IN ARRAY ARRAY[
    'users.id', 'users.nm', 'users.ph', 'users.eml', 'users.role', 'users.sts',
    'users.i_del', 'users.perm', 'users.vrf', 'users.device_id',
    'offers.id', 'offers.usr_id', 'offers.typ', 'offers.trx', 'offers.ttl',
    'offers.prc', 'offers.loc', 'offers.imgs', 'offers.vdo', 'offers.doc_img',
    'offers.exact_loc', 'offers.sts', 'offers.i_pub', 'offers.i_del',
    'appointments.id', 'appointments.off_id', 'appointments.own_id', 'appointments.bkr_id',
    'appointments.dt', 'appointments.sts',
    'payments.id', 'payments.uid', 'payments.sts', 'payments.channel', 'payments.proof',
    'reports.id', 'reports.rep_uid', 'reports.tgt_uid', 'reports.sts',
    'photography_tasks.id', 'photography_tasks.off_id', 'photography_tasks.photographer_id',
    'photography_tasks.media', 'photography_tasks.sts', 'photography_tasks.ts_submit'
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
    'admin_approve_verification',
    'admin_reject_verification',
    'admin_fraud_suspects',
    'request_verification',
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
    'details', CASE WHEN v_ok THEN 'photography keys present' ELSE 'photography keys missing' END
  );

  -- RLS
  FOREACH v_name IN ARRAY ARRAY[
    'users', 'offers', 'requests', 'appointments', 'notifications', 'payments',
    'reports', 'deals', 'activity_log', 'app_config', 'photography_tasks', 'ratings'
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
      'details', CASE WHEN COALESCE(v_ok, FALSE) THEN 'enabled' ELSE 'disabled/missing' END
    );
  END LOOP;

  -- Policy counts per sensitive table
  FOREACH v_name IN ARRAY ARRAY['users', 'offers', 'payments', 'reports', 'photography_tasks', 'notifications']
  LOOP
    SELECT COUNT(*) INTO v_count
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = v_name;

    v_checks := v_checks || jsonb_build_object(
      'name', 'security/policies: ' || v_name,
      'ok', v_count > 0,
      'details', 'policies=' || v_count::TEXT
    );
  END LOOP;

  -- Indexes
  FOREACH v_name IN ARRAY ARRAY[
    'ux_users_normalized_phone_active',
    'idx_users_role',
    'idx_users_sts',
    'idx_offers_sts',
    'idx_offers_iPub',
    'idx_photo_tasks_offer',
    'idx_photo_tasks_photographer',
    'idx_photo_tasks_status'
  ]
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM pg_indexes
      WHERE schemaname = 'public' AND indexname = v_name
    ) INTO v_ok;
    v_checks := v_checks || jsonb_build_object(
      'name', 'performance/index: ' || v_name,
      'ok', v_ok,
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
      'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- Config main
  SELECT value INTO v_config FROM app_config WHERE key = 'main' LIMIT 1;
  v_ok := v_config IS NOT NULL;
  v_checks := v_checks || jsonb_build_object(
    'name', 'config: app_config/main exists',
    'ok', v_ok,
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
      'details', CASE WHEN COALESCE(v_ok, FALSE) THEN 'exists' ELSE 'missing' END
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

  v_checks := v_checks || jsonb_build_object('name', 'data/count: active users', 'ok', v_total_users >= 0, 'details', v_total_users::TEXT);
  v_checks := v_checks || jsonb_build_object('name', 'data/count: active offers', 'ok', v_total_offers >= 0, 'details', v_total_offers::TEXT);
  v_checks := v_checks || jsonb_build_object('name', 'data/count: photography tasks', 'ok', v_total_photo_tasks >= 0, 'details', v_total_photo_tasks::TEXT);

  -- Data integrity checks
  SELECT COUNT(*) INTO v_count
  FROM users
  WHERE i_del = 0
    AND COALESCE(ph, '') = ''
    AND COALESCE(eml, '') = '';
  v_checks := v_checks || jsonb_build_object(
    'name', 'data/users: no contact method',
    'ok', v_count = 0,
    'details', 'count=' || v_count::TEXT
  );

  SELECT COUNT(*) INTO v_count
  FROM offers o
  LEFT JOIN users u ON u.id = o.usr_id
  WHERE o.i_del = 0
    AND (o.usr_id IS NULL OR u.id IS NULL OR u.i_del = 1);
  v_checks := v_checks || jsonb_build_object(
    'name', 'data/offers: orphan owner',
    'ok', v_count = 0,
    'details', 'count=' || v_count::TEXT
  );

  SELECT COUNT(*) INTO v_count
  FROM offers
  WHERE i_del = 0
    AND i_pub = 1
    AND jsonb_array_length(COALESCE(imgs, '[]'::jsonb)) = 0;
  v_checks := v_checks || jsonb_build_object(
    'name', 'data/offers: published without images',
    'ok', v_count = 0,
    'details', 'count=' || v_count::TEXT
  );

  SELECT COUNT(*) INTO v_count
  FROM offers
  WHERE i_del = 0
    AND i_pub = 1
    AND (loc IS NULL OR COALESCE(loc->>'d', '') = '');
  v_checks := v_checks || jsonb_build_object(
    'name', 'data/offers: published without location text',
    'ok', v_count = 0,
    'details', 'count=' || v_count::TEXT
  );

  SELECT COUNT(*) INTO v_count
  FROM appointments a
  LEFT JOIN offers o ON o.id = a.off_id
  WHERE a.off_id IS NOT NULL
    AND (o.id IS NULL OR o.i_del = 1);
  v_checks := v_checks || jsonb_build_object(
    'name', 'data/appointments: orphan offer',
    'ok', v_count = 0,
    'details', 'count=' || v_count::TEXT
  );

  SELECT COUNT(*) INTO v_count
  FROM photography_tasks pt
  LEFT JOIN offers o ON o.id = pt.off_id
  WHERE o.id IS NULL OR o.i_del = 1;
  v_checks := v_checks || jsonb_build_object(
    'name', 'data/photography: orphan offer',
    'ok', v_count = 0,
    'details', 'count=' || v_count::TEXT
  );

  SELECT COUNT(*) INTO v_count
  FROM photography_tasks pt
  LEFT JOIN users u ON u.id = pt.photographer_id
  WHERE pt.photographer_id IS NOT NULL
    AND (u.id IS NULL OR u.i_del = 1);
  v_checks := v_checks || jsonb_build_object(
    'name', 'data/photography: missing photographer user',
    'ok', v_count = 0,
    'details', 'count=' || v_count::TEXT
  );

  SELECT COUNT(*) INTO v_count
  FROM photography_tasks
  WHERE sts = 2
    AND jsonb_array_length(COALESCE(media, '[]'::jsonb)) = 0;
  v_checks := v_checks || jsonb_build_object(
    'name', 'data/photography: submitted without media',
    'ok', v_count = 0,
    'details', 'count=' || v_count::TEXT
  );

  SELECT COUNT(*) INTO v_count
  FROM payments
  WHERE sts = 0;
  v_checks := v_checks || jsonb_build_object(
    'name', 'queue/payments: pending approvals',
    'ok', TRUE,
    'details', 'pending=' || v_count::TEXT
  );

  SELECT COUNT(*) INTO v_count
  FROM reports
  WHERE sts = 0;
  v_checks := v_checks || jsonb_build_object(
    'name', 'queue/reports: open reports',
    'ok', TRUE,
    'details', 'open=' || v_count::TEXT
  );

  RETURN jsonb_build_object(
    'ok', NOT EXISTS (
      SELECT 1
      FROM jsonb_array_elements(v_checks) item
      WHERE COALESCE((item->>'ok')::BOOLEAN, FALSE) = FALSE
    ),
    'generated_at', NOW(),
    'summary', jsonb_build_object(
      'users', v_total_users,
      'offers', v_total_offers,
      'photography_tasks', v_total_photo_tasks,
      'pending_offers', v_pending_offers,
      'pending_payments', v_pending_payments,
      'open_reports', v_open_reports,
      'pending_verifications', v_pending_verifications,
      'duplicate_phones', v_duplicate_phones
    ),
    'checks', v_checks
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION qa_system_check(UUID) TO anon, authenticated;
