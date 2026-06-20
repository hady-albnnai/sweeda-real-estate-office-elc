-- 2026_06_20_lock_user_requests_rpcs.sql

BEGIN;

REVOKE ALL ON FUNCTION public.get_user_requests_internal(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_user_requests_internal(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.create_request_internal(uuid, jsonb) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.create_request_internal(uuid, jsonb) TO service_role;

REVOKE ALL ON FUNCTION public.update_request_internal(uuid, uuid, jsonb) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.update_request_internal(uuid, uuid, jsonb) TO service_role;

REVOKE ALL ON FUNCTION public.soft_delete_request_internal(uuid, uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.soft_delete_request_internal(uuid, uuid) TO service_role;

COMMIT;
