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
  req_uid UUID REFERENCES users(id) ON DELETE SET NULL,
  own_id UUID REFERENCES users(id) ON DELETE SET NULL,
  bkr_id UUID REFERENCES users(id) ON DELETE SET NULL,
  dt TIMESTAMPTZ NOT NULL, dt_end TIMESTAMPTZ,
  sts INTEGER DEFAULT 0 CHECK (sts BETWEEN 0 AND 5),
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
CREATE INDEX IF NOT EXISTS idx_appointments_req_uid ON appointments(req_uid, sts);
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
RETURNS INTEGER AS $$ DECLARE v_cnt INTEGER; BEGIN SELECT COUNT(*) INTO v_cnt FROM offers WHERE sts = 1 AND i_del = 0; RETURN v_cnt; END; $$ LANGUAGE plpgsql;

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
INSERT INTO app_config (key, value, description) VALUES ('main', '{"pts":{"sgn":1000,"wkL":100,"addO":500,"att":300,"dlD":2000,"ref":1500,"strk":50,"soc":100,"like":{"p":5,"l":10},"shr":{"p":10,"l":5},"cmt":{"p":20,"l":3},"gft":{"max":500,"pw":1}},"pen":{"noSh":-500,"cnl3":-300,"rej3":-1000,"fRp":-2000,"ban":-40000},"spd":{"ren":500,"pin":2000,"bst":4000,"dsc5":3000,"fms":8000},"bdg":{"0":{"nm":"🔰 جديد","p":0,"d":0},"1":{"nm":"🥉 برونزي","p":10000,"d":10},"2":{"nm":"🥈 فضي","p":20000,"d":15},"3":{"nm":"🥇 ذهبي","p":30000,"d":20,"eS":1},"4":{"nm":"💎 ماسي","p":40000,"d":20,"eS":1,"fA":1}},"pkg":{"0":{"nm":"مجاني","o":5,"d":30,"pr":0},"1":{"nm":"فضي","o":15,"d":45,"pr":10},"2":{"nm":"ذهبي","o":40,"d":60,"pr":25}},"fx":{"usd_syp":15000},"com":{"sl":3,"rn":"hm","ml":2},"qta":{"u":{"o":1,"r":3,"a":3},"b":{"o":5,"r":5,"a":3}},"soc":{"fb":"","ig":"","tk":"","wa":""},"ads":{"mx":5,"dd":7,"pr":null},"rptRsn":["إعلان وهمي / غير موجود","احتيال / نصب","معلومات مضللة","مضايقة / سلوك غير لائق","عرض مكرر","آخر"],"txts":{"plg":"إقرار وتعهد إلكتروني — عقارات السويداء","warnApp":"تحذير: هذا العرض عليه مواعيد سابقة","visBlk":"تسجيل دخول مطلوب","bnRsn":"تم حظر حسابك نهائياً","frzRsn":"تم تجميد حسابك"},"catProp":{"0":{"nm":"سكني","sub":["شقة سكنية","دار عربي","فيلا","مزرعة","بناء كامل","سطح"]},"1":{"nm":"تجاري","sub":["محل تجاري","معرض","مركز تجاري","مكتب","مستودع"]},"2":{"nm":"زراعي","sub":["أرض زراعية","مزرعة دواجن","مزرعة مواشي","مشتل"]},"3":{"nm":"صناعي","sub":["منشأة صناعية","ورشة","مصنع","أرض صناعية"]}},"catVeh":{"0":{"nm":"سيارة","sub":["سيدان","دفع رباعي","هاتشباك","كوبيه","مكشوفة"]},"1":{"nm":"شاحنة","sub":["شاحنة صغيرة","شاحنة كبيرة","نقل عام"]},"2":{"nm":"دراجة نارية","sub":["دراجة عادية","دراجة رياضية","دراجة كهربائية"]},"3":{"nm":"معدات ثقيلة","sub":["جرّار","حفّارة","حصّادة","درّاسة"]},"4":{"nm":"باصات/نقل","sub":["باص سكانيا","باص 24 راكب","ميكروباص","فان"]}},"docTp":{"0":"طابو أخضر","1":"حصة سهمية-حكم محكمة","2":"حصة سهمية-كاتب بالعدل","3":"مستملك","4":"تسلسل عقود","5":"جمعيات سكنية","6":"نمرة قديمة","7":"نمرة جديدة","8":"وارد"},"brnds":["تويوتا","هوندا","نيسان","هيونداي","كيا","مرسيدس","بي إم دبليو","فولكس فاجن","رينو","فورد","شيفروليه","أخرى"],"clrs":["أبيض","أسود","فضي","رمادي","أحمر","أزرق","أخضر","أصفر","بيج","بني","ذهبي","أخرى"],"roles":{"0":{"nm":"مستخدم"},"1":{"nm":"وسيط"},"2":{"nm":"مشرف"},"3":{"nm":"نائب"},"4":{"nm":"مدير"}}}'::jsonb, 'إعدادات التطبيق الرئيسية');

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
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

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
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

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
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

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
  v_config JSONB;
  v_limit INT;
  v_used INT;
  v_recent_deleted INT;
  v_duplicate BOOLEAN;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  SELECT * INTO v_user
  FROM users
  WHERE id = p_user_uid
    AND i_del = 0
    AND sts = 0;

  IF v_user.id IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_ACTIVE_OR_NOT_FOUND';
  END IF;

  IF COALESCE(trim(p_offer->>'ttl'), '') = '' THEN
    RAISE EXCEPTION 'TITLE_REQUIRED';
  END IF;

  IF COALESCE(trim(p_offer->>'contact_ph'), '') = '' THEN
    RAISE EXCEPTION 'CONTACT_PHONE_REQUIRED';
  END IF;

  IF COALESCE((p_offer->>'prc')::NUMERIC, 0) <= 0 THEN
    RAISE EXCEPTION 'INVALID_PRICE';
  END IF;

  IF COALESCE(v_user.role, 0) < 2 THEN
    SELECT value INTO v_config
    FROM app_config
    WHERE key = 'main';

    v_limit := COALESCE((v_config->'pkg'->(COALESCE(v_user.b_pkg, 0)::TEXT)->>'o')::INT,
      CASE WHEN COALESCE(v_user.role, 0) = 1 THEN 5 ELSE 1 END);

    SELECT COUNT(*) INTO v_used
    FROM offers
    WHERE usr_id = p_user_uid
      AND i_del = 0
      AND sts IN (0, 1, 2, 5);

    SELECT COUNT(*) INTO v_recent_deleted
    FROM offers
    WHERE usr_id = p_user_uid
      AND i_del = 1
      AND ts_upd >= NOW() - INTERVAL '24 hours';

    v_used := COALESCE(v_used, 0) + COALESCE(v_recent_deleted, 0);

    IF v_used >= v_limit THEN
      RAISE EXCEPTION 'QUOTA_EXCEEDED';
    END IF;
  END IF;

  SELECT check_offer_duplicate(
    COALESCE(p_offer->>'ttl', ''),
    COALESCE((p_offer->>'prc')::NUMERIC, 0),
    COALESCE(p_offer->'loc', '{"r":0,"d":""}'::jsonb),
    p_user_uid
  ) INTO v_duplicate;

  IF v_duplicate THEN
    RAISE EXCEPTION 'DUPLICATE_OFFER';
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
    1,
    '',
    0,
    0,
    0,
    COALESCE((p_offer->>'i_soc')::INT, 0),
    0,
    COALESCE(p_offer->>'soc_txt', ''),
    0,
    NULLIF(p_offer->>'dup_of', '')::UUID,
    COALESCE(p_offer->'avl', '{}'::jsonb),
    0,
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
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

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
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_photographer_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

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
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

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
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

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
-- Real-test stabilization internal RPCs (2026-06-11)
-- ============================================================================
-- ════════════════════════════════════════════════════════════════════════════
-- Real test stabilization RPCs and policy fixes
-- Date: 2026-06-11
-- Purpose:
--   Replace remaining fragile direct client writes/reads in core flows with
--   SECURITY DEFINER RPCs compatible with the current auth model.
-- ════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 1) Appointments read policy aligned with requester field
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Related users can read appointments" ON appointments;
CREATE POLICY "Related users can read appointments" ON appointments
  FOR SELECT USING (
    auth.uid() = own_id
    OR auth.uid() = bkr_id
    OR auth.uid() = req_uid
    OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role >= 2)
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- 2) Generic role helpers via inline checks inside RPCs
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_offer_by_id_internal(
  p_offer_id UUID,
  p_user_uid UUID DEFAULT NULL
)
RETURNS SETOF offers AS $$
DECLARE
  v_role INT := 0;
BEGIN
  IF p_user_uid IS NOT NULL AND auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  IF p_user_uid IS NOT NULL THEN
    SELECT COALESCE(role, 0) INTO v_role FROM users WHERE id = p_user_uid AND i_del = 0;
  END IF;

  RETURN QUERY
  SELECT *
  FROM offers
  WHERE id = p_offer_id
    AND i_del = 0
    AND (
      i_pub = 1
      OR (p_user_uid IS NOT NULL AND usr_id = p_user_uid)
      OR (p_user_uid IS NOT NULL AND v_role >= 2)
    )
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_user_offers_internal(p_user_uid UUID)
RETURNS SETOF offers AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  RETURN QUERY
  SELECT * FROM offers
  WHERE usr_id = p_user_uid
    AND i_del = 0
  ORDER BY ts_crt DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_user_requests_internal(p_user_uid UUID)
RETURNS SETOF requests AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  RETURN QUERY
  SELECT * FROM requests
  WHERE usr_id = p_user_uid
    AND i_del = 0
  ORDER BY ts_crt DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_user_payments_internal(p_user_uid UUID)
RETURNS SETOF payments AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  RETURN QUERY
  SELECT * FROM payments
  WHERE uid = p_user_uid
  ORDER BY ts_crt DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_user_notifications_internal(p_user_uid UUID)
RETURNS SETOF notifications AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  RETURN QUERY
  SELECT * FROM notifications
  WHERE uid = p_user_uid
    AND i_del = 0
  ORDER BY ts_crt DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_user_appointments_internal(p_user_uid UUID)
RETURNS SETOF appointments AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  RETURN QUERY
  SELECT * FROM appointments
  WHERE req_uid = p_user_uid
  ORDER BY dt ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_owner_appointments_internal(p_owner_uid UUID)
RETURNS SETOF appointments AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_owner_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  RETURN QUERY
  SELECT * FROM appointments
  WHERE own_id = p_owner_uid
  ORDER BY dt ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_broker_offers_internal(p_broker_uid UUID)
RETURNS SETOF offers AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_broker_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  RETURN QUERY
  SELECT * FROM offers
  WHERE i_del = 0
    AND (usr_id = p_broker_uid OR brk_id = p_broker_uid)
  ORDER BY ts_crt DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_broker_appointments_internal(p_broker_uid UUID)
RETURNS SETOF appointments AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_broker_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  RETURN QUERY
  SELECT DISTINCT a.*
  FROM appointments a
  LEFT JOIN offers o ON o.id = a.off_id
  WHERE a.bkr_id = p_broker_uid
     OR a.own_id = p_broker_uid
     OR o.usr_id = p_broker_uid
  ORDER BY dt ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_broker_deals_internal(p_broker_uid UUID)
RETURNS SETOF deals AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_broker_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  RETURN QUERY
  SELECT * FROM deals
  WHERE brk_uid = p_broker_uid
    AND i_del = 0
  ORDER BY ts_crt DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_admin_pending_offers_internal(p_admin_uid UUID)
RETURNS SETOF offers AS $$
DECLARE
  v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  RETURN QUERY
  SELECT * FROM offers
  WHERE sts = 1
    AND i_del = 0
  ORDER BY ts_crt DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_admin_offers_internal(p_admin_uid UUID, p_limit INT DEFAULT 100)
RETURNS SETOF offers AS $$
DECLARE
  v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  RETURN QUERY
  SELECT * FROM offers
  WHERE i_del = 0
  ORDER BY ts_crt DESC
  LIMIT GREATEST(COALESCE(p_limit, 100), 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_admin_appointments_internal(p_admin_uid UUID)
RETURNS SETOF appointments AS $$
DECLARE
  v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  RETURN QUERY SELECT * FROM appointments ORDER BY dt DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_admin_deals_internal(p_admin_uid UUID)
RETURNS SETOF deals AS $$
DECLARE
  v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  RETURN QUERY SELECT * FROM deals WHERE i_del = 0 ORDER BY ts_crt DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_admin_payments_internal(p_admin_uid UUID)
RETURNS SETOF payments AS $$
DECLARE
  v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  RETURN QUERY SELECT * FROM payments ORDER BY ts_crt DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_admin_reports_internal(p_admin_uid UUID)
RETURNS SETOF reports AS $$
DECLARE
  v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  RETURN QUERY SELECT * FROM reports ORDER BY ts_crt DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3) Core write RPCs for stable real testing
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_review_offer_internal(
  p_admin_uid UUID,
  p_offer_id UUID,
  p_approve BOOLEAN,
  p_reason TEXT DEFAULT ''
)
RETURNS BOOLEAN AS $$
DECLARE
  v_role INT;
  v_owner_uid UUID;
  v_now TIMESTAMPTZ := NOW();
  v_rejected_count INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  SELECT usr_id INTO v_owner_uid FROM offers WHERE id = p_offer_id AND i_del = 0;
  IF v_owner_uid IS NULL THEN
    RAISE EXCEPTION 'OFFER_NOT_FOUND';
  END IF;

  UPDATE offers
  SET sts = CASE WHEN p_approve THEN 2 ELSE 3 END,
      i_pub = CASE WHEN p_approve THEN 1 ELSE 0 END,
      rsn = CASE WHEN p_approve THEN '' ELSE COALESCE(p_reason, '') END,
      ts_pub = CASE WHEN p_approve THEN v_now ELSE NULL END,
      ts_upd = v_now
  WHERE id = p_offer_id;

  IF NOT p_approve THEN
    SELECT COUNT(*) INTO v_rejected_count
    FROM offers
    WHERE usr_id = v_owner_uid
      AND sts = 3
      AND ts_upd >= NOW() - INTERVAL '30 days';
    IF v_rejected_count > 0 AND MOD(v_rejected_count, 3) = 0 THEN
      PERFORM add_points(v_owner_uid, -1000);
    END IF;
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_request_internal(
  p_user_uid UUID,
  p_request JSONB
)
RETURNS SETOF requests AS $$
DECLARE
  v_user users%ROWTYPE;
  v_config JSONB;
  v_limit INT;
  v_used INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  SELECT * INTO v_user FROM users WHERE id = p_user_uid AND i_del = 0 AND sts = 0;
  IF v_user.id IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_ACTIVE_OR_NOT_FOUND';
  END IF;

  IF COALESCE(trim(p_request->>'cl_nm'), '') = '' OR COALESCE(trim(p_request->>'cl_ph'), '') = '' THEN
    RAISE EXCEPTION 'MISSING_CLIENT_DATA';
  END IF;

  IF COALESCE(v_user.role, 0) < 2 THEN
    SELECT value INTO v_config FROM app_config WHERE key = 'main';
    v_limit := CASE WHEN COALESCE(v_user.role, 0) = 1
      THEN COALESCE((v_config->'qta'->'b'->>'r')::INT, 5)
      ELSE COALESCE((v_config->'qta'->'u'->>'r')::INT, 3)
    END;

    SELECT COUNT(*) INTO v_used
    FROM requests
    WHERE usr_id = p_user_uid AND i_del = 0;

    IF COALESCE(v_used, 0) >= COALESCE(v_limit, 3) THEN
      RAISE EXCEPTION 'QUOTA_EXCEEDED';
    END IF;
  END IF;

  RETURN QUERY
  INSERT INTO requests (
    typ, elm, cl_nm, cl_ph, prc, cur, notes, specs,
    usr_id, sts, matches, i_del, ts_crt
  ) VALUES (
    COALESCE((p_request->>'typ')::INT, 0),
    COALESCE((p_request->>'elm')::INT, 0),
    COALESCE(p_request->>'cl_nm', ''),
    COALESCE(p_request->>'cl_ph', ''),
    COALESCE((p_request->>'prc')::NUMERIC, 0),
    COALESCE((p_request->>'cur')::INT, 1),
    COALESCE(p_request->>'notes', ''),
    COALESCE(p_request->'specs', '{}'::jsonb),
    p_user_uid,
    0,
    COALESCE(p_request->'matches', '{}'::jsonb),
    0,
    NOW()
  ) RETURNING *;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_request_internal(
  p_user_uid UUID,
  p_request_id UUID,
  p_patch JSONB
)
RETURNS BOOLEAN AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  UPDATE requests
  SET typ = COALESCE((p_patch->>'typ')::INT, typ),
      elm = COALESCE((p_patch->>'elm')::INT, elm),
      cl_nm = COALESCE(NULLIF(p_patch->>'cl_nm', ''), cl_nm),
      cl_ph = COALESCE(NULLIF(p_patch->>'cl_ph', ''), cl_ph),
      prc = COALESCE((p_patch->>'prc')::NUMERIC, prc),
      cur = COALESCE((p_patch->>'cur')::INT, cur),
      notes = COALESCE(p_patch->>'notes', notes),
      specs = COALESCE(p_patch->'specs', specs)
  WHERE id = p_request_id
    AND usr_id = p_user_uid
    AND i_del = 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'REQUEST_NOT_FOUND_OR_NOT_ALLOWED';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION soft_delete_request_internal(
  p_user_uid UUID,
  p_request_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  UPDATE requests
  SET i_del = 1
  WHERE id = p_request_id
    AND usr_id = p_user_uid
    AND i_del = 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'REQUEST_NOT_FOUND_OR_NOT_ALLOWED';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_payment_internal(
  p_user_uid UUID,
  p_payment JSONB
)
RETURNS SETOF payments AS $$
DECLARE
  v_user users%ROWTYPE;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  SELECT * INTO v_user FROM users WHERE id = p_user_uid AND i_del = 0 AND sts = 0;
  IF v_user.id IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_ACTIVE_OR_NOT_FOUND';
  END IF;

  IF COALESCE(trim(p_payment->>'proof'), '') = '' OR COALESCE(trim(p_payment->>'ref'), '') = '' THEN
    RAISE EXCEPTION 'MISSING_PAYMENT_PROOF_OR_REFERENCE';
  END IF;

  RETURN QUERY
  INSERT INTO payments (
    uid, tp, pkg, amt, cur, mtd, channel, proof, ref, sts, appr_by, ts_crt
  ) VALUES (
    p_user_uid,
    COALESCE((p_payment->>'tp')::INT, 0),
    COALESCE((p_payment->>'pkg')::INT, 0),
    COALESCE((p_payment->>'amt')::NUMERIC, 0),
    COALESCE((p_payment->>'cur')::INT, 1),
    COALESCE((p_payment->>'mtd')::INT, 0),
    COALESCE(p_payment->>'channel', ''),
    COALESCE(p_payment->>'proof', ''),
    COALESCE(p_payment->>'ref', ''),
    0,
    NULL,
    NOW()
  ) RETURNING *;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_reject_payment_internal(
  p_admin_uid UUID,
  p_payment_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  UPDATE payments
  SET sts = 2,
      appr_by = p_admin_uid,
      ts_upd = NOW()
  WHERE id = p_payment_id
    AND sts = 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PAYMENT_NOT_PENDING_OR_NOT_FOUND';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_report_internal(
  p_reporter_uid UUID,
  p_report JSONB
)
RETURNS SETOF reports AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_reporter_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  RETURN QUERY
  INSERT INTO reports (
    rep_uid, tgt_uid, tgt_tp, tgt_id, rsn, det, sts, act, act_dur, note, act_by, ts_crt
  ) VALUES (
    p_reporter_uid,
    NULLIF(p_report->>'tgt_uid', '')::UUID,
    COALESCE((p_report->>'tgt_tp')::INT, 0),
    COALESCE(p_report->>'tgt_id', ''),
    COALESCE((p_report->>'rsn')::INT, 0),
    COALESCE(p_report->>'det', ''),
    0,
    0,
    0,
    '',
    NULL,
    NOW()
  ) RETURNING *;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_handle_report_internal(
  p_admin_uid UUID,
  p_report_id UUID,
  p_action INT,
  p_note TEXT DEFAULT '',
  p_duration INT DEFAULT 0
)
RETURNS BOOLEAN AS $$
DECLARE
  v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  UPDATE reports
  SET sts = 1,
      act = COALESCE(p_action, 0),
      act_dur = COALESCE(p_duration, 0),
      note = COALESCE(p_note, ''),
      act_by = p_admin_uid
  WHERE id = p_report_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'REPORT_NOT_FOUND';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION book_appointment_internal(
  p_user_uid UUID,
  p_offer_id UUID,
  p_dt TIMESTAMPTZ,
  p_broker_id UUID DEFAULT NULL,
  p_request_id UUID DEFAULT NULL
)
RETURNS SETOF appointments AS $$
DECLARE
  v_offer offers%ROWTYPE;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  SELECT * INTO v_offer FROM offers WHERE id = p_offer_id AND i_del = 0;
  IF v_offer.id IS NULL THEN
    RAISE EXCEPTION 'OFFER_NOT_FOUND';
  END IF;
  IF p_user_uid = v_offer.usr_id THEN
    RAISE EXCEPTION 'CANNOT_BOOK_OWN_OFFER';
  END IF;
  IF p_dt <= NOW() THEN
    RAISE EXCEPTION 'INVALID_APPOINTMENT_TIME';
  END IF;
  IF EXISTS (
    SELECT 1 FROM appointments
    WHERE off_id = p_offer_id
      AND req_uid = p_user_uid
      AND dt = p_dt
      AND sts IN (0, 1)
  ) THEN
    RAISE EXCEPTION 'DUPLICATE_APPOINTMENT';
  END IF;

  RETURN QUERY
  INSERT INTO appointments (
    off_id, req_id, req_uid, own_id, bkr_id, dt, sts,
    fbk_own, fbk_req, i_force, rmnd_24, rmnd_2, rmnd_qtr, rmnd_end, ts_crt
  ) VALUES (
    p_offer_id,
    p_request_id,
    p_user_uid,
    v_offer.usr_id,
    COALESCE(p_broker_id, NULLIF(v_offer.brk_id, '')),
    p_dt,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    NOW()
  ) RETURNING *;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION cancel_appointment_internal(
  p_requester_uid UUID,
  p_appointment_id UUID,
  p_reason TEXT DEFAULT ''
)
RETURNS BOOLEAN AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_requester_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  UPDATE appointments
  SET sts = 3,
      cnl_by = p_requester_uid,
      cnl_rsn = COALESCE(p_reason, ''),
      dt_end = NOW()
  WHERE id = p_appointment_id
    AND req_uid = p_requester_uid
    AND sts IN (0, 1);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'APPOINTMENT_NOT_FOUND_OR_NOT_ALLOWED';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION broker_handle_appointment_internal(
  p_broker_uid UUID,
  p_appointment_id UUID,
  p_action TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
  v_allowed BOOLEAN := FALSE;
  v_now TIMESTAMPTZ := NOW();
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_broker_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM appointments a
    LEFT JOIN offers o ON o.id = a.off_id
    WHERE a.id = p_appointment_id
      AND (a.bkr_id = p_broker_uid OR a.own_id = p_broker_uid OR o.usr_id = p_broker_uid)
  ) INTO v_allowed;

  IF NOT v_allowed THEN
    RAISE EXCEPTION 'APPOINTMENT_NOT_FOUND_OR_NOT_ALLOWED';
  END IF;

  IF p_action = 'confirm' THEN
    UPDATE appointments
    SET sts = 1,
        fbk_own = 1,
        fbk_own_dt = v_now
    WHERE id = p_appointment_id;
  ELSIF p_action = 'reject' THEN
    UPDATE appointments
    SET sts = 4,
        fbk_own = 2,
        fbk_own_dt = v_now,
        dt_end = v_now
    WHERE id = p_appointment_id;
  ELSIF p_action = 'complete' THEN
    UPDATE appointments
    SET sts = 2,
        dt_end = v_now
    WHERE id = p_appointment_id;
  ELSE
    RAISE EXCEPTION 'INVALID_ACTION';
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_update_appointment_status_internal(
  p_admin_uid UUID,
  p_appointment_id UUID,
  p_status INT,
  p_admin_note TEXT DEFAULT ''
)
RETURNS BOOLEAN AS $$
DECLARE
  v_role INT;
  v_requester_uid UUID;
  v_cancel_count INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  SELECT req_uid INTO v_requester_uid FROM appointments WHERE id = p_appointment_id;

  UPDATE appointments
  SET sts = p_status,
      admin_nt = CASE WHEN COALESCE(trim(p_admin_note), '') = '' THEN admin_nt ELSE p_admin_note END,
      dt_end = CASE WHEN p_status >= 2 THEN NOW() ELSE dt_end END
  WHERE id = p_appointment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'APPOINTMENT_NOT_FOUND';
  END IF;

  IF p_status = 5 AND v_requester_uid IS NOT NULL THEN
    PERFORM add_points(v_requester_uid, -500);
  ELSIF p_status = 3 AND v_requester_uid IS NOT NULL THEN
    SELECT COUNT(*) INTO v_cancel_count
    FROM appointments
    WHERE req_uid = v_requester_uid
      AND sts = 3
      AND ts_crt >= NOW() - INTERVAL '30 days';
    IF v_cancel_count > 0 AND MOD(v_cancel_count, 3) = 0 THEN
      PERFORM add_points(v_requester_uid, -300);
    END IF;
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION admin_force_appointment_internal(
  p_admin_uid UUID,
  p_appointment_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  UPDATE appointments
  SET i_force = 1,
      force_by = p_admin_uid,
      sts = 1
  WHERE id = p_appointment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'APPOINTMENT_NOT_FOUND';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_deal_internal(
  p_admin_uid UUID,
  p_deal JSONB
)
RETURNS SETOF deals AS $$
DECLARE
  v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  RETURN QUERY
  INSERT INTO deals (
    off_id, app_id, sell_uid, buy_uid, brk_uid, fin_prc, cur,
    com_pct, com_val, com_note, form, sts, cmpl_by, i_del, ts_crt, ts_cmpl
  ) VALUES (
    NULLIF(p_deal->>'off_id', '')::UUID,
    NULLIF(p_deal->>'app_id', '')::UUID,
    NULLIF(p_deal->>'sell_uid', '')::UUID,
    NULLIF(p_deal->>'buy_uid', '')::UUID,
    NULLIF(p_deal->>'brk_uid', '')::UUID,
    COALESCE((p_deal->>'fin_prc')::NUMERIC, 0),
    COALESCE((p_deal->>'cur')::INT, 1),
    COALESCE((p_deal->>'com_pct')::NUMERIC, 0),
    COALESCE((p_deal->>'com_val')::NUMERIC, 0),
    NULLIF(p_deal->>'com_note', ''),
    COALESCE(p_deal->'form', '{}'::jsonb),
    COALESCE((p_deal->>'sts')::INT, 0),
    NULL,
    0,
    NOW(),
    NULL
  ) RETURNING *;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION complete_deal_internal(
  p_admin_uid UUID,
  p_deal_id UUID,
  p_commission NUMERIC DEFAULT NULL,
  p_note TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  v_role INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = p_admin_uid AND i_del = 0;
  IF v_role IS NULL OR v_role < 2 THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  UPDATE deals
  SET sts = 1,
      cmpl_by = p_admin_uid,
      ts_cmpl = NOW(),
      com_val = COALESCE(p_commission, com_val),
      com_note = COALESCE(p_note, com_note)
  WHERE id = p_deal_id
    AND i_del = 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'DEAL_NOT_FOUND';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION mark_notification_read_internal(
  p_user_uid UUID,
  p_notification_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  UPDATE notifications
  SET i_rd = 1
  WHERE id = p_notification_id
    AND uid = p_user_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'NOTIFICATION_NOT_FOUND_OR_NOT_ALLOWED';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION mark_all_notifications_read_internal(p_user_uid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  UPDATE notifications
  SET i_rd = 1
  WHERE uid = p_user_uid AND i_rd = 0;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_rating_internal(
  p_reviewer_uid UUID,
  p_target_uid UUID,
  p_stars INT,
  p_comment TEXT DEFAULT ''
)
RETURNS BOOLEAN AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_reviewer_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  INSERT INTO ratings (reviewer_uid, target_uid, stars, comment)
  VALUES (p_reviewer_uid, p_target_uid, p_stars, COALESCE(p_comment, ''));
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION register_daily_streak_internal(
  p_user_uid UUID,
  p_points INT DEFAULT 50
)
RETURNS JSONB AS $$
DECLARE
  v_current_streak INT := 0;
  v_last_ts TIMESTAMPTZ;
  v_now TIMESTAMPTZ := NOW();
  v_today TEXT;
  v_last_day TEXT;
  v_new_streak INT;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  SELECT COALESCE(strk, 0), strk_dt INTO v_current_streak, v_last_ts
  FROM users
  WHERE id = p_user_uid
    AND i_del = 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;

  v_today := to_char((v_now AT TIME ZONE 'UTC' + INTERVAL '3 hours')::date, 'YYYY-MM-DD');
  IF v_last_ts IS NOT NULL THEN
    v_last_day := to_char((v_last_ts AT TIME ZONE 'UTC' + INTERVAL '3 hours')::date, 'YYYY-MM-DD');
  END IF;

  IF v_last_day = v_today THEN
    RETURN jsonb_build_object('streak', v_current_streak, 'changed', false, 'awarded', false);
  END IF;

  v_new_streak := CASE WHEN v_last_day IS NULL THEN 1 ELSE v_current_streak + 1 END;

  UPDATE users
  SET strk = v_new_streak,
      strk_dt = v_now,
      ts_upd = v_now
  WHERE id = p_user_uid;

  PERFORM add_points(p_user_uid, p_points);

  RETURN jsonb_build_object('streak', v_new_streak, 'changed', true, 'awarded', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_user_profile_internal(
  p_user_uid UUID,
  p_payload JSONB
)
RETURNS BOOLEAN AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  UPDATE users
  SET nm = COALESCE(p_payload->>'nm', nm),
      sid = COALESCE(p_payload->>'sid', sid),
      ad = COALESCE(p_payload->>'ad', ad),
      img = COALESCE(p_payload->>'img', img),
      ts_upd = NOW()
  WHERE id = p_user_uid
    AND i_del = 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_user_notification_settings_internal(
  p_user_uid UUID,
  p_ntf JSONB
)
RETURNS BOOLEAN AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  IF jsonb_typeof(COALESCE(p_ntf, '{}'::jsonb)) <> 'object' THEN
    RAISE EXCEPTION 'INVALID_NOTIFICATION_SETTINGS';
  END IF;

  UPDATE users
  SET ntf = p_ntf,
      ts_upd = NOW()
  WHERE id = p_user_uid
    AND i_del = 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION submit_broker_request_internal(
  p_user_uid UUID,
  p_business_name TEXT,
  p_category INT,
  p_experience TEXT DEFAULT '',
  p_about TEXT DEFAULT ''
)
RETURNS BOOLEAN AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  UPDATE users
  SET brk_nm = COALESCE(p_business_name, ''),
      brk_cls = COALESCE(p_category, 0),
      vrf = CASE WHEN vrf = 0 THEN 1 ELSE vrf END,
      ts_upd = NOW()
  WHERE id = p_user_uid
    AND i_del = 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;

  INSERT INTO activity_log (uid, action, details, ts_crt)
  VALUES (
    p_user_uid,
    'broker_request',
    jsonb_build_object(
      'business_name', COALESCE(p_business_name, ''),
      'category', COALESCE(p_category, 0),
      'experience', COALESCE(p_experience, ''),
      'about', COALESCE(p_about, '')
    ),
    NOW()
  );

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION mark_social_published_internal(
  p_user_uid UUID,
  p_offer_id UUID,
  p_text TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_uid THEN
    RAISE EXCEPTION 'AUTH_UID_MISMATCH';
  END IF;

  UPDATE offers
  SET soc_pub = 1,
      soc_txt = COALESCE(p_text, ''),
      ts_upd = NOW()
  WHERE id = p_offer_id
    AND usr_id = p_user_uid
    AND i_del = 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'OFFER_NOT_FOUND_OR_NOT_ALLOWED';
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION increment_offer_views_internal(p_offer_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE offers
  SET vws = COALESCE(vws, 0) + 1
  WHERE id = p_offer_id
    AND i_del = 0
    AND i_pub = 1;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_offer_by_id_internal(UUID, UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_user_offers_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_user_requests_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_user_payments_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_user_notifications_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_user_appointments_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_owner_appointments_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_broker_offers_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_broker_appointments_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_broker_deals_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_admin_pending_offers_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_admin_offers_internal(UUID, INT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_admin_appointments_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_admin_deals_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_admin_payments_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_admin_reports_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_review_offer_internal(UUID, UUID, BOOLEAN, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION create_request_internal(UUID, JSONB) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION update_request_internal(UUID, UUID, JSONB) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION soft_delete_request_internal(UUID, UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION create_payment_internal(UUID, JSONB) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_reject_payment_internal(UUID, UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION create_report_internal(UUID, JSONB) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_handle_report_internal(UUID, UUID, INT, TEXT, INT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION book_appointment_internal(UUID, UUID, TIMESTAMPTZ, UUID, UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cancel_appointment_internal(UUID, UUID, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION broker_handle_appointment_internal(UUID, UUID, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_update_appointment_status_internal(UUID, UUID, INT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_force_appointment_internal(UUID, UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION create_deal_internal(UUID, JSONB) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION complete_deal_internal(UUID, UUID, NUMERIC, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION mark_notification_read_internal(UUID, UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION mark_all_notifications_read_internal(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION create_rating_internal(UUID, UUID, INT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION register_daily_streak_internal(UUID, INT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION update_user_profile_internal(UUID, JSONB) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION update_user_notification_settings_internal(UUID, JSONB) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION submit_broker_request_internal(UUID, TEXT, INT, TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION mark_social_published_internal(UUID, UUID, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION increment_offer_views_internal(UUID) TO anon, authenticated;

-- ============================================================================
-- Admin Employee Management Final (2026-06-15)
-- Source mirror: supabase/migrations/2026_06_15_admin_employee_management_final.sql
-- ============================================================================
-- ══════════════════════════════════════════════════════════════════════
-- Migration: Admin Employee Management Final
-- Date: 2026-06-15
-- Purpose:
--   Final safe RPC layer for employee management inspired by Final project
--   while respecting Sweeda users table, numeric roles, usr/pwd auth model.
-- ══════════════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Ensure auth/password fields exist for staff accounts.
ALTER TABLE users ADD COLUMN IF NOT EXISTS eml TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS usr TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS pwd TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS vrf INT DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS pkg_grace TIMESTAMPTZ;

-- Ensure final 0..6 role contract.
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role BETWEEN 0 AND 6);

CREATE UNIQUE INDEX IF NOT EXISTS ux_users_username_active
  ON users (LOWER(usr))
  WHERE usr IS NOT NULL AND i_del = 0;

-- ────────────────────────────────────────────────────────────────────
-- Shared helpers
-- ────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION _admin_employee_assert_actor(
  p_admin_uid UUID,
  p_min_role INT DEFAULT 5
) RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_role INT;
BEGIN
  IF p_admin_uid IS NULL THEN
    RAISE EXCEPTION 'ADMIN_UID_REQUIRED';
  END IF;

  IF auth.uid() IS NOT NULL AND auth.uid() <> p_admin_uid THEN
    RAISE EXCEPTION 'AUTH_MISMATCH';
  END IF;

  SELECT role INTO v_role
  FROM users
  WHERE id = p_admin_uid AND i_del = 0 AND sts = 0;

  IF v_role IS NULL OR v_role < p_min_role THEN
    RAISE EXCEPTION 'UNAUTHORIZED';
  END IF;

  RETURN v_role;
END;
$$;

CREATE OR REPLACE FUNCTION _admin_employee_log(
  p_admin_uid UUID,
  p_action TEXT,
  p_target_uid UUID DEFAULT NULL,
  p_payload JSONB DEFAULT '{}'::jsonb
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO activity_log (uid, act, det, ref_id, ref_col, ts_crt)
  VALUES (
    p_admin_uid,
    99,
    p_action || ': ' || COALESCE(p_payload::TEXT, '{}'),
    COALESCE(p_target_uid::TEXT, ''),
    'users',
    NOW()
  );
END;
$$;

-- ────────────────────────────────────────────────────────────────────
-- Read staff users for management screen
-- ────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_all_staff_users(p_admin_uid UUID)
RETURNS SETOF JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_role INT;
BEGIN
  v_admin_role := _admin_employee_assert_actor(p_admin_uid, 5);

  RETURN QUERY
    SELECT jsonb_build_object(
      'id', u.id,
      'nm', u.nm,
      'ph', u.ph,
      'eml', u.eml,
      'ad', u.ad,
      'role', u.role,
      'sid', u.sid,
      'img', u.img,
      'pt', u.pt,
      'bg', u.bg,
      'bg_ts', u.bg_ts,
      'b_pkg', u.b_pkg,
      'pkg_end', u.pkg_end,
      'pkg_grace', u.pkg_grace,
      'brk', u.brk,
      'brk_cls', u.brk_cls,
      'brk_nm', u.brk_nm,
      'sts', u.sts,
      'ban_rsn', u.ban_rsn,
      'ntf', u.ntf,
      'stats', u.stats,
      'wk_lgn', u.wk_lgn,
      'strk', u.strk,
      'strk_dt', u.strk_dt,
      'i_del', u.i_del,
      'perm', u.perm,
      'ts_crt', u.ts_crt,
      'ts_upd', u.ts_upd,
      'vrf', u.vrf,
      'usr', u.usr,
      'pwd', CASE WHEN u.pwd IS NOT NULL THEN 'set' ELSE NULL END
    )
    FROM users u
    WHERE u.i_del = 0
      AND u.role IN (2, 3, 4, 5, 6)
    ORDER BY u.role DESC, u.ts_crt DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION get_all_staff_users(UUID) TO anon, authenticated, service_role;

-- ────────────────────────────────────────────────────────────────────
-- Create staff user (called by Edge Function create-user)
-- ────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_create_staff_user(
  p_admin_uid UUID,
  p_full_name TEXT,
  p_phone TEXT,
  p_email TEXT,
  p_username TEXT,
  p_password TEXT,
  p_role INT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_role INT;
  v_phone TEXT;
  v_username TEXT;
  v_new_id UUID;
BEGIN
  v_admin_role := _admin_employee_assert_actor(p_admin_uid, 5);

  IF p_role NOT IN (2, 3, 4, 5) THEN
    RAISE EXCEPTION 'INVALID_ROLE';
  END IF;

  IF v_admin_role < 6 AND p_role >= 5 THEN
    RAISE EXCEPTION 'ONLY_MANAGER_CAN_CREATE_DEPUTY';
  END IF;

  IF LENGTH(TRIM(COALESCE(p_full_name, ''))) < 2 THEN
    RAISE EXCEPTION 'NAME_REQUIRED';
  END IF;

  IF LENGTH(COALESCE(p_password, '')) < 8 THEN
    RAISE EXCEPTION 'PASSWORD_TOO_SHORT';
  END IF;

  v_phone := normalize_sy_phone(COALESCE(p_phone, ''));
  IF v_phone = '' THEN
    RAISE EXCEPTION 'PHONE_REQUIRED';
  END IF;

  IF EXISTS (SELECT 1 FROM users WHERE normalize_sy_phone(ph) = v_phone AND i_del = 0) THEN
    RAISE EXCEPTION 'PHONE_EXISTS';
  END IF;

  v_username := NULLIF(LOWER(TRIM(COALESCE(p_username, ''))), '');
  IF v_username IS NOT NULL THEN
    IF LENGTH(v_username) < 3 OR LENGTH(v_username) > 30 THEN
      RAISE EXCEPTION 'USERNAME_LENGTH';
    END IF;
    IF NOT v_username ~ '^[a-z0-9_.]+$' THEN
      RAISE EXCEPTION 'USERNAME_INVALID_CHARS';
    END IF;
    IF EXISTS (SELECT 1 FROM users WHERE LOWER(usr) = v_username AND i_del = 0) THEN
      RAISE EXCEPTION 'USERNAME_TAKEN';
    END IF;
  END IF;

  INSERT INTO users (nm, ph, eml, usr, pwd, role, sts, vrf, i_del, ts_crt, ts_upd)
  VALUES (
    TRIM(COALESCE(p_full_name, '')),
    v_phone,
    NULLIF(TRIM(COALESCE(p_email, '')), ''),
    v_username,
    crypt(p_password, gen_salt('bf', 8)),
    p_role,
    0,
    0,
    0,
    NOW(),
    NOW()
  )
  RETURNING id INTO v_new_id;

  PERFORM _admin_employee_log(
    p_admin_uid,
    'staff_create',
    v_new_id,
    jsonb_build_object('role', p_role, 'phone', v_phone, 'username', v_username)
  );

  RETURN jsonb_build_object('success', true, 'user_id', v_new_id);
END;
$$;
REVOKE ALL ON FUNCTION admin_create_staff_user(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION admin_create_staff_user(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, INT) TO service_role;

-- ────────────────────────────────────────────────────────────────────
-- Update staff role (called by Edge Function update-user-role)
-- ────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_update_staff_role(
  p_admin_uid UUID,
  p_target_uid UUID,
  p_role INT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_role INT;
  v_target_role INT;
BEGIN
  v_admin_role := _admin_employee_assert_actor(p_admin_uid, 5);

  SELECT role INTO v_target_role FROM users WHERE id = p_target_uid AND i_del = 0;
  IF v_target_role IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;
  IF v_target_role = 6 THEN
    RAISE EXCEPTION 'CANNOT_MODIFY_MANAGER';
  END IF;
  IF p_role NOT IN (2, 3, 4, 5) THEN
    RAISE EXCEPTION 'INVALID_ROLE';
  END IF;
  IF v_admin_role < 6 AND (p_role >= 5 OR v_target_role >= 5) THEN
    RAISE EXCEPTION 'ONLY_MANAGER_CAN_MANAGE_DEPUTIES';
  END IF;

  UPDATE users
  SET role = p_role,
      brk = CASE WHEN p_role = 1 THEN 1 ELSE brk END,
      ts_upd = NOW()
  WHERE id = p_target_uid AND i_del = 0;

  PERFORM _admin_employee_log(
    p_admin_uid,
    'staff_role_update',
    p_target_uid,
    jsonb_build_object('old_role', v_target_role, 'new_role', p_role)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;
REVOKE ALL ON FUNCTION admin_update_staff_role(UUID, UUID, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION admin_update_staff_role(UUID, UUID, INT) TO service_role;

-- ────────────────────────────────────────────────────────────────────
-- Toggle staff status (called by Edge Function toggle-user-status)
-- ────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_toggle_staff_status(
  p_admin_uid UUID,
  p_target_uid UUID,
  p_status INT,
  p_reason TEXT DEFAULT ''
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_role INT;
  v_target_role INT;
BEGIN
  v_admin_role := _admin_employee_assert_actor(p_admin_uid, 5);

  SELECT role INTO v_target_role FROM users WHERE id = p_target_uid AND i_del = 0;
  IF v_target_role IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;
  IF v_target_role = 6 THEN
    RAISE EXCEPTION 'CANNOT_MODIFY_MANAGER';
  END IF;
  IF v_admin_role < 6 AND v_target_role >= 5 THEN
    RAISE EXCEPTION 'ONLY_MANAGER_CAN_MANAGE_DEPUTIES';
  END IF;
  IF p_status NOT IN (0, 1, 2) THEN
    RAISE EXCEPTION 'INVALID_STATUS';
  END IF;

  UPDATE users
  SET sts = p_status,
      ban_rsn = CASE WHEN p_status IN (1, 2) THEN COALESCE(p_reason, '') ELSE '' END,
      ts_upd = NOW()
  WHERE id = p_target_uid AND i_del = 0;

  PERFORM _admin_employee_log(
    p_admin_uid,
    'staff_status_update',
    p_target_uid,
    jsonb_build_object('status', p_status, 'reason', COALESCE(p_reason, ''))
  );

  RETURN jsonb_build_object('success', true);
END;
$$;
REVOKE ALL ON FUNCTION admin_toggle_staff_status(UUID, UUID, INT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION admin_toggle_staff_status(UUID, UUID, INT, TEXT) TO service_role;

-- ────────────────────────────────────────────────────────────────────
-- Reset staff password (called by Edge Function reset-user-password)
-- ────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_reset_staff_password(
  p_admin_uid UUID,
  p_target_uid UUID,
  p_new_password TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_role INT;
  v_target_role INT;
BEGIN
  v_admin_role := _admin_employee_assert_actor(p_admin_uid, 5);

  SELECT role INTO v_target_role FROM users WHERE id = p_target_uid AND i_del = 0;
  IF v_target_role IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;
  IF v_target_role = 6 THEN
    RAISE EXCEPTION 'CANNOT_MODIFY_MANAGER';
  END IF;
  IF v_admin_role < 6 AND v_target_role >= 5 THEN
    RAISE EXCEPTION 'ONLY_MANAGER_CAN_MANAGE_DEPUTIES';
  END IF;
  IF LENGTH(COALESCE(p_new_password, '')) < 8 THEN
    RAISE EXCEPTION 'PASSWORD_TOO_SHORT';
  END IF;

  UPDATE users
  SET pwd = crypt(p_new_password, gen_salt('bf', 8)),
      ts_upd = NOW()
  WHERE id = p_target_uid AND i_del = 0;

  PERFORM _admin_employee_log(p_admin_uid, 'staff_password_reset', p_target_uid, '{}'::jsonb);

  RETURN jsonb_build_object('success', true);
END;
$$;
REVOKE ALL ON FUNCTION admin_reset_staff_password(UUID, UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION admin_reset_staff_password(UUID, UUID, TEXT) TO service_role;

-- ────────────────────────────────────────────────────────────────────
-- Delete staff user (soft delete, called by Edge Function delete-user)
-- ────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_delete_staff_user(
  p_admin_uid UUID,
  p_target_uid UUID
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_role INT;
  v_target_role INT;
BEGIN
  v_admin_role := _admin_employee_assert_actor(p_admin_uid, 5);

  SELECT role INTO v_target_role FROM users WHERE id = p_target_uid AND i_del = 0;
  IF v_target_role IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;
  IF v_target_role = 6 THEN
    RAISE EXCEPTION 'CANNOT_DELETE_MANAGER';
  END IF;
  IF v_admin_role < 6 AND v_target_role >= 5 THEN
    RAISE EXCEPTION 'ONLY_MANAGER_CAN_MANAGE_DEPUTIES';
  END IF;

  UPDATE users
  SET i_del = 1,
      sts = 1,
      ts_upd = NOW()
  WHERE id = p_target_uid AND i_del = 0;

  PERFORM _admin_employee_log(p_admin_uid, 'staff_delete', p_target_uid, '{}'::jsonb);

  RETURN jsonb_build_object('success', true);
END;
$$;
REVOKE ALL ON FUNCTION admin_delete_staff_user(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION admin_delete_staff_user(UUID, UUID) TO service_role;

-- ============================================================================
-- Staff Sessions Security (2026-06-15)
-- Source mirror: supabase/migrations/2026_06_15_staff_sessions_security.sql
-- ============================================================================
-- ══════════════════════════════════════════════════════════════════════
-- Migration: Staff Sessions Security
-- Date: 2026-06-15
-- Purpose:
--   Add server-side staff sessions so sensitive employee-management Edge
--   Functions do not rely on admin_uid alone.
-- ══════════════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS staff_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,
  role_snapshot INT NOT NULL,
  device_id TEXT DEFAULT '',
  ip TEXT DEFAULT '',
  revoked INT DEFAULT 0 CHECK (revoked IN (0, 1)),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_used_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_staff_sessions_user_active
  ON staff_sessions (user_id, expires_at DESC)
  WHERE revoked = 0;

CREATE INDEX IF NOT EXISTS idx_staff_sessions_expiry
  ON staff_sessions (expires_at)
  WHERE revoked = 0;

-- Internal helper: creates a session and returns the plain token once.
CREATE OR REPLACE FUNCTION _issue_staff_session(
  p_user_uid UUID,
  p_device_id TEXT DEFAULT '',
  p_ip TEXT DEFAULT '',
  p_ttl INTERVAL DEFAULT INTERVAL '7 days'
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role INT;
  v_token TEXT;
  v_expires_at TIMESTAMPTZ;
  v_session_id UUID;
BEGIN
  SELECT role INTO v_role
  FROM users
  WHERE id = p_user_uid
    AND i_del = 0
    AND sts = 0;

  IF v_role IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_FOUND_OR_INACTIVE';
  END IF;

  IF v_role < 2 THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_STAFF');
  END IF;

  v_token := encode(gen_random_bytes(32), 'hex');
  v_expires_at := NOW() + p_ttl;

  INSERT INTO staff_sessions (
    user_id,
    token_hash,
    role_snapshot,
    device_id,
    ip,
    expires_at
  ) VALUES (
    p_user_uid,
    crypt(v_token, gen_salt('bf', 8)),
    v_role,
    COALESCE(p_device_id, ''),
    COALESCE(p_ip, ''),
    v_expires_at
  ) RETURNING id INTO v_session_id;

  RETURN jsonb_build_object(
    'success', true,
    'session_id', v_session_id,
    'session_token', v_token,
    'expires_at', v_expires_at,
    'role', v_role
  );
END;
$$;

REVOKE ALL ON FUNCTION _issue_staff_session(UUID, TEXT, TEXT, INTERVAL) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION _issue_staff_session(UUID, TEXT, TEXT, INTERVAL) TO service_role;

-- Validates a staff/admin session token.
CREATE OR REPLACE FUNCTION validate_staff_session(
  p_user_uid UUID,
  p_token TEXT,
  p_min_role INT DEFAULT 5
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_session RECORD;
  v_user RECORD;
BEGIN
  IF p_user_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'USER_UID_REQUIRED');
  END IF;

  IF COALESCE(p_token, '') = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'SESSION_TOKEN_REQUIRED');
  END IF;

  SELECT id, role, sts, i_del INTO v_user
  FROM users
  WHERE id = p_user_uid
    AND i_del = 0;

  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND');
  END IF;

  IF v_user.sts <> 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'USER_INACTIVE');
  END IF;

  IF v_user.role < p_min_role THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  FOR v_session IN
    SELECT id, token_hash, expires_at
    FROM staff_sessions
    WHERE user_id = p_user_uid
      AND revoked = 0
      AND expires_at > NOW()
    ORDER BY created_at DESC
  LOOP
    IF v_session.token_hash = crypt(p_token, v_session.token_hash) THEN
      UPDATE staff_sessions
      SET last_used_at = NOW()
      WHERE id = v_session.id;

      RETURN jsonb_build_object(
        'success', true,
        'user_id', p_user_uid,
        'role', v_user.role,
        'session_id', v_session.id,
        'expires_at', v_session.expires_at
      );
    END IF;
  END LOOP;

  RETURN jsonb_build_object('success', false, 'error', 'INVALID_SESSION');
END;
$$;

REVOKE ALL ON FUNCTION validate_staff_session(UUID, TEXT, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION validate_staff_session(UUID, TEXT, INT) TO service_role;

CREATE OR REPLACE FUNCTION revoke_staff_session(
  p_user_uid UUID,
  p_token TEXT
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_session RECORD;
BEGIN
  IF p_user_uid IS NULL OR COALESCE(p_token, '') = '' THEN
    RETURN FALSE;
  END IF;

  FOR v_session IN
    SELECT id, token_hash
    FROM staff_sessions
    WHERE user_id = p_user_uid
      AND revoked = 0
  LOOP
    IF v_session.token_hash = crypt(p_token, v_session.token_hash) THEN
      UPDATE staff_sessions SET revoked = 1 WHERE id = v_session.id;
      RETURN TRUE;
    END IF;
  END LOOP;

  RETURN FALSE;
END;
$$;

REVOKE ALL ON FUNCTION revoke_staff_session(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION revoke_staff_session(UUID, TEXT) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION revoke_all_staff_sessions(
  p_user_uid UUID
) RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INT;
BEGIN
  UPDATE staff_sessions
  SET revoked = 1
  WHERE user_id = p_user_uid
    AND revoked = 0;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION revoke_all_staff_sessions(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION revoke_all_staff_sessions(UUID) TO service_role;

-- Re-issue login_with_password with optional staff session info.
CREATE OR REPLACE FUNCTION login_with_password(
  p_identifier TEXT,
  p_password TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user RECORD;
  v_identifier TEXT;
  v_session JSONB := NULL;
BEGIN
  v_identifier := LOWER(TRIM(p_identifier));

  SELECT id, nm, role, pwd, sts, i_del INTO v_user
  FROM users
  WHERE (LOWER(usr) = v_identifier
         OR normalize_sy_phone(ph) = normalize_sy_phone(v_identifier))
    AND i_del = 0
  LIMIT 1;

  IF v_user IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_FOUND' USING HINT = 'لم يتم العثور على حساب بهذا الاسم أو الرقم';
  END IF;

  IF v_user.pwd IS NULL THEN
    RAISE EXCEPTION 'NO_PASSWORD_SET' USING HINT = 'لم يتم تعيين كلمة مرور لهذا الحساب، سجّل دخولك عبر واتساب أولاً';
  END IF;

  IF v_user.sts = 2 THEN
    RAISE EXCEPTION 'USER_BANNED';
  END IF;

  IF v_user.sts = 1 THEN
    RAISE EXCEPTION 'USER_FROZEN';
  END IF;

  IF v_user.pwd != crypt(p_password, v_user.pwd) THEN
    RAISE EXCEPTION 'WRONG_PASSWORD' USING HINT = 'كلمة المرور غير صحيحة';
  END IF;

  IF v_user.role >= 2 THEN
    v_session := _issue_staff_session(v_user.id, '', '', INTERVAL '7 days');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user.id,
    'role', v_user.role,
    'nm', v_user.nm,
    'staff_session', v_session
  );
END;
$$;

GRANT EXECUTE ON FUNCTION login_with_password(TEXT, TEXT) TO anon, authenticated, service_role;
