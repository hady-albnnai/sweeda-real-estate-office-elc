# إعداد وسائل التواصل والمصادقة

> هذا الملف يجمع كل ما يتعلق بتفعيل واتساب OTP + النشر التلقائي على فيسبوك وإنستغرام.
> كلهم يحتاجون **حساب Meta Business واحد**.

---

## الحالة الحالية

| المكوّن | الحالة |
|---|---|
| تسجيل دخول واتساب (Dev Mode) | ✅ شغّال — OTP بصندوق برتقالي |
| تسجيل دخول إيميل (Magic Link) | ✅ شغّال عبر Resend SMTP |
| واتساب OTP إنتاجي | ⏸️ يحتاج Meta Business |
| نشر تلقائي فيسبوك | ⏸️ يحتاج صفحة + Page Access Token |
| نشر تلقائي إنستغرام | ⏸️ يحتاج حساب بزنس مربوط بالصفحة |
| Edge Functions (send/verify OTP) | مكتوبة — غير منشورة |
| Edge Function (نشر سوشال) | غير مكتوبة بعد |

---

## المتطلبات المشتركة

كل شي يبدأ بحساب Meta Business واحد:

### الخطوة 1: صفحة فيسبوك
- أنشئ **صفحة فيسبوك** باسم المكتب
- Category: Real Estate Agent
- ملاحظة: يُفضل إنشاؤها من **خارج سوريا** للاستفادة من ميزات الإعلان

### الخطوة 2: حساب إنستغرام بزنس
- حوّل حسابك لـ **Business Account** من إعدادات إنستغرام
- اربطه بصفحة الفيسبوك

### الخطوة 3: Meta Business Account
- https://business.facebook.com → أنشئ حساب
- أضف الصفحة المُنشأة

### الخطوة 4: Meta App + Tokens
1. https://developers.facebook.com/apps → **Create App** → **Business**
2. أضف **WhatsApp** product
3. أنشئ **System User** بـ Admin role
4. **Generate Permanent Token** بصلاحيات:
   - `whatsapp_business_messaging`
   - `whatsapp_business_management`
   - `pages_manage_posts` (للنشر على فيسبوك)
   - `instagram_content_publish` (للنشر على إنستغرام)

---

## تفعيل واتساب OTP

### إعداد رقم الإرسال
- اختر **رقم Meta 555 المجاني** أو اربط رقم خارج سوريا
- ⚠️ رقم سوري (+963) **محظور** كـ Sender من Meta

### إنشاء قالب OTP
في **WhatsApp Manager → Message Templates:**

| الحقل | القيمة |
|---|---|
| Category | Authentication |
| Name | `otp_login` |
| Language | Arabic (`ar`) |
| Body | `{{1}} هو رمز التحقق الخاص بك. لا تشاركه مع أحد.` |

### نشر Edge Functions
```bash
supabase login
supabase link --project-ref vsgkgnjtebjxyqwpuopz

supabase secrets set META_WHATSAPP_TOKEN="EAAxxx..."
supabase secrets set META_PHONE_NUMBER_ID="123456789012345"
supabase secrets set META_OTP_TEMPLATE_NAME="otp_login"
supabase secrets set META_OTP_TEMPLATE_LANG="ar"

supabase functions deploy send-whatsapp-otp --no-verify-jwt
supabase functions deploy verify-whatsapp-otp --no-verify-jwt
```

### الحدود والتكلفة
- Tier 0: 250 مستخدم/يوم (بدون توثيق)
- أول 250 authentication مجاناً/شهر
- بعدها: ~$0.0125/رسالة لسوريا

---

## تفعيل النشر التلقائي

### المنطق
1. العرض يتم قبوله من الإدارة (`sts=2`)
2. إذا `i_soc=1` ← Edge Function تنشر على فيسبوك + إنستغرام
3. بعد النشر ← `soc_pub=1`

### ما يُحتاج من المالك
بعد إنشاء الحسابات أعطيني:
- **Page ID** (من إعدادات صفحة فيسبوك)
- **Instagram Business Account ID**
- **Page Access Token** (دائم)

### Secrets المطلوبة
```bash
supabase secrets set META_PAGE_ID="123..."
supabase secrets set META_PAGE_ACCESS_TOKEN="EAAxxx..."
supabase secrets set META_IG_USER_ID="456..."
```

### Edge Function (ستُكتب لاحقاً)
- `supabase/functions/publish-to-social/index.ts`
- تُستدعى عبر trigger بعد `admin_review_offer_internal(approve=true)`
- تنشر: صورة + عنوان + سعر + رابط العرض

---

## Plan B (إذا فشل Meta)

### Email OTP بدل Magic Link
- تعديل `AuthService` لاستخدام `generate_otp_v2` بقناة `email`
- نفس شاشة OTP (6 أرقام) — بدون تغيير بالواجهة
- المدة: ~30 دقيقة

---

## Checklist

- [ ] إنشاء صفحة فيسبوك
- [ ] إنشاء حساب إنستغرام بزنس + ربط بالصفحة
- [ ] إنشاء Meta Business Account
- [ ] إنشاء Meta App + WhatsApp product
- [ ] إنشاء System User + Permanent Token
- [ ] إنشاء قالب OTP (`otp_login`)
- [ ] نشر Edge Functions (OTP)
- [ ] اختبار واتساب OTP
- [ ] إعطاء Page ID + IG ID + Token
- [ ] كتابة ونشر Edge Function النشر التلقائي
- [ ] اختبار النشر على فيسبوك + إنستغرام
