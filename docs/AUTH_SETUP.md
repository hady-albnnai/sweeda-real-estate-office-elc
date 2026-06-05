# 🔐 دليل إعداد المصادقة (WhatsApp OTP + Email Magic Link)

> هذا الدليل يشرح كل الخطوات اللازمة لتفعيل تسجيل الدخول عبر **واتساب** (Meta WhatsApp Cloud API) و **الإيميل** (Supabase Magic Link).

---

## 🎯 ما تم بناؤه

### من جهة Flutter
- ✅ شاشة تسجيل دخول بـ **تبويبتين** (واتساب / إيميل) — `lib/screens/auth/login_screen.dart`
- ✅ شاشة OTP لرمز الواتساب — `lib/screens/auth/otp_verification_screen.dart`
- ✅ شاشة "تحقّق من بريدك" بعد إرسال Magic Link — `lib/screens/auth/check_email_screen.dart`
- ✅ `AuthService` يدعم WhatsApp + Email — `lib/services/auth_service.dart`
- ✅ `AuthProvider` محدّث — `lib/providers/auth_provider.dart`
- ✅ Deep Link handler في `app.dart` يلتقط جلسة الإيميل تلقائياً
- ✅ إعدادات Android Manifest و iOS Info.plist لـ scheme `io.supabase.sweeda://login-callback`

### من جهة Supabase
- ✅ Migration SQL: `supabase/migrations/2026_06_05_whatsapp_email_auth.sql`
  - عمود `eml` في `users`
  - توسعة `otp_codes` (channel + identifier)
  - دوال: `generate_otp_v2`, `verify_otp_v2`, `upsert_user_after_otp`, `get_user_by_email`
- ✅ Edge Functions:
  - `supabase/functions/send-whatsapp-otp/index.ts` — يولّد OTP ويرسله عبر Meta WhatsApp Cloud API
  - `supabase/functions/verify-whatsapp-otp/index.ts` — يتحقق ويعيد session

---

## 🚀 خطوات التفعيل (مرة واحدة)

### 1️⃣ تطبيق الـ SQL Migration

في **Supabase Dashboard → SQL Editor**، انسخ والصق محتوى:
```
supabase/migrations/2026_06_05_whatsapp_email_auth.sql
```
واضغط **Run**.

تحقق من نجاح الإنشاء:
```sql
SELECT proname FROM pg_proc WHERE proname IN
  ('generate_otp_v2','verify_otp_v2','upsert_user_after_otp','get_user_by_email');
-- يجب أن تظهر 4 صفوف
```

---

### 2️⃣ إعداد Supabase Email Auth (Magic Link)

في **Supabase Dashboard → Authentication → Providers → Email**:
1. فعّل **Enable Email Provider**
2. فعّل **Enable Email Confirmations** (موصى به)
3. (اختياري) عطّل **Confirm email change** لو ما بدك خطوة إضافية

في **Authentication → URL Configuration**:
- **Site URL:** `io.supabase.sweeda://login-callback`
- **Redirect URLs (Allow list):** أضف:
  ```
  io.supabase.sweeda://login-callback
  io.supabase.sweeda://**
  ```

في **Authentication → Email Templates → Magic Link**:
- عدّل الرسالة لتكون بالعربية (اختياري)
- تأكد أن الرابط يستخدم `{{ .ConfirmationURL }}`

> 📨 **تنبيه:** Supabase المجاني محدود بـ 3 إيميلات/ساعة من المرسل الافتراضي. للإنتاج، اربط **SMTP** خاص (Resend / SendGrid / Mailgun) من **Authentication → SMTP Settings**.

---

### 3️⃣ إعداد Meta WhatsApp Cloud API (مجاني)

#### أ) إنشاء حساب Meta Business
1. روح على https://business.facebook.com وأنشئ حساب
2. روح على https://developers.facebook.com/apps → **Create App** → اختر **Business**
3. أضف منتج **WhatsApp** للتطبيق

#### ب) الحصول على بيانات الاعتماد
من **WhatsApp → API Setup** ستجد:
- **Phone Number ID** → احفظه (هاد `META_PHONE_NUMBER_ID`)
- **Temporary Access Token** (24 ساعة فقط — للتجربة)

للحصول على **Token دائم**:
1. **Business Settings → System Users → Add** → User جديد بصلاحية Admin
2. اضغط **Generate New Token** → اختر تطبيقك → فعّل صلاحيتي:
   - `whatsapp_business_messaging`
   - `whatsapp_business_management`
3. احفظ الـ Token (هاد `META_WHATSAPP_TOKEN`)

#### ج) إنشاء قالب رسالة OTP
في **WhatsApp → Message Templates → Create Template**:
- **Category:** Authentication
- **Name:** `otp_login`
- **Language:** Arabic (`ar`)
- **Body:** `{{1}} هو رمز التحقق الخاص بك. لا تشاركه مع أحد.`
- **Buttons:** اختر "Copy code" → سيستخدم نفس `{{1}}`

> ⚠️ يحتاج موافقة من Meta (عادة دقائق إلى ساعات).
> اسم القالب ولغته يجب أن يطابقا قيم env: `META_OTP_TEMPLATE_NAME` و `META_OTP_TEMPLATE_LANG`.

#### د) إضافة Display Name و Phone Number
- أضف اسم العرض من **WhatsApp → Phone Numbers → Add**
- (مجاناً) تحصل على رقم تجريبي من Meta لإرسال الرسائل، أو أربط رقم خاص بك

---

### 4️⃣ نشر Edge Functions على Supabase

```bash
# تثبيت Supabase CLI
npm i -g supabase

# ربط المشروع
supabase login
supabase link --project-ref vsgkgnjtebjxyqwpuopz

# ضبط الأسرار (env vars)
supabase secrets set META_WHATSAPP_TOKEN="EAAxxx...your-permanent-token"
supabase secrets set META_PHONE_NUMBER_ID="1234567890"
supabase secrets set META_OTP_TEMPLATE_NAME="otp_login"
supabase secrets set META_OTP_TEMPLATE_LANG="ar"

# نشر الدوال
supabase functions deploy send-whatsapp-otp --no-verify-jwt
supabase functions deploy verify-whatsapp-otp --no-verify-jwt
```

> `--no-verify-jwt` ضروري لأن المستخدم يستدعي الدالة قبل ما يكون عنده session.

#### اختبار الدوال يدوياً:
```bash
curl -X POST 'https://vsgkgnjtebjxyqwpuopz.supabase.co/functions/v1/send-whatsapp-otp' \
  -H "Content-Type: application/json" \
  -H "apikey: <your-anon-key>" \
  -d '{"phone":"+963912345678"}'
```

---

### 5️⃣ بناء التطبيق وتجربته

```bash
flutter pub get
flutter run
```

#### سيناريو الواتساب:
1. اختر تبويبة "واتساب"
2. أدخل الرقم (مثلاً `0912345678`)
3. اضغط "إرسال عبر واتساب"
4. ستصلك رسالة واتساب فيها رمز 6 أرقام
5. أدخل الرمز وتدخل التطبيق

#### سيناريو الإيميل:
1. اختر تبويبة "إيميل"
2. أدخل بريدك
3. اضغط "إرسال الرابط السحري"
4. شيك إيميلك واضغط الرابط
5. سيُفتح التطبيق تلقائياً وتسجّل دخولك

---

## 🧪 وضع التطوير (بدون Meta)

لو ما حضّرت Meta WhatsApp بعد، النظام يشتغل بـ **وضع التطوير**:
- الـ Edge Function إذا ما لاقت `META_WHATSAPP_TOKEN`، ترجّع الـ OTP بـ response مباشرة
- التطبيق يعرض الـ OTP في شاشة OTP داخل صندوق برتقالي
- بقدر تكمل تسجيل الدخول مباشرة بدون رسالة واتساب فعلية

هذا مفيد للتجربة الأولى. لما تجهّز Meta، فقط ضع الـ secrets وانشر، ويصير الإرسال فعلي تلقائياً.

---

## 📋 Checklist سريع

- [ ] طبّق SQL migration
- [ ] فعّل Email Provider في Supabase + أضف Redirect URLs
- [ ] أنشئ Meta Business + Permanent Token + Phone Number ID
- [ ] أنشئ قالب `otp_login` بالعربية واطلب موافقة
- [ ] ضع secrets ونشر Edge Functions
- [ ] جرّب الـ flow الكامل من التطبيق

---

## 🆘 استكشاف الأخطاء

| المشكلة | الحل |
|---|---|
| `WHATSAPP_SEND_FAILED` | تأكد من Token + Phone Number ID + موافقة القالب |
| Magic Link ما بيفتح التطبيق | تأكد من scheme بـ Manifest/Info.plist + Redirect URLs بـ Supabase |
| `Too many OTP requests` | حدّ أمان (5 محاولات/10 دقائق) — انتظر |
| لا يصل إيميل | الـ free SMTP محدود — اربط SMTP خاص |
| OTP بظهر بصندوق برتقالي | وضع تطوير — حضّر secrets الـ Meta وانشر الدالة |

---

## 🔒 ملاحظات أمنية

- حد المحاولات: 5 OTP/10 دقائق لنفس identifier (مضمّن بالـ RPC)
- صلاحية الكود: 5 دقائق
- الـ Edge Functions تستخدم `service_role` داخلياً (لا تُسرّب)
- المستخدم الجديد ينُشأ بحقول فاضية → يكمل ملفه الشخصي في `/setup-profile`
