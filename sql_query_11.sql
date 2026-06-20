-- 2026_06_20_lock_user_notifications_rpcs.sql

BEGIN;

REVOKE ALL ON FUNCTION public.get_user_notifications_internal(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_user_notifications_internal(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.mark_notification_read_internal(uuid, uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.mark_notification_read_internal(uuid, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.mark_all_notifications_read_internal(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read_internal(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.update_user_notification_settings_internal(uuid, jsonb) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.update_user_notification_settings_internal(uuid, jsonb) TO service_role;

COMMIT;
