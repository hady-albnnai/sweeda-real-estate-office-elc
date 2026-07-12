-- ═══════════════════════════════════════════════════════════════
-- تنظيف كامل — يبقي حساب المدير فقط
-- شغّل هذا الاستعلام عند الحاجة لتفريغ بيانات الاختبار
-- ═══════════════════════════════════════════════════════════════

-- 1) حذف البيانات المرتبطة (كلها)
DELETE FROM appointments;
DELETE FROM photography_tasks;
DELETE FROM deals;
DELETE FROM payments;
DELETE FROM reports;
DELETE FROM ratings;
DELETE FROM completion_requests;
DELETE FROM expediting_tasks;
DELETE FROM notifications;
DELETE FROM activity_log;

-- 2) حذف الطلبات والعروض
DELETE FROM requests;
DELETE FROM offers;

-- 3) حذف بيانات المستخدمين (ما عدا المدير)
DELETE FROM staff_sessions WHERE user_id != '53701a2a-26ba-4b35-8f7d-f0a8f3956a98';
DELETE FROM user_daily_limits WHERE uid != '53701a2a-26ba-4b35-8f7d-f0a8f3956a98';
DELETE FROM user_devices WHERE uid != '53701a2a-26ba-4b35-8f7d-f0a8f3956a98';
DELETE FROM lawyer_profiles WHERE uid != '53701a2a-26ba-4b35-8f7d-f0a8f3956a98';

-- 4) حذف حسابات المستخدمين (ما عدا المدير)
DELETE FROM users WHERE id != '53701a2a-26ba-4b35-8f7d-f0a8f3956a98';

-- 5) حذف حسابات auth المتعلقة
DELETE FROM auth.users WHERE id NOT IN (SELECT id FROM users);

-- 6) تنظيف أكواد OTP
DELETE FROM otp_codes;

-- 7) تصفير عداد العروض
ALTER SEQUENCE IF EXISTS offers_number_seq RESTART WITH 1;
UPDATE app_config SET value = jsonb_set(value, '{offerNumber}', '0') WHERE key = 'main';
