-- ═══════════════════════════════════════════════════════════════════════
-- إصلاحات ميزة النشر على السوشال — 2026-07-13
-- 1. إصلاح صلاحيات mark_social_published_internal (أمني)
-- 2. منع تكرار النشر (soc_pub = 0 فقط)
-- ═══════════════════════════════════════════════════════════════════════

-- 1️⃣ إصلاح الصلاحيات: فقط service_role يقدر يستدعيها
--    anon و authenticated كانوا يقدروا يتجاوزوا الـ Edge Function مباشرة!
REVOKE ALL ON FUNCTION mark_social_published_internal(UUID, UUID, TEXT) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION mark_social_published_internal(UUID, UUID, TEXT) TO service_role;

-- 2️⃣ إعادة كتابة الدالة مع منع التكرار
--    التغيير: WHERE soc_pub = 0 + إرجاع FALSE بدل EXCEPTION عند التكرار
DROP FUNCTION IF EXISTS mark_social_published_internal(UUID, UUID, TEXT);

CREATE OR REPLACE FUNCTION mark_social_published_internal(
  p_user_uid UUID,
  p_offer_id UUID,
  p_text TEXT
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  UPDATE offers
  SET soc_pub = 1,
      soc_txt = COALESCE(p_text, '')
  WHERE id = p_offer_id
    AND usr_id = p_user_uid
    AND i_del = 0
    AND soc_pub = 0;  -- ✅ منع التكرار: فقط إذا لم يُنشر سابقاً

  IF NOT FOUND THEN
    -- العرض غير موجود أو تم نشره مسبقاً
    RETURN FALSE;
  END IF;
  RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION mark_social_published_internal(UUID, UUID, TEXT) TO service_role;
