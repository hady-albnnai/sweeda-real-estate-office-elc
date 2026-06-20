-- 2026_06_20_lock_final_rpcs.sql

BEGIN;

REVOKE ALL ON FUNCTION public.submit_broker_request_internal(uuid, text, integer, text, text) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.submit_broker_request_internal(uuid, text, integer, text, text) TO service_role;

REVOKE ALL ON FUNCTION public.get_admin_dashboard_stats(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_admin_dashboard_stats(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.get_staff_stats_internal(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_staff_stats_internal(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.get_all_staff_users(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_all_staff_users(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.admin_fraud_suspects(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.admin_fraud_suspects(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.revoke_staff_session(uuid, text) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.revoke_staff_session(uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public.reset_password_with_otp(uuid, text) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.reset_password_with_otp(uuid, text) TO service_role;

-- إضافات بسيطة تبقت من Linter:
REVOKE ALL ON FUNCTION public.update_user_stats_on_appointment() FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.update_user_stats_on_appointment() TO service_role;

REVOKE ALL ON FUNCTION public.update_user_stats_on_deal() FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.update_user_stats_on_deal() TO service_role;

REVOKE ALL ON FUNCTION public.update_user_stats_on_offer() FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.update_user_stats_on_offer() TO service_role;

REVOKE ALL ON FUNCTION public.update_user_stats_on_request() FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.update_user_stats_on_request() TO service_role;

REVOKE ALL ON FUNCTION public.register_daily_streak_internal(uuid, integer) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.register_daily_streak_internal(uuid, integer) TO service_role;

REVOKE ALL ON FUNCTION public.create_payment_internal(uuid, jsonb) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.create_payment_internal(uuid, jsonb) TO service_role;

REVOKE ALL ON FUNCTION public.create_rating_internal(uuid, uuid, integer, text) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.create_rating_internal(uuid, uuid, integer, text) TO service_role;

REVOKE ALL ON FUNCTION public.purchase_offer_boost(uuid, uuid, text) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.purchase_offer_boost(uuid, uuid, text) TO service_role;

COMMIT;
