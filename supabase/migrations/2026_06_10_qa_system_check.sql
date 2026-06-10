-- ════════════════════════════════════════════════════════════════════════════
-- QA system check RPC
-- Date: 2026-06-10
-- Purpose:
--   Returns a JSON report for server-side readiness checks from the admin QA UI.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION qa_system_check(p_admin_uid UUID)
RETURNS JSONB AS $$
DECLARE
  v_admin_role INT;
  v_checks JSONB := '[]'::jsonb;
  v_ok BOOLEAN;
  v_details TEXT;
  v_duplicate_phones INT := 0;
  v_total_users INT := 0;
  v_total_offers INT := 0;
  v_total_photo_tasks INT := 0;
BEGIN
  SELECT role INTO v_admin_role
  FROM users
  WHERE id = p_admin_uid
    AND i_del = 0;

  v_checks := v_checks || jsonb_build_object(
    'name', 'admin identity',
    'ok', COALESCE(v_admin_role >= 2, FALSE),
    'details', COALESCE('role=' || v_admin_role::TEXT, 'admin user not found')
  );

  -- Required tables
  FOREACH v_details IN ARRAY ARRAY[
    'users', 'offers', 'requests', 'appointments', 'notifications', 'payments',
    'reports', 'deals', 'app_config', 'user_devices', 'photography_tasks'
  ]
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = v_details
    ) INTO v_ok;
    v_checks := v_checks || jsonb_build_object(
      'name', 'table: ' || v_details,
      'ok', v_ok,
      'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- Required columns
  FOREACH v_details IN ARRAY ARRAY[
    'users.perm', 'users.role', 'users.sts', 'users.ph',
    'offers.imgs', 'offers.vdo', 'offers.doc_img',
    'photography_tasks.media', 'photography_tasks.sts', 'photography_tasks.photographer_id'
  ]
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = split_part(v_details, '.', 1)
        AND column_name = split_part(v_details, '.', 2)
    ) INTO v_ok;
    v_checks := v_checks || jsonb_build_object(
      'name', 'column: ' || v_details,
      'ok', v_ok,
      'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- Required functions
  FOREACH v_details IN ARRAY ARRAY[
    'normalize_sy_phone',
    'admin_update_user_role',
    'admin_set_user_status',
    'admin_update_user_permissions',
    'admin_update_user_permissions_by_admin',
    'create_offer_internal',
    'upsert_user_after_otp',
    'create_photography_task_internal',
    'submit_photography_task_internal',
    'update_photography_task_status_internal',
    'attach_photography_media_to_offer_internal',
    'get_user_full_by_id',
    'register_weekly_login',
    'approve_payment_final',
    'admin_fraud_suspects'
  ]
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proname = v_details
    ) INTO v_ok;
    v_checks := v_checks || jsonb_build_object(
      'name', 'function: ' || v_details,
      'ok', v_ok,
      'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- RLS checks
  FOREACH v_details IN ARRAY ARRAY['users', 'offers', 'photography_tasks', 'payments', 'reports']
  LOOP
    SELECT COALESCE(c.relrowsecurity, FALSE)
    INTO v_ok
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = v_details;

    v_checks := v_checks || jsonb_build_object(
      'name', 'rls: ' || v_details,
      'ok', COALESCE(v_ok, FALSE),
      'details', CASE WHEN COALESCE(v_ok, FALSE) THEN 'enabled' ELSE 'disabled/missing' END
    );
  END LOOP;

  -- Indexes
  SELECT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'ux_users_normalized_phone_active'
  ) INTO v_ok;
  v_checks := v_checks || jsonb_build_object(
    'name', 'index: ux_users_normalized_phone_active',
    'ok', v_ok,
    'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
  );

  -- Duplicate phones after normalization
  SELECT COUNT(*) INTO v_duplicate_phones
  FROM (
    SELECT normalize_sy_phone(ph)
    FROM users
    WHERE i_del = 0 AND COALESCE(ph, '') <> ''
    GROUP BY normalize_sy_phone(ph)
    HAVING COUNT(*) > 1
  ) d;
  v_checks := v_checks || jsonb_build_object(
    'name', 'duplicate normalized phones',
    'ok', v_duplicate_phones = 0,
    'details', v_duplicate_phones::TEXT
  );

  -- Counts
  SELECT COUNT(*) INTO v_total_users FROM users WHERE i_del = 0;
  SELECT COUNT(*) INTO v_total_offers FROM offers WHERE i_del = 0;
  SELECT COUNT(*) INTO v_total_photo_tasks FROM photography_tasks;

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
      'duplicate_phones', v_duplicate_phones
    ),
    'checks', v_checks
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION qa_system_check(UUID) TO anon, authenticated;
