# 🚀 دليل التطوير — عقارات السويداء

> **آخر تحديث:** 2026-06-04  
> **Commit الحالي:** المرحلة 1 ✅ مكتملة  
> **المستودع:** https://github.com/hady-albnnai/sweeda-real-estate-office-elc

---

## 📊 الحالة الحالية

| العنصر | الحالة | التفاصيل |
|---|---|---|
| **السيرفر (Supabase)** | ✅ 100% | 13 جدول + 12 دالة RPC + RLS + Realtime |
| **الموديلات** | ✅ 100% | 10 ملفات |
| **الـ Providers** | ✅ 100% | 8 ملفات (+ cancelAppointment) |
| **الـ Services** | ✅ 100% | auth, storage, notification |
| **الـ Router** | ✅ 100% | 30 مسار |
| **🎬 المرحلة 0: الأساس** | ✅ مكتملة | Splash + Firebase removal |
| **👤 المرحلة 1: شاشات المستخدم** | ✅ مكتملة | 8 شاشات + BottomNavBar |
| **🤝 المرحلة 2: لوحة السمسار** | ⏳ لم تبدأ | 4 شاشات stub |
| **🛡️ المرحلة 3: لوحة الإدارة** | ⏳ لم تبدأ | 8 شاشات stub |
| **⚙️ المرحلة 4: المنطق الخلفي** | ⏳ لم تبدأ | Config + نقاط + باقات + صور |
| **✨ المرحلة 5: التحسينات** | ⏳ لم تبدأ | Realtime + Push + Offline |
| **📦 المرحلة 6: البناء** | ⏳ لم تبدأ | APK + Testing |

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

### 📌 المرحلة 2: لوحة السمسار
| # | الملف | الوصف |
|---|---|---|
| 2.1 | `broker_dashboard_screen.dart` | لوحة تحكم + إحصائيات سريعة |
| 2.2 | `broker_offers_screen.dart` | عروض العملاء المرتبطين |
| 2.3 | `broker_deals_screen.dart` | الصفقات النشطة والمكتملة |
| 2.4 | `broker_stats_screen.dart` | رسوم بيانية تفصيلية |

### 📌 المرحلة 3: لوحة الإدارة
| # | الملف | الوصف |
|---|---|---|
| 3.1 | `admin_dashboard_screen.dart` | لوحة الإدارة الرئيسية |
| 3.2 | `users_management_screen.dart` | إدارة المستخدمين (حظر/تجميد) |
| 3.3 | `appointments_management_screen.dart` | إدارة جميع المواعيد |
| 3.4 | `deals_management_screen.dart` | الصفقات + العمولات + استمارة المندوب |
| 3.5 | `payments_screen.dart` | إدارة المدفوعات + الموافقة/الرفض |
| 3.6 | `reports_screen.dart` | عرض التبليغات + اتخاذ إجراء |
| 3.7 | `config_editor_screen.dart` | تعديل إعدادات التطبيق ديناميكياً |
| 3.8 | `analytics_screen.dart` | الإحصائيات الشاملة + رسوم بيانية |

### 📌 المرحلة 4: المنطق الخلفي
| # | العنصر | الوصف |
|---|---|---|
| 4.1 | Config Loading | تحميل Config من app_config + تخزين Hive |
| 4.2 | المطابقة التلقائية | RPC: مطابقة الطلبات بالعروض |
| 4.3 | نظام النقاط | RPC: add_points + update_user_badge |
| 4.4 | نظام الباقات | مجاني/فضي/ذهبي + حدود النشر |
| 4.5 | Streak System | تسجيل دخول يومي متتالي |
| 4.6 | Social Media | توليد نص المنشور تلقائياً |
| 4.7 | رفع الصور | Supabase Storage offer_images + ضغط |

### 📌 المرحلة 5: التحسينات
| # | العنصر | الوصف |
|---|---|---|
| 5.1 | Realtime Updates | تحديث فوري (Supabase stream) |
| 5.2 | Push Notifications | FCM + Edge Functions |
| 5.3 | Offline Support | Hive caching |
| 5.4 | Error Handling | معالجة أخطاء + حالات فارغة |
| 5.5 | Loading States | Shimmer animations |
| 5.6 | Splash Polish | Progress bar + native splash |

### 📌 المرحلة 6: البناء والنشر
| # | العنصر |
|---|---|
| 6.1 | Android APK + App Bundle |
| 6.2 | iOS IPA + TestFlight |
| 6.3 | Security Review (RLS + API keys) |
| 6.4 | Testing شامل |

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
│   ├── theme/app_theme.dart     # Luxury Dark + RTL
│   └── utils/app_utils.dart
├── models/                      # 10 ملفات
├── providers/                   # 8 ملفات
├── services/                    # auth, storage, notification
├── screens/
│   ├── splash/splash_screen.dart         ✅
│   ├── visitor/  (3 شاشات)               ✅
│   ├── auth/     (3 شاشات)               ✅
│   ├── user/     (8 شاشات)               ✅ المرحلة 1 كاملة
│   ├── broker/   (1 شاشة + 4 stubs)      ⏳
│   └── admin/    (1 شاشة + 8 stubs)      ⏳
└── widgets/                       # 10 ويدجت
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
- [x] شاشات المرحلة 1 كاملة
- [x] BottomNavigationBar يعمل
- [x] كل المسارات بالـ Router محددة
- [ ] المرحلة 2: لوحة السمسار
- [ ] المرحلة 3: لوحة الإدارة
- [ ] المرحلة 4: المنطق الخلفي
- [ ] المرحلة 5: التحسينات
- [ ] المرحلة 6: البناء والنشر
