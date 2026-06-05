# 📋 خطة المشروع — عقارات السويداء

> **آخر تحديث:** 2026-06-05  
> **Backend:** Supabase (PostgreSQL + Auth + Realtime + Storage + RPC)  
> **Frontend:** Flutter

---

## 📊 حالة التنفيذ

| المرحلة | الحالة | الشاشات المكتملة | الشاشات المتبقية |
|---|---|---|---|
| ✅ المرحلة 0: الأساس | مكتملة | Splash + Firebase removal + Router | — |
| ✅ المرحلة 1: شاشات المستخدم | **مكتملة** | 13/13 (+5 شاشات) | — |
| ✅ المرحلة 2: لوحة السمسار | **مكتملة** | 5/5 (broker_appointments أُعيد بناؤها) | — |
| ✅ المرحلة 3: لوحة الإدارة | **مكتملة** | 9/9 (offers_review أُعيد بناؤها) | — |
| ✅ المرحلة 4: المنطق الخلفي | **مكتملة** | 7/7 ميزة | — |
| ✅ المرحلة 5: التحسينات | **مكتملة** | 6/6 تحسين | — |
| ✅ المرحلة 6: البناء والنشر | **مُجهّزة** | إعداد+أمان+دليل | تنفيذ البناء محلياً |
| ✅ **المرحلة 7: المصادقة الجديدة** | **مكتملة** | WhatsApp + Email Magic Link | — |
| ✅ **المرحلة 8: الشاشات المتبقية** | **مكتملة** | packages + payment + edit + broker + request | — |
| ✅ **المرحلة 9: إصلاحات ما بعد الاختبار** | **مكتملة** | setup_profile overflow + routes + splash logo + native splash | — |
| ✅ **المرحلة 10: المزايا الناقصة (Critical)** | **مكتملة** | إقرار + صورة هوية + صورة سند + تبليغ + ربط pen + stats triggers + wk_lgn + referral | — |

**النسبة الإجمالية: ~98% مكتمل** (يتبقّى تنفيذ البناء/النشر على الجهاز المحلي + ترقيات RLS)

---

## 🎯 المرحلة 10: تنفيذ المزايا الناقصة من المواصفات (✅ مكتملة — 2026-06-05)

> راجع `docs/FEATURES_AUDIT.md` للتفاصيل الكاملة.

### الجزء A: المزايا القاعدية
| # | الميزة | التنفيذ |
|---|---|---|
| 10.1 | **الإقرار والتعهد** (`txts.plg`) | dialog يعرض النص من config + checkbox إجباري في `setup_profile_screen` و `add_offer_screen` |
| 10.2 | **صورة الهوية** (`users.img`) | حقل رفع صورة في `setup_profile_screen` + bucket `ids/{uid}/` |
| 10.3 | **صورة سند الملكية** (`doc_img` + `doc_tp`) | Step 4 جديد في `add_offer_screen` (dropdown نوع السند من config + رفع صورة) |
| 10.4 | **زر التبليغ** للمستخدم النهائي | زر flag في AppBar الـ `offer_detail_screen` + dialog مع `rptRsn` من config |

### الجزء B: المنطق الخلفي
| # | الميزة | التنفيذ |
|---|---|---|
| 10.5 | **خصم النقاط** (`pen`) مربوط بأحداث | `reviewOffer` يطبّق `pen.rej3` بعد 3 رفض، `updateAppointmentStatus` يطبّق `pen.noSh` (-500) و `pen.cnl3` (-300) |
| 10.6 | **users.stats** تحديث تلقائي | 4 PostgreSQL Triggers على offers/requests/appointments/deals + Backfill للحسابات الموجودة |
| 10.7 | **wk_lgn** تسجيل دخول أسبوعي | RPC `register_weekly_login` + استدعاء من `AuthProvider.registerStreak` |
| 10.8 | **نظام الإحالة** (`referral`) | عمود `ref_by`+`ref_cnt` + RPC `apply_referral` + شاشة `referral_screen` كاملة |

> Migration SQL جديد: `supabase/migrations/2026_06_05_stats_triggers_and_wkLogin.sql`

---

## 🐛 المرحلة 9: إصلاحات ما بعد الاختبار الأول (✅ مكتملة — 2026-06-05)

| # | المشكلة | الحل |
|---|---|---|
| 9.1 | `setup_profile_screen` RenderFlex overflowed by 67px | معاد بناؤها: SafeArea + SingleChildScrollView + حقول مدمجة |
| 9.2 | `context.go('/')` بعد تسجيل الدخول → "no routes for location" | توجيه حسب الدور (`/user/home`, `/broker/dashboard`, `/admin/dashboard`) |
| 9.3 | شاشة Splash تستخدم أيقونة افتراضية (`apartment_rounded`) | الآن تستخدم `assets/images/logo_app.png` مع errorBuilder |
| 9.4 | Splash لا يفحص حالة المستخدم → دائماً يفتح شاشة الزائر | أُضيف `auth.checkAuthStatus()` + توجيه حسب الدور |
| 9.5 | Native splash (Android) ما يظهر اللوجو بحجم مناسب | تحديد `220x220 dp` في `launch_background.xml` |
| 9.6 | `app.dart` magic link listener يستخدم `'/'` غير معرّف | نفس إصلاح 9.2 |
| 9.7 | `LocaleDataException: Locale data has not been initialized` عند فتح Profile | `initializeDateFormatting('ar', null)` في main.dart + try/catch في `formatTimestamp` |
| 9.8 | شاشة بيضاء قبل native splash على بعض أجهزة Android | إضافة `windowDisablePreview=true` + `windowContentOverlay=@null` في `styles.xml` |

> الملفات المعدّلة (7): `setup_profile_screen.dart`, `otp_verification_screen.dart`, `splash_screen.dart`, `app.dart`, `launch_background.xml` (×2), `main.dart`, `app_utils.dart`, `styles.xml` (×2)

---

## 🆕 المرحلة 8: استكمال الشاشات الناقصة (✅ مكتملة — 2026-06-05)

| # | الشاشة | الوصف | الحالة |
|---|---|---|---|
| 8.1 | `packages_screen.dart` | عرض الباقات (مجاني/فضي/ذهبي) + مقارنة | ✅ |
| 8.2 | `payment_screen.dart` | دفع الاشتراك + رفع إثبات | ✅ |
| 8.3 | `edit_offer_screen.dart` | تعديل/تجديد/حذف العرض + إدارة الصور | ✅ |
| 8.4 | `become_broker_screen.dart` | نموذج التقدّم لوساطة | ✅ |
| 8.5 | `request_detail_screen.dart` | تفاصيل الطلب + عروض مطابقة | ✅ |
| 8.6 | إعادة بناء `my_offers_screen` | تبويبات حسب الحالة + تعديل/عرض/مشاركة | ✅ |
| 8.7 | إعادة بناء `offers_review_screen` | صور + اسم المرسل + سبب رفض + كشف المكرر | ✅ |
| 8.8 | إعادة بناء `broker_appointments_screen` | تفاصيل العميل + اتصال/واتساب + إكمال | ✅ |
| 8.9 | إصلاح TODOs + الأزرار المعطلة | settings/home/my_requests/add_offer | ✅ |

> راجع `docs/SCREENS_AUDIT.md` للتفاصيل الكاملة.

---

## 📌 المرحلة 1: شاشات المستخدم (✅ مكتملة)

| # | الملف | الوصف | الحالة |
|---|---|---|---|
| 1.1 | `user_home_screen.dart` | الرئيسية + بحث + فلترة حسب النوع | ✅ |
| 1.2 | `my_requests_screen.dart` | طلباتي + FAB + حالات الطلب | ✅ |
| 1.3 | `my_appointments_screen.dart` | مواعيدي + إلغاء + حالات | ✅ |
| 1.4 | `favorites_screen.dart` | مفضلة (SharedPreferences) | ✅ |
| 1.5 | `profile_screen.dart` | ملف شخصي + بادج + نقاط + إحصائيات | ✅ |
| 1.6 | `settings_screen.dart` | إعدادات إشعارات + خروج | ✅ |
| 1.7 | `add_request_screen.dart` | نموذج Stepper 3 خطوات | ✅ |
| 1.8 | `bottom_nav_bar.dart` | BottomNavigationBar 5 أيقونات | ✅ |

---

## 📌 المرحلة 2: لوحة السمسار (✅ مكتملة)

| # | الملف | الوصف | الحالة |
|---|---|---|---|
| 2.1 | `broker_dashboard_screen.dart` | إحصائيات سريعة (4 بطاقات) + تنقّل للأقسام | ✅ |
| 2.2 | `broker_offers_screen.dart` | عروض السمسار (خاصة + مُسندة) + فلترة بالحالة | ✅ |
| 2.3 | `broker_deals_screen.dart` | الصفقات النشطة/المكتملة + ملخّص العمولات | ✅ |
| 2.4 | `broker_stats_screen.dart` | إحصائيات تفصيلية + أشرطة نسب (بدون مكتبات) | ✅ |

> **`BrokerProvider`** موسّع بـ: `fetchBrokerStats` · `fetchBrokerOffers` · `fetchBrokerDeals` · `fetchBrokerAppointments` · `handleAppointment` · `completeAppointment`.  
> **الدخول:** أزرار "لوحة الوسيط" و"لوحة الإدارة" في `profile_screen.dart` (تظهر حسب الدور).

---

## 📌 المرحلة 3: لوحة الإدارة (✅ مكتملة)

| # | الملف | الوصف | الحالة |
|---|---|---|---|
| 3.1 | `admin_dashboard_screen.dart` | لوحة رئيسية + إحصائيات + عدّادات إجراءات | ✅ |
| 3.2 | `users_management_screen.dart` | بحث + حظر/تجميد/تفعيل + تغيير الدور | ✅ |
| 3.3 | `appointments_management_screen.dart` | كل المواعيد + فلترة + فرض/إكمال/إلغاء | ✅ |
| 3.4 | `deals_management_screen.dart` | صفقات + إتمام + تسجيل العمولة | ✅ |
| 3.5 | `payments_screen.dart` | موافقة/رفض + تفعيل الباقة + إثبات الدفع | ✅ |
| 3.6 | `reports_screen.dart` | تبليغات + إجراء (تحذير/تجميد/حظر) | ✅ |
| 3.7 | `config_editor_screen.dart` | تعديل النقاط/العمولة/الحصص (دمج آمن) | ✅ |
| 3.8 | `analytics_screen.dart` | إحصائيات شاملة + أشرطة نسب | ✅ |

> **`AdminProvider`** موسّع: `getAllUsers/setUserStatus/ban/freeze/activate/updateUserRole/softDeleteUser` · `getAllAppointments/updateAppointmentStatus/forceAppointment` · `getAllDeals/createDeal/completeDeal` · `getAllPayments/approvePayment/rejectPayment` · `getAllReports/handleReport` · `getStats/getActionCounts`.

---

## 📌 المرحلة 4: المنطق الخلفي (✅ مكتملة)

| # | العنصر | التنفيذ | الحالة |
|---|---|---|---|
| 4.1 | Config Loading | `LocalCacheService`(Hive) + `ConfigProvider` كاش-أولاً + تحميل بالـ Splash | ✅ |
| 4.2 | المطابقة التلقائية | `matchOffersForRequest` (نوع+سعر±20%) + BottomSheet عند إضافة طلب | ✅ |
| 4.3 | نظام النقاط | `addPoints` (RPC + fallback) + `awardEvent`/`applyPenalty` من Config | ✅ |
| 4.4 | الباقات/الحصص | `canPublishOffer/Request` + `offerQuota/requestQuota` مطبّقة بالنشر | ✅ |
| 4.5 | Streak System | `registerDailyStreak` + استدعاء بالـ HomeScreen + نقاط | ✅ |
| 4.6 | Social Media | `generateSocialPost` + مشاركة `share_plus` بتفاصيل العرض | ✅ |
| 4.7 | رفع الصور | `StorageService`: اختيار + ضغط + رفع متعدد لـ offer_images | ✅ |

> **ملفات جديدة:** `core/services/business_service.dart` · `core/services/local_cache_service.dart`. **تبعية:** `path_provider`.

---

## 📌 المرحلة 5: التحسينات (✅ مكتملة)

| # | العنصر | التنفيذ | الحالة |
|---|---|---|---|
| 5.1 | Realtime | `OfferProvider.subscribeRealtime` بالـ HomeScreen | ✅ |
| 5.2 | الإشعارات | `notifications_screen` + badge + Realtime listener (داخلي/محلي) | ✅ |
| 5.3 | Offline | كاش العروض/الإعدادات في Hive + لافتة دون اتصال | ✅ |
| 5.4 | Error Handling | `AppErrorWidget`/`EmptyState` بالثيم + إعادة محاولة | ✅ |
| 5.5 | Loading | `shimmer_loading.dart` (بطاقات/عناصر وهمية) | ✅ |
| 5.6 | Splash Polish | شريط تقدّم + slogan + انتقال بعد تحميل Config | ✅ |

> Push عبر FCM الخارجي (تطبيق مغلق) يحتاج Edge Function + مفتاح FCM — يُؤجَّل لمرحلة لاحقة.

---

## 📌 المرحلة 6: البناء والنشر (✅ مُجهّزة)

| # | العنصر | الحالة |
|---|---|---|
| 6.1 | إعداد Android (Gradle/توقيع/ProGuard/إزالة Firebase) | ✅ |
| 6.2 | إعداد iOS (bundle id/أذونات Info.plist) | ✅ |
| 6.3 | المراجعة الأمنية → `docs/SECURITY_REVIEW.md` | ✅ |
| 6.4 | دليل البناء → `BUILD_GUIDE.md` | ✅ |
| — | تنفيذ `flutter build` + الرفع للمتاجر | ⏳ محلياً |
| — | تطبيق ترقيات RLS الإدارية | ⏳ على Supabase |

---

## 📈 ملخص

- **الشاشات المكتملة:** 29/39 (المستخدم 9 · السمسار 5 · الإدارة 9 + أساسيات)
- **الميزات المكتملة (منطق خلفي):** 7/7
- **التحسينات المكتملة:** 6/6
- **إعداد البناء والأمان:** ✅ مُجهّز (Gradle/توقيع/ProGuard/iOS/مراجعة أمنية/دليل)
- **إجمالي التقدم:** ~95% (يتبقّى تنفيذ البناء محلياً + ترقيات RLS قبل الإطلاق)
