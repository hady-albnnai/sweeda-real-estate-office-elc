# 📱 خطة تفعيل WhatsApp OTP الفعلي

> **الحالة:** ⏸️ مؤجّلة بناءً على قرار 2026-06-05
> **السبب:** المالك يفضّل تأسيس صفحة Facebook **خارج سوريا** للاستفادة من ميزات الإعلان والربح من Meta
> **الوضع الحالي للتطبيق:** يستخدم **وضع التطوير (Dev Mode)** — OTP يظهر بصندوق برتقالي

---

## 🔴 ملخص الواقع (مهم لفهم الخلفية)

### الحقائق المكتشفة بعد البحث المعمّق:

| البند | الحقيقة |
|---|---|
| ❌ **رقم سوري (+963) كرقم Sender** | محظور من Meta WhatsApp Business API ([1](https://respond.io/help/whatsapp/whatsapp-api-quick-start)) |
| ❌ **Infobip / Twilio / Vonage / MessageBird** | كل المزوّدين الكبار يستثنون سوريا من self-signup |
| ✅ **الإرسال إلى أرقام سورية (Outbound)** | متاح ومسموح |
| ✅ **رقم Meta 555 الافتراضي** | متاح مجاناً من Meta أثناء التسجيل |

### الحلول المستبعدة (بعد البحث):
- ❌ Twilio/Vonage SMS — سوريا محظورة
- ❌ Infobip — سوريا في قائمة الاستثناءات
- ❌ تسجيل رقم سوري بـ WhatsApp Business — محظور رسمياً
- ❌ Brevo SMS — التسجيل يتطلب SMS verification وما يصل لسوريا

### الحلول الموصى بها:
- ✅ **رقم Meta 555 المجاني** (الخطة الرئيسية)
- ✅ **Email OTP** (شغّال حالياً — Magic Link)
- 🟡 **Telegram Bot OTP** (احتياطي إن فشل Meta)

---

## 📊 معلومات Meta WhatsApp Cloud API (موثّقة من المصادر الرسمية 2026)

### حدود الإرسال (Messaging Tiers) — حسب [توثيق Meta الرسمي](https://developers.facebook.com/documentation/business-messaging/whatsapp/messaging-limits)

| Tier | الحد اليومي | المتطلبات |
|---|---|---|
| **Tier 0 (Unverified)** | **250 مستخدم فريد / 24 ساعة** | افتراضي عند إنشاء حساب جديد — بدون توثيق |
| **Tier 1** | 1,000 / 24 ساعة | بعد Business Verification أو رفع تلقائي بعد 150 رسالة جودة |
| **Tier 2** | 2,000 / 24 ساعة | تلقائي بعد ثبات الجودة |
| **Tier 3** | 10,000 / 24 ساعة | استمرارية + جودة Green |
| **Tier 4** | 100,000 / 24 ساعة | علامات تجارية مستقرة |
| **Tier 5** | Unlimited | Enterprise |

**ملاحظات مهمة:**
- 🔄 الحد **يتجدد كل 24 ساعة** (rolling window — مش بداية اليوم)
- 👤 **مستخدم فريد** = نفس الرقم لو بعتلو 10 رسائل بنفس اليوم = يُحسب 1
- 🔗 **مشترك على مستوى Business Portfolio** (مش رقم واحد)
- 📈 **التقييم كل 6 ساعات** (Meta يفحص الجودة ويرفع الـ tier تلقائياً)

### التسعير (Authentication Templates):
- 🆓 **أول 250 محادثة authentication مجاناً شهرياً** (خاصة بالحسابات الجديدة)
- 💰 بعد 250: ~$0.005 لكل authentication message (يختلف حسب الدولة)
- 💰 سوريا (+963): ~$0.0125/رسالة (متوسط منطقة الشرق الأوسط)
- 📊 **حساب تقديري:** 1000 OTP/شهر = ~$5

---

## 🎯 خطة التفعيل (5 مراحل) — للتنفيذ مستقبلاً

### المرحلة 1️⃣: إنشاء صفحة Facebook من خارج سوريا
**الهدف:** الحصول على صفحة موثوقة تفتح Meta Business Manager.

**الخطوات:**
1. السفر/الاستعانة بشخص خارج سوريا (تركيا/الإمارات/مصر/أي بلد)
2. إنشاء حساب Facebook جديد بـ:
   - رقم هاتف من الدولة الخارجية (مهم لتفعيل ميزات الإعلان)
   - بريد إلكتروني مخصص (يفضّل بدومين خاص لاحقاً مثل `info@sweeda-realestate.com`)
3. إنشاء صفحة:
   - **Name:** عقارات السويداء (Sweeda Real Estate)
   - **Category:** Real Estate Agent
   - **Country:** الدولة اللي تم التسجيل منها
4. ملء الصفحة:
   - Logo: `assets/images/logo_app.png`
   - Cover image
   - About: المكتب العقاري الإلكتروني — السويداء، سوريا
   - معلومات تواصل
5. (موصى به) نشر 3-5 منشورات أولية لجعلها تبدو نشطة

**التكلفة:** مجاني بالكامل

**المدة:** 1-2 ساعة

---

### المرحلة 2️⃣: إنشاء Meta Business Account
**الهدف:** ربط الصفحة بحساب أعمال يدير WhatsApp API.

**الخطوات:**
1. روح على: https://business.facebook.com
2. أنشئ Business Account جديد:
   - **Business Name:** Sweeda Real Estate
   - **Business Email:** نفس إيميل الصفحة
3. أضف الصفحة المُنشأة في المرحلة 1 (Pages → Add → existing page)
4. (اختياري) Business Verification:
   - يحتاج وثائق رسمية (سجل تجاري + إيميل بدومين)
   - **مش لازم للبداية** — 250 رسالة/يوم كافية للتجربة

**التكلفة:** مجاني

**المدة:** 30 دقيقة

---

### المرحلة 3️⃣: إعداد WhatsApp Cloud API + الحصول على رقم Meta 555
**الهدف:** الحصول على Phone Number ID + Access Token + رقم 555 المجاني.

**الخطوات:**
1. روح على: https://developers.facebook.com/apps
2. اضغط **Create App** → اختر **Business** type
3. أضف **WhatsApp** product للتطبيق
4. في **WhatsApp → API Setup:**
   - اختر **"Use a display name only"** للحصول على رقم Meta 555 المجاني
   - أو ربط رقم WhatsApp شخصي خارج سوريا (إن توفر)
5. احفظ:
   - **`Phone Number ID`** (مثل: `123456789012345`)
   - **`WhatsApp Business Account ID`**

**التكلفة:** مجاني (رقم 555 مجاني)

**المدة:** 15 دقيقة

---

### المرحلة 4️⃣: إنشاء Permanent Access Token
**الهدف:** الحصول على token دائم بدل المؤقت (24 ساعة).

**الخطوات:**
1. في Meta Business Manager: **Business Settings → System Users → Add**
2. أنشئ system user جديد:
   - **Name:** sweeda-api-system-user
   - **Role:** Admin
3. اضغط **Generate Token** → اختر تطبيقك → فعّل صلاحيتين:
   - `whatsapp_business_messaging`
   - `whatsapp_business_management`
4. اختر **Token Expiration: Never**
5. **احفظ الـ Token فوراً** (يظهر مرة واحدة) — يبدأ بـ `EAAxxx...`

**التكلفة:** مجاني

**المدة:** 10 دقائق

---

### المرحلة 5️⃣: إنشاء Authentication Template + نشر Edge Functions
**الهدف:** تجهيز قالب OTP رسمي + ربط Supabase Edge Functions.

#### أ) إنشاء قالب الـ OTP:

في **WhatsApp Manager → Message Templates → Create Template:**

| الحقل | القيمة |
|---|---|
| **Category** | Authentication |
| **Name** | `otp_login` |
| **Language** | Arabic (`ar`) |
| **Body** | `{{1}} هو رمز التحقق الخاص بك. لا تشاركه مع أحد.` |
| **Buttons** | Copy code (يستخدم `{{1}}` نفسها) |

⏱️ موافقة Meta: عادة 1-24 ساعة

#### ب) نشر Edge Functions على Supabase:

```bash
# تثبيت Supabase CLI (مرة واحدة)
npm i -g supabase

# تسجيل دخول وربط
supabase login
supabase link --project-ref vsgkgnjtebjxyqwpuopz

# ضبط الأسرار من Meta
supabase secrets set META_WHATSAPP_TOKEN="EAAxxx...your-permanent-token"
supabase secrets set META_PHONE_NUMBER_ID="123456789012345"
supabase secrets set META_OTP_TEMPLATE_NAME="otp_login"
supabase secrets set META_OTP_TEMPLATE_LANG="ar"

# نشر الدالتين
supabase functions deploy send-whatsapp-otp --no-verify-jwt
supabase functions deploy verify-whatsapp-otp --no-verify-jwt
```

**التكلفة:** مجاني (Supabase Edge Functions ضمن الـ free tier)

**المدة:** 20 دقيقة

---

## ✅ الاختبار النهائي بعد التفعيل

### من التطبيق:
1. افتح شاشة Login → تبويبة "واتساب"
2. أدخل رقم سوري حقيقي (مثلاً رقمك)
3. اضغط "إرسال عبر واتساب"
4. **المتوقّع:** يصلك واتساب من "+1 555 xxx" أو "عقارات السويداء" فيه الكود
5. أدخل الكود → دخول ناجح ✅
6. **الفرق عن وضع التطوير:** لن يظهر الصندوق البرتقالي للـ OTP

### من السيرفر (للتحقق):
```bash
# Logs الـ Edge Function
supabase functions logs send-whatsapp-otp --tail
```

---

## 🔄 الحالة الحالية (Dev Mode — شغّال 100%)

طالما المراحل أعلاه مؤجّلة، التطبيق يعمل بـ **Dev Mode**:

| المكوّن | الحالة |
|---|---|
| ✅ SQL Functions (`generate_otp_v2`, `verify_otp_v2`, إلخ) | مُطبّق على السيرفر |
| ✅ شاشة Login (تبويبتين واتساب/إيميل) | شغّال |
| ✅ تسجيل دخول واتساب — RPC Fallback | شغّال (OTP يظهر بصندوق برتقالي) |
| ✅ تسجيل دخول إيميل (Magic Link) | شغّال عبر Resend SMTP |
| ⏸️ Edge Function `send-whatsapp-otp` | مكتوب لكن غير منشور |
| ⏸️ Edge Function `verify-whatsapp-otp` | مكتوب لكن غير منشور |
| ⏸️ Meta Business + رقم 555 | لم يُنشأ بعد |

---

## 🎯 خطة الـ Plan B (إذا فشل Meta نهائياً)

في حال صار في عقبات لا يمكن تجاوزها مع Meta، الخطة البديلة جاهزة:

### استبدال Magic Link بـ Email OTP بـ 6 أرقام:
- **التغيير الوحيد:** تعديل `AuthService.sendEmailMagicLink` لاستخدام `generate_otp_v2` بقناة `email` + Edge Function ترسل OTP عبر Resend
- **الواجهة:** نفس شاشة OTP الموجودة (6 خانات أرقام) — لا تغيير
- **التجربة للمستخدم:** أبسط من Magic Link (ما يحتاج يخرج من التطبيق)
- **المدة المتوقعة لتنفيذ Plan B:** ~30 دقيقة كود + 10 دقائق نشر

---

## 📌 خلاصة

**الوضع الحالي:** التطبيق جاهز وشغّال بـ Email + WhatsApp Dev Mode.
**المؤجّل:** إعداد Meta WhatsApp الفعلي بسبب الحاجة لصفحة Facebook خارج سوريا.
**الجاهزية:** عند تفعيل المراحل 1-5، التطبيق يتحول تلقائياً من Dev Mode إلى Production WhatsApp بدون أي تعديل بالكود.

---

## 🔗 مراجع موثوقة

- [Meta WhatsApp Messaging Limits](https://developers.facebook.com/documentation/business-messaging/whatsapp/messaging-limits)
- [Meta WhatsApp Cloud API Pricing](https://developers.facebook.com/docs/whatsapp/pricing)
- [Meta WhatsApp Restricted Countries (respond.io)](https://respond.io/help/whatsapp/whatsapp-api-quick-start)
- [Free Meta Test Phone Number Guide (Wati)](https://support.wati.io/en/articles/11463159-getting-a-free-whatsapp-business-phone-number-from-meta)
