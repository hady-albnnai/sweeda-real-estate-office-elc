-- 2026_06_20_lock_user_appointments_rpcs.sql

BEGIN;

REVOKE ALL ON FUNCTION public.get_user_appointments_internal(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_user_appointments_internal(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.get_owner_appointments_internal(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_owner_appointments_internal(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.get_broker_appointments_internal(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_broker_appointments_internal(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.book_appointment_internal(uuid, uuid, timestamp with time zone, uuid, uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.book_appointment_internal(uuid, uuid, timestamp with time zone, uuid, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.cancel_appointment_internal(uuid, uuid, text) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.cancel_appointment_internal(uuid, uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public.broker_handle_appointment_internal(uuid, uuid, text) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.broker_handle_appointment_internal(uuid, uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public.owner_respond_appointment(uuid, uuid, boolean, integer, text, timestamp with time zone) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.owner_respond_appointment(uuid, uuid, boolean, integer, text, timestamp with time zone) TO service_role;

REVOKE ALL ON FUNCTION public.requester_counter_appointment(uuid, uuid, boolean, timestamp with time zone) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.requester_counter_appointment(uuid, uuid, boolean, timestamp with time zone) TO service_role;

COMMIT;
