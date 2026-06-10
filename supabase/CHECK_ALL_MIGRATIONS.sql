-- ════════════════════════════════════════════════════════════════════════════
-- 🩺 استعلام تشخيصي شامل — يفحص كل الـmigrations
-- ════════════════════════════════════════════════════════════════════════════
-- شغّله مرة واحدة في Supabase SQL Editor
-- يُرجع جدولاً واضحاً: ✅ موجود أو ❌ ناقص لكل عنصر
-- ────────────────────────────────────────────────────────────────────────────

WITH checks AS (
  -- ═══════════════════════════════════════════════════
  -- 1) EXTENSIONS
  -- ═══════════════════════════════════════════════════
  SELECT 1 AS ord, 'EXT' AS kind, 'pgcrypto' AS name,
    EXISTS(SELECT 1 FROM pg_extension WHERE extname='pgcrypto') AS exists,
    'Phase 9 — للـOTP الآمن' AS source
  UNION ALL

  -- ═══════════════════════════════════════════════════
  -- 2) أعمدة جديدة في users
  -- ═══════════════════════════════════════════════════
  SELECT 10, 'COL', 'users.eml',
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_name='users' AND column_name='eml'),
    'whatsapp_email_auth'
  UNION ALL
  SELECT 11, 'COL', 'users.ref_by',
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_name='users' AND column_name='ref_by'),
    'stats_triggers_and_wkLogin'
  UNION ALL
  SELECT 12, 'COL', 'users.ref_cnt',
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_name='users' AND column_name='ref_cnt'),
    'stats_triggers_and_wkLogin'
  UNION ALL
  SELECT 13, 'COL', 'users.vrf',
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_name='users' AND column_name='vrf'),
    'Phase 2 — التوثيق'
  UNION ALL
  SELECT 14, 'COL', 'users.device_id',
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_name='users' AND column_name='device_id'),
    'Phase 9 — fingerprint'
  UNION ALL
  SELECT 15, 'COL', 'users.signup_ip',
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_name='users' AND column_name='signup_ip'),
    'Phase 9'
  UNION ALL
  SELECT 16, 'COL', 'users.last_ip',
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_name='users' AND column_name='last_ip'),
    'Phase 9'
  UNION ALL
  SELECT 17, 'COL', 'users.device_history',
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_name='users' AND column_name='device_history'),
    'Phase 9'
  UNION ALL

  -- ═══════════════════════════════════════════════════
  -- 3) أعمدة جديدة في offers
  -- ═══════════════════════════════════════════════════
  SELECT 20, 'COL', 'offers.i_pin',
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_name='offers' AND column_name='i_pin'),
    'offer_boosts'
  UNION ALL
  SELECT 21, 'COL', 'offers.i_bst',
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_name='offers' AND column_name='i_bst'),
    'offer_boosts'
  UNION ALL
  SELECT 22, 'COL', 'offers.i_fms',
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_name='offers' AND column_name='i_fms'),
    'offer_boosts'
  UNION ALL
  SELECT 23, 'COL', 'offers.dsc_pct',
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_name='offers' AND column_name='dsc_pct'),
    'offer_boosts'
  UNION ALL

  -- ═══════════════════════════════════════════════════
  -- 4) أعمدة جديدة في otp_codes
  -- ═══════════════════════════════════════════════════
  SELECT 30, 'COL', 'otp_codes.channel',
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_name='otp_codes' AND column_name='channel'),
    'whatsapp_email_auth'
  UNION ALL
  SELECT 31, 'COL', 'otp_codes.identifier',
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_name='otp_codes' AND column_name='identifier'),
    'whatsapp_email_auth'
  UNION ALL
  SELECT 32, 'COL', 'otp_codes.attempts',
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_name='otp_codes' AND column_name='attempts'),
    'Phase 8 — قفل OTP'
  UNION ALL

  -- ═══════════════════════════════════════════════════
  -- 5) أعمدة في ratings
  -- ═══════════════════════════════════════════════════
  SELECT 40, 'COL', 'ratings.appointment_id',
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_name='ratings' AND column_name='appointment_id'),
    'Phase 8'
  UNION ALL
  SELECT 41, 'COL', 'ratings.deal_id',
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_name='ratings' AND column_name='deal_id'),
    'Phase 8'
  UNION ALL
  SELECT 42, 'COL', 'payments.channel',
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_name='payments' AND column_name='channel'),
    'payment_channel_and_storage'
  UNION ALL

  -- ═══════════════════════════════════════════════════
  -- 6) جداول جديدة
  -- ═══════════════════════════════════════════════════
  SELECT 50, 'TBL', 'ratings',
    EXISTS(SELECT 1 FROM pg_tables WHERE tablename='ratings'),
    'points_refinement'
  UNION ALL
  SELECT 51, 'TBL', 'user_daily_limits',
    EXISTS(SELECT 1 FROM pg_tables WHERE tablename='user_daily_limits'),
    'points_refinement'
  UNION ALL
  SELECT 52, 'TBL', 'user_devices',
    EXISTS(SELECT 1 FROM pg_tables WHERE tablename='user_devices'),
    'fcm_setup'
  UNION ALL

  -- ═══════════════════════════════════════════════════
  -- 7) Functions / RPCs
  -- ═══════════════════════════════════════════════════
  SELECT 60, 'FN', 'generate_otp_v2',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='generate_otp_v2'),
    'whatsapp_email_auth'
  UNION ALL
  SELECT 61, 'FN', 'verify_otp_v2',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='verify_otp_v2'),
    'whatsapp_email_auth'
  UNION ALL
  SELECT 62, 'FN', 'legacy verify_otp_safe removed',
    NOT EXISTS(SELECT 1 FROM pg_proc WHERE proname='verify_otp_safe'),
    'cleanup_2026_06_11'
  UNION ALL
  SELECT 63, 'FN', 'apply_referral',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='apply_referral'),
    'stats_triggers_and_wkLogin (+ Phase 8/9 تحديثات)'
  UNION ALL
  SELECT 64, 'FN', 'register_weekly_login',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='register_weekly_login'),
    'stats_triggers_and_wkLogin'
  UNION ALL
  SELECT 65, 'FN', 'award_points_safe',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='award_points_safe'),
    'points_refinement'
  UNION ALL
  SELECT 66, 'FN', 'purchase_offer_boost',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='purchase_offer_boost'),
    'offer_boosts'
  UNION ALL
  SELECT 67, 'FN', 'expire_offer_boosts',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='expire_offer_boosts'),
    'offer_boosts'
  UNION ALL
  SELECT 68, 'FN', 'expire_offers',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='expire_offers'),
    'cron_jobs'
  UNION ALL
  SELECT 69, 'FN', 'notify_user',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='notify_user'),
    'fcm_setup'
  UNION ALL
  SELECT 70, 'FN', 'send_push_notification',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='send_push_notification'),
    'notification_triggers'
  UNION ALL
  SELECT 71, 'FN', 'legacy request_verification removed',
    NOT EXISTS(SELECT 1 FROM pg_proc WHERE proname='request_verification'),
    'cleanup_2026_06_11'
  UNION ALL
  SELECT 72, 'FN', 'legacy admin_approve_verification removed',
    NOT EXISTS(SELECT 1 FROM pg_proc WHERE proname='admin_approve_verification'),
    'cleanup_2026_06_11'
  UNION ALL
  SELECT 73, 'FN', 'legacy admin_reject_verification removed',
    NOT EXISTS(SELECT 1 FROM pg_proc WHERE proname='admin_reject_verification'),
    'cleanup_2026_06_11'
  UNION ALL
  SELECT 74, 'FN', 'check_user_safe_update',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='check_user_safe_update'),
    'Phase 8 — منع self-promotion'
  UNION ALL
  SELECT 75, 'FN', 'check_offer_safe_update',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='check_offer_safe_update'),
    'Phase 8'
  UNION ALL
  SELECT 76, 'FN', 'check_rating_valid',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='check_rating_valid'),
    'Phase 8'
  UNION ALL
  SELECT 77, 'FN', 'register_device',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='register_device'),
    'Phase 9'
  UNION ALL
  SELECT 78, 'FN', 'admin_fraud_suspects',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='admin_fraud_suspects'),
    'Phase 9'
  UNION ALL
  SELECT 79, 'FN', 'admin_get_id_signed_path',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='admin_get_id_signed_path'),
    'Phase 9'
  UNION ALL
  SELECT 80, 'FN', 'accounts_on_same_device',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='accounts_on_same_device'),
    'Phase 9'
  UNION ALL
  SELECT 81, 'FN', 'approve_payment_final',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='approve_payment_final'),
    'payment_approval_logic'
  UNION ALL

  -- ═══════════════════════════════════════════════════
  -- 8) Triggers
  -- ═══════════════════════════════════════════════════
  SELECT 90, 'TRG', 'trg_user_safe_update',
    EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='trg_user_safe_update'),
    'Phase 8'
  UNION ALL
  SELECT 91, 'TRG', 'trg_user_safe_insert',
    EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='trg_user_safe_insert'),
    'Phase 8'
  UNION ALL
  SELECT 92, 'TRG', 'trg_offer_safe_update',
    EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='trg_offer_safe_update'),
    'Phase 8'
  UNION ALL
  SELECT 93, 'TRG', 'trg_rating_valid',
    EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='trg_rating_valid'),
    'Phase 8'
  UNION ALL
  SELECT 94, 'TRG', 'trg_rating_bonus_notify',
    EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='trg_rating_bonus_notify'),
    'points_refinement'
  UNION ALL
  SELECT 95, 'TRG', 'trg_offers_stats',
    EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='trg_offers_stats'),
    'stats_triggers'
  UNION ALL
  SELECT 96, 'TRG', 'trg_requests_stats',
    EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='trg_requests_stats'),
    'stats_triggers'
  UNION ALL
  SELECT 97, 'TRG', 'trg_appointments_stats',
    EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='trg_appointments_stats'),
    'stats_triggers'
  UNION ALL
  SELECT 98, 'TRG', 'trg_deals_stats',
    EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='trg_deals_stats'),
    'stats_triggers'
  UNION ALL
  SELECT 99, 'TRG', 'trg_offer_status_notify',
    EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='trg_offer_status_notify'),
    'notification_triggers'
  UNION ALL
  SELECT 100, 'TRG', 'trg_appointment_notify',
    EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='trg_appointment_notify'),
    'notification_triggers'
  UNION ALL
  SELECT 101, 'TRG', 'trg_deal_notify',
    EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='trg_deal_notify'),
    'notification_triggers'
  UNION ALL
  SELECT 102, 'TRG', 'trg_payment_notify',
    EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='trg_payment_notify'),
    'notification_triggers'
  UNION ALL
  SELECT 103, 'TRG', 'trg_offer_match_notify',
    EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='trg_offer_match_notify'),
    'notification_triggers'
  UNION ALL

  -- ═══════════════════════════════════════════════════
  -- 9) Views
  -- ═══════════════════════════════════════════════════
  SELECT 110, 'VW', 'users_public',
    EXISTS(SELECT 1 FROM pg_views WHERE viewname='users_public'),
    'Phase 8'
  UNION ALL
  SELECT 111, 'VW', 'fraud_suspects',
    EXISTS(SELECT 1 FROM pg_views WHERE viewname='fraud_suspects'),
    'Phase 9'
  UNION ALL

  -- ═══════════════════════════════════════════════════
  -- 10) Storage buckets
  -- ═══════════════════════════════════════════════════
  SELECT 120, 'BKT', 'ids_private (PRIVATE)',
    EXISTS(SELECT 1 FROM storage.buckets WHERE id='ids_private' AND public=false),
    'Phase 9'
  UNION ALL
  SELECT 121, 'BKT', 'offer_images',
    EXISTS(SELECT 1 FROM storage.buckets WHERE id='offer_images'),
    'الأساسي'
  UNION ALL
  SELECT 122, 'BKT', 'config_assets',
    EXISTS(SELECT 1 FROM storage.buckets WHERE id='config_assets'),
    'payment_channel_and_storage'
  UNION ALL
  SELECT 123, 'BKT', 'payment_proofs',
    EXISTS(SELECT 1 FROM storage.buckets WHERE id='payment_proofs'),
    'payment_channel_and_storage'
  UNION ALL

  -- ═══════════════════════════════════════════════════
  -- 11) Storage policies
  -- ═══════════════════════════════════════════════════
  SELECT 130, 'POL', 'ids_private_owner_select',
    EXISTS(SELECT 1 FROM pg_policies
           WHERE schemaname='storage' AND tablename='objects'
             AND policyname='ids_private_owner_select'),
    'Phase 9'
  UNION ALL
  SELECT 131, 'POL', 'ids_private_owner_insert',
    EXISTS(SELECT 1 FROM pg_policies
           WHERE schemaname='storage' AND tablename='objects'
             AND policyname='ids_private_owner_insert'),
    'Phase 9'
  UNION ALL

  -- ═══════════════════════════════════════════════════
  -- 12) Internal permissions
  -- ═══════════════════════════════════════════════════
  SELECT 135, 'COL', 'users.perm',
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_schema='public' AND table_name='users' AND column_name='perm'),
    'internal_permissions'
  UNION ALL
  SELECT 136, 'FN', 'legacy admin_update_user_permissions removed',
    NOT EXISTS(SELECT 1 FROM pg_proc WHERE proname='admin_update_user_permissions'),
    'cleanup_2026_06_11'
  UNION ALL
  SELECT 137, 'FN', 'admin_update_user_role',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='admin_update_user_role'),
    'admin_user_management'
  UNION ALL
  SELECT 138, 'FN', 'admin_set_user_status',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='admin_set_user_status'),
    'admin_user_management'
  UNION ALL
  SELECT 139, 'IDX', 'ux_users_normalized_phone_active',
    EXISTS(SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='ux_users_normalized_phone_active'),
    'phone_uniqueness'
  UNION ALL

  -- ═══════════════════════════════════════════════════
  -- 13) RLS policies على الجداول الرئيسية
  -- ═══════════════════════════════════════════════════
  SELECT 140, 'POL', 'users: Users can read own row only',
    EXISTS(SELECT 1 FROM pg_policies
           WHERE tablename='users' AND policyname='Users can read own row only'),
    'Phase 8 (إخفاء البيانات الشخصية)'
  UNION ALL
  SELECT 141, 'POL', 'ratings: ratings_insert_authenticated',
    EXISTS(SELECT 1 FROM pg_policies
           WHERE tablename='ratings' AND policyname='ratings_insert_authenticated'),
    'Phase 8'
  UNION ALL
  SELECT 142, 'POL', 'notifications: notifications_no_user_insert',
    EXISTS(SELECT 1 FROM pg_policies
           WHERE tablename='notifications' AND policyname='notifications_no_user_insert'),
    'Phase 8 (منع phishing)'
  UNION ALL
  SELECT 143, 'COL', 'appointments.req_uid',
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_schema='public' AND table_name='appointments' AND column_name='req_uid'),
    'logic_fixes_appointments_offers'
  UNION ALL
  SELECT 144, 'FN', 'request_verification_by_uid',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='request_verification_by_uid'),
    'verification_dev_auth_rpcs'
  UNION ALL
  SELECT 145, 'FN', 'admin_approve_verification_by_admin',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='admin_approve_verification_by_admin'),
    'verification_dev_auth_rpcs'
  UNION ALL
  SELECT 146, 'FN', 'admin_reject_verification_by_admin',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='admin_reject_verification_by_admin'),
    'verification_dev_auth_rpcs'
  UNION ALL
  SELECT 147, 'CFG', 'app_config.pkg prices',
    EXISTS(
      SELECT 1 FROM app_config
      WHERE key='main'
        AND value ? 'pkg'
        AND value->'pkg'->'1' ? 'pr'
        AND value->'pkg'->'2' ? 'pr'
    ),
    'config_package_prices_and_fx'
  UNION ALL
  SELECT 148, 'CFG', 'app_config.fx.usd_syp',
    EXISTS(
      SELECT 1 FROM app_config
      WHERE key='main'
        AND value ? 'fx'
        AND value->'fx' ? 'usd_syp'
    ),
    'config_package_prices_and_fx'
  UNION ALL
  SELECT 149, 'VW', 'users_public بدون img خاص',
    EXISTS(
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema='public' AND table_name='users_public' AND column_name='img'
    ) = false,
    'users_public_no_private_img'
  UNION ALL
  SELECT 1491, 'FN', 'admin_review_offer_internal',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='admin_review_offer_internal'),
    'real_test_stabilization_internal_rpcs'
  UNION ALL
  SELECT 1492, 'FN', 'create_request_internal',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='create_request_internal'),
    'real_test_stabilization_internal_rpcs'
  UNION ALL
  SELECT 1493, 'FN', 'book_appointment_internal',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='book_appointment_internal'),
    'real_test_stabilization_internal_rpcs'
  UNION ALL
  SELECT 1494, 'FN', 'create_payment_internal',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='create_payment_internal'),
    'real_test_stabilization_internal_rpcs'
  UNION ALL
  SELECT 1495, 'FN', 'create_report_internal',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='create_report_internal'),
    'real_test_stabilization_internal_rpcs'
  UNION ALL
  SELECT 1496, 'FN', 'register_daily_streak_internal',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname='register_daily_streak_internal'),
    'real_test_stabilization_internal_rpcs'
  UNION ALL

  -- ═══════════════════════════════════════════════════
  -- 14) Cron jobs (يتطلب pg_cron مفعّل)
  -- ═══════════════════════════════════════════════════
  SELECT 150, 'CRON', 'daily-expire-offers',
    EXISTS(SELECT 1 FROM cron.job WHERE jobname='daily-expire-offers'),
    'cron_jobs'
  UNION ALL
  SELECT 151, 'CRON', 'daily-expire-boosts',
    EXISTS(SELECT 1 FROM cron.job WHERE jobname='daily-expire-boosts'),
    'cron_jobs'
  UNION ALL
  SELECT 152, 'CRON', 'hourly-appointment-reminders',
    EXISTS(SELECT 1 FROM cron.job WHERE jobname='hourly-appointment-reminders'),
    'cron_jobs'
)
SELECT
  CASE WHEN exists THEN '✅' ELSE '❌ ناقص' END AS status,
  kind AS type,
  name,
  source
FROM checks
ORDER BY exists ASC, ord ASC;  -- الناقصة في الأعلى
