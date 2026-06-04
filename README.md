# 🏛️ عقارات السويداء — مكتب عقاري إلكتروني

> تطبيق موبايل (Flutter) + Backend (Supabase PostgreSQL)

تطبيق لمكتب عقاري إلكتروني خاص بمحافظة السويداء، يتيح تصفّح وعرض العقارات والسيارات (بيعاً وإيجاراً)، حجز مواعيد المعاينة، ونشر الطلبات — مع لوحات إدارة للمكتب والسماسرة.

---

## 🧭 نظرة عامة

| العنصر | القرار |
|---|---|
| **النوع** | تطبيق موبايل (Android / iOS) |
| **الواجهة** | عربية بالكامل، اتجاه RTL، خط Cairo |
| **الأدوار** | زائر · مستخدم · سمسار · إدارة |
| **الـ Backend** | Supabase (PostgreSQL + Auth + Realtime + Storage + RPC Functions) |
| **التحقق** | OTP عبر رقم الموبايل (Supabase Auth + RPC fallback) |
| **الإشعارات** | Realtime listener + Push Notifications |
| **التقنية** | Flutter + Supabase + Provider + GoRouter |
| **الإصدار المستهدف** | Android (API 24+) · iOS (15+) |

---

## 📂 بنية المستودع

```
sweeda-real-estate-office-elc/
├── docs/
│   ├── SPEC.md                    ← المواصفات الكاملة
│   ├── PROJECT_PLAN.md            ← خطة المشروع التفصيلية
│   └── locations.json             ← مناطق السويداء
├── supabase/
│   ├── setup.sql                  ← الجداول + الدوال + RLS + Config
│   └── SERVER_DOCS.md             ← توثيق السيرفر
├── lib/
│   ├── main.dart                  ← Supabase init
│   ├── app.dart                   ← Providers + MaterialApp
│   ├── core/                      ← constants, network, router, theme, utils
│   ├── models/                    ← 10 ملفات
│   ├── providers/                 ← 8 ملفات
│   ├── services/                  ← auth, storage, notification
│   ├── screens/                   ← splash, visitor, auth, user, broker, admin
│   └── widgets/                   ← ويدجت مشتركة
├── prototype/                     ← نموذج HTML
├── assets/                        ← صور + أيقونات
└── android/ ios/ web/ linux/ macos/ windows/
```

---

## 🗄️ بنية Supabase

### الجداول (13 جدول)
`users` · `offers` · `requests` · `appointments` · `notifications` · `payments` · `reports` · `deals` · `activity_log` · `stats` · `app_config` · `otp_codes` · `user_devices`

### الدوال (12 دالة RPC)
`generate_otp` · `verify_otp` · `create_user_from_phone` · `get_user_by_phone` · `check_offer_duplicate` · `calculate_commission` · `update_user_badge` · `get_pending_offers_count` · `add_points` · `soft_delete` · `expire_offers` · `send_appointment_reminders`

### Realtime
`offers` · `notifications` · `appointments` · `deals` · `requests`

### Storage
`offer_images` (Public bucket)

---

## 🚀 بدء التطوير

```bash
flutter pub get
flutter run
```

---

## 📋 حالة المشروع

راجع [`docs/PROJECT_PLAN.md`](docs/PROJECT_PLAN.md) للخطة التفصيلية.

| المرحلة | الحالة |
|---|---|
| ✅ السيرفر (Supabase) | مكتمل |
| ✅ التنظيف (Firebase → Supabase) | مكتمل |
| ✅ شاشة السبلاش | مكتملة |
| ⏳ شاشات المستخدم | قيد التنفيذ |

---

جميع الحقوق محفوظة © 2026 — مشروع عقارات السويداء
