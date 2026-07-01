-- =====================================================================
-- 2026_07_02_appointment_booking_rules.sql
-- قواعد حجز المواعيد النهائية:
--   1) الحجز لا يخرج عن مواعيد صاحب العرض (avl) — مع دعم حالة 'any'
--      (جاهز بأي وقت): كل أيام الأسبوع ضمن دوام من app_config (appt.any_from/any_to
--      افتراضياً 09:00-21:00). avl فارغة = لا حجز إطلاقاً (NO_AVAILABILITY).
--   2) إسناد المشرف الأقل مواعيد نشطة، مع استبعاد المشغول ضمن فارق الساعة،
--      وعند عدم توفر أي مشرف: إشعار طالب الحجز + اقتراح أقرب موعد متاح.
--   3) عدم التعارض: لا موعدين نشطين على نفس العرض بفارق يقل عن ساعة
--      (appt.gap_mins افتراضياً 60) — ويُطبَّق الفارق نفسه على جدول المشرف.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0) إعدادات الحجز في app_config (القيم الموجودة مسبقاً لا تُستبدل)
-- ---------------------------------------------------------------------
UPDATE public.app_config
SET value = jsonb_set(
  value,
  '{appt}',
  '{"any_from":"09:00","any_to":"21:00","gap_mins":60}'::jsonb
    || COALESCE(value->'appt', '{}'::jsonb),
  true
)
WHERE key = 'main';

-- ---------------------------------------------------------------------
-- 1) دالة قراءة إعدادات الحجز (مع قيم افتراضية آمنة)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.appt_booking_config()
RETURNS JSONB
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path TO public, extensions, pg_temp
AS $$
  SELECT '{"any_from":"09:00","any_to":"21:00","gap_mins":60}'::jsonb
         || COALESCE((SELECT value->'appt' FROM public.app_config WHERE key = 'main'), '{}'::jsonb);
$$;

REVOKE ALL ON FUNCTION public.appt_booking_config() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.appt_booking_config() FROM anon;
REVOKE ALL ON FUNCTION public.appt_booking_config() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.appt_booking_config() TO service_role;

-- ---------------------------------------------------------------------
-- 2) get_booked_slots_internal — أوقات المواعيد النشطة (sts 0/1) ليوم محدد
--    تُعيد الأوقات الفعلية HH24:MI بتوقيت دمشق، والعميل يطبّق فارق الساعة
--    لتظليل كل وقت يقع ضمن أقل من gap_mins من موعد نشط.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_booked_slots_internal(
  p_offer_id UUID,
  p_date DATE
) RETURNS TEXT[]
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path TO public, extensions, pg_temp
AS $$
  SELECT COALESCE(
    array_agg(to_char(dt AT TIME ZONE 'Asia/Damascus', 'HH24:MI') ORDER BY dt),
    '{}'::text[]
  )
  FROM public.appointments
  WHERE off_id = p_offer_id
    AND sts IN (0, 1)
    AND (dt AT TIME ZONE 'Asia/Damascus')::date = p_date;
$$;

REVOKE ALL ON FUNCTION public.get_booked_slots_internal(UUID, DATE) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_booked_slots_internal(UUID, DATE) FROM anon;
REVOKE ALL ON FUNCTION public.get_booked_slots_internal(UUID, DATE) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.get_booked_slots_internal(UUID, DATE) TO service_role;

-- ---------------------------------------------------------------------
-- 3) get_available_supervisor — توحيد المنطق مع book_appointment_internal:
--    مشغول = لديه موعد نشط (sts 0/1) ضمن أقل من gap_mins من الوقت المطلوب.
--    الاختيار: الأقل مواعيد نشطة ثم الأقدم إنشاءً.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_available_supervisor(p_dt TIMESTAMPTZ)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, extensions, pg_temp
AS $$
DECLARE
  v_uid UUID;
  v_gap INT := (public.appt_booking_config()->>'gap_mins')::INT;
BEGIN
  SELECT u.id INTO v_uid
  FROM public.users u
  WHERE u.role = 3 AND u.sts = 0 AND u.i_del = 0
    AND NOT EXISTS (
      SELECT 1 FROM public.appointments a
      WHERE a.supervisor_uid = u.id
        AND a.sts IN (0, 1)
        AND a.dt > p_dt - make_interval(mins => v_gap)
        AND a.dt < p_dt + make_interval(mins => v_gap)
    )
  ORDER BY (
    SELECT COUNT(*) FROM public.appointments a2
    WHERE a2.supervisor_uid = u.id AND a2.sts IN (0, 1)
  ) ASC, u.ts_crt ASC
  LIMIT 1;

  IF v_uid IS NULL THEN RAISE EXCEPTION 'NO_SUPERVISOR_AVAILABLE'; END IF;
  RETURN v_uid;
END;
$$;

-- ---------------------------------------------------------------------
-- 4) suggest_appointment_slot — أقرب موعد متاح فعلياً خلال 14 يوماً:
--    ضمن avl (أو دوام any من الإعدادات) + لا تعارض على العرض + مشرف متاح.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.suggest_appointment_slot(
  p_offer_id UUID,
  p_from TIMESTAMPTZ DEFAULT NOW()
) RETURNS TIMESTAMPTZ
LANGUAGE plpgsql STABLE
SECURITY DEFINER
SET search_path TO public, extensions, pg_temp
AS $$
DECLARE
  v_offer   public.offers%ROWTYPE;
  v_cfg     JSONB := public.appt_booking_config();
  v_gap     INT;
  v_date    DATE;
  v_day_key TEXT;
  v_slots   JSONB;
  v_slot    TEXT;
  v_from_m  INT;
  v_to_m    INT;
  v_m       INT;
  v_cand    TIMESTAMPTZ;
  d         INT;
BEGIN
  v_gap := (v_cfg->>'gap_mins')::INT;

  SELECT * INTO v_offer FROM public.offers WHERE id = p_offer_id AND i_del = 0;
  IF v_offer.id IS NULL THEN RETURN NULL; END IF;
  IF v_offer.avl IS NULL OR v_offer.avl = '{}'::jsonb OR v_offer.avl = 'null'::jsonb THEN
    RETURN NULL;
  END IF;

  FOR d IN 0..13 LOOP
    v_date := (p_from AT TIME ZONE 'Asia/Damascus')::date + d;
    v_day_key := LOWER(to_char(v_date, 'Dy'));

    IF v_offer.avl ? 'any' THEN
      v_slots := jsonb_build_array((v_cfg->>'any_from') || '-' || (v_cfg->>'any_to'));
    ELSE
      v_slots := v_offer.avl -> v_day_key;
    END IF;

    IF v_slots IS NULL OR jsonb_array_length(v_slots) = 0 THEN CONTINUE; END IF;

    FOR v_slot IN SELECT jsonb_array_elements_text(v_slots) LOOP
      v_from_m := SPLIT_PART(SPLIT_PART(v_slot, '-', 1), ':', 1)::INT * 60
                + SPLIT_PART(SPLIT_PART(v_slot, '-', 1), ':', 2)::INT;
      v_to_m   := SPLIT_PART(SPLIT_PART(v_slot, '-', 2), ':', 1)::INT * 60
                + SPLIT_PART(SPLIT_PART(v_slot, '-', 2), ':', 2)::INT;

      v_m := v_from_m;
      WHILE v_m < v_to_m LOOP
        v_cand := ((v_date::text || ' ' ||
                    LPAD((v_m / 60)::text, 2, '0') || ':' ||
                    LPAD((v_m % 60)::text, 2, '0'))::timestamp)
                  AT TIME ZONE 'Asia/Damascus';

        IF v_cand > NOW()
           AND NOT EXISTS (
             SELECT 1 FROM public.appointments
             WHERE off_id = p_offer_id AND sts IN (0, 1)
               AND dt > v_cand - make_interval(mins => v_gap)
               AND dt < v_cand + make_interval(mins => v_gap)
           )
           AND EXISTS (
             SELECT 1 FROM public.users u
             WHERE u.role = 3 AND u.sts = 0 AND u.i_del = 0
               AND NOT EXISTS (
                 SELECT 1 FROM public.appointments a
                 WHERE a.supervisor_uid = u.id AND a.sts IN (0, 1)
                   AND a.dt > v_cand - make_interval(mins => v_gap)
                   AND a.dt < v_cand + make_interval(mins => v_gap)
               )
           )
        THEN
          RETURN v_cand;
        END IF;

        v_m := v_m + v_gap;
      END LOOP;
    END LOOP;
  END LOOP;

  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.suggest_appointment_slot(UUID, TIMESTAMPTZ) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.suggest_appointment_slot(UUID, TIMESTAMPTZ) FROM anon;
REVOKE ALL ON FUNCTION public.suggest_appointment_slot(UUID, TIMESTAMPTZ) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.suggest_appointment_slot(UUID, TIMESTAMPTZ) TO service_role;

-- ---------------------------------------------------------------------
-- 5) book_appointment_internal — النسخة النهائية بالقواعد الثلاث
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.book_appointment_internal(
  p_user_uid UUID,
  p_offer_id UUID,
  p_dt TIMESTAMPTZ,
  p_broker_id UUID DEFAULT NULL,
  p_request_id UUID DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, extensions, pg_temp
AS $$
DECLARE
  v_offer      public.offers%ROWTYPE;
  v_req        public.requests%ROWTYPE;
  v_cfg        JSONB := public.appt_booking_config();
  v_gap        INT;
  v_day_key    TEXT;
  v_slot       TEXT;
  v_slot_from  INT;
  v_slot_to    INT;
  v_req_mins   INT;
  v_avl_slots  JSONB;
  v_found_slot BOOLEAN := FALSE;
  v_supervisor UUID;
  v_suggest    TIMESTAMPTZ;
  v_active_count INT;
  v_pending_completion INT;
  v_appointment_id UUID;
BEGIN
  v_gap := (v_cfg->>'gap_mins')::INT;

  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  SELECT * INTO v_offer FROM public.offers WHERE id = p_offer_id AND i_del = 0;
  IF v_offer.id IS NULL THEN RAISE EXCEPTION 'OFFER_NOT_FOUND'; END IF;
  IF v_offer.sts NOT IN (2) THEN RAISE EXCEPTION 'OFFER_NOT_AVAILABLE'; END IF;
  IF p_user_uid = v_offer.usr_id THEN RAISE EXCEPTION 'CANNOT_BOOK_OWN_OFFER'; END IF;
  IF p_dt <= NOW() THEN RAISE EXCEPTION 'INVALID_APPOINTMENT_TIME'; END IF;

  IF p_request_id IS NOT NULL THEN
    SELECT * INTO v_req
    FROM public.requests
    WHERE id = p_request_id
      AND usr_id = p_user_uid
      AND i_del = 0
      AND sts IN (0, 1)
      AND (ts_end IS NULL OR ts_end > NOW());
    IF v_req.id IS NULL THEN
      RAISE EXCEPTION 'REQUEST_NOT_FOUND_OR_NOT_ACTIVE';
    END IF;
    IF v_req.elm <> v_offer.typ OR v_req.typ <> v_offer.trx THEN
      RAISE EXCEPTION 'REQUEST_OFFER_MISMATCH';
    END IF;
  END IF;

  SELECT COUNT(*) INTO v_pending_completion
  FROM public.completion_requests cr
  JOIN public.appointments a ON a.id = cr.app_id
  WHERE a.off_id = p_offer_id
    AND cr.decision = 'pending';
  IF v_pending_completion > 0 THEN RAISE EXCEPTION 'OFFER_HAS_PENDING_COMPLETION'; END IF;

  -- ✅ القاعدة 1: الحجز حصراً ضمن مواعيد صاحب العرض
  -- avl فارغة = لا معاينة على هذا العرض إطلاقاً (سد ثغرة تخطي الفحص)
  IF v_offer.avl IS NULL OR v_offer.avl = '{}'::jsonb OR v_offer.avl = 'null'::jsonb THEN
    RAISE EXCEPTION 'NO_AVAILABILITY';
  END IF;

  v_day_key := LOWER(to_char(p_dt AT TIME ZONE 'Asia/Damascus', 'Dy'));

  -- 'any' = جاهز بأي وقت → كل الأيام ضمن دوام الإعدادات (09:00-21:00 افتراضياً)
  IF v_offer.avl ? 'any' THEN
    v_avl_slots := jsonb_build_array((v_cfg->>'any_from') || '-' || (v_cfg->>'any_to'));
  ELSE
    v_avl_slots := v_offer.avl -> v_day_key;
  END IF;

  IF v_avl_slots IS NULL OR jsonb_array_length(v_avl_slots) = 0 THEN
    RAISE EXCEPTION 'DAY_NOT_AVAILABLE';
  END IF;

  v_req_mins := EXTRACT(HOUR FROM p_dt AT TIME ZONE 'Asia/Damascus')::INT * 60
              + EXTRACT(MINUTE FROM p_dt AT TIME ZONE 'Asia/Damascus')::INT;
  FOR v_slot IN SELECT jsonb_array_elements_text(v_avl_slots)
  LOOP
    v_slot_from := SPLIT_PART(SPLIT_PART(v_slot, '-', 1), ':', 1)::INT * 60
                 + SPLIT_PART(SPLIT_PART(v_slot, '-', 1), ':', 2)::INT;
    v_slot_to := SPLIT_PART(SPLIT_PART(v_slot, '-', 2), ':', 1)::INT * 60
               + SPLIT_PART(SPLIT_PART(v_slot, '-', 2), ':', 2)::INT;
    IF v_req_mins >= v_slot_from AND v_req_mins < v_slot_to THEN
      v_found_slot := TRUE; EXIT;
    END IF;
  END LOOP;
  IF NOT v_found_slot THEN RAISE EXCEPTION 'TIME_NOT_IN_AVAILABLE_SLOTS'; END IF;

  -- ✅ القاعدة 3: عدم التعارض — فارق لا يقل عن ساعة بين مواعيد نفس العرض
  -- (موعد 10:00 → أقرب حجز مسموح 11:00)
  IF EXISTS (
    SELECT 1 FROM public.appointments
    WHERE off_id = p_offer_id AND sts IN (0, 1)
      AND dt > p_dt - make_interval(mins => v_gap)
      AND dt < p_dt + make_interval(mins => v_gap)
  ) THEN
    RAISE EXCEPTION 'TIME_CONFLICT_ON_OFFER';
  END IF;

  IF EXISTS (SELECT 1 FROM public.appointments WHERE off_id = p_offer_id AND req_uid = p_user_uid AND sts IN (0, 1)) THEN
    RAISE EXCEPTION 'DUPLICATE_APPOINTMENT';
  END IF;

  -- ✅ القاعدة 2: المشرف الأقل مواعيد نشطة، مع استبعاد المشغول ضمن فارق الساعة
  -- (استعلام مرتّب: إن كان الأقل حمولة مشغولاً ينتقل تلقائياً للتالي)
  SELECT u.id INTO v_supervisor
  FROM public.users u
  WHERE u.role = 3 AND u.sts = 0 AND u.i_del = 0
    AND NOT EXISTS (
      SELECT 1 FROM public.appointments a
      WHERE a.supervisor_uid = u.id AND a.sts IN (0, 1)
        AND a.dt > p_dt - make_interval(mins => v_gap)
        AND a.dt < p_dt + make_interval(mins => v_gap)
    )
  ORDER BY (
    SELECT COUNT(*) FROM public.appointments a2 WHERE a2.supervisor_uid = u.id AND a2.sts IN (0, 1)
  ) ASC, u.ts_crt ASC
  LIMIT 1;

  -- ✅ القاعدة 2 (تكملة): لا مشرف متاح → إشعار الطالب + اقتراح أقرب موعد متاح
  IF v_supervisor IS NULL THEN
    v_suggest := public.suggest_appointment_slot(p_offer_id, p_dt);
    PERFORM public.notify_user(
      p_user_uid,
      2,
      'لا يوجد مشرف متاح للتوقيت المطلوب',
      CASE WHEN v_suggest IS NOT NULL
        THEN 'تعذّر تثبيت موعد المعاينة في التوقيت الذي اخترته لعدم توفر مشرف. أقرب موعد متاح: '
             || to_char(v_suggest AT TIME ZONE 'Asia/Damascus', 'YYYY/MM/DD HH24:MI')
             || ' — يمكنك إعادة الحجز عليه أو اختيار وقت آخر.'
        ELSE 'تعذّر تثبيت موعد المعاينة في التوقيت الذي اخترته لعدم توفر مشرف. يرجى اختيار وقت آخر.'
      END,
      p_offer_id::text,
      'appointment_suggest'
    );
    RETURN jsonb_build_object(
      'success', false,
      'error', 'NO_SUPERVISOR_AVAILABLE',
      'suggested_dt', v_suggest
    );
  END IF;

  INSERT INTO public.appointments (
    off_id, req_id, req_uid, own_id, bkr_id, dt, sts,
    supervisor_uid,
    fbk_own, fbk_req, i_force, rmnd_24, rmnd_2, rmnd_qtr, rmnd_end, ts_crt
  ) VALUES (
    p_offer_id, p_request_id, p_user_uid, v_offer.usr_id, COALESCE(p_broker_id, v_offer.brk_id), p_dt, 0,
    v_supervisor,
    0, 0, 0, 0, 0, 0, 0, NOW()
  ) RETURNING id INTO v_appointment_id;

  IF p_request_id IS NOT NULL THEN
    UPDATE public.requests
    SET sts = 1
    WHERE id = p_request_id
      AND usr_id = p_user_uid
      AND sts = 0
      AND i_del = 0;
  END IF;

  SELECT COUNT(*) INTO v_active_count FROM public.appointments WHERE off_id = p_offer_id AND sts IN (0, 1);
  RETURN jsonb_build_object('success', true, 'appointment_id', v_appointment_id, 'active_appointments', v_active_count, 'supervisor_uid', v_supervisor);
END;
$$;

REVOKE ALL ON FUNCTION public.book_appointment_internal(UUID, UUID, TIMESTAMPTZ, UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.book_appointment_internal(UUID, UUID, TIMESTAMPTZ, UUID, UUID) FROM anon;
REVOKE ALL ON FUNCTION public.book_appointment_internal(UUID, UUID, TIMESTAMPTZ, UUID, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.book_appointment_internal(UUID, UUID, TIMESTAMPTZ, UUID, UUID) TO service_role;
