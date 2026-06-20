-- 2026_06_20_lock_missed_rpcs.sql

BEGIN;

-- من الواضح أن create_report_internal لم تُقفل من قبل
REVOKE ALL ON FUNCTION public.create_report_internal(uuid, jsonb) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.create_report_internal(uuid, jsonb) TO service_role;

-- دوال تتعلق بالوسيط (Broker) تُستدعى بواسطة المستخدم أو الإدارة، سنقفلها أيضاً
REVOKE ALL ON FUNCTION public.get_broker_deals_internal(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_broker_deals_internal(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.get_broker_offers_internal(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_broker_offers_internal(uuid) TO service_role;

-- دوال تتعلق بطلبات الإدارة
REVOKE ALL ON FUNCTION public.get_admin_requests_internal(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_admin_requests_internal(uuid) TO service_role;

-- دوال المدفوعات للمستخدم
REVOKE ALL ON FUNCTION public.get_user_payments_internal(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_user_payments_internal(uuid) TO service_role;

-- دالة تسجيل الدخول بالإيميل
REVOKE ALL ON FUNCTION public.handle_email_auth_internal() FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.handle_email_auth_internal() TO service_role;

COMMIT;
