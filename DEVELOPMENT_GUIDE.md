# 🚀 دليل التطوير — عقارات السويداء

> **آخر تحديث:** 2026-06-05  
> **Commit الحالي:** المرحلة 6 ✅ مُجهّزة (بناء + أمان + توثيق)  
> **المستودع:** https://github.com/hady-albnnai/sweeda-real-estate-office-elc

---

## 📊 الحالة الحالية

| العنصر | الحالة | التفاصيل |
|---|---|---|
| **السيرفر (Supabase)** | ✅ 100% | 13 جدول + 12 دالة RPC + RLS + Realtime |
| **الموديلات** | ✅ 100% | 10 ملفات |
| **الـ Providers** | ✅ 100% | 9 ملفات (broker + admin موسّعان بالكامل) |
| **الـ Services** | ✅ 100% | auth, storage(+ضغط/رفع), notification, **business**, **local_cache(Hive)** |
| **الـ Router** | ✅ 100% | 31 مسار (+ شاشة الإشعارات) |
| **🎬 المرحلة 0: الأساس** | ✅ مكتملة | Splash + Firebase removal |
| **👤 المرحلة 1: شاشات المستخدم** | ✅ مكتملة | 8 شاشات + BottomNavBar |
| **🤝 المرحلة 2: لوحة السمسار** | ✅ مكتملة | 4 شاشات + ربط بالبروفايل |
| **🛡️ المرحلة 3: لوحة الإدارة** | ✅ مكتملة | 9 شاشات (dashboard + 8 أقسام) |
| **⚙️ المرحلة 4: المنطق الخلفي** | ✅ مكتملة | Config+Hive · نقاط · باقات/حصص · مطابقة · Streak · سوشال · رفع صور |
| **✨ المرحلة 5: التحسينات** | ✅ مكتملة | Realtime + إشعارات + Offline + Shimmer + Splash |
| **📦 المرحلة 6: البناء** | ✅ مُجهّزة | إعداد Gradle/توقيع + إزالة Firebase + ProGuard + دليل + مراجعة أمنية |

---

## ⚠️ ملاحظات حرجة

### 1. `desc` → `descript`
كلمة `desc` محجوزة بـ PostgreSQL. تم تغييرها لـ `descript` في كل الملفات.

### 2. Supabase Stream API
الـ stream ما بيقبل `.eq()` أو `.match()` أو `.filter()`.
الحل: `.stream(primaryKey: ['id']).listen()` + فلترة يدوية.

### 3. التوكنات
- anon key: موجود في lib/main.dart و lib/app.dart
- Project URL: https://vsgkgnjtebjxyqwpuopz.supabase.co

### 4. الملفات المحذوفة (Firebase)
firebase.json ❌ | functions/ ❌ | firebase_options.dart ❌ | firestore_service.dart ❌ | cloud_functions_service.dart ❌

---

## 🗺️ خطة العمل التفصيلية

### ✅ المرحلة 1: شاشات المستخدم الأساسية (مكتملة)

| # | الملف | الوصف | الحالة |
|---|---|---|---|
| 1.1 | `user_home_screen.dart` | الرئيسية + بحث + فلترة + BottomNavBar | ✅ |
| 1.2 | `my_requests_screen.dart` | طلباتي + FAB + حالة الطلب | ✅ |
| 1.3 | `my_appointments_screen.dart` | مواعيدي + إلغاء + حالات | ✅ |
| 1.4 | `favorites_screen.dart` | مفضلة (SharedPreferences) | ✅ |
| 1.5 | `profile_screen.dart` | ملف شخصي + بادج + نقاط + إحصائيات | ✅ |
| 1.6 | `settings_screen.dart` | إعدادات + إشعارات + خروج | ✅ |
| 1.7 | `add_request_screen.dart` | نموذج إضافة طلب (Stepper 3 خطوات) | ✅ |
| 1.8 | `bottom_nav_bar.dart` | شريط تنقل سفلي (5 أيقونات) | ✅ |

### ✅ المرحلة 2: لوحة السمسار (مكتملة)
| # | الملف | الوصف | الحالة |
|---|---|---|---|
| 2.1 | `broker_dashboard_screen.dart` | لوحة تحكم + 4 بطاقات إحصائيات + تنقّل للأقسام | ✅ |
| 2.2 | `broker_offers_screen.dart` | عروض السمسار (خاصة + مُسندة) + فلترة بالحالة | ✅ |
| 2.3 | `broker_deals_screen.dart` | الصفقات + ملخّص العمولات + فلترة (نشطة/مكتملة) | ✅ |
| 2.4 | `broker_stats_screen.dart` | إحصائيات تفصيلية + أشرطة نسب (بدون مكتبات خارجية) | ✅ |
| — | `broker_appointments_screen.dart` | طلبات المعاينة (قبول/رفض) — موجودة مسبقاً | ✅ |

**`BrokerProvider` تم توسيعه:** `fetchBrokerStats` · `fetchBrokerOffers` · `fetchBrokerDeals` · `fetchBrokerAppointments` / `getBrokerAppointments` · `handleAppointment` · `completeAppointment`. الحالة محفوظة داخلياً (offers/deals/appointments/stats) + getters.

**الدخول للوحة:** زر "لوحة الوسيط" في `profile_screen.dart` (يظهر لمن `role==1` أو `isBroker`). كذلك زر "لوحة الإدارة" لمن `isAdmin` (role≥2).

### ✅ المرحلة 3: لوحة الإدارة (مكتملة)
| # | الملف | الوصف | الحالة |
|---|---|---|---|
| 3.1 | `admin_dashboard_screen.dart` | لوحة رئيسية + إحصائيات + عدّادات إجراءات + شبكة تنقّل | ✅ |
| 3.2 | `users_management_screen.dart` | بحث + حظر/تجميد/تفعيل + تغيير الدور | ✅ |
| 3.3 | `appointments_management_screen.dart` | كل المواعيد + فلترة + فرض/إكمال/إلغاء | ✅ |
| 3.4 | `deals_management_screen.dart` | الصفقات + إتمام + تسجيل العمولة + ملخّص | ✅ |
| 3.5 | `payments_screen.dart` | موافقة/رفض + تفعيل الباقة + إثبات الدفع | ✅ |
| 3.6 | `reports_screen.dart` | عرض التبليغات + اتخاذ إجراء (تحذير/تجميد/حظر) | ✅ |
| 3.7 | `config_editor_screen.dart` | تعديل النقاط/العمولة/الحصص ديناميكياً (دمج آمن) | ✅ |
| 3.8 | `analytics_screen.dart` | إحصائيات شاملة + أشرطة نسب (بدون مكتبات) | ✅ |
| — | `offers_review_screen.dart` | مراجعة العروض — موجودة مسبقاً (مربوطة بالداشبورد) | ✅ |

**`AdminProvider` تم توسعته بالكامل:** مراجعة عروض · إدارة مستخدمين (`getAllUsers`/`setUserStatus`/`ban`/`freeze`/`activate`/`updateUserRole`/`softDeleteUser`) · مواعيد (`getAllAppointments`/`updateAppointmentStatus`/`forceAppointment`) · صفقات (`getAllDeals`/`createDeal`/`completeDeal`) · مدفوعات (`getAllPayments`/`approvePayment`/`rejectPayment`) · تبليغات (`getAllReports`/`handleReport`) · إحصائيات (`getStats`/`getActionCounts`).

**الدخول:** زر "لوحة الإدارة" في `profile_screen.dart` (يظهر لمن `isAdmin` أي role≥2).

### ✅ المرحلة 4: المنطق الخلفي (مكتملة)
| # | العنصر | التنفيذ | الحالة |
|---|---|---|---|
| 4.1 | Config Loading | `LocalCacheService` (Hive) + `ConfigProvider` كاش-أولاً ثم تحديث من السيرفر + تحميل بالـ Splash | ✅ |
| 4.2 | المطابقة التلقائية | `BusinessService.matchOffersForRequest` (نوع + سعر ±20%) — تظهر للمستخدم عند إضافة طلب عبر BottomSheet | ✅ |
| 4.3 | نظام النقاط | `BusinessService.addPoints` (RPC `add_points` + fallback) + `awardEvent`/`applyPenalty` حسب مفاتيح Config | ✅ |
| 4.4 | الباقات والحصص | `canPublishOffer`/`canPublishRequest` + `offerQuota`/`requestQuota` (pkg → qta) — مطبّقة بشاشة إضافة العرض/الطلب | ✅ |
| 4.5 | Streak System | `registerDailyStreak` + `AuthProvider.registerStreak` — يُستدعى بالـ HomeScreen ويمنح نقاط | ✅ |
| 4.6 | Social Media | `generateSocialPost` + `markSocialPublished` + مشاركة عبر `share_plus` بشاشة تفاصيل العرض | ✅ |
| 4.7 | رفع الصور | `StorageService` موسّع: اختيار (image_picker) + ضغط (flutter_image_compress) + رفع متعدد لـ `offer_images` | ✅ |

> **ملفات جديدة:** `lib/core/services/local_cache_service.dart` · `lib/core/services/business_service.dart`  
> **تبعية جديدة:** `path_provider: ^2.1.2` (لازمة لضغط الصور).  
> **تهيئة:** `LocalCacheService.initialize()` تُستدعى في `main()` قبل `runApp`.

### ✅ المرحلة 5: التحسينات (مكتملة)
| # | العنصر | التنفيذ | الحالة |
|---|---|---|---|
| 5.1 | Realtime Updates | `OfferProvider.subscribeRealtime()` (stream + فلترة يدوية) — مفعّل بالـ HomeScreen مع إلغاء بالـ dispose | ✅ |
| 5.2 | الإشعارات | `notifications_screen.dart` + badge على أيقونة الجرس + الـ Realtime listener موجود بـ NotificationService (محلي). ملاحظة: Push عبر FCM يحتاج Edge Function لاحقاً | ✅ |
| 5.3 | Offline Support | `OfferProvider` كاش-أولاً عبر Hive + لافتة "وضع دون اتصال" + `ConfigProvider` كاش | ✅ |
| 5.4 | Error Handling | `AppErrorWidget`/`EmptyState` محدّثان بالثيم + استخدامهما مع زر إعادة محاولة | ✅ |
| 5.5 | Loading States | `widgets/shimmer_loading.dart` (بطاقات/عناصر/شبكات وهمية) مستخدمة بالشاشات | ✅ |
| 5.6 | Splash Polish | شريط تقدّم + slogan + الانتقال بعد تحميل Config فعلياً (لا تأخير ثابت) | ✅ |

> **ملاحظة Push:** الإشعارات داخل التطبيق + Realtime + المحلية تعمل. إشعارات FCM الخارجية (والتطبيق مغلق) تتطلب Edge Function + مفتاح FCM — تُؤجَّل لمرحلة لاحقة عند الحاجة.

### ✅ المرحلة 6: البناء والنشر (مُجهّزة)
| # | العنصر | التنفيذ | الحالة |
|---|---|---|---|
| 6.1 | إعداد Android | إزالة Firebase/google-services من Gradle · `applicationId=com.sweeda.realestate` · توقيع release عبر `key.properties` · `minify+shrink` + `proguard-rules.pro` · نقل MainActivity للـ package الجديد | ✅ |
| 6.2 | إعداد iOS | `bundle id=com.sweeda.realestate` · أذونات Info.plist (صور/كاميرا) بالعربي · لغة افتراضية ar | ✅ |
| 6.3 | المراجعة الأمنية | `docs/SECURITY_REVIEW.md` (RLS · مفاتيح · توقيع · توصيات) | ✅ |
| 6.4 | دليل البناء | `BUILD_GUIDE.md` خطوة بخطوة (Android/iOS/Supabase + مشاكل شائعة) | ✅ |
| 6.5 | حماية الأسرار | `.gitignore` يستثني keystore/key.properties/google-services.json/.env | ✅ |

> **⚠️ يتبقّى على الجهاز المحلي:** تنفيذ `flutter build apk/appbundle/ipa` فعلياً + إنشاء keystore + الرفع للمتاجر + تطبيق ترقيات RLS الإدارية (انظر SECURITY_REVIEW). لا يمكن تنفيذ أوامر البناء ضمن البيئة السحابية (لا يوجد Flutter SDK).

---

## 🗄️ مرجع Supabase السريع

### الجداول (13)
`users` · `offers` · `requests` · `appointments` · `notifications` · `payments` · `reports` · `deals` · `activity_log` · `stats` · `app_config` · `otp_codes` · `user_devices`

### الدوال (12)
راجع: `supabase/FUNCTIONS_REFERENCE.md`

### Realtime
`offers` · `notifications` · `appointments` · `deals` · `requests`

### Storage
`offer_images` (Public bucket)

---

## 🏗️ بنية المشروع

```
lib/
├── main.dart                    # Supabase.init() + runApp()
├── app.dart                     # MultiProvider + MaterialApp.router
├── core/
│   ├── constants/db_constants.dart
│   ├── network/supabase_service.dart
│   ├── router/app_router.dart   # 30 مسار
│   ├── services/                # business_service + local_cache_service (Hive)
│   ├── theme/app_theme.dart     # Luxury Dark + RTL
│   └── utils/app_utils.dart
├── models/                      # 10 ملفات
├── providers/                   # 9 ملفات
├── services/                    # auth, storage(+ضغط/رفع), notification
├── screens/
│   ├── splash/splash_screen.dart         ✅
│   ├── visitor/  (3 شاشات)               ✅
│   ├── auth/     (3 شاشات)               ✅
│   ├── user/     (9 شاشات)               ✅ المرحلة 1 + الإشعارات
│   ├── broker/   (5 شاشات)               ✅ المرحلة 2 كاملة
│   └── admin/    (9 شاشات)               ✅ المرحلة 3 كاملة
└── widgets/                       # 11 ويدجت (+ shimmer_loading)
```

---

## 🛠️ أوامر العمل

```bash
git pull origin main
flutter pub get
flutter run                    # تشغيل
flutter run -d chrome          # Chrome
flutter build apk --release    # APK
flutter analyze                # فحص أخطاء
```

---

## ✅ Checklist

- [x] flutter pub get بدون أخطاء
- [x] التطبيق بقلع وشاشة Splash بتظهر
- [x] OTP fallback بيشتغل
- [x] **WhatsApp OTP عبر Edge Function (Meta Cloud API)** — `feature/whatsapp-email-auth`
- [x] **Email Magic Link** بديل (Supabase Auth + Deep Link) — `feature/whatsapp-email-auth`
- [x] شاشة Login بتبويبتين (واتساب/إيميل) — `feature/whatsapp-email-auth`
- [x] RPCs الجديدة: `generate_otp_v2`, `verify_otp_v2`, `upsert_user_after_otp`, `get_user_by_email`
- [x] راجع `docs/AUTH_SETUP.md` لخطوات التفعيل الكاملة
- [x] شاشات المرحلة 1 كاملة
- [x] BottomNavigationBar يعمل
- [x] كل المسارات بالـ Router محددة
- [x] المرحلة 2: لوحة السمسار (4 شاشات + ربط)
- [x] المرحلة 3: لوحة الإدارة (9 شاشات + AdminProvider موسّع)
- [x] المرحلة 4: المنطق الخلفي (Config/Hive + نقاط + باقات + مطابقة + Streak + سوشال + صور)
- [x] المرحلة 5: التحسينات (Realtime + إشعارات + Offline + Shimmer + Splash)
- [x] المرحلة 6: البناء والنشر (تجهيز Gradle/توقيع/أمان/دليل — يتبقّى تنفيذ البناء محلياً)
