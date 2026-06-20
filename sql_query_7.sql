-- 2026_06_20_lock_tasks_rpcs.sql

BEGIN;

-- المنفذ
REVOKE ALL ON FUNCTION public.get_my_tasks(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_my_tasks(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.get_postponed_tasks(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_postponed_tasks(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.get_completed_tasks(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_completed_tasks(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.get_executor_task_by_appointment(uuid, uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_executor_task_by_appointment(uuid, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.get_my_completion_requests(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_my_completion_requests(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.update_task_outcome(uuid, uuid, text, text, text, timestamp with time zone) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.update_task_outcome(uuid, uuid, text, text, text, timestamp with time zone) TO service_role;

REVOKE ALL ON FUNCTION public.request_completion_by_appointment(uuid, uuid, text) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.request_completion_by_appointment(uuid, uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public.get_all_pending_completion_requests(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_all_pending_completion_requests(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.process_completion_request(uuid, uuid, text, text) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.process_completion_request(uuid, uuid, text, text) TO service_role;

-- المصور والإدارة
REVOKE ALL ON FUNCTION public.get_photographer_tasks_internal(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_photographer_tasks_internal(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.start_photography_task_internal(uuid, uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.start_photography_task_internal(uuid, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.submit_photography_task_internal(uuid, uuid, jsonb, text) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.submit_photography_task_internal(uuid, uuid, jsonb, text) TO service_role;

REVOKE ALL ON FUNCTION public.create_photography_task_internal(uuid, uuid, uuid, text, timestamp with time zone) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.create_photography_task_internal(uuid, uuid, uuid, text, timestamp with time zone) TO service_role;

REVOKE ALL ON FUNCTION public.update_photography_task_status_internal(uuid, uuid, integer, text) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.update_photography_task_status_internal(uuid, uuid, integer, text) TO service_role;

REVOKE ALL ON FUNCTION public.attach_photography_media_to_offer_internal(uuid, uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.attach_photography_media_to_offer_internal(uuid, uuid) TO service_role;

COMMIT;
