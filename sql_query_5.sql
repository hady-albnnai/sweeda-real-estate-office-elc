-- 2026_06_20_lock_admin_reports_rpcs.sql

BEGIN;

-- 1. get_admin_reports_internal
REVOKE ALL ON FUNCTION public.get_admin_reports_internal(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_admin_reports_internal(uuid) TO service_role;

-- 2. admin_handle_report_internal
REVOKE ALL ON FUNCTION public.admin_handle_report_internal(uuid, uuid, integer, text, integer) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.admin_handle_report_internal(uuid, uuid, integer, text, integer) TO service_role;

COMMIT;
