# 📚 مرجع دوال Supabase (RPC + Edge Functions)

> **مشروع:** عقارات السويداء  
> **آخر تحديث:** 2026-06-05 (المرحلة 10)  
> **المصدر:** `supabase/setup.sql` + Migrations + Edge Functions

---

## 🟢 حالة التفعيل على السيرفر (vsgkgnjtebjxyqwpuopz)

| الحالة | المحتوى |
|---|---|
| ✅ **مُطبّق على السيرفر** | كل دوال `setup.sql` الأصلية (12 دالة) |
| ✅ **مُطبّق على السيرفر** | Migration المصادقة (`2026_06_05_whatsapp_email_auth.sql`) — 4 دوال + عمود `eml` + توسعة `otp_codes` |
| ✅ **مُطبّق على السيرفر** | Migration الإحصائيات والإحالة (`2026_06_05_stats_triggers_and_wkLogin.sql`) — 6 دوال + 4 triggers + عمودي `ref_by`/`ref_cnt` |
| ✅ **مُطبّق على السيرفر** | Migration ترقيات العروض (`2026_06_05_offer_boosts.sql`) — 2 دالة + 8 أعمدة (`i_pin`, `i_bst`, `i_fms`, `pin_end`, `bst_end`, `fms_end`, `dsc_pct`, `dsc_end`) |
| ✅ **مُطبّق على السيرفر** | Migration الجدولة التلقائية (`2026_06_05_cron_jobs.sql`) — extension `pg_cron` مفعّل + 3 cron jobs نشطة |
| ✅ **مُطبّق على السيرفر** | Migration FCM (`2026_06_05_fcm_setup.sql`) — UNIQUE على device_token + `get_user_device_tokens` + `notify_user` |
| ✅ **مُطبّق على السيرفر** | Migration Notification Triggers (`2026_06_06_notification_triggers.sql`) — 7 دوال + 6 triggers + إعداد `app_config.fcm` |
| ✅ **مُطبّق على السيرفر** | Migration Payment Channels Config (`2026_06_06_payment_channels.sql`) — `payChannels` (4 قنوات) داخل `app_config.main` |
| ✅ **مُطبّق على السيرفر** | Migration Payment Channel + Storage (`2026_06_06_payment_channel_and_storage.sql`) — `payments.channel` TEXT + bucket `config_assets` (عام) + bucket `payment_proofs` (خاص + RLS) |
| ✅ **مُطبّق على السيرفر** | Migration Points Refinement (`2026_06_06_points_refinement.sql`) — `user_daily_limits` table + `award_points_safe` RPC + Pin duration (2 days) + Rating bonus trigger |
| ✅ **مُطبّق على السيرفر** | Migration Payment Approval (`2026_06_06_payment_approval_logic.sql`) — `approve_payment_final` RPC (auto-upgrade package + set end date) |
| ⚠️ **مكتوب لكن لم يُنشر بعد** | Edge Functions: `send-whatsapp-otp`, `verify-whatsapp-otp` (يحتاج `supabase functions deploy` + secrets META) |
| ⚠️ **معلّق** | تفعيل Email SMTP (Resend) — تم في Dashboard ✅ بس Meta WhatsApp credentials لسا (يستخدم وضع التطوير) |

---

## 📋 قائمة الدوال (33 دالة RPC + 3 Edge Functions)

### دوال RPC (PostgreSQL):

| # | اسم الدالة | المدخلات | المخرج | SECURITY DEFINER |
|---|---|---|---|---|
| **— مصادقة (Auth) —** | | | | |
| 1 | `generate_otp` ⚠️ Legacy | `p_phone TEXT` | `TEXT` | ✅ |
| 2 | `verify_otp` ⚠️ Legacy | `p_phone TEXT, p_code TEXT` | `BOOLEAN` | ✅ |
| 3 | `generate_otp_v2` 🆕 | `p_identifier TEXT, p_channel TEXT` | `TEXT` | ✅ |
| 4 | `verify_otp_v2` 🆕 | `p_identifier TEXT, p_code TEXT` | `BOOLEAN` | ✅ |
| 5 | `upsert_user_after_otp` 🆕 | `p_identifier TEXT, p_channel TEXT` | `TABLE(user_id UUID, is_new BOOLEAN)` | ✅ |
| 6 | `get_user_by_email` 🆕 | `p_email TEXT` | `SETOF users` | ✅ |
| 7 | `get_user_by_phone` | `p_phone TEXT` | `SETOF users` | ✅ |
| 8 | `create_user_from_phone` | `p_phone, p_nm` | `UUID` | ✅ |
| **— مستخدمون ونقاط —** | | | | |
| 9 | `update_user_badge` | `p_uid UUID` | `VOID` | ❌ |
| 10 | `add_points` | `p_uid, p_pts` | `VOID` | ❌ |
| 10.1 | `award_points_safe` 🆕🔔 | `p_uid, p_event_type, p_points` | `JSONB` | ✅ |
| 11 | `register_weekly_login` 🆕🆕 | `p_uid UUID, p_pts INT=500` | `BOOLEAN` | ✅ |
| 12 | `apply_referral` 🆕🆕 | `p_new_uid UUID, p_referrer_code TEXT, p_pts INT=1500` | `BOOLEAN` | ✅ |
| **— عروض —** | | | | |
| 13 | `check_offer_duplicate` | `ttl, prc, loc, usr_id` | `BOOLEAN` | ✅ |
| 14 | `get_pending_offers_count` | — | `INTEGER` | ❌ |
| 15 | `expire_offers` | — | `VOID` | ❌ |
| **— ترقيات العروض (spd) —** | | | | |
| 16 | `purchase_offer_boost` 🆕🆕🆕 | `p_uid UUID, p_offer_id UUID, p_boost_type TEXT, p_cost INT` | `JSONB` | ✅ |
| 17 | `expire_offer_boosts` 🆕🆕🆕 | — | `INTEGER` | ✅ |
| **— إشعارات FCM (E2) —** | | | | |
| 18 | `get_user_device_tokens` 🆕🆕🆕🆕 | `p_uid UUID` | `TABLE(device_token, platform)` | ✅ |
| 19 | `notify_user` 🆕🆕🆕🆕 | `p_uid, p_type, p_title, p_body, p_ref_id?, p_action?` | `UUID` | ✅ |
| **— صفقات ومواعيد —** | | | | |
| 20 | `calculate_commission` | `prc, pct` | `NUMERIC` | ❌ |
| 21 | `send_appointment_reminders` | — | `VOID` | ❌ |
| **— عام —** | | | | |
| 22 | `soft_delete` | `p_table, p_id` | `VOID` | ✅ |
| 23 | `approve_payment_final` 🆕🔔 | `p_payment_id, p_admin_id` | `JSONB` | ✅ |
| **— Triggers Functions (تُستدعى تلقائياً) —** | | | | |
| 24 | `update_user_stats_on_offer` 🆕🆕 | TRIGGER | `TRIGGER` | ✅ |
| 24 | `update_user_stats_on_request` 🆕🆕 | TRIGGER | `TRIGGER` | ✅ |
| 25 | `update_user_stats_on_appointment` 🆕🆕 | TRIGGER | `TRIGGER` | ✅ |
| 26 | `update_user_stats_on_deal` 🆕🆕 | TRIGGER | `TRIGGER` | ✅ |
| **— إشعارات تلقائية (Notification Triggers — E2+) —** | | | | |
| 27 | `send_push_notification` 🆕🔔 | `p_uid, p_title, p_body, p_data?` | `BIGINT` (request_id) | ✅ |
| 28 | `trg_offer_status_changed` 🆕🔔 | TRIGGER على `offers.sts` | `TRIGGER` | ✅ |
| 29 | `trg_appointment_created` 🆕🔔 | TRIGGER INSERT على `appointments` | `TRIGGER` | ✅ |
| 30 | `trg_appointment_status_changed` 🆕🔔 | TRIGGER على `appointments.sts` | `TRIGGER` | ✅ |
| 31 | `trg_deal_completed` 🆕🔔 | TRIGGER على `deals.sts` | `TRIGGER` | ✅ |
| 32 | `trg_payment_approved` 🆕🔔 | TRIGGER على `payments.sts` | `TRIGGER` | ✅ |
| 33 | `trg_offer_published_match_requests` 🆕🔔 | TRIGGER على `offers.i_pub` (1→0) | `TRIGGER` | ✅ |

### 🔗 Triggers Active على الجداول:

| Trigger | الجدول | الحدث | الدالة |
|---|---|---|---|
| `trg_offers_stats` | `offers` | INSERT/UPDATE/DELETE | `update_user_stats_on_offer` |
| `trg_requests_stats` | `requests` | INSERT/UPDATE/DELETE | `update_user_stats_on_request` |
| `trg_appointments_stats` | `appointments` | INSERT/UPDATE/DELETE | `update_user_stats_on_appointment` |
| `trg_deals_stats` | `deals` | INSERT/UPDATE/DELETE | `update_user_stats_on_deal` |
| `trg_offer_status_notify` 🔔 | `offers` | UPDATE `sts` | `trg_offer_status_changed` |
| `trg_offer_match_notify` 🔔 | `offers` | UPDATE `i_pub` | `trg_offer_published_match_requests` |
| `trg_appointment_notify` 🔔 | `appointments` | INSERT | `trg_appointment_created` |
| `trg_appointment_status_notify` 🔔 | `appointments` | UPDATE `sts` | `trg_appointment_status_changed` |
| `trg_deal_notify` 🔔 | `deals` | INSERT/UPDATE `sts` | `trg_deal_completed` |
| `trg_payment_notify` 🔔 | `payments` | UPDATE `sts` | `trg_payment_approved` |

### ⏰ Cron Jobs (pg_cron) النشطة على السيرفر:

| jobid | jobname | schedule | الوصف |
|---|---|---|---|
| 1 | `daily-expire-offers` | `0 3 * * *` (3:00 UTC يومياً) | يستدعي `expire_offers()` لإنهاء العروض المنتهية |
| 2 | `daily-expire-boosts` | `5 3 * * *` (3:05 UTC يومياً) | يستدعي `expire_offer_boosts()` لإلغاء الترقيات المنتهية |
| 3 | `hourly-appointment-reminders` | `0 * * * *` (بداية كل ساعة) | يستدعي `send_appointment_reminders()` للتذكير قبل المواعيد |

**التحقق من حالة الجدولة:**
```sql
SELECT jobname, schedule, active FROM cron.job;
SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;
```

**ملاحظة التوقيت:** السيرفر يستخدم UTC. للتحويل لتوقيت دمشق (UTC+3)، أضف 3 ساعات. مثلاً `0 3 * * *` UTC = 6:00 صباحاً بتوقيت السويداء.

### Edge Functions (Deno):

| # | الاسم | الغرض | المدخل JSON | المخرج JSON | الحالة |
|---|---|---|---|---|---|
| 1 | `send-whatsapp-otp` 🆕 | يولّد OTP ويرسله عبر Meta WhatsApp Cloud API | `{ phone: "+963..." }` | `{ success, messageId?, devMode?, otp? }` | ⚠️ مكتوب — لم يُنشر |
| 2 | `verify-whatsapp-otp` 🆕 | يتحقق + ينشئ user + يصدر session | `{ phone, code }` | `{ success, userId, isNew, session: { token_hash, ... } }` | ⚠️ مكتوب — لم يُنشر |
| 3 | `send-push-notification` 🆕🆕🆕🆕🆕 | يرسل FCM push لكل أجهزة المستخدم (HTTP v1 API) | `{ uid, title, body, data? }` | `{ success, sent, failed, total }` | ⚠️ مكتوب — لم يُنشر |

> ⚠️ **`generate_otp` / `verify_otp` القديمة** ما زالت موجودة للتوافق الخلفي فقط — استخدم النسخة V2 في الكود الجديد.  
> 📖 لخطوات تفعيل WhatsApp + Email Magic Link: راجع `docs/AUTH_SETUP.md`

---

## 🆕🆕 الدوال الجديدة (المرحلة 10) — مفصّلة

### `register_weekly_login(p_uid UUID, p_pts INT DEFAULT 500)` → `BOOLEAN`

تفحص آخر تسجيل دخول للمستخدم في `users.wk_lgn`. إذا مرّ 7 أيام أو أكثر → تمنحه `pts.wkL` (500 نقطة) وتضيف الوقت الحالي للقائمة. تعيد `TRUE` إذا منحت النقاط، `FALSE` إذا لم يحن الموعد.

```sql
SELECT register_weekly_login('uuid-...', 500);
```

```dart
// Flutter (يُستدعى تلقائياً من AuthProvider.registerStreak)
final granted = await client.rpc('register_weekly_login',
  params: {'p_uid': uid, 'p_pts': 500});
```

**الجداول المتأثرة:** `users` (UPDATE `wk_lgn`, `pt`, `ts_upd`) + استدعاء `update_user_badge`.

---

### `apply_referral(p_new_uid UUID, p_referrer_code TEXT, p_pts INT DEFAULT 1500)` → `BOOLEAN`

عند تسجيل مستخدم جديد بكود إحالة (أول 8 أحرف من uid المحيل):
- يربط `users.ref_by` = uid المحيل
- يزيد `users.ref_cnt` للمحيل
- يمنح كلا الطرفين `pts.ref` (1500 نقطة)
- يُحدّث البادج لكليهما

```dart
final ok = await client.rpc('apply_referral', params: {
  'p_new_uid': newUid,
  'p_referrer_code': 'A1B2C3D4',
  'p_pts': 1500,
});
```

**الحماية:**
- يرفض الإحالة الذاتية (p_referrer_code → uid نفسه)
- يرفض الإحالة المكررة (إذا `ref_by` موجود مسبقاً)

---

### `update_user_stats_on_*` — Triggers تلقائية

دوال داخلية تستدعى تلقائياً عند أي INSERT/UPDATE/DELETE على الجداول التالية:

| Trigger | يحدّث |
|---|---|
| `trg_offers_stats` | `users.stats.off` (عدد عروض المستخدم النشطة) |
| `trg_requests_stats` | `users.stats.req` (عدد طلباته) |
| `trg_appointments_stats` | `users.stats.app` (عدد مواعيده) |
| `trg_deals_stats` | `users.stats.dl` (عدد صفقاته كبائع أو مشتري) |

**لا تستدعى يدوياً** — تعمل في الخلفية.

---

## 🆕🆕🆕 دوال ترقيات العروض (المرحلة C — spd) — مفصّلة

### `purchase_offer_boost(p_uid UUID, p_offer_id UUID, p_boost_type TEXT, p_cost INTEGER)` → `JSONB`

شراء ترقية لعرض موجود باستخدام نقاط المستخدم. تتحقق من الملكية + رصيد النقاط ثم تطبّق الترقية وتخصم النقاط وتسجّل في `activity_log`.

**الأنواع المدعومة (`p_boost_type`):**

| النوع | الوصف | المدة | الكلفة من Config |
|---|---|---|---|
| `'ren'` | تجديد العرض (تمديد ts_end + تنشيط من المنتهي) | 30 يوم إضافية | `spd.ren` (500) |
| `'pin'` | تثبيت في الأعلى (`i_pin=1`) | 7 أيام | `spd.pin` (2000) |
| `'bst'` | Boost — وصول أكبر (`i_bst=1`) | 14 يوم | `spd.bst` (4000) |
| `'dsc5'` | خصم 5% على عمولة المكتب (`dsc_pct=5`) | 60 يوم | `spd.dsc5` (3000) |
| `'fms'` | عرض مميّز Featured (`i_fms=1`) | 30 يوم | `spd.fms` (8000) |

**المخرج (JSONB):**

```json
// نجاح
{ "success": true, "result": { "boost_type": "pin", "duration_days": 7 }, "new_balance": 1500 }

// فشل (أمثلة)
{ "success": false, "error": "INSUFFICIENT_POINTS", "current_points": 500, "required": 2000 }
{ "success": false, "error": "OFFER_NOT_FOUND" }
{ "success": false, "error": "NOT_OWNER" }
{ "success": false, "error": "INVALID_BOOST_TYPE" }
```

```dart
// Flutter
final res = await client.rpc('purchase_offer_boost', params: {
  'p_uid': uid,
  'p_offer_id': offerId,
  'p_boost_type': 'pin',
  'p_cost': 2000,
});
if (res['success'] == true) {
  print('New balance: ${res['new_balance']}');
}
```

**الجداول المتأثرة:**
- `offers` (UPDATE: حسب نوع الترقية)
- `users` (UPDATE `pt`)
- `activity_log` (INSERT)

---

### `expire_offer_boosts()` → `INTEGER`

تُلغي تلقائياً جميع الترقيات المنتهية (يرجع عدد الـ pins التي أُلغيت). **مخصصة للـ cron jobs اليومية.**

```sql
SELECT expire_offer_boosts();  -- يرجع: 5 (مثلاً)
```

**ما تفعله:**
- `i_pin=0` و `pin_end=NULL` لكل عرض `pin_end < NOW()`
- نفس الشي لـ `i_bst` و `i_fms`
- `dsc_pct=0` و `dsc_end=NULL` للخصومات المنتهية

**استدعاء يدوي (اختياري):**
```dart
final count = await client.rpc('expire_offer_boosts');
```

---

## 🆕🆕🆕🆕🆕 دوال FCM (المرحلة E2) — مفصّلة

### `get_user_device_tokens(p_uid UUID)` → `TABLE(device_token TEXT, platform TEXT)`

تُرجع كل الـ FCM tokens النشطة (`is_active = TRUE`) لمستخدم معيّن.
**تُستخدم من Edge Function `send-push-notification`** لتحديد الأجهزة المرسل إليها.

```sql
SELECT * FROM get_user_device_tokens('uuid-...');
-- النتيجة:
--   device_token                | platform
--   fNT8z...long-fcm-token      | android
--   eX2P...another-token        | ios
```

**الجدول المتأثر:** `user_devices` (SELECT)

---

### `notify_user(p_uid, p_type, p_title, p_body, p_ref_id?, p_action?)` → `UUID`

تُنشئ سجل إشعار في جدول `notifications` (يظهر داخل التطبيق + يُرسَل عبر Realtime).

**الأنواع (`p_type`):**
| القيمة | الوصف |
|---|---|
| 0 | عروض (offers) |
| 1 | طلبات (requests) |
| 2 | مواعيد (appointments) |
| 3 | مالية (finance) |
| 4 | حساب (account) |
| 5 | تقييم (rating) |

```dart
// مثال: إشعار للمستخدم بقبول عرضه
await client.rpc('notify_user', params: {
  'p_uid': ownerUid,
  'p_type': 0,
  'p_title': 'تمت الموافقة على عرضك ✅',
  'p_body': 'عرض "${offer.ttl}" متاح الآن للجمهور',
  'p_ref_id': offer.id,
  'p_action': 'view_offer',
});
```

**الجدول المتأثر:** `notifications` (INSERT)

**ملاحظة:** لإرسال إشعار **داخل التطبيق + Push notification** معاً، استدعِ:
1. `notify_user(...)` لإنشاء السجل الداخلي
2. `send-push-notification` Edge Function لإرسال الـ Push

(لاحقاً نضيف trigger يستدعيها تلقائياً معاً)

---

## 🆕 دوال المصادقة V2 (واتساب + إيميل)

### `generate_otp_v2(p_identifier TEXT, p_channel TEXT)` → `TEXT`

تولّد OTP موحّد لأي قناة (`whatsapp` / `email` / `sms`). تتضمّن **حد معدّل**: 5 طلبات/10 دقائق لنفس identifier.

```sql
SELECT generate_otp_v2('+963999123456', 'whatsapp');
SELECT generate_otp_v2('user@example.com', 'email');
```

```dart
// عادةً لا تُستدعى مباشرة من Flutter — تُستدعى من داخل Edge Function
final code = await client.rpc('generate_otp_v2',
  params: {'p_identifier': '+963$phone', 'p_channel': 'whatsapp'});
```

**الجدول:** `otp_codes` (INSERT) — يكتب `identifier` و `channel`

> ⚠️ **مهم (إصلاح 2026-06-08):** كان عمود `phone` لا يزال `NOT NULL`، مما يفشل INSERT.
> الحل: شغّل migration `2026_06_08_fix_otp_phone_nullable.sql` الذي يجعل `phone` nullable
> ويُضيف CHECK constraint أن `phone OR identifier` على الأقل موجود.  
**استثناء:** يرمي `Too many OTP requests` لو تجاوز الحد

---

### `verify_otp_v2(p_identifier TEXT, p_code TEXT)` → `BOOLEAN`

تتحقق من الكود، تعلّمه `used=1`، وتحذف الأكواد القديمة (>1 يوم).

```dart
final ok = await client.rpc('verify_otp_v2',
  params: {'p_identifier': '+963$phone', 'p_code': code});
```

---

### `upsert_user_after_otp(p_identifier TEXT, p_channel TEXT)` → `TABLE(user_id UUID, is_new BOOLEAN)`

تُستخدم بعد تأكيد OTP الواتساب. تبحث عن user بـ `ph` (للواتساب) أو `eml` (للإيميل)، وتنشئه لو غير موجود.

```dart
final rows = await client.rpc('upsert_user_after_otp',
  params: {'p_identifier': '+963$phone', 'p_channel': 'whatsapp'});
final row = (rows as List).first;
print('userId: ${row['user_id']}, isNew: ${row['is_new']}');
```

---

### `get_user_by_email(p_email TEXT)` → `SETOF users`

مقابل `get_user_by_phone` لكن للإيميل (العمود `eml`).

---

## 🌐 Edge Functions

### `send-whatsapp-otp`

```bash
curl -X POST 'https://<project>.supabase.co/functions/v1/send-whatsapp-otp' \
  -H "apikey: <anon_key>" -H "Content-Type: application/json" \
  -d '{"phone":"+963912345678"}'
```

**Secrets المطلوبة** (Supabase Dashboard → Edge Functions → Secrets):
- `META_WHATSAPP_TOKEN`
- `META_PHONE_NUMBER_ID`
- `META_OTP_TEMPLATE_NAME` (افتراضي: `otp_login`)
- `META_OTP_TEMPLATE_LANG` (افتراضي: `ar`)

**وضع التطوير:** لو ما كانت الـ secrets موجودة، الدالة ترجع `{ devMode: true, otp: "123456" }` بدل إرسال فعلي.

### `verify-whatsapp-otp`

```bash
curl -X POST 'https://<project>.supabase.co/functions/v1/verify-whatsapp-otp' \
  -H "apikey: <anon_key>" -H "Content-Type: application/json" \
  -d '{"phone":"+963912345678","code":"123456"}'
```

ترجع `session.token_hash` يستخدمه Flutter مع `auth.verifyOTP(type: OtpType.magiclink, tokenHash: ...)` لاستلام session.

---

## 🔐 دوال المصادقة والتحقق (3)

### 1. `generate_otp(p_phone TEXT)` → `TEXT`

تولّد كود OTP عشوائي 6 أرقام وتحفظه في جدول `otp_codes` (ينتهي بعد 5 دقائق).

```sql
-- SQL
SELECT generate_otp('+963999123456');
-- يُرجع: "993744" مثلاً
```

```dart
// Flutter
final otpCode = await client.rpc(
  'generate_otp',
  params: {'p_phone': '+963$phone'},
);
print('🔑 OTP Code: $otpCode');
```

**الجدول المتأثر:** `otp_codes` (INSERT)  
**الأمان:** `SECURITY DEFINER` (يتجاوز RLS)

---

### 2. `verify_otp(p_phone TEXT, p_code TEXT)` → `BOOLEAN`

تتحقق من كود OTP: إذا صحيح → تعلّمه كمستخدم (used=1) → تحذفه → ترجع `true`.

```sql
-- SQL
SELECT verify_otp('+963999123456', '993744');
-- يُرجع: true أو false
```

```dart
// Flutter
final isValid = await client.rpc(
  'verify_otp',
  params: {'p_phone': '+963$phone', 'p_code': code},
);
if (isValid) {
  // OTP صحيح — ادخل المستخدم
}
```

**الجدول المتأثر:** `otp_codes` (UPDATE + DELETE)  
**الأمان:** `SECURITY DEFINER`

---

### 3. `create_user_from_phone(p_phone TEXT, p_nm TEXT DEFAULT '')` → `UUID`

تبحث عن مستخدم بالهاتف:
- إذا موجود → ترجع الـ ID الخاص فيه
- إذا جديد → تنشئه وتعطيه **1000 نقطة** تسجيل أولي

```sql
-- SQL
SELECT create_user_from_phone('+963999123456', 'أحمد');
-- يُرجع: UUID جديد أو موجود
```

```dart
// Flutter
final userId = await client.rpc(
  'create_user_from_phone',
  params: {'p_phone': '+963$phone', 'p_nm': name},
);
// userId = "a1b2c3d4-..."
```

**الجداول المتأثرة:** `users` (SELECT أو INSERT) + `add_points()` (UPDATE pt, bg, bg_ts)  
**الأمان:** `SECURITY DEFINER`

---

## 👤 دوال المستخدمين (2)

### 4. `get_user_by_phone(p_phone TEXT)` → `SETOF users`

تبحث عن مستخدم (أو مستخدمين) بالهاتف — ترجع المستخدم كامل إذا موجود.

```sql
-- SQL
SELECT * FROM get_user_by_phone('+963999123456');
```

```dart
// Flutter
final users = await client.rpc(
  'get_user_by_phone',
  params: {'p_phone': '+963$phone'},
);
// List<Map<String, dynamic>>
```

**الجدول:** `users` (SELECT WHERE ph = ? AND i_del = 0)  
**الأمان:** `SECURITY DEFINER`

---

### 5. `update_user_badge(p_uid UUID)` → `VOID`

تحدّث بادج المستخدم تلقائياً حسب النقاط:

| النقاط | البادج |
|---|---|
| < 10,000 | 🔰 جديد (0) |
| >= 10,000 | 🥉 برونزي (1) |
| >= 20,000 | 🥈 فضي (2) |
| >= 30,000 | 🥇 ذهبي (3) |
| >= 40,000 | 💎 ماسي (4) |

```sql
-- SQL
SELECT update_user_badge('a1b2c3d4-...');
-- يحدّث bg و bg_ts في جدول users
```

```dart
// Flutter
await client.rpc('update_user_badge', params: {'p_uid': userId});
```

**الجدول المتأثر:** `users` (UPDATE bg, bg_ts)  
**ملاحظة:** عادةً تُستدعى عبر `add_points()` — ما تحتاج استدعاءها مباشرة

---

## 🏠 دوال العروض (3)

### 6. `check_offer_duplicate(p_ttl TEXT, p_prc NUMERIC, p_loc JSONB, p_usr_id UUID)` → `BOOLEAN`

تتحقق إذا في عرض بنفس العنوان والسعر (من مستخدم آخر) — يعني مكرر محتمل.

```sql
-- SQL
SELECT check_offer_duplicate('شقة في المزرعة', 500000000, '{"r":0,"d":"المزرعة"}', 'uuid1');
-- يُرجع: true أو false
```

```dart
// Flutter
final isDup = await client.rpc(
  'check_offer_duplicate',
  params: {
    'p_ttl': title,
    'p_prc': price,
    'p_loc': {'r': region, 'd': location},
    'p_usr_id': currentUserId,
  },
);
if (isDup) {
  // عرض مكرر — حذّر المستخدم
}
```

**الجدول:** `offers` (SELECT WHERE ttl = ? AND prc = ? AND i_del = 0 AND usr_id != ?)  
**الأمان:** `SECURITY DEFINER`

---

### 7. `expire_offers()` → `VOID`

تنهي العروض القديمة (أكثر من 30 يوم) تلقائياً — تغير حالتها من `1` أو `2` إلى `4` (منتهي).

```sql
-- SQL
SELECT expire_offers();
-- تُستدعى بـ Scheduled Function كل يوم
```

```dart
// Flutter (يُستدعى يدوياً أو بـ cron)
await client.rpc('expire_offers');
```

**الجدول المتأثر:** `offers` (UPDATE sts=4, ts_end=NOW())  
**الشرط:** `sts IN (1, 2) AND i_del = 0 AND ts_crt < NOW() - INTERVAL '30 days'`

---

### 8. `get_pending_offers_count()` → `INTEGER`

ترجع عدد العروض اللي لسه **قيد المراجعة** (sts = 0) — مفيدة للوحة الإدارة.

```sql
-- SQL
SELECT get_pending_offers_count();
-- يُرجع: 15 مثلاً
```

```dart
// Flutter
final count = await client.rpc('get_pending_offers_count');
print('عروض بانتظار المراجعة: $count');
```

**الجدول:** `offers` (COUNT WHERE sts = 0 AND i_del = 0)

---

## 💰 دوال مالية وإدارية (4)

### 9. `calculate_commission(p_prc NUMERIC, p_pct NUMERIC)` → `NUMERIC`

تحسب العمولة: `السعر × النسبة ÷ 100` (مقربة لمنزلتين عشريتين).

```sql
-- SQL
SELECT calculate_commission(500000000, 3);
-- يُرجع: 15000000.00
```

```dart
// Flutter
final commission = await client.rpc(
  'calculate_commission',
  params: {'p_prc': price, 'p_pct': percentage},
);
```

**ملاحظة:** ما بتعدل أي جدول — مجرد حساب رياضي

---

### 10. `add_points(p_uid UUID, p_pts INTEGER)` → `VOID`

تضيف نقاط للمستخدم + تُحدّث البادج تلقائياً.

```sql
-- SQL
SELECT add_points('a1b2c3d4-...', 500);
-- يزيد pt بـ 500 + يحدّث bg و bg_ts
```

```dart
// Flutter
await client.rpc(
  'add_points',
  params: {'p_uid': userId, 'p_pts': points},
);
```

**الجدول المتأثر:** `users` (UPDATE pt + call update_user_badge)

**نقاط المكافآت (من Config):**

| النشاط | النقاط |
|---|---|
| تسجيل أول حساب | +1000 |
| تسجيل دخول أسبوعي | +500 |
| إضافة عرض | +500 |
| حضور موعد | +300 |
| إتمام صفقة | +2000 |
| إحالة صديق | +1500 |
| Streak يومي | +200 |
| مشاركة اجتماعية | +100 |
| لايك | +5 (حد يومي 10) |
| مشاركة | +10 (حد يومي 5) |
| تعليق | +20 (حد يومي 3) |
| هدية نقاط | حتى 500 (مرة بالأسبوع) |

**نقاط الخصم (من Config):**

| السبب | الخصم |
|---|---|
| عدم الحضور | -500 |
| إلغاء 3 مرات | -300 |
| رفض 3 عروض | -1000 |
| تبليغ خاطئ | -2000 |
| حظر نهائي | -40000 |

---

### 11. `soft_delete(p_table TEXT, p_id UUID)` → `VOID`

حذف ناعم — بدل ما تحذف السجل فعلياً، تحط `i_del = 1`.

```sql
-- SQL
SELECT soft_delete('offers', 'a1b2c3d4-...');
-- يحدّث i_del = 1 في الجدول المحدد
```

```dart
// Flutter
await client.rpc(
  'soft_delete',
  params: {'p_table': 'offers', 'p_id': offerId},
);
```

**الأمان:** `SECURITY DEFINER` (يتجاوز RLS)  
**ملاحظة:** تقبل اسم أي جدول + الـ ID

---

### 12. `send_appointment_reminders()` → `VOID`

ترسل تذكيرات المواعيد القريبة — تُعلّم `rmnd_2` و `rmnd_24`.

```sql
-- SQL
SELECT send_appointment_reminders();
-- تُستدعى بـ Scheduled Function كل ساعة
```

```dart
// Flutter (يُستدعى بـ cron job)
await client.rpc('send_appointment_reminders');
```

**المنطق:**
- تذكير قبل **ساعتين**: `rmnd_2 = 1` إذا `dt <= NOW() + 2h AND dt > NOW() AND rmnd_2 = 0`
- تذكير قبل **24 ساعة**: `rmnd_24 = 1` إذا `dt <= NOW() + 24h AND dt > NOW() AND rmnd_24 = 0`
- ما بتأثر على المواعيد الملغاة قسرياً (`i_force = 1`)

**الجدول المتأثر:** `appointments` (UPDATE rmnd_2, rmnd_24)

---

## 📊 ملخص الجداول المتأثرة

| الجدول | دوال القراءة | دوال الكتابة | Triggers تلقائية |
|---|---|---|---|
| `users` | `get_user_by_phone`, `get_user_by_email` 🆕 | `create_user_from_phone`, `upsert_user_after_otp` 🆕, `update_user_badge`, `add_points`, `register_weekly_login` 🆕🆕, `apply_referral` 🆕🆕, `purchase_offer_boost` 🆕🆕🆕 (يخصم pt) | — (يُحدَّث `stats` عبر triggers على جداول أخرى) |
| `offers` | `check_offer_duplicate`, `get_pending_offers_count` | `expire_offers`, `purchase_offer_boost` 🆕🆕🆕, `expire_offer_boosts` 🆕🆕🆕 | `trg_offers_stats` 🆕🆕 → `users.stats.off` |
| `activity_log` | — | `purchase_offer_boost` 🆕🆕🆕 (يسجّل كل عملية شراء) | — |
| `user_devices` | `get_user_device_tokens` 🆕🆕🆕🆕 | (يُكتب من Flutter `FCMService.setup()`) | — |
| `notifications` | — | `notify_user` 🆕🆕🆕🆕 (INSERT) | — |
| `requests` | — | — | `trg_requests_stats` 🆕🆕 → `users.stats.req` |
| `appointments` | — | `send_appointment_reminders` | `trg_appointments_stats` 🆕🆕 → `users.stats.app` |
| `deals` | — | — | `trg_deals_stats` 🆕🆕 → `users.stats.dl` |
| `otp_codes` | `verify_otp`, `verify_otp_v2` 🆕 | `generate_otp`, `verify_otp`, `generate_otp_v2` 🆕, `verify_otp_v2` 🆕 | — |

---

## 🔒 ملخص الأمان

| الدالة | SECURITY DEFINER | تتجاوز RLS |
|---|---|---|
| `generate_otp` | ✅ | ✅ |
| `verify_otp` | ✅ | ✅ |
| `generate_otp_v2` 🆕 | ✅ | ✅ |
| `verify_otp_v2` 🆕 | ✅ | ✅ |
| `upsert_user_after_otp` 🆕 | ✅ | ✅ |
| `get_user_by_email` 🆕 | ✅ | ✅ |
| `get_user_by_phone` | ✅ | ✅ |
| `check_offer_duplicate` | ✅ | ✅ |
| `soft_delete` | ✅ | ✅ |
| `create_user_from_phone` | ✅ | ✅ |
| `register_weekly_login` 🆕🆕 | ✅ | ✅ |
| `apply_referral` 🆕🆕 | ✅ | ✅ |
| `purchase_offer_boost` 🆕🆕🆕 | ✅ | ✅ |
| `expire_offer_boosts` 🆕🆕🆕 | ✅ | ✅ |
| `get_user_device_tokens` 🆕🆕🆕🆕 | ✅ | ✅ |
| `notify_user` 🆕🆕🆕🆕 | ✅ | ✅ |
| `update_user_stats_on_offer` 🆕🆕 | ✅ | ✅ |
| `update_user_stats_on_request` 🆕🆕 | ✅ | ✅ |
| `update_user_stats_on_appointment` 🆕🆕 | ✅ | ✅ |
| `update_user_stats_on_deal` 🆕🆕 | ✅ | ✅ |
| `send_push_notification` 🆕🔔 | ✅ | ✅ |
| `trg_offer_status_changed` 🆕🔔 | ✅ | ✅ |
| `trg_appointment_created` 🆕🔔 | ✅ | ✅ |
| `trg_appointment_status_changed` 🆕🔔 | ✅ | ✅ |
| `trg_deal_completed` 🆕🔔 | ✅ | ✅ |
| `trg_payment_approved` 🆕🔔 | ✅ | ✅ |
| `trg_offer_published_match_requests` 🆕🔔 | ✅ | ✅ |
| `calculate_commission` | ❌ | ❌ |
| `update_user_badge` | ❌ | ❌ |
| `get_pending_offers_count` | ❌ | ❌ |
| `add_points` | ❌ | ❌ |
| `expire_offers` | ❌ | ❌ |
| `send_appointment_reminders` | ❌ | ❌ |

---

## 📁 الملفات المرتبطة

| الملف | المحتوى |
|---|---|
| `supabase/setup.sql` | الكود الكامل (مصدر الحقيقة) |
| `supabase/migrations/2026_06_05_whatsapp_email_auth.sql` 🆕 | Migration #1: V2 RPCs + `eml` + `otp_codes` channel — **مطبّق ✅** |
| `supabase/migrations/2026_06_05_stats_triggers_and_wkLogin.sql` 🆕🆕 | Migration #2: 4 triggers + `register_weekly_login` + `apply_referral` + `ref_by`/`ref_cnt` — **مطبّق ✅** |
| `supabase/migrations/2026_06_05_offer_boosts.sql` 🆕🆕🆕 | Migration #3: `purchase_offer_boost` + `expire_offer_boosts` + 8 أعمدة ترقيات — **مطبّق ✅** |
| `supabase/migrations/2026_06_05_cron_jobs.sql` 🆕🆕🆕🆕 | Migration #4: جدولة 3 cron jobs (expire_offers + expire_boosts + reminders) — **مطبّق ✅** |
| `supabase/migrations/2026_06_05_fcm_setup.sql` 🆕🆕🆕🆕🆕 | Migration #5: UNIQUE token + `get_user_device_tokens` + `notify_user` — **مطبّق ✅** |
| `supabase/migrations/2026_06_06_notification_triggers.sql` 🔔 | Migration #6: 7 دوال + 6 triggers لربط الإشعارات بالأحداث — **مطبّق ✅** |
| `supabase/migrations/2026_06_06_payment_channels.sql` 💳 | Migration #7: `payChannels` (4 قنوات) داخل `app_config.main` — **مطبّق ✅** |
| `supabase/migrations/2026_06_06_payment_channel_and_storage.sql` 💳📁 | Migration #8: `payments.channel` TEXT + bucket `config_assets` + bucket `payment_proofs` + RLS — **جاهز للتطبيق** |
| `supabase/functions/send-push-notification/index.ts` 🆕🆕🆕🆕🆕 | Edge Function لإرسال FCM Push عبر Service Account |
| `lib/services/fcm_service.dart` 🆕🆕🆕🆕🆕 | خدمة FCM Flutter (تهيئة + token + معالجات الإشعارات) |
| `lib/screens/user/boost_offer_screen.dart` 🆕🆕🆕 | شاشة شراء ترقيات العروض (5 خيارات: ren/pin/bst/dsc5/fms) |
| `supabase/functions/send-whatsapp-otp/index.ts` 🆕 | Edge Function لإرسال OTP عبر Meta WhatsApp — **لم يُنشر ⚠️** |
| `supabase/functions/verify-whatsapp-otp/index.ts` 🆕 | Edge Function للتحقق وإصدار session — **لم يُنشر ⚠️** |
| `supabase/SERVER_DOCS.md` | توثيق الجداول + RLS + Realtime |
| `lib/core/constants/db_constants.dart` | أسماء الدوال كـ constants |
| `lib/services/auth_service.dart` | استخدام WhatsApp OTP + Email Magic Link (الـ V2) |
| `lib/screens/auth/login_screen.dart` | شاشة تسجيل الدخول بتبويبتين (واتساب/إيميل) |
| `lib/screens/auth/setup_profile_screen.dart` 🆕🆕 | إكمال الملف + رفع صورة الهوية + الإقرار والتعهد |
| `lib/screens/user/packages_screen.dart` 🆕 | شاشة عرض الباقات (تقرأ `app_config.pkg`) |
| `lib/screens/user/payment_screen.dart` 🆕 | شاشة دفع الاشتراك (تكتب في `payments` بـ `tp=0`) |
| `lib/screens/user/edit_offer_screen.dart` 🆕 | تعديل العرض (تستخدم `OfferProvider.updateOffer`/`softDeleteOffer`) |
| `lib/screens/user/become_broker_screen.dart` 🆕 | طلب وساطة (تحدّث `brk_nm`/`brk_cls` + log في `activity_log`) |
| `lib/screens/user/request_detail_screen.dart` 🆕 | تفاصيل الطلب + `BusinessService.matchOffersForRequest` |
| `lib/screens/user/add_offer_screen.dart` 🆕🆕 | إضافة عرض + Step 4 (سند الملكية + إقرار) |
| `lib/screens/user/referral_screen.dart` 🆕🆕 | شاشة الإحالة + كود + رابط + مشاركة |
| `lib/screens/visitor/offer_detail_screen.dart` 🆕🆕 | تفاصيل العرض + زر التبليغ (`_reportOffer`) |
| `docs/AUTH_SETUP.md` 🆕 | **دليل تفعيل المصادقة الكامل** (Meta + Supabase Email + Deploy) |
| `docs/SCREENS_AUDIT.md` 🆕 | تدقيق شامل لحالة جميع الشاشات (37 شاشة) |
| `docs/FEATURES_AUDIT.md` 🆕🆕 | تدقيق مزايا المواصفات الأصلية + خطة التنفيذ |
| `DEVELOPMENT_GUIDE.md` | دليل التطوير الشامل |
