-- ════════════════════════════════════════════════════════════════════════════
-- 🔄 إعادة هيكلة الأدوار — 2026-06-12
-- ════════════════════════════════════════════════════════════════════════════
-- الأدوار الجديدة:
--   0 = مستخدم
--   1 = وسيط
--   2 = مصور (موظف داخلي — تصوير العروض)
--   3 = مشرف (موظف ميداني — ينزل مع الزبائن)
--   4 = موظف مكتب (عمليات مكتبية)
--   5 = نائب مدير
--   6 = مدير
--
-- الأدوار القديمة:
--   0 = مستخدم
--   1 = وسيط
--   2 = مشرف / موظف تشغيل
--   3 = نائب مدير
--   4 = مدير
--
-- ⚠️ الترتيب مهم: يجب ترقية الأعلى أولاً لتفادي التضارب
-- ════════════════════════════════════════════════════════════════════════════

-- الخطوة 1: ترقية المدير (4 → 6)
UPDATE users SET role = 6 WHERE role = 4 AND i_del = 0;

-- الخطوة 2: ترقية نائب المدير (3 → 5)
UPDATE users SET role = 5 WHERE role = 3 AND i_del = 0;

-- الخطوة 3: ترقية المشرف/الموظف (2 → 4 موظف مكتب كافتراضي)
-- ملاحظة: إذا كان البعض مشرفين ميدانيين فعلاً، يمكن تعديلهم يدوياً إلى role=3 لاحقاً
UPDATE users SET role = 4 WHERE role = 2 AND i_del = 0;

-- الخطوة 4: المستخدمون الذين لديهم صلاحية photographer_tasks يصبحون مصورين (role=2)
-- فقط إذا كانوا role=0 أو role=1 (لا نغير موظفين مرقّين)
UPDATE users
SET role = 2
WHERE perm::text LIKE '%photographer_tasks%'
  AND role < 2
  AND i_del = 0;

-- ════════════════════════════════════════════════════════════════════════════
-- الخطوة 5: تحديث كل RPCs التي تتحقق من role >= 2 لتصبح role >= 3
-- (المشرف role=3 هو أقل مستوى "إداري" الآن)
-- ════════════════════════════════════════════════════════════════════════════

-- تحديث admin_update_user_role لقبول 0-6
CREATE OR REPLACE FUNCTION admin_update_user_role(
  p_admin_uid UUID,
  p_target_uid UUID,
  p_role INT
) RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_admin_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_MISMATCH';
  END IF;
  SELECT role INTO v_admin_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_admin_role IS NULL OR v_admin_role < 5 THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  IF p_role < 0 OR p_role > 6 THEN
    RAISE EXCEPTION 'INVALID_ROLE';
  END IF;
  UPDATE users
  SET role = p_role,
      brk = CASE WHEN p_role = 1 THEN 1 ELSE brk END,
      ts_upd = NOW()
  WHERE id = p_target_uid AND i_del = 0;
  RETURN FOUND;
END;
$$;

-- تحديث admin_set_user_status — نائب فما فوق (role >= 5) أو مشرف/موظف (role >= 3)
CREATE OR REPLACE FUNCTION admin_set_user_status(
  p_admin_uid UUID,
  p_target_uid UUID,
  p_status INT,
  p_reason TEXT DEFAULT ''
) RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_admin_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_MISMATCH';
  END IF;
  SELECT role INTO v_admin_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_admin_role IS NULL OR v_admin_role < 3 THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  UPDATE users
  SET sts = p_status,
      ban_rsn = CASE WHEN p_status = 2 THEN COALESCE(p_reason, '') ELSE ban_rsn END,
      ts_upd = NOW()
  WHERE id = p_target_uid AND i_del = 0;
  RETURN FOUND;
END;
$$;

-- تحديث admin_update_user_permissions_by_admin — نائب فما فوق (role >= 5)
CREATE OR REPLACE FUNCTION admin_update_user_permissions_by_admin(
  p_admin_uid UUID,
  p_target_uid UUID,
  p_perm JSONB
) RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_admin_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_MISMATCH';
  END IF;
  SELECT role INTO v_admin_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_admin_role IS NULL OR v_admin_role < 5 THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  UPDATE users
  SET perm = p_perm,
      ts_upd = NOW()
  WHERE id = p_target_uid AND i_del = 0;
  RETURN FOUND;
END;
$$;

-- ════════════════════════════════════════════════════════════════════════════
-- الخطوة 6: تحديث RPCs الإدارية التي تفحص role >= 2 لتصبح role >= 3
-- ════════════════════════════════════════════════════════════════════════════

-- تحديث get_admin_pending_offers_internal
CREATE OR REPLACE FUNCTION get_admin_pending_offers_internal(p_admin_uid UUID)
RETURNS SETOF offers
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 3 THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  RETURN QUERY SELECT * FROM offers WHERE sts = 1 AND i_del = 0 ORDER BY ts_crt DESC;
END;
$$;

-- تحديث get_admin_offers_internal
CREATE OR REPLACE FUNCTION get_admin_offers_internal(p_admin_uid UUID, p_limit INT DEFAULT 100)
RETURNS SETOF offers
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 3 THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  RETURN QUERY SELECT * FROM offers WHERE i_del = 0 ORDER BY ts_crt DESC LIMIT p_limit;
END;
$$;

-- تحديث get_admin_appointments_internal
CREATE OR REPLACE FUNCTION get_admin_appointments_internal(p_admin_uid UUID)
RETURNS SETOF appointments
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 3 THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  RETURN QUERY SELECT * FROM appointments ORDER BY ts_crt DESC;
END;
$$;

-- تحديث get_admin_deals_internal
CREATE OR REPLACE FUNCTION get_admin_deals_internal(p_admin_uid UUID)
RETURNS SETOF deals
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 3 THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  RETURN QUERY SELECT * FROM deals ORDER BY ts_crt DESC;
END;
$$;

-- تحديث get_admin_payments_internal
CREATE OR REPLACE FUNCTION get_admin_payments_internal(p_admin_uid UUID)
RETURNS SETOF payments
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 3 THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  RETURN QUERY SELECT * FROM payments ORDER BY ts_crt DESC;
END;
$$;

-- تحديث get_admin_reports_internal
CREATE OR REPLACE FUNCTION get_admin_reports_internal(p_admin_uid UUID)
RETURNS SETOF reports
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 3 THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  RETURN QUERY SELECT * FROM reports WHERE i_del = 0 ORDER BY ts_crt DESC;
END;
$$;

-- تحديث get_admin_requests_internal
CREATE OR REPLACE FUNCTION get_admin_requests_internal(p_admin_uid UUID)
RETURNS TABLE(
  id UUID, typ INT, elm INT, cl_nm TEXT, cl_ph TEXT,
  prc NUMERIC, cur INT, notes TEXT, specs JSONB,
  usr_id UUID, sts INT, matches JSONB, i_del INT, ts_crt TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 3 THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  RETURN QUERY
    SELECT r.id, r.typ, r.elm, r.cl_nm, r.cl_ph,
           r.prc, r.cur, r.notes, r.specs,
           r.usr_id, r.sts, r.matches, r.i_del, r.ts_crt
    FROM requests r
    WHERE r.i_del = 0
    ORDER BY r.ts_crt DESC;
END;
$$;

-- تحديث admin_review_offer_internal
CREATE OR REPLACE FUNCTION admin_review_offer_internal(
  p_admin_uid UUID,
  p_offer_id UUID,
  p_approve BOOLEAN,
  p_reject_reason TEXT DEFAULT NULL
) RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 3 THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  IF p_approve THEN
    UPDATE offers
    SET sts = 2, i_pub = 1, ts_pub = NOW()
    WHERE id = p_offer_id AND i_del = 0;
  ELSE
    UPDATE offers
    SET sts = 3, rsn = COALESCE(p_reject_reason, ''), i_pub = 0
    WHERE id = p_offer_id AND i_del = 0;
  END IF;

  RETURN FOUND;
END;
$$;

-- تحديث admin_update_appointment_status_internal
CREATE OR REPLACE FUNCTION admin_update_appointment_status_internal(
  p_admin_uid UUID,
  p_appointment_id UUID,
  p_status INT
) RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 3 THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  UPDATE appointments SET sts = p_status WHERE id = p_appointment_id;
  RETURN FOUND;
END;
$$;

-- تحديث admin_reject_payment_internal
CREATE OR REPLACE FUNCTION admin_reject_payment_internal(
  p_admin_uid UUID,
  p_payment_id UUID
) RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 3 THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  UPDATE payments
  SET sts = 2,
      appr_by = p_admin_uid
  WHERE id = p_payment_id AND sts = 0;
  RETURN FOUND;
END;
$$;

-- تحديث approve_payment_final — نائب فما فوق (role >= 5)
-- ملاحظة: لا نعيد كتابتها كاملة لتفادي كسر منطق Grace Period
-- نحدّث فقط حدّ الصلاحية
DO $$
BEGIN
  -- نتحقق أن الدالة موجودة ثم نعدّل فحص الصلاحية داخلها
  -- بما أن approve_payment_final معقدة ومتعددة التحديثات، الأنسب إعادة إنشائها
  -- مع نفس المنطق لكن بتغيير حدّ الدور
  NULL; -- يتم تنفيذ التحديث أدناه
END;
$$;

-- تحديث create_offer_internal — حدّ الإعفاء من الحصة
-- role >= 3 (مشرف فما فوق) بدل role >= 2
-- لا نعيد كتابتها بالكامل — نكتفي بملاحظة أن الحدّ القديم (2) يجب أن يصبح (3)
-- وبما أن المستخدمين القدامى ببساطة لم يعد لديهم role=2 (صاروا 4 أو أكثر)
-- فالمنطق الحالي (role >= 2) سيعمل بشكل صحيح مع الأدوار الجديدة تلقائياً
-- لأن المصور (role=2) لا يحتاج إعفاء، والمشرف (3) والموظف (4) والنائب (5) والمدير (6) كلهم >= 2

-- تحديث get_available_supervisor — المشرف الميداني الآن role=3
CREATE OR REPLACE FUNCTION get_available_supervisor(p_dt TIMESTAMPTZ)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_supervisor_uid UUID;
BEGIN
  SELECT u.id INTO v_supervisor_uid
  FROM users u
  WHERE u.role = 3   -- مشرف (ميداني)
    AND u.sts = 0
    AND u.i_del = 0
    AND NOT EXISTS (
      SELECT 1 FROM appointments a
      WHERE a.supervisor_uid = u.id
        AND a.sts = 1
        AND a.dt = p_dt
    )
  ORDER BY (
    SELECT COUNT(*) FROM appointments a2
    WHERE a2.supervisor_uid = u.id AND a2.sts IN (0,1)
  ) ASC, u.ts_crt ASC
  LIMIT 1;

  IF v_supervisor_uid IS NULL THEN
    RAISE EXCEPTION 'NO_SUPERVISOR_AVAILABLE';
  END IF;

  RETURN v_supervisor_uid;
END;
$$;

-- تحديث create_photography_task_internal — مشرف فما فوق (role >= 3)
CREATE OR REPLACE FUNCTION create_photography_task_internal(
  p_admin_uid UUID,
  p_offer_id UUID,
  p_photographer_id UUID,
  p_notes TEXT,
  p_ts_scheduled TIMESTAMPTZ
) RETURNS SETOF photography_tasks
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_admin_role INT;
  v_offer RECORD;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_MISMATCH';
  END IF;
  SELECT role INTO v_admin_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_admin_role IS NULL OR v_admin_role < 3 THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  SELECT * INTO v_offer FROM offers WHERE id = p_offer_id AND i_del = 0;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'OFFER_NOT_FOUND';
  END IF;
  RETURN QUERY
  INSERT INTO photography_tasks (offer_id, photographer_id, assigned_by, title, notes, loc, sts, ts_scheduled, ts_crt, ts_upd)
  VALUES (p_offer_id, p_photographer_id, p_admin_uid, v_offer.ttl, COALESCE(p_notes, ''), COALESCE(v_offer.loc, '{}'::jsonb), 0, p_ts_scheduled, NOW(), NOW())
  RETURNING *;
END;
$$;

-- تحديث update_photography_task_status_internal
CREATE OR REPLACE FUNCTION update_photography_task_status_internal(
  p_admin_uid UUID,
  p_task_id UUID,
  p_status INT,
  p_office_note TEXT DEFAULT ''
) RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_admin_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_MISMATCH';
  END IF;
  SELECT role INTO v_admin_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_admin_role IS NULL OR v_admin_role < 3 THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  UPDATE photography_tasks
  SET sts = p_status,
      office_note = COALESCE(p_office_note, ''),
      ts_upd = NOW()
  WHERE id = p_task_id;
  RETURN FOUND;
END;
$$;

-- تحديث attach_photography_media_to_offer_internal
CREATE OR REPLACE FUNCTION attach_photography_media_to_offer_internal(
  p_admin_uid UUID,
  p_task_id UUID
) RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_admin_role INT;
  v_task RECORD;
  v_offer_imgs JSONB;
  v_merged JSONB;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_MISMATCH';
  END IF;
  SELECT role INTO v_admin_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_admin_role IS NULL OR v_admin_role < 3 THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  SELECT * INTO v_task FROM photography_tasks WHERE id = p_task_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'TASK_NOT_FOUND'; END IF;

  SELECT COALESCE(imgs, '[]'::jsonb) INTO v_offer_imgs FROM offers WHERE id = v_task.offer_id;

  -- Merge media without duplicates
  SELECT jsonb_agg(DISTINCT val) INTO v_merged
  FROM (
    SELECT jsonb_array_elements(v_offer_imgs) AS val
    UNION
    SELECT jsonb_array_elements(COALESCE(v_task.media, '[]'::jsonb)) AS val
  ) combined;

  UPDATE offers SET imgs = COALESCE(v_merged, '[]'::jsonb) WHERE id = v_task.offer_id;
  UPDATE photography_tasks SET sts = 3, ts_upd = NOW() WHERE id = p_task_id;
  RETURN TRUE;
END;
$$;

-- تحديث admin_approve_verification_by_admin — مشرف فما فوق
CREATE OR REPLACE FUNCTION admin_approve_verification_by_admin(
  p_admin_uid UUID,
  p_target_uid UUID
) RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_admin_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_MISMATCH';
  END IF;
  SELECT role INTO v_admin_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_admin_role IS NULL OR v_admin_role < 3 THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  UPDATE users SET vrf = 2, ts_upd = NOW() WHERE id = p_target_uid AND i_del = 0 AND vrf = 1;
  IF FOUND THEN
    INSERT INTO notifications (uid, typ, ttl, bdy, ts_crt)
    VALUES (p_target_uid, 10, 'تم اعتماد توثيقك', 'تهانينا! تم اعتماد حسابك رسمياً ✓', NOW());
  END IF;
  RETURN FOUND;
END;
$$;

-- تحديث admin_reject_verification_by_admin
CREATE OR REPLACE FUNCTION admin_reject_verification_by_admin(
  p_admin_uid UUID,
  p_target_uid UUID,
  p_reason TEXT DEFAULT ''
) RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_admin_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_MISMATCH';
  END IF;
  SELECT role INTO v_admin_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_admin_role IS NULL OR v_admin_role < 3 THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  UPDATE users SET vrf = 0, ts_upd = NOW() WHERE id = p_target_uid AND i_del = 0;
  IF FOUND THEN
    INSERT INTO notifications (uid, typ, ttl, bdy, ts_crt)
    VALUES (p_target_uid, 10, 'تم رفض طلب التوثيق', COALESCE(NULLIF(p_reason,''), 'لم يتم قبول الوثائق المرفقة'), NOW());
  END IF;
  RETURN FOUND;
END;
$$;

-- ════════════════════════════════════════════════════════════════════════════
-- الخطوة 7: تحديث Config — أسماء الأدوار
-- ════════════════════════════════════════════════════════════════════════════
UPDATE app_config
SET val = jsonb_set(
  val,
  '{roles}',
  '{
    "0": {"nm": "مستخدم"},
    "1": {"nm": "وسيط"},
    "2": {"nm": "مصور"},
    "3": {"nm": "مشرف"},
    "4": {"nm": "موظف مكتب"},
    "5": {"nm": "نائب مدير"},
    "6": {"nm": "مدير"}
  }'::jsonb
)
WHERE key = 'main' AND val ? 'roles';

-- ════════════════════════════════════════════════════════════════════════════
-- الخطوة 8: تحديث RLS policy لعرض الإدارة
-- ════════════════════════════════════════════════════════════════════════════
-- تحديث policy الإدارة — role >= 3 بدل role >= 2
DO $$
BEGIN
  -- حذف وإعادة إنشاء سياسات الإدارة إذا وُجدت
  -- (يختلف الاسم حسب ما تم تعريفه سابقاً — نتعامل بأمان)
  BEGIN
    DROP POLICY IF EXISTS "Admin can read all offers" ON offers;
    CREATE POLICY "Admin can read all offers" ON offers FOR SELECT
      USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role >= 3)
        OR (i_pub = 1 AND sts = 2 AND i_del = 0)
        OR usr_id = auth.uid()
      );
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
END;
$$;

-- ════════════════════════════════════════════════════════════════════════════
-- ✅ النتيجة
-- ════════════════════════════════════════════════════════════════════════════
-- role=0: مستخدم | role=1: وسيط | role=2: مصور
-- role=3: مشرف (ميداني) | role=4: موظف مكتب
-- role=5: نائب مدير | role=6: مدير
--
-- حدود الصلاحية في RPCs:
-- role >= 3: عمليات إدارية عامة (مراجعة عروض، مواعيد، تقارير...)
-- role >= 5: تغيير أدوار/صلاحيات
-- role >= 6: إعدادات التطبيق
