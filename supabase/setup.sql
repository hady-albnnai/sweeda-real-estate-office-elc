-- ============================================================================
--  عقارات السويداء — Supabase Database Setup
--  ============================================================================

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nm TEXT NOT NULL DEFAULT '', ph TEXT UNIQUE NOT NULL DEFAULT '',
  ad TEXT DEFAULT '', role INTEGER DEFAULT 0 CHECK (role BETWEEN 0 AND 4),
  sid TEXT DEFAULT '', img TEXT DEFAULT '', pt INTEGER DEFAULT 0,
  bg INTEGER DEFAULT 0 CHECK (bg BETWEEN 0 AND 4), bg_ts TIMESTAMPTZ,
  b_pkg INTEGER DEFAULT 0 CHECK (b_pkg BETWEEN 0 AND 2), pkg_end TIMESTAMPTZ,
  brk INTEGER DEFAULT 0 CHECK (brk IN (0,1)),
  brk_cls INTEGER DEFAULT 0 CHECK (brk_cls BETWEEN 0 AND 2), brk_nm TEXT DEFAULT '',
  sts INTEGER DEFAULT 0 CHECK (sts BETWEEN 0 AND 2), ban_rsn TEXT DEFAULT '',
  ntf JSONB DEFAULT '{"off":0,"app":0,"fin":0,"rat":0}'::jsonb,
  perm JSONB DEFAULT '[]'::jsonb,
  stats JSONB DEFAULT '{"off":0,"req":0,"app":0,"dl":0}'::jsonb,
  wk_lgn JSONB DEFAULT '[]'::jsonb, strk INTEGER DEFAULT 0, strk_dt TIMESTAMPTZ,
  i_del INTEGER DEFAULT 0 CHECK (i_del IN (0,1)),
  ts_crt TIMESTAMPTZ DEFAULT NOW(), ts_upd TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_users_ph ON users(ph);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_sts ON users(sts);
CREATE INDEX IF NOT EXISTS idx_users_iDel ON users(i_del);

CREATE TABLE IF NOT EXISTS offers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usr_id UUID REFERENCES users(id) ON DELETE SET NULL,
  brk_id UUID REFERENCES users(id) ON DELETE SET NULL,
  brk_pct NUMERIC(5,2) DEFAULT 0,
  typ INTEGER NOT NULL CHECK (typ IN (0,1)), trx INTEGER NOT NULL CHECK (trx IN (0,1)),
  cat INTEGER NOT NULL DEFAULT 0, sub INTEGER DEFAULT 0,
  ttl TEXT NOT NULL DEFAULT '', prc NUMERIC(15,2) NOT NULL DEFAULT 0,
  cur INTEGER DEFAULT 1 CHECK (cur IN (0,1)),
  loc JSONB DEFAULT '{"r":0,"d":""}'::jsonb,
  descript TEXT DEFAULT '', imgs JSONB DEFAULT '[]'::jsonb,
  vdo TEXT DEFAULT '', doc_tp INTEGER DEFAULT 0, doc_img TEXT DEFAULT '',
  exact_loc TEXT DEFAULT '', specs JSONB DEFAULT '{}'::jsonb,
  com NUMERIC(10,2) DEFAULT 0, sts INTEGER DEFAULT 0 CHECK (sts BETWEEN 0 AND 6),
  rsn TEXT DEFAULT '', vws INTEGER DEFAULT 0, fvs INTEGER DEFAULT 0,
  i_pub INTEGER DEFAULT 0 CHECK (i_pub IN (0,1)), i_soc INTEGER DEFAULT 0 CHECK (i_soc IN (0,1)),
  soc_pub INTEGER DEFAULT 0 CHECK (soc_pub IN (0,1)), soc_txt TEXT DEFAULT '',
  i_dup INTEGER DEFAULT 0 CHECK (i_dup IN (0,1)), dup_of UUID,
  avl JSONB DEFAULT '{}'::jsonb,
  i_del INTEGER DEFAULT 0 CHECK (i_del IN (0,1)),
  ts_crt TIMESTAMPTZ DEFAULT NOW(), ts_pub TIMESTAMPTZ, ts_end TIMESTAMPTZ, ts_ren TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_offers_usr ON offers(usr_id, i_del);
CREATE INDEX IF NOT EXISTS idx_offers_sts ON offers(sts, i_del);
CREATE INDEX IF NOT EXISTS idx_offers_iPub ON offers(i_pub, i_del, ts_crt DESC);
CREATE INDEX IF NOT EXISTS idx_offers_typ ON offers(typ, sts, i_del);
CREATE INDEX IF NOT EXISTS idx_offers_trx ON offers(trx, sts, i_del);

CREATE TABLE IF NOT EXISTS requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  typ INTEGER NOT NULL CHECK (typ IN (0,1)), elm INTEGER NOT NULL CHECK (elm IN (0,1)),
  cl_nm TEXT NOT NULL DEFAULT '', cl_ph TEXT NOT NULL DEFAULT '',
  prc NUMERIC(15,2), cur INTEGER DEFAULT 1 CHECK (cur IN (0,1)),
  notes TEXT DEFAULT '', specs JSONB DEFAULT '{}'::jsonb,
  usr_id UUID REFERENCES users(id) ON DELETE SET NULL,
  sts INTEGER DEFAULT 0 CHECK (sts BETWEEN 0 AND 3), matches JSONB DEFAULT '{}'::jsonb,
  i_del INTEGER DEFAULT 0 CHECK (i_del IN (0,1)), ts_crt TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_requests_usr ON requests(usr_id, i_del);
CREATE INDEX IF NOT EXISTS idx_requests_sts ON requests(sts, i_del);

CREATE TABLE IF NOT EXISTS appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  off_id UUID REFERENCES offers(id) ON DELETE SET NULL,
  req_id UUID REFERENCES requests(id) ON DELETE SET NULL,
  own_id UUID REFERENCES users(id) ON DELETE SET NULL,
  bkr_id UUID REFERENCES users(id) ON DELETE SET NULL,
  dt TIMESTAMPTZ NOT NULL, dt_end TIMESTAMPTZ,
  sts INTEGER DEFAULT 0 CHECK (sts BETWEEN 0 AND 3),
  cnl_by UUID, cnl_rsn TEXT,
  fbk_own INTEGER DEFAULT 0 CHECK (fbk_own BETWEEN 0 AND 3),
  fbk_req INTEGER DEFAULT 0 CHECK (fbk_req BETWEEN 0 AND 3),
  fbk_own_dt TIMESTAMPTZ, fbk_req_dt TIMESTAMPTZ,
  fbk_own_dur INTEGER DEFAULT 0, fbk_req_dur INTEGER DEFAULT 0,
  admin_nt TEXT, i_force INTEGER DEFAULT 0 CHECK (i_force IN (0,1)), force_by UUID,
  rmnd_24 INTEGER DEFAULT 0 CHECK (rmnd_24 IN (0,1)),
  rmnd_2 INTEGER DEFAULT 0 CHECK (rmnd_2 IN (0,1)),
  rmnd_qtr INTEGER DEFAULT 0 CHECK (rmnd_qtr IN (0,1)),
  rmnd_end INTEGER DEFAULT 0 CHECK (rmnd_end IN (0,1)),
  ts_crt TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_appointments_own ON appointments(own_id, sts);
CREATE INDEX IF NOT EXISTS idx_appointments_off ON appointments(off_id, sts);
CREATE INDEX IF NOT EXISTS idx_appointments_dt ON appointments(dt, sts);

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uid UUID REFERENCES users(id) ON DELETE CASCADE,
  tp INTEGER NOT NULL CHECK (tp BETWEEN 0 AND 5),
  ttl TEXT NOT NULL DEFAULT '', bdy TEXT NOT NULL DEFAULT '',
  act TEXT DEFAULT '', ref_id TEXT DEFAULT '',
  i_rd INTEGER DEFAULT 0 CHECK (i_rd IN (0,1)), i_del INTEGER DEFAULT 0 CHECK (i_del IN (0,1)),
  ts_crt TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_notifications_uid ON notifications(uid, i_rd, ts_crt DESC);

CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uid UUID REFERENCES users(id) ON DELETE SET NULL,
  tp INTEGER NOT NULL CHECK (tp BETWEEN 0 AND 2), pkg INTEGER DEFAULT 0 CHECK (pkg BETWEEN 0 AND 2),
  amt NUMERIC(10,2) NOT NULL DEFAULT 0, cur INTEGER DEFAULT 1 CHECK (cur BETWEEN 0 AND 2),
  mtd INTEGER DEFAULT 0 CHECK (mtd BETWEEN 0 AND 2),
  proof TEXT DEFAULT '', ref TEXT DEFAULT '',
  sts INTEGER DEFAULT 0 CHECK (sts BETWEEN 0 AND 2), appr_by UUID,
  ts_crt TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_payments_uid ON payments(uid, ts_crt DESC);
CREATE INDEX IF NOT EXISTS idx_payments_sts ON payments(sts);

CREATE TABLE IF NOT EXISTS reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rep_uid UUID REFERENCES users(id) ON DELETE SET NULL,
  tgt_uid UUID REFERENCES users(id) ON DELETE SET NULL,
  tgt_tp INTEGER NOT NULL CHECK (tgt_tp BETWEEN 0 AND 2),
  tgt_id TEXT NOT NULL DEFAULT '', rsn INTEGER NOT NULL,
  det TEXT DEFAULT '', sts INTEGER DEFAULT 0 CHECK (sts BETWEEN 0 AND 3),
  act INTEGER DEFAULT 0 CHECK (act BETWEEN 0 AND 3), act_dur INTEGER DEFAULT 0,
  note TEXT DEFAULT '', act_by UUID, ts_crt TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_reports_rep ON reports(rep_uid, ts_crt DESC);
CREATE INDEX IF NOT EXISTS idx_reports_sts ON reports(sts);

CREATE TABLE IF NOT EXISTS deals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  off_id UUID REFERENCES offers(id) ON DELETE SET NULL,
  app_id UUID REFERENCES appointments(id) ON DELETE SET NULL,
  sell_uid UUID REFERENCES users(id) ON DELETE SET NULL,
  buy_uid UUID REFERENCES users(id) ON DELETE SET NULL,
  brk_uid UUID REFERENCES users(id) ON DELETE SET NULL,
  fin_prc NUMERIC(15,2), cur INTEGER DEFAULT 1 CHECK (cur IN (0,1)),
  com_pct NUMERIC(5,2), com_val NUMERIC(10,2), com_note TEXT,
  form JSONB DEFAULT '{}'::jsonb,
  sts INTEGER DEFAULT 0 CHECK (sts BETWEEN 0 AND 2), cmpl_by UUID,
  i_del INTEGER DEFAULT 0 CHECK (i_del IN (0,1)),
  ts_crt TIMESTAMPTZ DEFAULT NOW(), ts_cmpl TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_deals_sell ON deals(sell_uid, sts);
CREATE INDEX IF NOT EXISTS idx_deals_buy ON deals(buy_uid, sts);

CREATE TABLE IF NOT EXISTS activity_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uid UUID REFERENCES users(id) ON DELETE SET NULL,
  act INTEGER NOT NULL, det TEXT DEFAULT '', ref_id TEXT DEFAULT '', ref_col TEXT DEFAULT '',
  i_del INTEGER DEFAULT 0 CHECK (i_del IN (0,1)), ts_crt TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tp INTEGER NOT NULL CHECK (tp BETWEEN 0 AND 2), dt TIMESTAMPTZ NOT NULL, cnt INTEGER DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_stats_tp_dt ON stats(tp, dt);

CREATE TABLE IF NOT EXISTS app_config (
  key TEXT PRIMARY KEY, value JSONB NOT NULL, description TEXT DEFAULT ''
);

CREATE TABLE IF NOT EXISTS otp_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone TEXT NOT NULL, code TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL, used INTEGER DEFAULT 0 CHECK (used IN (0,1)),
  ts_crt TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_otp_phone ON otp_codes(phone, used, expires_at);

CREATE TABLE IF NOT EXISTS user_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uid UUID REFERENCES users(id) ON DELETE CASCADE,
  device_token TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('android','ios','web')),
  is_active BOOLEAN DEFAULT TRUE,
  ts_crt TIMESTAMPTZ DEFAULT NOW(), ts_upd TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_devices_uid ON user_devices(uid, is_active);

-- Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE offers;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE appointments;
ALTER PUBLICATION supabase_realtime ADD TABLE deals;
ALTER PUBLICATION supabase_realtime ADD TABLE requests;

-- RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE deals ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE otp_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read config" ON app_config FOR SELECT USING (true);
CREATE POLICY "Admin can write config" ON app_config FOR ALL USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role >= 2));
CREATE POLICY "Users can read active users" ON users FOR SELECT USING (i_del = 0);
CREATE POLICY "Users can update own profile" ON users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON users FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Anyone can read published offers" ON offers FOR SELECT USING (i_del = 0 AND (i_pub = 1 OR auth.uid() = usr_id OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role >= 2)));
CREATE POLICY "Authenticated can create offers" ON offers FOR INSERT WITH CHECK (auth.uid() = usr_id);
CREATE POLICY "Owner can update own offer" ON offers FOR UPDATE USING (auth.uid() = usr_id);
CREATE POLICY "Users read own notifications" ON notifications FOR SELECT USING (auth.uid() = uid);
CREATE POLICY "Authenticated can create appointments" ON appointments FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Related users can read appointments" ON appointments FOR SELECT USING (auth.uid() = own_id OR auth.uid() = bkr_id);
CREATE POLICY "Users can read own requests" ON requests FOR SELECT USING (auth.uid() = usr_id AND i_del = 0);
CREATE POLICY "Authenticated can create requests" ON requests FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Users read own payments" ON payments FOR SELECT USING (auth.uid() = uid);
CREATE POLICY "Authenticated can create payments" ON payments FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Users read own reports" ON reports FOR SELECT USING (auth.uid() = rep_uid);
CREATE POLICY "Authenticated can create reports" ON reports FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Related users can read deals" ON deals FOR SELECT USING (auth.uid() = sell_uid OR auth.uid() = buy_uid);
CREATE POLICY "Admin can read activity log" ON activity_log FOR SELECT USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role >= 2));
CREATE POLICY "Authenticated can generate OTP" ON otp_codes FOR INSERT WITH CHECK (true);
CREATE POLICY "Users manage own devices" ON user_devices FOR ALL USING (auth.uid() = uid);

-- Admin UPDATE policies (for payments, reports, deals, offers review etc.)
CREATE POLICY "Admin can update payments" ON payments FOR UPDATE USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role >= 2));
CREATE POLICY "Admin can update reports" ON reports FOR UPDATE USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role >= 2));
CREATE POLICY "Admin can update deals" ON deals FOR UPDATE USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role >= 2));
CREATE POLICY "Admin can update appointments" ON appointments FOR UPDATE USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role >= 2));
CREATE POLICY "Admin can update offers" ON offers FOR UPDATE USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role >= 2) OR auth.uid() = usr_id);

-- Functions
CREATE OR REPLACE FUNCTION generate_otp(p_phone TEXT)
RETURNS TEXT AS $$
DECLARE v_code TEXT;
BEGIN
  v_code := LPAD(FLOOR(RANDOM() * 900000 + 100000)::TEXT, 6, '0');
  INSERT INTO otp_codes (phone, code, expires_at) VALUES (p_phone, v_code, NOW() + INTERVAL '5 minutes');
  RETURN v_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION verify_otp(p_phone TEXT, p_code TEXT)
RETURNS BOOLEAN AS $$
DECLARE v_found BOOLEAN;
BEGIN
  SELECT EXISTS(SELECT 1 FROM otp_codes WHERE phone = p_phone AND code = p_code AND used = 0 AND expires_at > NOW()) INTO v_found;
  IF v_found THEN
    UPDATE otp_codes SET used = 1 WHERE phone = p_phone AND code = p_code AND used = 0 AND expires_at > NOW();
    DELETE FROM otp_codes WHERE phone = p_phone AND used = 1;
    RETURN TRUE;
  END IF;
  RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_user_by_phone(p_phone TEXT)
RETURNS SETOF users AS $$
BEGIN RETURN QUERY SELECT * FROM users WHERE ph = p_phone AND i_del = 0; END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION check_offer_duplicate(p_ttl TEXT, p_prc NUMERIC, p_loc JSONB, p_usr_id UUID)
RETURNS BOOLEAN AS $$
DECLARE v_dup BOOLEAN;
BEGIN SELECT EXISTS(SELECT 1 FROM offers WHERE ttl = p_ttl AND prc = p_prc AND i_del = 0 AND usr_id != p_usr_id) INTO v_dup; RETURN v_dup; END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION calculate_commission(p_prc NUMERIC, p_pct NUMERIC)
RETURNS NUMERIC AS $$ BEGIN RETURN ROUND(p_prc * p_pct / 100, 2); END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_user_badge(p_uid UUID)
RETURNS VOID AS $$
DECLARE v_pts INTEGER; v_new_bg INTEGER;
BEGIN
  SELECT pt INTO v_pts FROM users WHERE id = p_uid;
  IF v_pts IS NULL THEN RETURN; END IF;
  IF v_pts >= 40000 THEN v_new_bg := 4;
  ELSIF v_pts >= 30000 THEN v_new_bg := 3;
  ELSIF v_pts >= 20000 THEN v_new_bg := 2;
  ELSIF v_pts >= 10000 THEN v_new_bg := 1;
  ELSE v_new_bg := 0; END IF;
  UPDATE users SET bg = v_new_bg, bg_ts = NOW() WHERE id = p_uid AND bg != v_new_bg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_pending_offers_count()
RETURNS INTEGER AS $$ DECLARE v_cnt INTEGER; BEGIN SELECT COUNT(*) INTO v_cnt FROM offers WHERE sts = 0 AND i_del = 0; RETURN v_cnt; END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION add_points(p_uid UUID, p_pts INTEGER)
RETURNS VOID AS $$ BEGIN UPDATE users SET pt = pt + p_pts, ts_upd = NOW() WHERE id = p_uid; PERFORM update_user_badge(p_uid); END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION soft_delete(p_table TEXT, p_id UUID)
RETURNS VOID AS $$ BEGIN EXECUTE format('UPDATE %I SET i_del = 1 WHERE id = %L', p_table, p_id); END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION expire_offers()
RETURNS VOID AS $$ BEGIN UPDATE offers SET sts = 4, ts_end = NOW() WHERE sts IN (1, 2) AND i_del = 0 AND ts_crt < NOW() - INTERVAL '30 days'; END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION send_appointment_reminders()
RETURNS VOID AS $$ BEGIN
  UPDATE appointments SET rmnd_2 = 1 WHERE sts IN (0, 1) AND i_force = 0 AND dt <= NOW() + INTERVAL '2 hours' AND dt > NOW() AND rmnd_2 = 0;
  UPDATE appointments SET rmnd_24 = 1 WHERE sts IN (0, 1) AND i_force = 0 AND dt <= NOW() + INTERVAL '24 hours' AND dt > NOW() AND rmnd_24 = 0;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_user_from_phone(p_phone TEXT, p_nm TEXT DEFAULT '')
RETURNS UUID AS $$
DECLARE v_uid UUID; v_exists BOOLEAN;
BEGIN
  SELECT EXISTS(SELECT 1 FROM users WHERE ph = p_phone AND i_del = 0) INTO v_exists;
  IF v_exists THEN SELECT id INTO v_uid FROM users WHERE ph = p_phone AND i_del = 0 LIMIT 1; RETURN v_uid; END IF;
  INSERT INTO users (nm, ph, role, sts, i_del, ts_crt) VALUES (p_nm, p_phone, 0, 0, 0, NOW()) RETURNING id INTO v_uid;
  PERFORM add_points(v_uid, 1000); RETURN v_uid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Config Data
INSERT INTO app_config (key, value, description) VALUES ('main', '{"pts":{"sgn":1000,"wkL":100,"addO":500,"att":300,"dlD":2000,"ref":1500,"strk":50,"soc":100,"like":{"p":5,"l":10},"shr":{"p":10,"l":5},"cmt":{"p":20,"l":3},"gft":{"max":500,"pw":1}},"pen":{"noSh":-500,"cnl3":-300,"rej3":-1000,"fRp":-2000,"ban":-40000},"spd":{"ren":500,"pin":2000,"bst":4000,"dsc5":3000,"fms":8000},"bdg":{"0":{"nm":"🔰 جديد","p":0,"d":0},"1":{"nm":"🥉 برونزي","p":10000,"d":10},"2":{"nm":"🥈 فضي","p":20000,"d":15},"3":{"nm":"🥇 ذهبي","p":30000,"d":20,"eS":1},"4":{"nm":"💎 ماسي","p":40000,"d":20,"eS":1,"fA":1}},"pkg":{"0":{"nm":"مجاني","o":5,"d":30},"1":{"nm":"فضي","o":15,"d":45},"2":{"nm":"ذهبي","o":40,"d":60}},"com":{"sl":3,"rn":"hm","ml":2},"qta":{"u":{"o":1,"r":3,"a":3},"b":{"o":5,"r":5,"a":3}},"soc":{"fb":"","ig":"","tk":"","wa":""},"ads":{"mx":5,"dd":7,"pr":null},"rptRsn":["إعلان وهمي / غير موجود","احتيال / نصب","معلومات مضللة","مضايقة / سلوك غير لائق","عرض مكرر","آخر"],"txts":{"plg":"إقرار وتعهد إلكتروني — عقارات السويداء","warnApp":"تحذير: هذا العرض عليه مواعيد سابقة","visBlk":"تسجيل دخول مطلوب","bnRsn":"تم حظر حسابك نهائياً","frzRsn":"تم تجميد حسابك"},"catProp":{"0":{"nm":"سكني","sub":["شقة سكنية","دار عربي","فيلا","مزرعة","بناء كامل","سطح"]},"1":{"nm":"تجاري","sub":["محل تجاري","معرض","مركز تجاري","مكتب","مستودع"]},"2":{"nm":"زراعي","sub":["أرض زراعية","مزرعة دواجن","مزرعة مواشي","مشتل"]},"3":{"nm":"صناعي","sub":["منشأة صناعية","ورشة","مصنع","أرض صناعية"]}},"catVeh":{"0":{"nm":"سيارة","sub":["سيدان","دفع رباعي","هاتشباك","كوبيه","مكشوفة"]},"1":{"nm":"شاحنة","sub":["شاحنة صغيرة","شاحنة كبيرة","نقل عام"]},"2":{"nm":"دراجة نارية","sub":["دراجة عادية","دراجة رياضية","دراجة كهربائية"]},"3":{"nm":"معدات ثقيلة","sub":["جرّار","حفّارة","حصّادة","درّاسة"]},"4":{"nm":"باصات/نقل","sub":["باص سكانيا","باص 24 راكب","ميكروباص","فان"]}},"docTp":{"0":"طابو أخضر","1":"حصة سهمية-حكم محكمة","2":"حصة سهمية-كاتب بالعدل","3":"مستملك","4":"تسلسل عقود","5":"جمعيات سكنية","6":"نمرة قديمة","7":"نمرة جديدة","8":"وارد"},"brnds":["تويوتا","هوندا","نيسان","هيونداي","كيا","مرسيدس","بي إم دبليو","فولكس فاجن","رينو","فورد","شيفروليه","أخرى"],"clrs":["أبيض","أسود","فضي","رمادي","أحمر","أزرق","أخضر","أصفر","بيج","بني","ذهبي","أخرى"],"roles":{"0":{"nm":"مستخدم"},"1":{"nm":"وسيط"},"2":{"nm":"مشرف"},"3":{"nm":"نائب"},"4":{"nm":"مدير"}}}'::jsonb, 'إعدادات التطبيق الرئيسية');

-- ============================================================================
-- Internal permissions management (2026-06-10)
-- ============================================================================
ALTER TABLE users
ADD COLUMN IF NOT EXISTS perm JSONB NOT NULL DEFAULT '[]'::jsonb;

CREATE OR REPLACE FUNCTION admin_update_user_permissions(
  p_target_uid UUID,
  p_perm JSONB DEFAULT '[]'::jsonb
)
RETURNS BOOLEAN AS $$
DECLARE
  v_admin_role INT;
  v_item TEXT;
  v_allowed TEXT[] := ARRAY[
    'admin_dashboard',
    'office_operations',
    'manage_users',
    'manage_permissions',
    'review_offers',
    'review_verifications',
    'media_review',
    'photography_management',
    'photographer_tasks',
    'fraud_suspects',
    'manage_appointments',
    'manage_deals',
    'manage_payments',
    'manage_reports',
    'manage_config',
    'view_analytics',
    'broker_dashboard',
    'broker_offers',
    'broker_appointments',
    'broker_deals',
    'broker_stats',
    'user_home',
    'user_offers',
    'user_requests',
    'user_appointments',
    'user_profile'
  ];
BEGIN
  SELECT role INTO v_admin_role FROM users WHERE id = auth.uid();

  IF v_admin_role IS NULL OR v_admin_role < 3 THEN
    RAISE EXCEPTION 'FORBIDDEN: Deputy/admin role required.';
  END IF;

  IF p_perm IS NULL THEN
    p_perm := '[]'::jsonb;
  END IF;

  IF jsonb_typeof(p_perm) <> 'array' THEN
    RAISE EXCEPTION 'INVALID_PERMISSIONS: Expected JSON array.';
  END IF;

  FOR v_item IN SELECT jsonb_array_elements_text(p_perm)
  LOOP
    IF NOT (v_item = ANY(v_allowed)) THEN
      RAISE EXCEPTION 'INVALID_PERMISSION: %', v_item;
    END IF;
  END LOOP;

  UPDATE users
  SET perm = p_perm,
      ts_upd = NOW()
  WHERE id = p_target_uid
    AND i_del = 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

REVOKE EXECUTE ON FUNCTION admin_update_user_permissions FROM anon;
GRANT EXECUTE ON FUNCTION admin_update_user_permissions TO authenticated;


-- ============================================================================
-- Photography tasks workflow (2026-06-10)
-- ============================================================================
-- ════════════════════════════════════════════════════════════════════════════
-- Photography tasks workflow
-- Date: 2026-06-10
-- Purpose:
--   Adds a lightweight internal workflow for assigning photographers to offers,
--   uploading media, submitting to office, and approving/rejecting the media.
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS photography_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  off_id UUID REFERENCES offers(id) ON DELETE CASCADE,
  photographer_id UUID REFERENCES users(id) ON DELETE SET NULL,
  requested_by UUID REFERENCES users(id) ON DELETE SET NULL,
  ttl TEXT NOT NULL DEFAULT '',
  notes TEXT NOT NULL DEFAULT '',
  loc JSONB DEFAULT '{}'::jsonb,
  media JSONB NOT NULL DEFAULT '[]'::jsonb,
  photographer_note TEXT NOT NULL DEFAULT '',
  office_note TEXT NOT NULL DEFAULT '',
  sts INTEGER NOT NULL DEFAULT 0 CHECK (sts BETWEEN 0 AND 5),
  ts_scheduled TIMESTAMPTZ,
  ts_submit TIMESTAMPTZ,
  ts_done TIMESTAMPTZ,
  ts_crt TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ts_upd TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_photo_tasks_offer ON photography_tasks(off_id);
CREATE INDEX IF NOT EXISTS idx_photo_tasks_photographer ON photography_tasks(photographer_id, sts);
CREATE INDEX IF NOT EXISTS idx_photo_tasks_status ON photography_tasks(sts, ts_crt DESC);

ALTER TABLE photography_tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Photography tasks read" ON photography_tasks;
CREATE POLICY "Photography tasks read" ON photography_tasks
FOR SELECT USING (
  auth.uid() = photographer_id
  OR auth.uid() = requested_by
  OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role >= 2 AND i_del = 0)
);

DROP POLICY IF EXISTS "Admin can insert photography tasks" ON photography_tasks;
CREATE POLICY "Admin can insert photography tasks" ON photography_tasks
FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role >= 2 AND i_del = 0)
);

DROP POLICY IF EXISTS "Admin or photographer can update photography tasks" ON photography_tasks;
CREATE POLICY "Admin or photographer can update photography tasks" ON photography_tasks
FOR UPDATE USING (
  auth.uid() = photographer_id
  OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role >= 2 AND i_del = 0)
);


-- ============================================================================
-- Admin user role/status + phone uniqueness hardening (2026-06-10)
-- ============================================================================
-- ════════════════════════════════════════════════════════════════════════════
-- Admin user role/status RPCs + phone uniqueness hardening
-- Date: 2026-06-10
-- Purpose:
--   Fix admin user role/status changes under the current dev auth model and
--   prevent duplicate user accounts for the same phone in different formats.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION normalize_sy_phone(p_phone TEXT)
RETURNS TEXT AS $$
DECLARE
  v TEXT;
BEGIN
  v := COALESCE(p_phone, '');
  v := regexp_replace(v, '[^0-9+]', '', 'g');

  IF v = '' THEN
    RETURN '';
  END IF;

  IF left(v, 1) = '+' THEN
    IF left(v, 4) = '+963' THEN
      RETURN v;
    END IF;
    RETURN v;
  END IF;

  IF left(v, 4) = '00963' THEN
    RETURN '+963' || substring(v from 6);
  END IF;

  IF left(v, 3) = '963' THEN
    RETURN '+' || v;
  END IF;

  IF left(v, 1) = '0' THEN
    RETURN '+963' || substring(v from 2);
  END IF;

  IF left(v, 1) = '9' THEN
    RETURN '+963' || v;
  END IF;

  RETURN v;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

UPDATE users
SET ph = normalize_sy_phone(ph),
    ts_upd = NOW()
WHERE ph IS NOT NULL
  AND ph <> normalize_sy_phone(ph);

CREATE UNIQUE INDEX IF NOT EXISTS ux_users_normalized_phone_active
ON users (normalize_sy_phone(ph))
WHERE i_del = 0 AND COALESCE(ph, '') <> '';

CREATE OR REPLACE FUNCTION admin_update_user_role(
  p_admin_uid UUID,
  p_target_uid UUID,
  p_role INT
)
RETURNS BOOLEAN AS $$
DECLARE
  v_admin_role INT;
BEGIN
  SELECT role INTO v_admin_role FROM users WHERE id = p_admin_uid AND i_del = 0;

  IF v_admin_role IS NULL OR v_admin_role < 3 THEN
    RAISE EXCEPTION 'FORBIDDEN: Deputy/admin role required.';
  END IF;

  IF p_role < 0 OR p_role > 4 THEN
    RAISE EXCEPTION 'INVALID_ROLE';
  END IF;

  UPDATE users
  SET role = p_role,
      brk = CASE WHEN p_role = 1 THEN 1 ELSE brk END,
      ts_upd = NOW()
  WHERE id = p_target_uid
    AND i_del = 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_set_user_status(
  p_admin_uid UUID,
  p_target_uid UUID,
  p_status INT,
  p_reason TEXT DEFAULT ''
)
RETURNS BOOLEAN AS $$
DECLARE
  v_admin_role INT;
BEGIN
  SELECT role INTO v_admin_role FROM users WHERE id = p_admin_uid AND i_del = 0;

  IF v_admin_role IS NULL OR v_admin_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN: Admin role required.';
  END IF;

  IF p_status < 0 OR p_status > 2 THEN
    RAISE EXCEPTION 'INVALID_STATUS';
  END IF;

  UPDATE users
  SET sts = p_status,
      ban_rsn = CASE WHEN p_status = 0 THEN '' ELSE COALESCE(p_reason, '') END,
      ts_upd = NOW()
  WHERE id = p_target_uid
    AND i_del = 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_user_from_phone(p_phone TEXT, p_nm TEXT DEFAULT '')
RETURNS UUID AS $$
DECLARE
  v_uid UUID;
  v_phone TEXT;
BEGIN
  v_phone := normalize_sy_phone(p_phone);

  SELECT id INTO v_uid
  FROM users
  WHERE normalize_sy_phone(ph) = v_phone
    AND i_del = 0
  LIMIT 1;

  IF v_uid IS NOT NULL THEN
    RETURN v_uid;
  END IF;

  INSERT INTO users (nm, ph, role, sts, i_del, ts_crt)
  VALUES (p_nm, v_phone, 0, 0, 0, NOW())
  RETURNING id INTO v_uid;

  PERFORM add_points(v_uid, 1000);
  RETURN v_uid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION normalize_sy_phone(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_update_user_role(UUID, UUID, INT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION admin_set_user_status(UUID, UUID, INT, TEXT) TO authenticated, anon;

CREATE OR REPLACE FUNCTION admin_update_user_permissions_by_admin(
  p_admin_uid UUID,
  p_target_uid UUID,
  p_perm JSONB DEFAULT '[]'::jsonb
)
RETURNS BOOLEAN AS $$
DECLARE
  v_admin_role INT;
  v_item TEXT;
  v_allowed TEXT[] := ARRAY[
    'admin_dashboard',
    'office_operations',
    'manage_users',
    'manage_permissions',
    'review_offers',
    'review_verifications',
    'media_review',
    'photography_management',
    'photographer_tasks',
    'fraud_suspects',
    'manage_appointments',
    'manage_deals',
    'manage_payments',
    'manage_reports',
    'manage_config',
    'view_analytics',
    'broker_dashboard',
    'broker_offers',
    'broker_appointments',
    'broker_deals',
    'broker_stats',
    'user_home',
    'user_offers',
    'user_requests',
    'user_appointments',
    'user_profile'
  ];
BEGIN
  SELECT role INTO v_admin_role FROM users WHERE id = p_admin_uid AND i_del = 0;

  IF v_admin_role IS NULL OR v_admin_role < 3 THEN
    RAISE EXCEPTION 'FORBIDDEN: Deputy/admin role required.';
  END IF;

  IF p_perm IS NULL THEN
    p_perm := '[]'::jsonb;
  END IF;

  IF jsonb_typeof(p_perm) <> 'array' THEN
    RAISE EXCEPTION 'INVALID_PERMISSIONS: Expected JSON array.';
  END IF;

  FOR v_item IN SELECT jsonb_array_elements_text(p_perm)
  LOOP
    IF NOT (v_item = ANY(v_allowed)) THEN
      RAISE EXCEPTION 'INVALID_PERMISSION: %', v_item;
    END IF;
  END LOOP;

  UPDATE users
  SET perm = p_perm,
      ts_upd = NOW()
  WHERE id = p_target_uid
    AND i_del = 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION admin_update_user_permissions_by_admin(UUID, UUID, JSONB) TO authenticated, anon;


-- ============================================================================
-- Offer creation RPC for dev auth model (2026-06-10)
-- ============================================================================
-- ════════════════════════════════════════════════════════════════════════════
-- Offer creation RPC for current dev auth model
-- Date: 2026-06-10
-- Purpose:
--   Avoid direct INSERT failures under RLS when auth.uid() is not available
--   in the WhatsApp dev fallback flow.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION create_offer_internal(
  p_user_uid UUID,
  p_offer JSONB
)
RETURNS SETOF offers AS $$
DECLARE
  v_user users%ROWTYPE;
BEGIN
  SELECT * INTO v_user
  FROM users
  WHERE id = p_user_uid
    AND i_del = 0
    AND sts = 0;

  IF v_user.id IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_ACTIVE_OR_NOT_FOUND';
  END IF;

  RETURN QUERY
  INSERT INTO offers (
    usr_id,
    brk_id,
    brk_pct,
    typ,
    trx,
    cat,
    sub,
    contact_ph,
    ttl,
    prc,
    cur,
    loc,
    descript,
    imgs,
    vdo,
    doc_tp,
    doc_img,
    exact_loc,
    specs,
    com,
    sts,
    rsn,
    vws,
    fvs,
    i_pub,
    i_soc,
    soc_pub,
    soc_txt,
    i_dup,
    dup_of,
    avl,
    i_del,
    ts_crt,
    ts_pub,
    ts_end,
    ts_ren
  ) VALUES (
    p_user_uid,
    NULLIF(p_offer->>'brk_id', '')::UUID,
    COALESCE((p_offer->>'brk_pct')::NUMERIC, 0),
    COALESCE((p_offer->>'typ')::INT, 0),
    COALESCE((p_offer->>'trx')::INT, 0),
    COALESCE((p_offer->>'cat')::INT, 0),
    COALESCE((p_offer->>'sub')::INT, 0),
    COALESCE(p_offer->>'contact_ph', ''),
    COALESCE(p_offer->>'ttl', ''),
    COALESCE((p_offer->>'prc')::NUMERIC, 0),
    COALESCE((p_offer->>'cur')::INT, 1),
    COALESCE(p_offer->'loc', '{"r":0,"d":""}'::jsonb),
    COALESCE(p_offer->>'descript', ''),
    COALESCE(p_offer->'imgs', '[]'::jsonb),
    COALESCE(p_offer->>'vdo', ''),
    COALESCE((p_offer->>'doc_tp')::INT, 0),
    COALESCE(p_offer->>'doc_img', ''),
    COALESCE(p_offer->>'exact_loc', ''),
    COALESCE(p_offer->'specs', '{}'::jsonb),
    COALESCE((p_offer->>'com')::NUMERIC, 0),
    COALESCE((p_offer->>'sts')::INT, 0),
    COALESCE(p_offer->>'rsn', ''),
    COALESCE((p_offer->>'vws')::INT, 0),
    COALESCE((p_offer->>'fvs')::INT, 0),
    COALESCE((p_offer->>'i_pub')::INT, 0),
    COALESCE((p_offer->>'i_soc')::INT, 0),
    COALESCE((p_offer->>'soc_pub')::INT, 0),
    COALESCE(p_offer->>'soc_txt', ''),
    COALESCE((p_offer->>'i_dup')::INT, 0),
    NULLIF(p_offer->>'dup_of', '')::UUID,
    COALESCE(p_offer->'avl', '{}'::jsonb),
    COALESCE((p_offer->>'i_del')::INT, 0),
    NOW(),
    NULL,
    NULL,
    NULL
  )
  RETURNING *;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION create_offer_internal(UUID, JSONB) TO anon, authenticated;


-- ============================================================================
-- Ensure WhatsApp/SMS auth upsert uses normalized phone (2026-06-10)
-- ============================================================================
-- ════════════════════════════════════════════════════════════════════════════
-- Ensure WhatsApp/SMS auth upsert uses normalized phone
-- Date: 2026-06-10
-- Purpose:
--   The dev fallback login path calls upsert_user_after_otp, so it must use
--   normalize_sy_phone to avoid duplicated accounts for the same phone.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION upsert_user_after_otp(
  p_identifier TEXT,
  p_channel TEXT
)
RETURNS TABLE(user_id UUID, is_new BOOLEAN) AS $$
DECLARE
  v_uid UUID;
  v_new BOOLEAN := FALSE;
  v_identifier TEXT;
BEGIN
  IF p_channel = 'whatsapp' OR p_channel = 'sms' THEN
    v_identifier := normalize_sy_phone(p_identifier);

    SELECT id INTO v_uid
    FROM users
    WHERE normalize_sy_phone(ph) = v_identifier
      AND i_del = 0
    LIMIT 1;

    IF v_uid IS NULL THEN
      INSERT INTO users (nm, ph, eml, role, sts, i_del, ts_crt)
      VALUES ('', v_identifier, '', 0, 0, 0, NOW())
      RETURNING id INTO v_uid;
      v_new := TRUE;
    END IF;
  ELSIF p_channel = 'email' THEN
    v_identifier := LOWER(TRIM(p_identifier));

    SELECT id INTO v_uid
    FROM users
    WHERE LOWER(COALESCE(eml, '')) = v_identifier
      AND i_del = 0
    LIMIT 1;

    IF v_uid IS NULL THEN
      INSERT INTO users (nm, ph, eml, role, sts, i_del, ts_crt)
      VALUES ('', '', v_identifier, 0, 0, 0, NOW())
      RETURNING id INTO v_uid;
      v_new := TRUE;
    END IF;
  END IF;

  RETURN QUERY SELECT v_uid, v_new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION upsert_user_after_otp(TEXT, TEXT) TO anon, authenticated;


-- ============================================================================
-- Photography RPCs compatible with current dev auth model (2026-06-10)
-- ============================================================================
-- ════════════════════════════════════════════════════════════════════════════
-- Photography RPCs compatible with current dev auth model
-- Date: 2026-06-10
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION create_photography_task_internal(
  p_admin_uid UUID,
  p_offer_id UUID,
  p_photographer_id UUID,
  p_notes TEXT DEFAULT '',
  p_ts_scheduled TIMESTAMPTZ DEFAULT NULL
)
RETURNS SETOF photography_tasks AS $$
DECLARE
  v_admin_role INT;
  v_offer offers%ROWTYPE;
BEGIN
  SELECT role INTO v_admin_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_admin_role IS NULL OR v_admin_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN: Admin role required.';
  END IF;

  SELECT * INTO v_offer FROM offers WHERE id = p_offer_id AND i_del = 0;
  IF v_offer.id IS NULL THEN
    RAISE EXCEPTION 'OFFER_NOT_FOUND';
  END IF;

  RETURN QUERY
  INSERT INTO photography_tasks (
    off_id,
    photographer_id,
    requested_by,
    ttl,
    notes,
    loc,
    sts,
    ts_scheduled,
    ts_crt,
    ts_upd
  ) VALUES (
    p_offer_id,
    p_photographer_id,
    p_admin_uid,
    v_offer.ttl,
    COALESCE(p_notes, ''),
    COALESCE(v_offer.loc, '{}'::jsonb),
    0,
    p_ts_scheduled,
    NOW(),
    NOW()
  )
  RETURNING *;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION submit_photography_task_internal(
  p_photographer_uid UUID,
  p_task_id UUID,
  p_media JSONB,
  p_photographer_note TEXT DEFAULT ''
)
RETURNS BOOLEAN AS $$
BEGIN
  IF jsonb_typeof(COALESCE(p_media, '[]'::jsonb)) <> 'array' THEN
    RAISE EXCEPTION 'INVALID_MEDIA_ARRAY';
  END IF;

  UPDATE photography_tasks
  SET media = COALESCE(p_media, '[]'::jsonb),
      photographer_note = COALESCE(p_photographer_note, ''),
      sts = 2,
      ts_submit = NOW(),
      ts_upd = NOW()
  WHERE id = p_task_id
    AND photographer_id = p_photographer_uid
    AND sts IN (0, 1, 4);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'TASK_NOT_FOUND_OR_NOT_ALLOWED';
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_photography_task_status_internal(
  p_admin_uid UUID,
  p_task_id UUID,
  p_status INT,
  p_office_note TEXT DEFAULT ''
)
RETURNS BOOLEAN AS $$
DECLARE
  v_admin_role INT;
BEGIN
  SELECT role INTO v_admin_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_admin_role IS NULL OR v_admin_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN: Admin role required.';
  END IF;

  IF p_status < 0 OR p_status > 5 THEN
    RAISE EXCEPTION 'INVALID_STATUS';
  END IF;

  UPDATE photography_tasks
  SET sts = p_status,
      office_note = COALESCE(p_office_note, office_note),
      ts_done = CASE WHEN p_status IN (3, 4, 5) THEN NOW() ELSE ts_done END,
      ts_upd = NOW()
  WHERE id = p_task_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'TASK_NOT_FOUND';
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION attach_photography_media_to_offer_internal(
  p_admin_uid UUID,
  p_task_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  v_admin_role INT;
  v_task photography_tasks%ROWTYPE;
  v_existing JSONB;
BEGIN
  SELECT role INTO v_admin_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_admin_role IS NULL OR v_admin_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN: Admin role required.';
  END IF;

  SELECT * INTO v_task FROM photography_tasks WHERE id = p_task_id;
  IF v_task.id IS NULL THEN
    RAISE EXCEPTION 'TASK_NOT_FOUND';
  END IF;

  IF jsonb_array_length(COALESCE(v_task.media, '[]'::jsonb)) = 0 THEN
    RAISE EXCEPTION 'NO_MEDIA';
  END IF;

  SELECT COALESCE(imgs, '[]'::jsonb) INTO v_existing
  FROM offers
  WHERE id = v_task.off_id;

  UPDATE offers
  SET imgs = (
    SELECT jsonb_agg(DISTINCT value)
    FROM jsonb_array_elements(v_existing || v_task.media)
  )
  WHERE id = v_task.off_id;

  UPDATE photography_tasks
  SET sts = 3,
      office_note = 'تم اعتماد التصوير وربط الوسائط بالعرض',
      ts_done = NOW(),
      ts_upd = NOW()
  WHERE id = p_task_id;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION create_photography_task_internal(UUID, UUID, UUID, TEXT, TIMESTAMPTZ) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION submit_photography_task_internal(UUID, UUID, JSONB, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION update_photography_task_status_internal(UUID, UUID, INT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION attach_photography_media_to_offer_internal(UUID, UUID) TO anon, authenticated;


-- ============================================================================
-- QA system check RPC (2026-06-10)
-- ============================================================================
-- ════════════════════════════════════════════════════════════════════════════
-- QA system check RPC
-- Date: 2026-06-10
-- Purpose:
--   Returns a JSON report for server-side readiness checks from the admin QA UI.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION qa_system_check(p_admin_uid UUID)
RETURNS JSONB AS $$
DECLARE
  v_admin_role INT;
  v_checks JSONB := '[]'::jsonb;
  v_ok BOOLEAN;
  v_details TEXT;
  v_duplicate_phones INT := 0;
  v_total_users INT := 0;
  v_total_offers INT := 0;
  v_total_photo_tasks INT := 0;
BEGIN
  SELECT role INTO v_admin_role
  FROM users
  WHERE id = p_admin_uid
    AND i_del = 0;

  v_checks := v_checks || jsonb_build_object(
    'name', 'admin identity',
    'ok', COALESCE(v_admin_role >= 2, FALSE),
    'details', COALESCE('role=' || v_admin_role::TEXT, 'admin user not found')
  );

  -- Required tables
  FOREACH v_details IN ARRAY ARRAY[
    'users', 'offers', 'requests', 'appointments', 'notifications', 'payments',
    'reports', 'deals', 'app_config', 'user_devices', 'photography_tasks'
  ]
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = v_details
    ) INTO v_ok;
    v_checks := v_checks || jsonb_build_object(
      'name', 'table: ' || v_details,
      'ok', v_ok,
      'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- Required columns
  FOREACH v_details IN ARRAY ARRAY[
    'users.perm', 'users.role', 'users.sts', 'users.ph',
    'offers.imgs', 'offers.vdo', 'offers.doc_img',
    'photography_tasks.media', 'photography_tasks.sts', 'photography_tasks.photographer_id'
  ]
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = split_part(v_details, '.', 1)
        AND column_name = split_part(v_details, '.', 2)
    ) INTO v_ok;
    v_checks := v_checks || jsonb_build_object(
      'name', 'column: ' || v_details,
      'ok', v_ok,
      'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- Required functions
  FOREACH v_details IN ARRAY ARRAY[
    'normalize_sy_phone',
    'admin_update_user_role',
    'admin_set_user_status',
    'admin_update_user_permissions',
    'admin_update_user_permissions_by_admin',
    'create_offer_internal',
    'upsert_user_after_otp',
    'create_photography_task_internal',
    'submit_photography_task_internal',
    'update_photography_task_status_internal',
    'attach_photography_media_to_offer_internal',
    'get_user_full_by_id',
    'register_weekly_login',
    'approve_payment_final',
    'admin_fraud_suspects'
  ]
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proname = v_details
    ) INTO v_ok;
    v_checks := v_checks || jsonb_build_object(
      'name', 'function: ' || v_details,
      'ok', v_ok,
      'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- RLS checks
  FOREACH v_details IN ARRAY ARRAY['users', 'offers', 'photography_tasks', 'payments', 'reports']
  LOOP
    SELECT COALESCE(c.relrowsecurity, FALSE)
    INTO v_ok
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = v_details;

    v_checks := v_checks || jsonb_build_object(
      'name', 'rls: ' || v_details,
      'ok', COALESCE(v_ok, FALSE),
      'details', CASE WHEN COALESCE(v_ok, FALSE) THEN 'enabled' ELSE 'disabled/missing' END
    );
  END LOOP;

  -- Indexes
  SELECT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'ux_users_normalized_phone_active'
  ) INTO v_ok;
  v_checks := v_checks || jsonb_build_object(
    'name', 'index: ux_users_normalized_phone_active',
    'ok', v_ok,
    'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
  );

  -- Duplicate phones after normalization
  SELECT COUNT(*) INTO v_duplicate_phones
  FROM (
    SELECT normalize_sy_phone(ph)
    FROM users
    WHERE i_del = 0 AND COALESCE(ph, '') <> ''
    GROUP BY normalize_sy_phone(ph)
    HAVING COUNT(*) > 1
  ) d;
  v_checks := v_checks || jsonb_build_object(
    'name', 'duplicate normalized phones',
    'ok', v_duplicate_phones = 0,
    'details', v_duplicate_phones::TEXT
  );

  -- Counts
  SELECT COUNT(*) INTO v_total_users FROM users WHERE i_del = 0;
  SELECT COUNT(*) INTO v_total_offers FROM offers WHERE i_del = 0;
  SELECT COUNT(*) INTO v_total_photo_tasks FROM photography_tasks;

  RETURN jsonb_build_object(
    'ok', NOT EXISTS (
      SELECT 1
      FROM jsonb_array_elements(v_checks) item
      WHERE COALESCE((item->>'ok')::BOOLEAN, FALSE) = FALSE
    ),
    'generated_at', NOW(),
    'summary', jsonb_build_object(
      'users', v_total_users,
      'offers', v_total_offers,
      'photography_tasks', v_total_photo_tasks,
      'duplicate_phones', v_duplicate_phones
    ),
    'checks', v_checks
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION qa_system_check(UUID) TO anon, authenticated;


-- ============================================================================
-- Extended QA system check RPC (2026-06-10)
-- ============================================================================
-- ════════════════════════════════════════════════════════════════════════════
-- Extended QA system check RPC
-- Date: 2026-06-10
-- Purpose:
--   Expands /admin/qa to cover schema, functions, RLS, storage, config,
--   and data-integrity checks.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION qa_system_check(p_admin_uid UUID)
RETURNS JSONB AS $$
DECLARE
  v_admin_role INT;
  v_checks JSONB := '[]'::jsonb;
  v_ok BOOLEAN;
  v_name TEXT;
  v_count INT := 0;
  v_text TEXT;
  v_config JSONB := '{}'::jsonb;
  v_duplicate_phones INT := 0;
  v_total_users INT := 0;
  v_total_offers INT := 0;
  v_total_photo_tasks INT := 0;
  v_pending_offers INT := 0;
  v_pending_payments INT := 0;
  v_open_reports INT := 0;
  v_pending_verifications INT := 0;
BEGIN
  SELECT role INTO v_admin_role
  FROM users
  WHERE id = p_admin_uid
    AND i_del = 0;

  v_checks := v_checks || jsonb_build_object(
    'name', 'auth/admin: current admin identity',
    'ok', COALESCE(v_admin_role >= 2, FALSE),
    'details', COALESCE('role=' || v_admin_role::TEXT, 'admin user not found')
  );

  -- Tables
  FOREACH v_name IN ARRAY ARRAY[
    'users', 'offers', 'requests', 'appointments', 'notifications', 'payments',
    'reports', 'deals', 'activity_log', 'stats', 'app_config', 'otp_codes',
    'user_devices', 'photography_tasks', 'ratings'
  ]
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = v_name
    ) INTO v_ok;
    v_checks := v_checks || jsonb_build_object(
      'name', 'schema/table: ' || v_name,
      'ok', v_ok,
      'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- Columns
  FOREACH v_name IN ARRAY ARRAY[
    'users.id', 'users.nm', 'users.ph', 'users.eml', 'users.role', 'users.sts',
    'users.i_del', 'users.perm', 'users.vrf', 'users.device_id',
    'offers.id', 'offers.usr_id', 'offers.typ', 'offers.trx', 'offers.ttl',
    'offers.prc', 'offers.loc', 'offers.imgs', 'offers.vdo', 'offers.doc_img',
    'offers.exact_loc', 'offers.sts', 'offers.i_pub', 'offers.i_del',
    'appointments.id', 'appointments.off_id', 'appointments.own_id', 'appointments.bkr_id',
    'appointments.dt', 'appointments.sts',
    'payments.id', 'payments.uid', 'payments.sts', 'payments.channel', 'payments.proof',
    'reports.id', 'reports.rep_uid', 'reports.tgt_uid', 'reports.sts',
    'photography_tasks.id', 'photography_tasks.off_id', 'photography_tasks.photographer_id',
    'photography_tasks.media', 'photography_tasks.sts', 'photography_tasks.ts_submit'
  ]
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = split_part(v_name, '.', 1)
        AND column_name = split_part(v_name, '.', 2)
    ) INTO v_ok;
    v_checks := v_checks || jsonb_build_object(
      'name', 'schema/column: ' || v_name,
      'ok', v_ok,
      'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- Functions
  FOREACH v_name IN ARRAY ARRAY[
    'normalize_sy_phone',
    'generate_otp',
    'verify_otp',
    'generate_otp_v2',
    'verify_otp_v2',
    'upsert_user_after_otp',
    'get_user_full_by_id',
    'get_user_by_phone',
    'get_user_by_email',
    'create_user_from_phone',
    'admin_update_user_role',
    'admin_set_user_status',
    'admin_update_user_permissions',
    'admin_update_user_permissions_by_admin',
    'create_offer_internal',
    'check_offer_duplicate',
    'add_points',
    'award_points_safe',
    'update_user_badge',
    'register_weekly_login',
    'apply_referral',
    'purchase_offer_boost',
    'expire_offer_boosts',
    'approve_payment_final',
    'notify_user',
    'get_user_device_tokens',
    'admin_approve_verification',
    'admin_reject_verification',
    'admin_fraud_suspects',
    'request_verification',
    'create_photography_task_internal',
    'submit_photography_task_internal',
    'update_photography_task_status_internal',
    'attach_photography_media_to_offer_internal',
    'qa_system_check'
  ]
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proname = v_name
    ) INTO v_ok;
    v_checks := v_checks || jsonb_build_object(
      'name', 'rpc/function: ' || v_name,
      'ok', v_ok,
      'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- Function content checks
  SELECT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'upsert_user_after_otp'
      AND pg_get_functiondef(p.oid) ILIKE '%normalize_sy_phone%'
  ) INTO v_ok;
  v_checks := v_checks || jsonb_build_object(
    'name', 'rpc/content: upsert_user_after_otp normalizes phone',
    'ok', v_ok,
    'details', CASE WHEN v_ok THEN 'uses normalize_sy_phone' ELSE 'does not normalize phone' END
  );

  SELECT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'admin_update_user_permissions'
      AND pg_get_functiondef(p.oid) ILIKE '%photographer_tasks%'
      AND pg_get_functiondef(p.oid) ILIKE '%photography_management%'
  ) INTO v_ok;
  v_checks := v_checks || jsonb_build_object(
    'name', 'rpc/content: permissions include photography keys',
    'ok', v_ok,
    'details', CASE WHEN v_ok THEN 'photography keys present' ELSE 'photography keys missing' END
  );

  -- RLS
  FOREACH v_name IN ARRAY ARRAY[
    'users', 'offers', 'requests', 'appointments', 'notifications', 'payments',
    'reports', 'deals', 'activity_log', 'app_config', 'photography_tasks', 'ratings'
  ]
  LOOP
    SELECT COALESCE(c.relrowsecurity, FALSE)
    INTO v_ok
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = v_name;

    v_checks := v_checks || jsonb_build_object(
      'name', 'security/rls: ' || v_name,
      'ok', COALESCE(v_ok, FALSE),
      'details', CASE WHEN COALESCE(v_ok, FALSE) THEN 'enabled' ELSE 'disabled/missing' END
    );
  END LOOP;

  -- Policy counts per sensitive table
  FOREACH v_name IN ARRAY ARRAY['users', 'offers', 'payments', 'reports', 'photography_tasks', 'notifications']
  LOOP
    SELECT COUNT(*) INTO v_count
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = v_name;

    v_checks := v_checks || jsonb_build_object(
      'name', 'security/policies: ' || v_name,
      'ok', v_count > 0,
      'details', 'policies=' || v_count::TEXT
    );
  END LOOP;

  -- Indexes
  FOREACH v_name IN ARRAY ARRAY[
    'ux_users_normalized_phone_active',
    'idx_users_role',
    'idx_users_sts',
    'idx_offers_sts',
    'idx_offers_ipub',
    'idx_photo_tasks_offer',
    'idx_photo_tasks_photographer',
    'idx_photo_tasks_status'
  ]
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM pg_indexes
      WHERE schemaname = 'public' AND indexname = v_name
    ) INTO v_ok;
    v_checks := v_checks || jsonb_build_object(
      'name', 'performance/index: ' || v_name,
      'ok', v_ok,
      'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- Storage buckets
  FOREACH v_name IN ARRAY ARRAY['offer_images', 'config_assets', 'payment_proofs', 'ids_private']
  LOOP
    SELECT EXISTS (SELECT 1 FROM storage.buckets WHERE id = v_name) INTO v_ok;
    v_checks := v_checks || jsonb_build_object(
      'name', 'storage/bucket: ' || v_name,
      'ok', v_ok,
      'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- Config main
  SELECT value INTO v_config FROM app_config WHERE key = 'main' LIMIT 1;
  v_ok := v_config IS NOT NULL;
  v_checks := v_checks || jsonb_build_object(
    'name', 'config: app_config/main exists',
    'ok', v_ok,
    'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
  );

  FOREACH v_name IN ARRAY ARRAY[
    'pts', 'pen', 'spd', 'bdg', 'pkg', 'com', 'qta', 'soc', 'ads',
    'rptRsn', 'txts', 'catProp', 'catVeh', 'docTp', 'locs', 'brnds',
    'clrs', 'roles', 'payChannels'
  ]
  LOOP
    v_ok := v_config ? v_name;
    v_checks := v_checks || jsonb_build_object(
      'name', 'config/key: ' || v_name,
      'ok', COALESCE(v_ok, FALSE),
      'details', CASE WHEN COALESCE(v_ok, FALSE) THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- Duplicate normalized phones
  SELECT COUNT(*) INTO v_duplicate_phones
  FROM (
    SELECT normalize_sy_phone(ph)
    FROM users
    WHERE i_del = 0 AND COALESCE(ph, '') <> ''
    GROUP BY normalize_sy_phone(ph)
    HAVING COUNT(*) > 1
  ) d;
  v_checks := v_checks || jsonb_build_object(
    'name', 'data/users: duplicate normalized phones',
    'ok', v_duplicate_phones = 0,
    'details', 'duplicates=' || v_duplicate_phones::TEXT
  );

  -- Core counts
  SELECT COUNT(*) INTO v_total_users FROM users WHERE i_del = 0;
  SELECT COUNT(*) INTO v_total_offers FROM offers WHERE i_del = 0;
  SELECT COUNT(*) INTO v_total_photo_tasks FROM photography_tasks;
  SELECT COUNT(*) INTO v_pending_offers FROM offers WHERE i_del = 0 AND sts IN (0, 1);
  SELECT COUNT(*) INTO v_pending_payments FROM payments WHERE sts = 0;
  SELECT COUNT(*) INTO v_open_reports FROM reports WHERE sts = 0;
  SELECT COUNT(*) INTO v_pending_verifications FROM users WHERE i_del = 0 AND vrf = 1;

  v_checks := v_checks || jsonb_build_object('name', 'data/count: active users', 'ok', v_total_users >= 0, 'details', v_total_users::TEXT);
  v_checks := v_checks || jsonb_build_object('name', 'data/count: active offers', 'ok', v_total_offers >= 0, 'details', v_total_offers::TEXT);
  v_checks := v_checks || jsonb_build_object('name', 'data/count: photography tasks', 'ok', v_total_photo_tasks >= 0, 'details', v_total_photo_tasks::TEXT);

  -- Data integrity checks
  SELECT COUNT(*) INTO v_count
  FROM users
  WHERE i_del = 0
    AND COALESCE(ph, '') = ''
    AND COALESCE(eml, '') = '';
  v_checks := v_checks || jsonb_build_object(
    'name', 'data/users: no contact method',
    'ok', v_count = 0,
    'details', 'count=' || v_count::TEXT
  );

  SELECT COUNT(*) INTO v_count
  FROM offers o
  LEFT JOIN users u ON u.id = o.usr_id
  WHERE o.i_del = 0
    AND (o.usr_id IS NULL OR u.id IS NULL OR u.i_del = 1);
  v_checks := v_checks || jsonb_build_object(
    'name', 'data/offers: orphan owner',
    'ok', v_count = 0,
    'details', 'count=' || v_count::TEXT
  );

  SELECT COUNT(*) INTO v_count
  FROM offers
  WHERE i_del = 0
    AND i_pub = 1
    AND jsonb_array_length(COALESCE(imgs, '[]'::jsonb)) = 0;
  v_checks := v_checks || jsonb_build_object(
    'name', 'data/offers: published without images',
    'ok', v_count = 0,
    'details', 'count=' || v_count::TEXT
  );

  SELECT COUNT(*) INTO v_count
  FROM offers
  WHERE i_del = 0
    AND i_pub = 1
    AND (loc IS NULL OR COALESCE(loc->>'d', '') = '');
  v_checks := v_checks || jsonb_build_object(
    'name', 'data/offers: published without location text',
    'ok', v_count = 0,
    'details', 'count=' || v_count::TEXT
  );

  SELECT COUNT(*) INTO v_count
  FROM appointments a
  LEFT JOIN offers o ON o.id = a.off_id
  WHERE a.off_id IS NOT NULL
    AND (o.id IS NULL OR o.i_del = 1);
  v_checks := v_checks || jsonb_build_object(
    'name', 'data/appointments: orphan offer',
    'ok', v_count = 0,
    'details', 'count=' || v_count::TEXT
  );

  SELECT COUNT(*) INTO v_count
  FROM photography_tasks pt
  LEFT JOIN offers o ON o.id = pt.off_id
  WHERE o.id IS NULL OR o.i_del = 1;
  v_checks := v_checks || jsonb_build_object(
    'name', 'data/photography: orphan offer',
    'ok', v_count = 0,
    'details', 'count=' || v_count::TEXT
  );

  SELECT COUNT(*) INTO v_count
  FROM photography_tasks pt
  LEFT JOIN users u ON u.id = pt.photographer_id
  WHERE pt.photographer_id IS NOT NULL
    AND (u.id IS NULL OR u.i_del = 1);
  v_checks := v_checks || jsonb_build_object(
    'name', 'data/photography: missing photographer user',
    'ok', v_count = 0,
    'details', 'count=' || v_count::TEXT
  );

  SELECT COUNT(*) INTO v_count
  FROM photography_tasks
  WHERE sts = 2
    AND jsonb_array_length(COALESCE(media, '[]'::jsonb)) = 0;
  v_checks := v_checks || jsonb_build_object(
    'name', 'data/photography: submitted without media',
    'ok', v_count = 0,
    'details', 'count=' || v_count::TEXT
  );

  SELECT COUNT(*) INTO v_count
  FROM payments
  WHERE sts = 0;
  v_checks := v_checks || jsonb_build_object(
    'name', 'queue/payments: pending approvals',
    'ok', TRUE,
    'details', 'pending=' || v_count::TEXT
  );

  SELECT COUNT(*) INTO v_count
  FROM reports
  WHERE sts = 0;
  v_checks := v_checks || jsonb_build_object(
    'name', 'queue/reports: open reports',
    'ok', TRUE,
    'details', 'open=' || v_count::TEXT
  );

  RETURN jsonb_build_object(
    'ok', NOT EXISTS (
      SELECT 1
      FROM jsonb_array_elements(v_checks) item
      WHERE COALESCE((item->>'ok')::BOOLEAN, FALSE) = FALSE
    ),
    'generated_at', NOW(),
    'summary', jsonb_build_object(
      'users', v_total_users,
      'offers', v_total_offers,
      'photography_tasks', v_total_photo_tasks,
      'pending_offers', v_pending_offers,
      'pending_payments', v_pending_payments,
      'open_reports', v_open_reports,
      'pending_verifications', v_pending_verifications,
      'duplicate_phones', v_duplicate_phones
    ),
    'checks', v_checks
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION qa_system_check(UUID) TO anon, authenticated;


-- ============================================================================
-- Ensure app_config.main has locs key (2026-06-10)
-- ============================================================================
-- Ensure app_config.main has locs key for QA/config completeness.
UPDATE app_config
SET value = jsonb_set(
  value,
  '{locs}',
  COALESCE(value->'locs', '[]'::jsonb),
  true
)
WHERE key = 'main'
  AND NOT (value ? 'locs');


-- ============================================================================
-- QA System Check v3 (2026-06-10)
-- ============================================================================
-- ════════════════════════════════════════════════════════════════════════════
-- QA System Check v3 — maximum safe read-only coverage
-- Date: 2026-06-10
-- Notes:
--   - Uses severity: critical / warning / info.
--   - Overall ok fails only on critical checks with ok=false.
--   - Avoids writing test data.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION qa_system_check(p_admin_uid UUID)
RETURNS JSONB AS $$
DECLARE
  v_admin_role INT;
  v_admin_perm JSONB := '[]'::jsonb;
  v_checks JSONB := '[]'::jsonb;
  v_ok BOOLEAN;
  v_name TEXT;
  v_count INT := 0;
  v_count2 INT := 0;
  v_config JSONB := '{}'::jsonb;
  v_duplicate_phones INT := 0;
  v_total_users INT := 0;
  v_total_offers INT := 0;
  v_total_photo_tasks INT := 0;
  v_pending_offers INT := 0;
  v_pending_payments INT := 0;
  v_open_reports INT := 0;
  v_pending_verifications INT := 0;
  v_critical_failed INT := 0;
  v_warning_failed INT := 0;
  v_info_count INT := 0;
BEGIN
  SELECT role, COALESCE(perm, '[]'::jsonb)
  INTO v_admin_role, v_admin_perm
  FROM users
  WHERE id = p_admin_uid
    AND i_del = 0;

  v_checks := v_checks || jsonb_build_object(
    'name', 'auth/admin: current admin identity',
    'ok', COALESCE(v_admin_role >= 2, FALSE),
    'severity', 'critical',
    'category', 'auth',
    'details', COALESCE('role=' || v_admin_role::TEXT || ', perm_items=' || jsonb_array_length(v_admin_perm)::TEXT, 'admin user not found')
  );

  -- Tables
  FOREACH v_name IN ARRAY ARRAY[
    'users', 'offers', 'requests', 'appointments', 'notifications', 'payments',
    'reports', 'deals', 'activity_log', 'stats', 'app_config', 'otp_codes',
    'user_devices', 'photography_tasks', 'ratings'
  ]
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = v_name
    ) INTO v_ok;
    v_checks := v_checks || jsonb_build_object(
      'name', 'schema/table: ' || v_name,
      'ok', v_ok,
      'severity', 'critical',
      'category', 'schema',
      'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- Columns
  FOREACH v_name IN ARRAY ARRAY[
    'users.id', 'users.nm', 'users.ph', 'users.eml', 'users.role', 'users.sts',
    'users.i_del', 'users.perm', 'users.vrf', 'users.device_id', 'users.stats',
    'offers.id', 'offers.usr_id', 'offers.typ', 'offers.trx', 'offers.ttl',
    'offers.prc', 'offers.cur', 'offers.loc', 'offers.imgs', 'offers.vdo', 'offers.doc_img',
    'offers.exact_loc', 'offers.specs', 'offers.sts', 'offers.i_pub', 'offers.i_del',
    'appointments.id', 'appointments.off_id', 'appointments.own_id', 'appointments.bkr_id',
    'appointments.dt', 'appointments.sts', 'appointments.cnl_rsn',
    'payments.id', 'payments.uid', 'payments.sts', 'payments.channel', 'payments.proof',
    'reports.id', 'reports.rep_uid', 'reports.tgt_uid', 'reports.tgt_id', 'reports.sts',
    'photography_tasks.id', 'photography_tasks.off_id', 'photography_tasks.photographer_id',
    'photography_tasks.media', 'photography_tasks.sts', 'photography_tasks.ts_submit', 'photography_tasks.office_note',
    'notifications.id', 'notifications.uid', 'notifications.i_rd', 'notifications.i_del'
  ]
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = split_part(v_name, '.', 1)
        AND column_name = split_part(v_name, '.', 2)
    ) INTO v_ok;
    v_checks := v_checks || jsonb_build_object(
      'name', 'schema/column: ' || v_name,
      'ok', v_ok,
      'severity', 'critical',
      'category', 'schema',
      'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- Functions
  FOREACH v_name IN ARRAY ARRAY[
    'normalize_sy_phone',
    'generate_otp',
    'verify_otp',
    'generate_otp_v2',
    'verify_otp_v2',
    'upsert_user_after_otp',
    'get_user_full_by_id',
    'get_user_by_phone',
    'get_user_by_email',
    'create_user_from_phone',
    'admin_update_user_role',
    'admin_set_user_status',
    'admin_update_user_permissions',
    'admin_update_user_permissions_by_admin',
    'create_offer_internal',
    'check_offer_duplicate',
    'add_points',
    'award_points_safe',
    'update_user_badge',
    'register_weekly_login',
    'apply_referral',
    'purchase_offer_boost',
    'expire_offer_boosts',
    'approve_payment_final',
    'notify_user',
    'get_user_device_tokens',
    'send_push_notification',
    'admin_approve_verification',
    'admin_reject_verification',
    'admin_fraud_suspects',
    'request_verification',
    'register_device',
    'create_photography_task_internal',
    'submit_photography_task_internal',
    'update_photography_task_status_internal',
    'attach_photography_media_to_offer_internal',
    'qa_system_check'
  ]
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proname = v_name
    ) INTO v_ok;
    v_checks := v_checks || jsonb_build_object(
      'name', 'rpc/function: ' || v_name,
      'ok', v_ok,
      'severity', CASE WHEN v_name IN ('generate_otp_v2','verify_otp_v2','send_push_notification') THEN 'warning' ELSE 'critical' END,
      'category', 'rpc',
      'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- Function content checks
  SELECT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'upsert_user_after_otp'
      AND pg_get_functiondef(p.oid) ILIKE '%normalize_sy_phone%'
  ) INTO v_ok;
  v_checks := v_checks || jsonb_build_object(
    'name', 'rpc/content: upsert_user_after_otp normalizes phone',
    'ok', v_ok,
    'severity', 'critical',
    'category', 'rpc',
    'details', CASE WHEN v_ok THEN 'uses normalize_sy_phone' ELSE 'does not normalize phone' END
  );

  SELECT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'admin_update_user_permissions'
      AND pg_get_functiondef(p.oid) ILIKE '%photographer_tasks%'
      AND pg_get_functiondef(p.oid) ILIKE '%photography_management%'
  ) INTO v_ok;
  v_checks := v_checks || jsonb_build_object(
    'name', 'rpc/content: permissions include photography keys',
    'ok', v_ok,
    'severity', 'critical',
    'category', 'rpc',
    'details', CASE WHEN v_ok THEN 'photography keys present' ELSE 'photography keys missing' END
  );

  SELECT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'create_offer_internal'
      AND pg_get_functiondef(p.oid) ILIKE '%SECURITY DEFINER%'
  ) INTO v_ok;
  v_checks := v_checks || jsonb_build_object(
    'name', 'rpc/security: create_offer_internal security definer',
    'ok', v_ok,
    'severity', 'critical',
    'category', 'security',
    'details', CASE WHEN v_ok THEN 'security definer' ELSE 'not security definer / missing' END
  );

  -- RLS
  FOREACH v_name IN ARRAY ARRAY[
    'users', 'offers', 'requests', 'appointments', 'notifications', 'payments',
    'reports', 'deals', 'activity_log', 'app_config', 'photography_tasks', 'ratings', 'user_devices'
  ]
  LOOP
    SELECT COALESCE(c.relrowsecurity, FALSE)
    INTO v_ok
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = v_name;

    v_checks := v_checks || jsonb_build_object(
      'name', 'security/rls: ' || v_name,
      'ok', COALESCE(v_ok, FALSE),
      'severity', CASE WHEN v_name IN ('stats') THEN 'warning' ELSE 'critical' END,
      'category', 'security',
      'details', CASE WHEN COALESCE(v_ok, FALSE) THEN 'enabled' ELSE 'disabled/missing' END
    );
  END LOOP;

  -- Policy counts per sensitive table
  FOREACH v_name IN ARRAY ARRAY['users', 'offers', 'payments', 'reports', 'photography_tasks', 'notifications', 'ratings', 'user_devices']
  LOOP
    SELECT COUNT(*) INTO v_count
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = v_name;

    v_checks := v_checks || jsonb_build_object(
      'name', 'security/policies: ' || v_name,
      'ok', v_count > 0,
      'severity', 'critical',
      'category', 'security',
      'details', 'policies=' || v_count::TEXT
    );
  END LOOP;

  -- Indexes
  FOREACH v_name IN ARRAY ARRAY[
    'ux_users_normalized_phone_active',
    'idx_users_role',
    'idx_users_sts',
    'idx_users_iDel',
    'idx_offers_usr',
    'idx_offers_sts',
    'idx_offers_ipub',
    'idx_offers_typ',
    'idx_offers_trx',
    'idx_requests_usr',
    'idx_requests_sts',
    'idx_photo_tasks_offer',
    'idx_photo_tasks_photographer',
    'idx_photo_tasks_status'
  ]
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM pg_indexes
      WHERE schemaname = 'public' AND lower(indexname) = lower(v_name)
    ) INTO v_ok;
    v_checks := v_checks || jsonb_build_object(
      'name', 'performance/index: ' || v_name,
      'ok', v_ok,
      'severity', CASE WHEN v_name IN ('idx_photo_tasks_offer','idx_photo_tasks_photographer','idx_photo_tasks_status') THEN 'critical' ELSE 'warning' END,
      'category', 'performance',
      'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- Storage buckets
  FOREACH v_name IN ARRAY ARRAY['offer_images', 'config_assets', 'payment_proofs', 'ids_private']
  LOOP
    SELECT EXISTS (SELECT 1 FROM storage.buckets WHERE id = v_name) INTO v_ok;
    v_checks := v_checks || jsonb_build_object(
      'name', 'storage/bucket: ' || v_name,
      'ok', v_ok,
      'severity', 'critical',
      'category', 'storage',
      'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- Storage public/private expectations
  FOREACH v_name IN ARRAY ARRAY['offer_images:true', 'config_assets:true', 'payment_proofs:false', 'ids_private:false']
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM storage.buckets
      WHERE id = split_part(v_name, ':', 1)
        AND public = (split_part(v_name, ':', 2))::BOOLEAN
    ) INTO v_ok;
    v_checks := v_checks || jsonb_build_object(
      'name', 'storage/visibility: ' || split_part(v_name, ':', 1),
      'ok', v_ok,
      'severity', 'warning',
      'category', 'storage',
      'details', 'expected public=' || split_part(v_name, ':', 2)
    );
  END LOOP;

  -- Config main
  SELECT value INTO v_config FROM app_config WHERE key = 'main' LIMIT 1;
  v_ok := v_config IS NOT NULL;
  v_checks := v_checks || jsonb_build_object(
    'name', 'config: app_config/main exists',
    'ok', v_ok,
    'severity', 'critical',
    'category', 'config',
    'details', CASE WHEN v_ok THEN 'exists' ELSE 'missing' END
  );

  FOREACH v_name IN ARRAY ARRAY[
    'pts', 'pen', 'spd', 'bdg', 'pkg', 'com', 'qta', 'soc', 'ads',
    'rptRsn', 'txts', 'catProp', 'catVeh', 'docTp', 'locs', 'brnds',
    'clrs', 'roles', 'payChannels'
  ]
  LOOP
    v_ok := v_config ? v_name;
    v_checks := v_checks || jsonb_build_object(
      'name', 'config/key: ' || v_name,
      'ok', COALESCE(v_ok, FALSE),
      'severity', CASE WHEN v_name = 'locs' THEN 'warning' ELSE 'critical' END,
      'category', 'config',
      'details', CASE WHEN COALESCE(v_ok, FALSE) THEN 'exists' ELSE 'missing' END
    );
  END LOOP;

  -- Config deep checks
  FOREACH v_name IN ARRAY ARRAY[
    'pkg.0', 'pkg.1', 'pkg.2',
    'qta.u', 'qta.b',
    'pts.sgn', 'pts.addO', 'pts.wkL',
    'catProp', 'catVeh', 'docTp', 'payChannels'
  ]
  LOOP
    IF v_name = 'catProp' THEN
      v_ok := jsonb_typeof(v_config->'catProp') = 'object' AND (SELECT COUNT(*) FROM jsonb_object_keys(v_config->'catProp')) > 0;
    ELSIF v_name = 'catVeh' THEN
      v_ok := jsonb_typeof(v_config->'catVeh') = 'object' AND (SELECT COUNT(*) FROM jsonb_object_keys(v_config->'catVeh')) > 0;
    ELSIF v_name = 'docTp' THEN
      v_ok := jsonb_typeof(v_config->'docTp') = 'object' AND (SELECT COUNT(*) FROM jsonb_object_keys(v_config->'docTp')) > 0;
    ELSIF v_name = 'payChannels' THEN
      v_ok := jsonb_typeof(v_config->'payChannels') = 'object' AND (SELECT COUNT(*) FROM jsonb_object_keys(v_config->'payChannels')) > 0;
    ELSE
      v_ok := v_config #> string_to_array(v_name, '.') IS NOT NULL;
    END IF;

    v_checks := v_checks || jsonb_build_object(
      'name', 'config/deep: ' || v_name,
      'ok', COALESCE(v_ok, FALSE),
      'severity', 'warning',
      'category', 'config',
      'details', CASE WHEN COALESCE(v_ok, FALSE) THEN 'valid/present' ELSE 'missing/empty' END
    );
  END LOOP;

  -- Duplicate normalized phones
  SELECT COUNT(*) INTO v_duplicate_phones
  FROM (
    SELECT normalize_sy_phone(ph)
    FROM users
    WHERE i_del = 0 AND COALESCE(ph, '') <> ''
    GROUP BY normalize_sy_phone(ph)
    HAVING COUNT(*) > 1
  ) d;
  v_checks := v_checks || jsonb_build_object(
    'name', 'data/users: duplicate normalized phones',
    'ok', v_duplicate_phones = 0,
    'severity', 'critical',
    'category', 'data',
    'details', 'duplicates=' || v_duplicate_phones::TEXT
  );

  -- Core counts
  SELECT COUNT(*) INTO v_total_users FROM users WHERE i_del = 0;
  SELECT COUNT(*) INTO v_total_offers FROM offers WHERE i_del = 0;
  SELECT COUNT(*) INTO v_total_photo_tasks FROM photography_tasks;
  SELECT COUNT(*) INTO v_pending_offers FROM offers WHERE i_del = 0 AND sts IN (0, 1);
  SELECT COUNT(*) INTO v_pending_payments FROM payments WHERE sts = 0;
  SELECT COUNT(*) INTO v_open_reports FROM reports WHERE sts = 0;
  SELECT COUNT(*) INTO v_pending_verifications FROM users WHERE i_del = 0 AND vrf = 1;

  v_checks := v_checks || jsonb_build_object('name', 'data/count: active users', 'ok', v_total_users >= 0, 'severity', 'info', 'category', 'data', 'details', v_total_users::TEXT);
  v_checks := v_checks || jsonb_build_object('name', 'data/count: active offers', 'ok', v_total_offers >= 0, 'severity', 'info', 'category', 'data', 'details', v_total_offers::TEXT);
  v_checks := v_checks || jsonb_build_object('name', 'data/count: photography tasks', 'ok', v_total_photo_tasks >= 0, 'severity', 'info', 'category', 'data', 'details', v_total_photo_tasks::TEXT);

  -- User data integrity
  SELECT COUNT(*) INTO v_count
  FROM users
  WHERE i_del = 0
    AND COALESCE(ph, '') = ''
    AND COALESCE(eml, '') = '';
  v_checks := v_checks || jsonb_build_object('name', 'data/users: no contact method', 'ok', v_count = 0, 'severity', 'warning', 'category', 'data', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM users
  WHERE i_del = 0
    AND (role < 0 OR role > 4);
  v_checks := v_checks || jsonb_build_object('name', 'data/users: invalid role range', 'ok', v_count = 0, 'severity', 'critical', 'category', 'data', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM users
  WHERE i_del = 0
    AND (sts < 0 OR sts > 2);
  v_checks := v_checks || jsonb_build_object('name', 'data/users: invalid status range', 'ok', v_count = 0, 'severity', 'critical', 'category', 'data', 'details', 'count=' || v_count::TEXT);

  -- Unknown permission keys
  SELECT COUNT(*) INTO v_count
  FROM users u,
       jsonb_array_elements_text(COALESCE(u.perm, '[]'::jsonb)) perm_key
  WHERE u.i_del = 0
    AND perm_key NOT IN (
      'admin_dashboard','office_operations','manage_users','manage_permissions',
      'review_offers','review_verifications','media_review','photography_management',
      'photographer_tasks','fraud_suspects','manage_appointments','manage_deals',
      'manage_payments','manage_reports','manage_config','view_analytics',
      'broker_dashboard','broker_offers','broker_appointments','broker_deals','broker_stats',
      'user_home','user_offers','user_requests','user_appointments','user_profile'
    );
  v_checks := v_checks || jsonb_build_object('name', 'data/users: unknown permission keys', 'ok', v_count = 0, 'severity', 'critical', 'category', 'permissions', 'details', 'count=' || v_count::TEXT);

  -- Offers integrity
  SELECT COUNT(*) INTO v_count
  FROM offers o
  LEFT JOIN users u ON u.id = o.usr_id
  WHERE o.i_del = 0
    AND (o.usr_id IS NULL OR u.id IS NULL OR u.i_del = 1);
  v_checks := v_checks || jsonb_build_object('name', 'data/offers: orphan owner', 'ok', v_count = 0, 'severity', 'critical', 'category', 'data', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM offers
  WHERE i_del = 0
    AND (sts < 0 OR sts > 6);
  v_checks := v_checks || jsonb_build_object('name', 'data/offers: invalid status range', 'ok', v_count = 0, 'severity', 'critical', 'category', 'data', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM offers
  WHERE i_del = 0
    AND i_pub = 1
    AND jsonb_array_length(COALESCE(imgs, '[]'::jsonb)) = 0;
  v_checks := v_checks || jsonb_build_object('name', 'data/offers: published without images', 'ok', v_count = 0, 'severity', 'warning', 'category', 'media', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM offers
  WHERE i_del = 0
    AND i_pub = 1
    AND (loc IS NULL OR COALESCE(loc->>'d', '') = '');
  v_checks := v_checks || jsonb_build_object('name', 'data/offers: published without location text', 'ok', v_count = 0, 'severity', 'warning', 'category', 'data', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM offers,
       jsonb_array_elements_text(COALESCE(imgs, '[]'::jsonb)) img_url
  WHERE i_del = 0
    AND (img_url IS NULL OR length(trim(img_url)) = 0 OR img_url NOT ILIKE 'http%');
  v_checks := v_checks || jsonb_build_object('name', 'data/offers: invalid image URLs', 'ok', v_count = 0, 'severity', 'warning', 'category', 'media', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM offers
  WHERE i_del = 0
    AND COALESCE(vdo, '') <> ''
    AND vdo NOT ILIKE 'http%';
  v_checks := v_checks || jsonb_build_object('name', 'data/offers: invalid video URLs', 'ok', v_count = 0, 'severity', 'warning', 'category', 'media', 'details', 'count=' || v_count::TEXT);

  -- Appointments integrity
  SELECT COUNT(*) INTO v_count
  FROM appointments a
  LEFT JOIN offers o ON o.id = a.off_id
  WHERE a.off_id IS NOT NULL
    AND (o.id IS NULL OR o.i_del = 1);
  v_checks := v_checks || jsonb_build_object('name', 'data/appointments: orphan offer', 'ok', v_count = 0, 'severity', 'critical', 'category', 'data', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM appointments
  WHERE sts < 0 OR sts > 5;
  v_checks := v_checks || jsonb_build_object('name', 'data/appointments: invalid status range', 'ok', v_count = 0, 'severity', 'critical', 'category', 'data', 'details', 'count=' || v_count::TEXT);

  -- Payments/reports integrity
  SELECT COUNT(*) INTO v_count
  FROM payments p
  LEFT JOIN users u ON u.id = p.uid
  WHERE p.uid IS NOT NULL
    AND (u.id IS NULL OR u.i_del = 1);
  v_checks := v_checks || jsonb_build_object('name', 'data/payments: orphan user', 'ok', v_count = 0, 'severity', 'warning', 'category', 'data', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM payments
  WHERE sts < 0 OR sts > 3;
  v_checks := v_checks || jsonb_build_object('name', 'data/payments: invalid status range', 'ok', v_count = 0, 'severity', 'critical', 'category', 'data', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM reports
  WHERE sts < 0 OR sts > 1;
  v_checks := v_checks || jsonb_build_object('name', 'data/reports: invalid status range', 'ok', v_count = 0, 'severity', 'critical', 'category', 'data', 'details', 'count=' || v_count::TEXT);

  -- Photography integrity
  SELECT COUNT(*) INTO v_count
  FROM photography_tasks pt
  LEFT JOIN offers o ON o.id = pt.off_id
  WHERE o.id IS NULL OR o.i_del = 1;
  v_checks := v_checks || jsonb_build_object('name', 'data/photography: orphan offer', 'ok', v_count = 0, 'severity', 'critical', 'category', 'photography', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM photography_tasks pt
  LEFT JOIN users u ON u.id = pt.photographer_id
  WHERE pt.photographer_id IS NOT NULL
    AND (u.id IS NULL OR u.i_del = 1);
  v_checks := v_checks || jsonb_build_object('name', 'data/photography: missing photographer user', 'ok', v_count = 0, 'severity', 'critical', 'category', 'photography', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM photography_tasks
  WHERE sts < 0 OR sts > 5;
  v_checks := v_checks || jsonb_build_object('name', 'data/photography: invalid status range', 'ok', v_count = 0, 'severity', 'critical', 'category', 'photography', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM photography_tasks
  WHERE sts = 2
    AND jsonb_array_length(COALESCE(media, '[]'::jsonb)) = 0;
  v_checks := v_checks || jsonb_build_object('name', 'data/photography: submitted without media', 'ok', v_count = 0, 'severity', 'warning', 'category', 'photography', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM photography_tasks,
       jsonb_array_elements_text(COALESCE(media, '[]'::jsonb)) media_url
  WHERE media_url IS NULL OR length(trim(media_url)) = 0 OR media_url NOT ILIKE 'http%';
  v_checks := v_checks || jsonb_build_object('name', 'data/photography: invalid media URLs', 'ok', v_count = 0, 'severity', 'warning', 'category', 'photography', 'details', 'count=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM photography_tasks pt
  JOIN users u ON u.id = pt.photographer_id
  WHERE pt.photographer_id IS NOT NULL
    AND u.i_del = 0
    AND NOT (COALESCE(u.perm, '[]'::jsonb) ? 'photographer_tasks');
  v_checks := v_checks || jsonb_build_object('name', 'data/photography: assigned user lacks photographer_tasks', 'ok', v_count = 0, 'severity', 'warning', 'category', 'permissions', 'details', 'count=' || v_count::TEXT);

  -- Queues as info
  SELECT COUNT(*) INTO v_count FROM payments WHERE sts = 0;
  v_checks := v_checks || jsonb_build_object('name', 'queue/payments: pending approvals', 'ok', TRUE, 'severity', 'info', 'category', 'queue', 'details', 'pending=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count FROM reports WHERE sts = 0;
  v_checks := v_checks || jsonb_build_object('name', 'queue/reports: open reports', 'ok', TRUE, 'severity', 'info', 'category', 'queue', 'details', 'open=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count FROM offers WHERE i_del = 0 AND sts IN (0, 1);
  v_checks := v_checks || jsonb_build_object('name', 'queue/offers: pending review', 'ok', TRUE, 'severity', 'info', 'category', 'queue', 'details', 'pending=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count FROM users WHERE i_del = 0 AND vrf = 1;
  v_checks := v_checks || jsonb_build_object('name', 'queue/verifications: pending review', 'ok', TRUE, 'severity', 'info', 'category', 'queue', 'details', 'pending=' || v_count::TEXT);

  SELECT COUNT(*) INTO v_count FROM photography_tasks WHERE sts = 2;
  SELECT COUNT(*) INTO v_count2 FROM photography_tasks WHERE sts = 4;
  v_checks := v_checks || jsonb_build_object('name', 'queue/photography: submitted and rejected', 'ok', TRUE, 'severity', 'info', 'category', 'queue', 'details', 'submitted=' || v_count::TEXT || ', rejected=' || v_count2::TEXT);

  -- Severity summary
  SELECT COUNT(*) INTO v_critical_failed
  FROM jsonb_array_elements(v_checks) item
  WHERE COALESCE((item->>'ok')::BOOLEAN, FALSE) = FALSE
    AND COALESCE(item->>'severity', 'critical') = 'critical';

  SELECT COUNT(*) INTO v_warning_failed
  FROM jsonb_array_elements(v_checks) item
  WHERE COALESCE((item->>'ok')::BOOLEAN, FALSE) = FALSE
    AND COALESCE(item->>'severity', 'critical') = 'warning';

  SELECT COUNT(*) INTO v_info_count
  FROM jsonb_array_elements(v_checks) item
  WHERE COALESCE(item->>'severity', 'critical') = 'info';

  RETURN jsonb_build_object(
    'ok', v_critical_failed = 0,
    'generated_at', NOW(),
    'summary', jsonb_build_object(
      'users', v_total_users,
      'offers', v_total_offers,
      'photography_tasks', v_total_photo_tasks,
      'pending_offers', v_pending_offers,
      'pending_payments', v_pending_payments,
      'open_reports', v_open_reports,
      'pending_verifications', v_pending_verifications,
      'duplicate_phones', v_duplicate_phones,
      'critical_failed', v_critical_failed,
      'warning_failed', v_warning_failed,
      'info_count', v_info_count,
      'total_checks', jsonb_array_length(v_checks)
    ),
    'checks', v_checks
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION qa_system_check(UUID) TO anon, authenticated;
