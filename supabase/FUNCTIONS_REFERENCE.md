# 📚 مرجع دوال Supabase (RPC + Edge Functions)

> **مشروع:** عقارات السويداء  
> **آخر تحديث:** 2026-06-05  
> **المصدر:** `supabase/setup.sql` + `supabase/migrations/2026_06_05_whatsapp_email_auth.sql`

---

## 📋 قائمة الدوال (16 دالة RPC + 2 Edge Functions)

### دوال RPC (PostgreSQL):

| # | اسم الدالة | المدخلات | المخرج | SECURITY DEFINER |
|---|---|---|---|---|
| 1 | `generate_otp` ⚠️ Legacy | `p_phone TEXT` | `TEXT` | ✅ |
| 2 | `verify_otp` ⚠️ Legacy | `p_phone TEXT, p_code TEXT` | `BOOLEAN` | ✅ |
| 3 | **`generate_otp_v2`** 🆕 | `p_identifier TEXT, p_channel TEXT` | `TEXT` | ✅ |
| 4 | **`verify_otp_v2`** 🆕 | `p_identifier TEXT, p_code TEXT` | `BOOLEAN` | ✅ |
| 5 | **`upsert_user_after_otp`** 🆕 | `p_identifier TEXT, p_channel TEXT` | `TABLE(user_id UUID, is_new BOOLEAN)` | ✅ |
| 6 | **`get_user_by_email`** 🆕 | `p_email TEXT` | `SETOF users` | ✅ |
| 7 | `get_user_by_phone` | `p_phone TEXT` | `SETOF users` | ✅ |
| 8 | `check_offer_duplicate` | `ttl, prc, loc, usr_id` | `BOOLEAN` | ✅ |
| 9 | `calculate_commission` | `prc, pct` | `NUMERIC` | ❌ |
| 10 | `update_user_badge` | `p_uid UUID` | `VOID` | ❌ |
| 11 | `get_pending_offers_count` | — | `INTEGER` | ❌ |
| 12 | `add_points` | `p_uid, p_pts` | `VOID` | ❌ |
| 13 | `soft_delete` | `p_table, p_id` | `VOID` | ✅ |
| 14 | `expire_offers` | — | `VOID` | ❌ |
| 15 | `send_appointment_reminders` | — | `VOID` | ❌ |
| 16 | `create_user_from_phone` | `p_phone, p_nm` | `UUID` | ✅ |

### Edge Functions (Deno):

| # | الاسم | الغرض | المدخل JSON | المخرج JSON |
|---|---|---|---|---|
| 1 | **`send-whatsapp-otp`** 🆕 | يولّد OTP ويرسله عبر Meta WhatsApp Cloud API | `{ phone: "+963..." }` | `{ success, messageId? , devMode?, otp? }` |
| 2 | **`verify-whatsapp-otp`** 🆕 | يتحقق + ينشئ user + يصدر session | `{ phone, code }` | `{ success, userId, isNew, session: { token_hash, ... } }` |

> ⚠️ **`generate_otp` / `verify_otp` القديمة** ما زالت موجودة للتوافق الخلفي فقط — استخدم النسخة V2 في الكود الجديد.  
> 📖 لخطوات تفعيل WhatsApp + Email Magic Link: راجع `docs/AUTH_SETUP.md`

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

| الجدول | دوال القراءة | دوال الكتابة |
|---|---|---|
| `users` | `get_user_by_phone`, `get_user_by_email` 🆕 | `create_user_from_phone`, `upsert_user_after_otp` 🆕, `update_user_badge`, `add_points` |
| `offers` | `check_offer_duplicate`, `get_pending_offers_count` | `expire_offers` |
| `appointments` | — | `send_appointment_reminders` |
| `otp_codes` | `verify_otp`, `verify_otp_v2` 🆕 | `generate_otp`, `verify_otp`, `generate_otp_v2` 🆕, `verify_otp_v2` 🆕 |

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
| `supabase/migrations/2026_06_05_whatsapp_email_auth.sql` 🆕 | Migration: V2 RPCs + `eml` + `otp_codes` channel |
| `supabase/functions/send-whatsapp-otp/index.ts` 🆕 | Edge Function لإرسال OTP عبر Meta WhatsApp |
| `supabase/functions/verify-whatsapp-otp/index.ts` 🆕 | Edge Function للتحقق وإصدار session |
| `supabase/SERVER_DOCS.md` | توثيق الجداول + RLS + Realtime |
| `lib/core/constants/db_constants.dart` | أسماء الدوال كـ constants |
| `lib/services/auth_service.dart` | استخدام WhatsApp OTP + Email Magic Link (الـ V2) |
| `lib/screens/auth/login_screen.dart` | شاشة تسجيل الدخول بتبويبتين (واتساب/إيميل) |
| `lib/screens/user/packages_screen.dart` 🆕 | شاشة عرض الباقات (تقرأ `app_config.pkg`) |
| `lib/screens/user/payment_screen.dart` 🆕 | شاشة دفع الاشتراك (تكتب في `payments` بـ `tp=0`) |
| `lib/screens/user/edit_offer_screen.dart` 🆕 | تعديل العرض (تستخدم `OfferProvider.updateOffer`/`softDeleteOffer`) |
| `lib/screens/user/become_broker_screen.dart` 🆕 | طلب وساطة (تحدّث `brk_nm`/`brk_cls` + log في `activity_log`) |
| `lib/screens/user/request_detail_screen.dart` 🆕 | تفاصيل الطلب + `BusinessService.matchOffersForRequest` |
| `docs/AUTH_SETUP.md` 🆕 | **دليل تفعيل المصادقة الكامل** (Meta + Supabase Email + Deploy) |
| `docs/SCREENS_AUDIT.md` 🆕 | تدقيق شامل لحالة جميع الشاشات (37 شاشة) |
| `DEVELOPMENT_GUIDE.md` | دليل التطوير الشامل |
