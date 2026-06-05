# 🔍 تدقيق شامل للشاشات — عقارات السويداء

> **تاريخ التدقيق:** 2026-06-05
> **النتيجة:** 32 شاشة موجودة + 6 شاشات/مهام **ناقصة أو غير مكتملة** + 4 مشاكل وظيفية

---

## 📊 الملخص التنفيذي

| الفئة | المكتمل | ناقص/يحتاج عمل |
|---|---|---|
| **Auth** | 4/4 ✅ | — |
| **Visitor** | 3/3 ✅ | — |
| **User** | 10/10 ⚠️ | 1 شاشة (Request Detail) + إصلاحات |
| **Broker** | 5/5 ⚠️ | شاشة المعاينة ضعيفة جداً (51 سطر) |
| **Admin** | 9/9 ⚠️ | شاشة Offers Review ضعيفة جداً (52 سطر) |
| **Payments / Packages** | 0/2 ❌ | شاشة الاشتراك بالباقات (User) + شاشة تفاصيل الباقة |
| **Become Broker** | 0/1 ❌ | شاشة "تقدّم لتصبح وسيطاً" |
| **Notifications من الزائر** | ⚠️ | زر notification بالـ home ما يفعل شي |

---

## ✅ الشاشات الموجودة (32 شاشة)

### 🔐 Auth (4)
| الملف | السطور | الحالة |
|---|---|---|
| `login_screen.dart` | 283 | ✅ مكتمل (تبويبتين واتساب/إيميل) |
| `otp_verification_screen.dart` | 202 | ✅ مكتمل |
| `setup_profile_screen.dart` | 95 | ✅ مكتمل |
| `check_email_screen.dart` | 96 | ✅ مكتمل |

### 🌐 Visitor (3)
| الملف | السطور | الحالة |
|---|---|---|
| `home_screen.dart` | 88 | ⚠️ زر الإشعارات غير مفعّل (`onPressed: () {}`) |
| `offer_detail_screen.dart` | 273 | ✅ مكتمل (مع زر الحجز + المفضلة + المشاركة) |
| `search_screen.dart` | 181 | ✅ مكتمل |
| `splash_screen.dart` | 178 | ✅ مكتمل |

### 👤 User (10)
| الملف | السطور | الحالة |
|---|---|---|
| `user_home_screen.dart` | 268 | ✅ مكتمل |
| `add_offer_screen.dart` | 351 | ✅ مكتمل |
| `add_request_screen.dart` | 372 | ✅ مكتمل |
| `my_offers_screen.dart` | **44** ⚠️ | **ضعيف:** بدون تعديل/حذف/تجديد/مشاهدة تفاصيل، زر "أضف عرضك الأول" معطّل |
| `my_requests_screen.dart` | 137 | ⚠️ TODO: شاشة تفاصيل الطلب (`onTap` فاضي) |
| `my_appointments_screen.dart` | 152 | ✅ مكتمل |
| `favorites_screen.dart` | 108 | ✅ مكتمل |
| `profile_screen.dart` | 313 | ✅ مكتمل |
| `settings_screen.dart` | 201 | ⚠️ TODO: حفظ إعدادات الإشعارات في Supabase + "الباقة الحالية" زر معطّل |
| `notifications_screen.dart` | 154 | ✅ مكتمل |

### 🤝 Broker (5)
| الملف | السطور | الحالة |
|---|---|---|
| `broker_dashboard_screen.dart` | 208 | ✅ مكتمل |
| `broker_offers_screen.dart` | 238 | ✅ مكتمل |
| `broker_appointments_screen.dart` | **51** ⚠️ | **ضعيف:** بدون فلترة بالحالة + بدون تفاصيل الطلب + يستخدم `MaterialPageRoute` بدل GoRouter + ما في "إكمال المعاينة" |
| `broker_deals_screen.dart` | 237 | ✅ مكتمل |
| `broker_stats_screen.dart` | 213 | ✅ مكتمل |

### 🛡️ Admin (9)
| الملف | السطور | الحالة |
|---|---|---|
| `admin_dashboard_screen.dart` | 284 | ✅ مكتمل |
| `users_management_screen.dart` | 294 | ✅ مكتمل |
| `offers_review_screen.dart` | **52** ⚠️ | **ضعيف جداً:** ما يعرض الصور، ما يعرض اسم المُرسل (بس uid)، بدون سبب رفض، بدون تفاصيل العرض |
| `appointments_management_screen.dart` | 252 | ✅ مكتمل |
| `deals_management_screen.dart` | 283 | ✅ مكتمل |
| `payments_screen.dart` | 272 | ✅ مكتمل (من جهة الإدارة) |
| `reports_screen.dart` | 272 | ✅ مكتمل |
| `config_editor_screen.dart` | 235 | ✅ مكتمل |
| `analytics_screen.dart` | 193 | ✅ مكتمل |

---

## ❌ الشاشات الناقصة (6)

### 1. 💳 `packages_screen.dart` — شاشة الاشتراك بالباقات (مهم)
**الوصف:** المستخدم يشوف الباقات المتاحة (مجاني/فضي/ذهبي)، يقارن المزايا، ويختار باقة للاشتراك.

**الموقع المقترح:** `lib/screens/user/packages_screen.dart`
**Route:** `/user/packages`
**يجب أن تربط من:**
- `settings_screen.dart` (السطر 65: "الباقة الحالية" زر معطّل حالياً)
- `profile_screen.dart` (بطاقة الباقة)
- `add_offer_screen.dart` (لما يتجاوز الحصة)

**يستخدم:** `ConfigProvider.config.pkg` للحصول على بيانات الباقات.

---

### 2. 💰 `payment_screen.dart` — شاشة دفع الاشتراك (مهم)
**الوصف:** بعد اختيار باقة، يدخل بيانات الدفع + يرفع إثبات الدفع (صورة).

**الموقع المقترح:** `lib/screens/user/payment_screen.dart`
**Route:** `/user/payment/:packageId`
**يستخدم:** `PaymentProvider.createPayment` (موجود فعلاً)

---

### 3. 🤝 `become_broker_screen.dart` — التقدّم لتصبح وسيطاً
**الوصف:** نموذج تقديم: اسم تجاري + فئة الوساطة + بيانات + إرسال طلب للإدارة.

**الموقع المقترح:** `lib/screens/user/become_broker_screen.dart`
**Route:** `/user/become-broker`
**يجب أن تربط من:** `profile_screen.dart` أو `settings_screen.dart`

---

### 4. 📋 `request_detail_screen.dart` — تفاصيل الطلب
**الوصف:** عرض تفاصيل طلب البحث + العروض المطابقة + إمكانية حذف/تعديل.

**الموقع المقترح:** `lib/screens/user/request_detail_screen.dart`
**Route:** `/user/request/:id`
**TODO موجود في:** `my_requests_screen.dart:132`

---

### 5. ✏️ `edit_offer_screen.dart` — تعديل عرض
**الوصف:** نفس `add_offer_screen` لكن للتعديل (مع تجديد العرض).

**الموقع المقترح:** `lib/screens/user/edit_offer_screen.dart`
**Route:** `/user/edit-offer/:id`
**يجب أن تربط من:** `my_offers_screen.dart`

---

### 6. 🔔 شاشة الإشعارات للزائر / تفعيل زر الإشعارات في الـ home
**الحالة:** زر `IconButton(icon: Icons.notifications_none, onPressed: () {})` في `home_screen.dart:18` بدون وظيفة.
**الحل:** إما يفتح شاشة Login (إذا مش مسجّل دخول) أو يحول لـ `/user/notifications`.

---

## ⚠️ المشاكل الوظيفية في الشاشات الموجودة (4)

### 1. `my_offers_screen.dart` (44 سطر فقط) — يحتاج إعادة كتابة كاملة
**النواقص:**
- ❌ زر "أضف عرضك الأول" بدون `onPressed` (سطر 23: `onPressed: () {}`)
- ❌ لا يفلتر بحالة العرض (مسودة/منشور/مرفوض/منتهي)
- ❌ لا يوفّر تعديل/حذف/تجديد العرض
- ❌ لا يربط بشاشة `edit_offer_screen` (لأنها غير موجودة أصلاً)

### 2. `broker_appointments_screen.dart` (51 سطر فقط) — ضعيف
**النواقص:**
- ❌ لا يعرض اسم العميل أو رقم هاتفه
- ❌ لا يعرض تفاصيل العرض المطلوب معاينته
- ❌ لا يوجد "تأكيد إكمال المعاينة" (يحتاج لإصدار صفقة)
- ❌ يستخدم `Navigator.pushReplacement` بدل `context.go` (غير متوافق مع GoRouter)
- ❌ لا فلترة بالحالة

### 3. `offers_review_screen.dart` (52 سطر فقط) — ضعيف جداً
**النواقص:**
- ❌ لا يعرض صور العرض (مجرد ListTile بسيط)
- ❌ يعرض `usrId` بدل اسم المرسل
- ❌ لا يعرض الوصف/الموقع/التفاصيل
- ❌ لا يطلب سبب الرفض (يرفض مباشرة بدون تعليل)
- ❌ يستخدم `Navigator.pushReplacement` بدل `context.go`
- ❌ لا يكشف العروض المكررة المحتملة (`i_dup`)

### 4. `settings_screen.dart` — TODOs مفتوحة
- ❌ السطر 149: حفظ إعدادات الإشعارات لا يصل لـ Supabase (TODO)
- ❌ السطر 65: زر "الباقة الحالية" بدون وظيفة

---

## 🎯 خطة العمل المقترحة (مرتّبة بالأولوية)

### الأولوية القصوى (للإصدار 1.0):
1. ✅ **إنشاء `packages_screen` + `payment_screen`** — بدونهم لا يصير في إيرادات للمكتب
2. ✅ **إعادة بناء `my_offers_screen`** + ربطه بشاشات edit/delete/renew
3. ✅ **إنشاء `edit_offer_screen`** — حالياً المستخدم لا يقدر يعدّل عروضه!
4. ✅ **تقوية `offers_review_screen` للإدارة** — حالياً غير قابلة للاستخدام الفعلي
5. ✅ **تقوية `broker_appointments_screen`** — السمسار محتاج تفاصيل العميل ليتواصل معه

### الأولوية المتوسطة:
6. ✅ **إنشاء `become_broker_screen`** — لتوسعة قاعدة الوسطاء
7. ✅ **إنشاء `request_detail_screen`** + تفعيل الـ TODO في `my_requests_screen`
8. ✅ **إصلاح `settings_screen`** — حفظ الإشعارات فعلياً

### الأولوية المنخفضة:
9. ✅ **تفعيل زر الإشعارات في `home_screen`** للزائر
10. ✅ **استبدال `Navigator.pushReplacement` بـ `context.go`** بكل الشاشات (توحيد التنقّل)

---

## 📈 النسب الحقيقية

| التقدير | النسبة |
|---|---|
| **حسب `PROJECT_PLAN.md`** | 95% |
| **حسب التدقيق الفعلي** | **~78%** |
| **الفجوة** | 5 شاشات أساسية + 4 إصلاحات وظيفية |

---

## 💡 ملاحظة مهمة

`PROJECT_PLAN.md` بيعتبر الشاشات "مكتملة" بمجرد وجود الملف، بس بالتدقيق الفعلي اكتشفنا أن:
- 3 شاشات (`my_offers`, `broker_appointments`, `offers_review`) **موجودة بس ضعيفة جداً** وغير صالحة للاستخدام الفعلي
- ميزة **الاشتراك بالباقات** غائبة بالكامل من جهة المستخدم (موجودة بس من جهة الإدارة)
- ميزة **التقدّم للوساطة** غائبة بالكامل
- ميزة **تعديل العرض** غائبة بالكامل
