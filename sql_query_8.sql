-- 2026_06_20_lock_user_offers_rpcs.sql

BEGIN;

REVOKE ALL ON FUNCTION public.get_user_offers_internal(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_user_offers_internal(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.get_offer_by_id_internal(uuid, uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_offer_by_id_internal(uuid, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.create_offer_internal(uuid, jsonb) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.create_offer_internal(uuid, jsonb) TO service_role;

REVOKE ALL ON FUNCTION public.increment_offer_views_internal(uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.increment_offer_views_internal(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.check_offer_duplicate(text, numeric, jsonb, uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.check_offer_duplicate(text, numeric, jsonb, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.purchase_offer_boost(uuid, uuid, text) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.purchase_offer_boost(uuid, uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public.mark_social_published_internal(uuid, uuid, text) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.mark_social_published_internal(uuid, uuid, text) TO service_role;

COMMIT;
