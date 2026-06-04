# 🚀 دليل التطوير — عقارات السويداء

> **آخر تحديث:** 2026-06-04  
> **المستودع:** https://github.com/hady-albnnai/sweeda-real-estate-office-elc

---

## 📊 الحالة الحالية

| العنصر | الحالة | الملاحظات |
|---|---|---|
| السيرفر (Supabase) | ✅ 100% | 13 جدول + 12 دالة RPC + RLS + Realtime |
| الموديلات | ✅ 100% | 10 ملفات بأسماء حقول قصيرة |
| الـ Providers | ✅ 100% | 8 ملفات |
| الـ Services | ✅ 100% | auth, storage, notification |
| الشاشات الجاهزة | ✅ | splash, visitor(3), auth(3), user(2), broker(1), admin(1) |
| الشاشات stubs | ⏳ | ~20 شاشة بـ "قيد التطوير" |
| الـ Router | ✅ 100% | 21 مسار منظم |

---

## ⚠️ ملاحظات حرجة

### 1. desc → descript
كلمة `desc` محجوزة بـ PostgreSQL. تم تغييرها لـ `descript`:
- جدول offers → عمود descript
- lib/models/offer_model.dart → حقل descript

### 2. Supabase Stream API
الـ stream ما بيقبل `.eq()` أو `.match()` أو `.filter()` مباشرة.
الحل الصحيح:

```dart
client.from(DbTables.offers)
    .stream(primaryKey: ['id'])
    .listen((data) {
  for (var row in data) {
    if ((row['i_pub'] ?? 0) == 1 && (row['i_del'] ?? 0) == 0) {
      // process row
    }
  }
});
```

### 3. التوكنات
- anon key: موجود في lib/main.dart و lib/app.dart
- service_role: لا تشاركه أبداً
- Project URL: https://vsgkgnjtebjxyqwpuopz.supabase.co

### 4. الملفات المحذوفة (Firebase)
- firebase.json ❌
- functions/ ❌
- firebase_options.dart ❌
- lib/services/firestore_service.dart ❌
- lib/services/cloud_functions_service.dart ❌

---

## 🗺️ خطة العمل

### المرحلة 1: شاشات المستخدم ⏳ الأولوية القصوى
1. `user_home_screen.dart` — شاشة رئيسية (3 تبويبات + BottomNavBar)
2. `my_requests_screen.dart` — طلباتي + إضافة طلب
3. `my_appointments_screen.dart` — مواعيدي + إلغاء
4. `favorites_screen.dart` — المفضلة (Hive محلي)
5. `profile_screen.dart` — الملف الشخصي + البادج + النقاط
6. `settings_screen.dart` — الإعدادات + خروج
7. `add_request_screen.dart` — نموذج إضافة طلب
8. `bottom_nav_bar.dart` — ربط كل الشاشات

### المرحلة 2: لوحة السمسار ⏳
1. `broker_dashboard_screen.dart` — إحصائيات سريعة
2. `broker_offers_screen.dart` — عروض العملاء
3. `broker_deals_screen.dart` — الصفقات
4. `broker_stats_screen.dart` — رسوم بيانية

### المرحلة 3: لوحة الإدارة ⏳
1. `admin_dashboard_screen.dart`
2. `users_management_screen.dart`
3. `appointments_management_screen.dart`
4. `deals_management_screen.dart`
5. `payments_screen.dart`
6. `reports_screen.dart`
7. `config_editor_screen.dart`
8. `analytics_screen.dart`

### المرحلة 4: المنطق الخلفي ⏳
1. Config Loading + Hive Cache
2. المطابقة التلقائية (RPC)
3. نظام النقاط + البادجات
4. نظام الباقات
5. Streak System
6. Social Media auto-post
7. رفع الصور (Supabase Storage)

### المرحلة 5: التحسينات ⏳
1. Realtime Updates
2. Push Notifications (FCM)
3. Offline Support (Hive)
4. Error Handling + Empty States
5. Shimmer Loading
6. RTL Polish
7. Splash Polish

### المرحلة 6: البناء والنشر ⏳
1. Android APK + Bundle
2. iOS IPA
3. Security Review
4. Testing شامل

---

## 🗄️ مرجع Supabase السريع

### الجداول (13)
users | offers | requests | appointments | notifications | payments | reports | deals | activity_log | stats | app_config | otp_codes | user_devices

### الدوال RPC (12)
generate_otp | verify_otp | create_user_from_phone | get_user_by_phone | check_offer_duplicate | calculate_commission | update_user_badge | get_pending_offers_count | add_points | soft_delete | expire_offers | send_appointment_reminders

### Realtime
offers | notifications | appointments | deals | requests

### Storage
offer_images (Public bucket)

---

## 🏗️ بنية المشروع

```
lib/
├── main.dart                      # Supabase.init() + runApp()
├── app.dart                       # MultiProvider + MaterialApp.router
├── core/
│   ├── constants/db_constants.dart
│   ├── network/supabase_service.dart
│   ├── router/app_router.dart     # 21 مسار
│   ├── theme/app_theme.dart
│   └── utils/app_utils.dart
├── models/                        # 10 ملفات
├── providers/                     # 8 ملفات
├── services/                      # auth, storage, notification
├── screens/
│   ├── splash/splash_screen.dart
│   ├── visitor/  (3)
│   ├── auth/     (3)
│   ├── user/     (2 + stubs)
│   ├── broker/   (1 + stubs)
│   └── admin/    (1 + stubs)
└── widgets/                       # 9 ويدجت
```

---

## 🛠️ أوامر العمل

```bash
git pull origin main       # تحديث
flutter pub get            # اعتماديات
flutter run                # تشغيل
flutter run -d chrome      # Chrome
flutter build apk --release  # APK
flutter analyze            # فحص أخطاء
```

---

## 📁 الملفات المرجعية بالمستودع

| الملف | المحتوى |
|---|---|
| `DEVELOPMENT_GUIDE.md` | هذا الملف — دليل شامل |
| `docs/SPEC.md` | المواصفات التقنية الكاملة |
| `docs/PROJECT_PLAN.md` | الخطة الزمنية التفصيلية |
| `docs/locations.json` | مناطق السويداء |
| `supabase/setup.sql` | SQL كامل للجداول + الدوال |
| `supabase/SERVER_DOCS.md` | توثيق السيرفر |
| `README.md` | نظرة عامة |

---

## ✅ Checklist

- [ ] flutter pub get بدون أخطاء
- [ ] flutter analyze بدون أخطاء حمراء
- [ ] التطبيق بقلع وشاشة Splash بتظهر
- [ ] OTP fallback بيشتغل
- [ ] الصفحة الرئيسية بتعرض العروض
- [ ] ما في أي مرجع لـ Firebase بالكود
- [ ] كل الشاشات stubs بتفتح بدون crash

---
> 💡 نصيحة: ابدأ بالمرحلة 1 (شاشات المستخدم). كل شاشة جديدة، سوّي stub أول بعدين املأها ببيانات Supabase.
