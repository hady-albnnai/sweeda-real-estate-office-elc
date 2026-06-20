-- 2026_06_20_lock_user_account_rpcs.sql

BEGIN;

REVOKE ALL ON FUNCTION public.login_with_password(text, text) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.login_with_password(text, text) TO service_role;

REVOKE ALL ON FUNCTION public.check_username_available(text) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.check_username_available(text) TO service_role;

REVOKE ALL ON FUNCTION public.register_device(text, text) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.register_device(text, text) TO service_role;

REVOKE ALL ON FUNCTION public.get_user_full_by_id(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_user_full_by_id(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.update_user_profile_internal(uuid, jsonb) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.update_user_profile_internal(uuid, jsonb) TO service_role;

REVOKE ALL ON FUNCTION public.get_user_device_tokens(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_user_device_tokens(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.register_password(uuid, text, text) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.register_password(uuid, text, text) TO service_role;

REVOKE ALL ON FUNCTION public.change_password_internal(uuid, text, text) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.change_password_internal(uuid, text, text) TO service_role;

REVOKE ALL ON FUNCTION public.request_verification_by_uid(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.request_verification_by_uid(uuid) TO service_role;

COMMIT;
