# 🔧 دليل ضبط توكنات النشر على فيسبوك وإنستغرام

> **التاريخ:** 2026-08-05  
> **الهدف:** تفعيل النشر التلقائي للعروض على صفحات التواصل الاجتماعي  
> **المدة المتوقعة:** 30-45 دقيقة

---

## 📋 المتطلبات

- ✅ حساب فيسبوك مع صلاحيات أدمن على الصفحة
- ✅ حساب إنستغرام مهني (Professional Account) مرتبط بالصفحة
- ✅ حساب Supabase مع صلاحيات أدمن

---

## 🎯 المرحلة 1: إنشاء Meta App

### الخطوة 1.1: الدخول إلى Meta for Developers

1. افتح: https://developers.facebook.com/
2. سجّل الدخول بحساب الفيسبوك (اللي عندك صلاحيات أدمن على الصفحة)
3. اضغط **"My Apps"** → **"Create App"**

### الخطوة 1.2: إنشاء التطبيق

1. اختر نوع التطبيق: **"Business"**
2. املأ البيانات:
   - **App Name:** `عقارات السويداء` (أو أي اسم تريده)
   - **App Contact Email:** إيميلك
3. اضغط **"Create App"**

### الخطوة 1.3: إضافة المنتجات

بعد إنشاء التطبيق، ستظهر لوحة التحكم:

1. اضغط **"Add Product"**
2. أضف المنتجين التاليين:
   - ✅ **Facebook Login for Business**
   - ✅ **Instagram Basic Display**

---

## 📘 المرحلة 2: الحصول على Page Access Token

### الخطوة 2.1: إعداد Facebook Login

1. من القائمة اليسرى: **"Facebook Login for Business"** → **"Settings"**
2. في قسم **"Configuration"**:
   - **App ID:** انسخه (ستحتاجه لاحقاً)
   - **App Secret:** اضغط "Show" وانسخه

### الخطوة 2.2: الحصول على Page Access Token

#### الطريقة 1: Graph API Explorer (الأسهل)

1. افتح: https://developers.facebook.com/tools/explorer/
2. في الأعلى:
   - **Application:** اختر `عقارات السويداء` (التطبيق اللي أنشأته)
   - **User or Page:** اختر `Page`
   - **Page:** اختر صفحتك `عقارات السويداء`
3. في قسم **"Permissions"**، أضف:
   - `pages_read_engagement`
   - `pages_manage_posts`
   - `pages_show_list`
4. اضغط **"Generate Access Token"**
5. ستظهر نافذة لتسجيل الدخول → وافق على الصلاحيات
6. انسخ الـ **Access Token** (يبدأ بـ `EAAB...`)

⚠️ **ملاحظة:** هذا التوكن صالح لمدة **60 يوم فقط**. للحصول على توكن دائم، اتبع الخطوة 2.3.

#### الطريقة 2: الحصول على توكن دائم (Long-Lived Token)

1. افتح: https://developers.facebook.com/tools/debug/accesstoken/
2. الصق التوكن القصير (من الخطوة السابقة)
3. اضغط **"Debug"**
4. اضغط **"Extend Access Token"**
5. انسخ التوكن الجديد (صالح لمدة **60 يوم**)

⚠️ **للحصول على توكن لا ينتهي:**
```bash
# استبدل المتغيرات:
# {short-lived-token} = التوكن من الخطوة 2.2
# {app-id} = App ID من الخطوة 2.1
# {app-secret} = App Secret من الخطوة 2.1

curl -i -X GET "https://graph.facebook.com/v25.0/oauth/access_token?\
grant_type=fb_exchange_token&\
client_id={app-id}&\
client_secret={app-secret}&\
fb_exchange_token={short-lived-token}"
```

النتيجة:
```json
{
  "access_token": "EAABsbCS1iHgBA...(توكن طويل جداً)",
  "token_type": "bearer",
  "expires_in": 5184000  // 60 يوم
}
```

### الخطوة 2.3: تحويله إلى Page Access Token دائم

```bash
# استبدل {long-lived-user-token} بالتوكن من الخطوة السابقة
# استبدل {page-id} بـ ID صفحتك (ستحصل عليه في المرحلة 3)

curl -i -X GET "https://graph.facebook.com/v25.0/{page-id}?\
fields=access_token&\
access_token={long-lived-user-token}"
```

النتيجة:
```json
{
  "access_token": "EAABsbCS1iHgBA...(هذا هو Page Access Token الدائم)",
  "id": "123456789"  // هذا هو Page ID
}
```

✅ **انسخ `access_token`** → هذا هو `META_PAGE_ACCESS_TOKEN`

---

## 📗 المرحلة 3: الحصول على Page ID

### الطريقة 1: من الصفحة مباشرة

1. افتح صفحتك على فيسبوك: https://facebook.com/عقارات-السويداء
2. اضغط **"About"** (حول)
3. ابحث عن **"Page ID"**
4. انسخ الرقم (مثل: `123456789`)

### الطريقة 2: من Graph API Explorer

1. افتح: https://developers.facebook.com/tools/explorer/
2. في حقل الاستعلام، اكتب:
   ```
   me/accounts
   ```
3. اضغط **"Submit"**
4. ستظهر النتيجة:
   ```json
   {
     "data": [
       {
         "access_token": "EAAB...",
         "category": "Real Estate",
         "category_list": [...],
         "name": "عقارات السويداء",
         "id": "123456789"  // ← هذا هو Page ID
       }
     ]
   }
   ```

✅ **انسخ `id`** → هذا هو `META_FACEBOOK_PAGE_ID`

---

## 📸 المرحلة 4: الحصول على Instagram Account ID

### المتطلبات:
- ✅ حساب إنستغرام مهني (Professional Account)
- ✅ الحساب مرتبط بصفحة الفيسبوك

### الخطوة 4.1: التحقق من الارتباط

1. افتح إنستغرام → **Settings** → **Account** → **Linked Accounts**
2. تأكد أن **Facebook** موجود ومرتبطة بصفحتك

### الخطوة 4.2: الحصول على Instagram Account ID

#### الطريقة 1: من Graph API Explorer

1. افتح: https://developers.facebook.com/tools/explorer/
2. في حقل الاستعلام، اكتب:
   ```
   {page-id}?fields=instagram_business_account
   ```
   (استبدل `{page-id}` بـ Page ID من المرحلة 3)
3. اضغط **"Submit"**
4. ستظهر النتيجة:
   ```json
   {
     "instagram_business_account": {
       "id": "17841405..."  // ← هذا هو Instagram Account ID
     },
     "id": "123456789"
   }
   ```

✅ **انسخ `instagram_business_account.id`** → هذا هو `META_INSTAGRAM_ACCOUNT_ID`

#### الطريقة 2: من Instagram Professional Dashboard

1. افتح إنستغرام → **Profile** → **Professional Dashboard**
2. اضغط **"Business Tools"** → **"Facebook"**
3. ستظهر صفحة الفيسبوك المرتبطة → اضغط عليها
4. في URL، ستجد ID الحساب (رقم طويل)

---

## 🔐 المرحلة 5: ضبط التوكنات في Supabase

### الخطوة 5.1: الدخول إلى Supabase Dashboard

1. افتح: https://supabase.com/dashboard
2. اختر المشروع: `vsgkgnjtebjxyqwpuopz`

### الخطوة 5.2: إضافة Secrets

1. من القائمة اليسرى: **"Edge Functions"** → **"Secrets"**
2. اضغط **"Add Secret"** وأضف الثلاثة التاليين:

#### Secret 1: META_PAGE_ACCESS_TOKEN
```
Name: META_PAGE_ACCESS_TOKEN
Value: EAABsbCS1iHgBA...(التوكن من المرحلة 2)
```

#### Secret 2: META_FACEBOOK_PAGE_ID
```
Name: META_FACEBOOK_PAGE_ID
Value: 123456789 (من المرحلة 3)
```

#### Secret 3: META_INSTAGRAM_ACCOUNT_ID
```
Name: META_INSTAGRAM_ACCOUNT_ID
Value: 17841405...(من المرحلة 4)
```

### الخطوة 5.3: إعادة نشر Edge Functions

بعد إضافة الـ Secrets، يجب إعادة نشر الـ Edge Functions:

```bash
cd /path/to/sweeda-real-estate-office-elc

# إعادة نشر admin-offers
supabase functions deploy admin-offers \
  --no-verify-jwt \
  --project-ref vsgkgnjtebjxyqwpuopz

# إعادة نشر publish-to-social
supabase functions deploy publish-to-social \
  --no-verify-jwt \
  --project-ref vsgkgnjtebjxyqwpuopz
```

---

## 🧪 المرحلة 6: اختبار النشر

### الخطوة 6.1: إضافة عرض تجريبي

1. سجّل الدخول كمستخدم عادي (`مستخدم2عادي`)
2. أضف عرض جديد:
   - العنوان: `شقة تجريبية للنشر`
   - السعر: `100000`
   - الصور: ارفع صورة واحدة على الأقل
   - ✅ فعّل checkbox **"النشر على فيسبوك + إنستغرام"**
3. احفظ العرض

### الخطوة 6.2: مراجعة العرض

1. سجّل الدخول كمدير (`hady`)
2. اذهب إلى **مراجعة العروض**
3. ستجد العرض مع الشارة الزرقاء:
   ```
   📣 سيُنشر تلقائياً على فيسبوك + إنستغرام (بعد الموافقة)
   ```
4. اضغط **"قبول"**

### الخطوة 6.3: التحقق من النتيجة

#### ✅ إذا نجح:
```
✅ تم نشر العرض داخلياً • 📣 ✅ تم النشر تلقائياً على فيسبوك وإنستغرام
```

**تحقق من:**
- صفحة الفيسبوك: يجب أن يظهر المنشور
- حساب الإنستغرام: يجب أن يظهر المنشور

#### ❌ إذا فشل:

| الخطأ | السبب | الحل |
|-------|-------|------|
| `META_SECRETS_NOT_CONFIGURED` | التوكنات غير مضبوطة | راجع المرحلة 5 |
| `PUBLIC_IMAGE_REQUIRED` | العرض بدون صور | أضف صورة واحدة على الأقل |
| `OFFER_NOT_APPROVED` | العرض غير منشور | تأكد أن `sts=2` و `i_pub=1` |
| `Invalid OAuth access token` | التوكن منتهي أو خاطئ | أعد الحصول على توكن جديد |
| `Permission error` | صلاحيات ناقصة | راجع الخطوة 2.2 (Permissions) |

---

## 🔄 المرحلة 7: النشر اليدوي (للعروض القديمة)

إذا كان عندك عروض في قائمة "جاهزة للنشر":

1. اذهب إلى **مراجعة العروض**
2. ستجد القسم: **📣 جاهزة للنشر على فيسبوك + إنستغرام**
3. لكل عرض:
   - اضغط **"نشر الآن"** → ينشر عرض واحد
   - أو اضغط **"نشر الكل"** → ينشر كل العروض الجاهزة

---

## ⚙️ الإعدادات الإضافية (اختياري)

### تعطيل النشر التلقائي

إذا تريد أن يبقى النشر يدوي فقط:

1. اذهب إلى **الإعدادات** (`/admin/config`)
2. ابحث عن: **"النشر التلقائي فور قبول العرض"**
3. عطّل الخيار
4. احفظ

**النتيجة:**
- العروض تُنشر داخلياً فقط
- تبقى في قائمة "جاهزة للنشر"
- المدير ينشرها يدوياً عندما يريد

### تعديل قالب النص

القالب الافتراضي:
```
🏠 عرض جديد على عقارات السويداء

📍 [العنوان]
[عقار/سيارة] [للبيع/للإيجار]
💰 السعر: ...
📌 المنطقة: ...

[الوصف]

للتفاصيل والحجز:
📱 تطبيق عقارات السويداء
#عقارات_السويداء #عروض_عقارية
```

**لتعديله:**
- القالب يُولَّد تلقائياً في `add_offer_screen.dart` → `_generateSocialPostText()`
- يمكنك تعديل النص هناك

---

## 🎯 ملخص التوكنات المطلوبة

| التوكن | الوصف | مثال |
|--------|-------|------|
| `META_PAGE_ACCESS_TOKEN` | توكن الوصول لصفحة الفيسبوك | `EAABsbCS1iHgBA...` |
| `META_FACEBOOK_PAGE_ID` | ID صفحة الفيسبوك | `123456789` |
| `META_INSTAGRAM_ACCOUNT_ID` | ID حساب الإنستغرام المهني | `17841405...` |

---

## ⚠️ ملاحظات مهمة

### 1. صلاحية التوكنات
- **Page Access Token الدائم:** لا ينتهي (طالما لم تغير كلمة السر)
- **User Access Token:** ينتهي بعد 60 يوم
- **Short-lived Token:** ينتهي بعد ساعة

**الحل:** استخدم Page Access Token الدائم (المرحلة 2.3)

### 2. الصور
- فيسبوك: يقبل أي صورة (حتى لو واحدة)
- إنستغرام: **يجب** أن يكون عندك صورة واحدة على الأقل
- الحد الأقصى: 10 صور (Carousel)

### 3. الصلاحيات
- يجب أن تكون **أدمن** على صفحة الفيسبوك
- يجب أن يكون حساب الإنستغرام **مهني** (Professional)
- يجب أن يكون حساب الإنستغرام **مرتباً** بصفحة الفيسبوك

### 4. الحدود (Rate Limits)
- فيسبوك: 200 منشور/ساعة
- إنستغرام: 25 منشور/24 ساعة
- **لا تقلق:** التطبيق يحمي من التكرار عبر `social_publications`

---

## 🆘 حل المشاكل

### المشكلة 1: "Invalid OAuth access token"
**السبب:** التوكن منتهي أو خاطئ  
**الحل:**
1. أعد الحصول على توكن جديد (المرحلة 2)
2. تأكد أنه **Page Access Token** (ليس User Access Token)
3. أعد ضبطه في Supabase Secrets

### المشكلة 2: "Permission error" أو "Insufficient permission"
**السبب:** صلاحيات ناقصة  
**الحل:**
1. راجع الخطوة 2.2 (Permissions)
2. تأكد من إضافة:
   - `pages_read_engagement`
   - `pages_manage_posts`
   - `pages_show_list`
3. أعد توليد التوكن

### المشكلة 3: "Instagram account not linked"
**السبب:** حساب الإنستغرام غير مرتباً بصفحة الفيسبوك  
**الحل:**
1. افتح إنستغرام → **Settings** → **Account** → **Linked Accounts**
2. اربط حساب الفيسبوك
3. تأكد أن الصفحة هي نفسها

### المشكلة 4: "No Instagram Business Account found"
**السبب:** حساب الإنستغرام شخصي (ليس مهني)  
**الحل:**
1. افتح إنستغرام → **Profile** → **Settings**
2. اضغط **"Account"** → **"Switch to Professional Account"**
3. اختر **"Business"**
4. اربطه بصفحة الفيسبوك

---

## ✅ Checklist النهائية

قبل الاختبار، تأكد من:

- [ ] Meta App مُنشأ (المرحلة 1)
- [ ] Facebook Login for Business مُضاف
- [ ] Instagram Basic Display مُضاف
- [ ] Page Access Token دائم (المرحلة 2.3)
- [ ] Page ID منسوخ (المرحلة 3)
- [ ] Instagram Account ID منسوخ (المرحلة 4)
- [ ] التوكنات الثلاثة مُضافة في Supabase Secrets (المرحلة 5)
- [ ] Edge Functions مُعاد نشرها (المرحلة 5.3)
- [ ] حساب الإنستغرام مهني ومرتباً بالفيسبوك
- [ ] عندك صلاحيات أدمن على الصفحة

---

## 📞 الدعم

إذا واجهت مشكلة:
1. راجع قسم **"حل المشاكل"** أعلاه
2. تحقق من السجلات في Supabase Dashboard → **Edge Functions** → **Logs**
3. تواصل معي وسأساعدك

---

**الحالة:** 📋 جاهز للتنفيذ  
**التاريخ:** 2026-08-05  
**الإصدار:** 1.0
