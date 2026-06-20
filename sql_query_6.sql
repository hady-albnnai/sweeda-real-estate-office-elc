-- 2026_06_20_lock_admin_deals_rpcs.sql

BEGIN;

-- 1. get_admin_deals_internal
REVOKE ALL ON FUNCTION public.get_admin_deals_internal(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_admin_deals_internal(uuid) TO service_role;

-- 2. create_deal_internal
REVOKE ALL ON FUNCTION public.create_deal_internal(uuid, jsonb) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.create_deal_internal(uuid, jsonb) TO service_role;

-- 3. complete_deal_internal
REVOKE ALL ON FUNCTION public.complete_deal_internal(uuid, uuid, numeric, text) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.complete_deal_internal(uuid, uuid, numeric, text) TO service_role;

COMMIT;
