<div dir="rtl">

# 🏛️ عقارات السويداء — مكتب عقاري إلكتروني

> ✅ **جاهز للتطوير** — جميع النقاط معتمدة، المواصفات كاملة، جاهز للتسليم للمبرمج.

تطبيق موبايل لمكتب عقاري إلكتروني خاص بمحافظة السويداء (مبدئياً)، يتيح تصفّح وعرض العقارات والسيارات (بيعاً وإيجاراً)، حجز مواعيد المعاينة، ونشر الطلبات — مع لوحات إدارة للمكتب والسماسرة.

---

## 🧭 نظرة عامة

| العنصر | القرار |
|---|---|
| النوع | تطبيق موبايل (Android / iOS) |
| الواجهة | عربية بالكامل، اتجاه RTL، خط Cairo |
| الأدوار | زائر · مستخدم · سمسار · إدارة |
| الـ Backend | Firebase (Firestore + Phone Auth + FCM + Cloud Functions) |
| التحقق | OTP عبر رقم الموبايل |
| الإشعارات | خارجية عبر FCM + داخلية |
| التقنية | Flutter (للنسخة النهائية) |
| الإصدار المستهدف | Android (API 24+) · iOS (15+) |

---

## 📂 بنية المستودع

```
sweeda-real-estate-office-elc/
│
├── README.md                  ← هذا الملف
│
├── docs/
│   ├── SPEC.md                ← 📄 مستند المواصفات النهائي (جميع النقاط معتمدة)
│   └── locations.json         ← 📍 قائمة المناطق (معتمدة)
│
├── prototype/                 ← 🎨 نموذج واجهة تفاعلي (HTML)
│   ├── index.html
│   └── app.js
│
├── lib/                       ← 📱 كود Flutter الأساسي
│   ├── main.dart              ← نقطة الدخول
│   ├── app.dart               ← إعداد التطبيق (MaterialApp, RTL, Theme)
│   ├── core/                  ← ⚙️ بنية أساسية
│   │   ├── config/            ← تحميل وتخزين Config
│   │   ├── theme/             ← الثيم (Cairo, RTL, ألوان)
│   │   ├── constants/         ← ثوابت عامة
│   │   ├── network/           ← إعداد Firebase Services
│   │   └── utils/             ← أدوات مساعدة (تنسيق, تحقق, إلخ)
│   ├── models/                ← 🧠 نماذج البيانات
│   │   ├── user_model.dart
│   │   ├── offer_model.dart
│   │   ├── request_model.dart
│   │   ├── appointment_model.dart
│   │   ├── notification_model.dart
│   │   ├── payment_model.dart
│   │   ├── report_model.dart
│   │   ├── deal_model.dart
│   │   └── config_model.dart
│   ├── providers/             ← 🔄 إدارة الحالة (State Management)
│   │   ├── auth_provider.dart
│   │   ├── config_provider.dart
│   │   ├── offer_provider.dart
│   │   ├── request_provider.dart
│   │   ├── appointment_provider.dart
│   │   ├── notification_provider.dart
│   │   ├── payment_provider.dart
│   │   └── admin_provider.dart
│   ├── services/              ← 🔌 خدمات Firebase و Cloud Functions
│   │   ├── auth_service.dart
│   │   ├── firestore_service.dart
│   │   ├── cloud_functions_service.dart
│   │   ├── notification_service.dart
│   │   └── storage_service.dart
│   ├── screens/               ← 📺 الشاشات
│   │   ├── visitor/           ← شاشات الزائر
│   │   │   ├── home_screen.dart
│   │   │   ├── offer_detail_screen.dart
│   │   │   └── search_screen.dart
│   │   ├── auth/              ← شاشات تسجيل الدخول
│   │   │   ├── login_screen.dart
│   │   │   └── otp_verification_screen.dart
│   │   ├── user/              ← شاشات المستخدم
│   │   │   ├── user_home_screen.dart
│   │   │   ├── my_offers_screen.dart
│   │   │   ├── my_requests_screen.dart
│   │   │   ├── my_appointments_screen.dart
│   │   │   ├── add_offer_screen.dart
│   │   │   ├── add_request_screen.dart
│   │   │   ├── favorites_screen.dart
│   │   │   ├── profile_screen.dart
│   │   │   └── settings_screen.dart
│   │   ├── broker/            ← شاشات السمسار/الوسيط
│   │   │   ├── broker_dashboard_screen.dart
│   │   │   ├── broker_offers_screen.dart
│   │   │   ├── broker_appointments_screen.dart
│   │   │   ├── broker_deals_screen.dart
│   │   │   └── broker_stats_screen.dart
│   │   └── admin/             ← شاشات الإدارة
│   │       ├── admin_dashboard_screen.dart
│   │       ├── users_management_screen.dart
│   │       ├── offers_review_screen.dart
│   │       ├── appointments_management_screen.dart
│   │       ├── deals_management_screen.dart
│   │       ├── payments_screen.dart
│   │       ├── reports_screen.dart
│   │       ├── config_editor_screen.dart
│   │       └── analytics_screen.dart
│   └── widgets/               ← 🔧 ويدجت مشتركة
│       ├── custom_app_bar.dart
│       ├── bottom_nav_bar.dart
│       ├── offer_card.dart
│       ├── loading_widget.dart
│       ├── empty_state.dart
│       ├── error_widget.dart
│       ├── image_slider.dart
│       ├── filter_bar.dart
│       └── role_switcher.dart
│
├── functions/                 ← 🔥 Cloud Functions
│   ├── index.js               ← جميع الدوال
│   ├── package.json
│   └── .eslintrc.js
│
├── pubspec.yaml               ← ملف اعتماديات Flutter
├── analysis_options.yaml      ← إعدادات التحليل
├── .gitignore
└── firebase.json              ← إعدادات Firebase (لاحقاً)
```

---

## ✅ حالة العمل — جميع النقاط معتمدة

> المشروع الآن في **مرحلة جاهز للتطوير (Ready for Dev)**.

| النقطة | الحالة |
|---|---|
| النقطة 1: الزائر | ✅ معتمدة |
| النقطة 2: المستخدم والتفعيل (OTP) | ✅ معتمدة |
| النقطة 3: الهيكل العام للواجهة | ✅ معتمدة |
| النقطة 4: تبويب العروض | ✅ معتمدة |
| النقطة 5: تبويب الطلبات | ✅ معتمدة |
| النقطة 6: رفع العرض والمراجعة | ✅ معتمدة |
| النقطة 7: حجز المواعيد | ✅ معتمدة |
| النقطة 8: موافقة الوسيط وصاحب العرض | ✅ معتمدة |
| النقطة 9: الوسيط ولوحته | ✅ معتمدة |
| النقطة 10: لوحة الإدارة والصلاحيات | ✅ معتمدة |
| النقطة 11: الإشعارات (داخلية + FCM) | ✅ معتمدة |
| النقطة 12: هيكل Firestore + Config | ✅ معتمد |

📄 راجع [docs/SPEC.md](docs/SPEC.md) للمواصفات الكاملة.

---

## 🚀 تجربة النموذج

افتح `prototype/index.html` في المتصفح لتجربة محاكاة واجهات التطبيق
(شريط تبديل الأدوار أسفل يمين الشاشة: زائر / مستخدم / سمسار / إدارة).

> ⚠️ النموذج للتصوّر والتجربة فقط (بيانات وهمية)، وليس التطبيق النهائي.

---

## 🛠️ بدء التطوير

### المتطلبات

- Flutter SDK (>= 3.10)
- Firebase project (مُفعّل: Firestore, Authentication, Cloud Functions, FCM, Storage)
- Android Studio / VS Code

### الخطوات الأولى

```bash
# 1. تثبيت الاعتماديات
flutter pub get

# 2. إعداد Firebase
#    - ضع google-services.json في android/app/
#    - ضع GoogleService-Info.plist في ios/Runner/

# 3. تشغيل التطبيق
flutter run
```

---

## 📜 الترخيص

جميع الحقوق محفوظة © 2026 — مشروع عقارات السويداء.

</div>