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
| **التحقق** | طريقتان: **WhatsApp OTP** (Meta Cloud API عبر Edge Function) + **Email Magic Link** (Supabase Auth) — مع dev fallback |
| **الإشعارات** | داخلية (Realtime) + خارجية (Firebase FCM — للتطبيق المغلق) |
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
│   ├── providers/                 ← 9 ملفات
│   ├── services/                  ← auth, storage(+ضغط/رفع), notification
│   ├── core/services/             ← business_service, local_cache_service (Hive)
│   ├── screens/                   ← splash, visitor, auth, user(8), broker(5), admin(9)
│   └── widgets/                   ← ويدجت مشتركة
├── prototype/                     ← نموذج HTML
├── assets/                        ← صور + أيقونات
└── android/ ios/ web/ linux/ macos/ windows/
```

---

## 🗄️ بنية Supabase

### الجداول (13 جدول)
`users` · `offers` · `requests` · `appointments` · `notifications` · `payments` · `reports` · `deals` · `activity_log` · `stats` · `app_config` · `otp_codes` · `user_devices`

### الدوال (33 دالة RPC)
`generate_otp` · `verify_otp` · `generate_otp_v2` · `verify_otp_v2` · `upsert_user_after_otp` · `get_user_by_email` · `create_user_from_phone` · `get_user_by_phone` · `check_offer_duplicate` · `calculate_commission` · `update_user_badge` · `get_pending_offers_count` · `add_points` · `soft_delete` · `expire_offers` · `send_appointment_reminders` + الدوال التلقائية (Triggers) و `send_push_notification`

**Edge Functions:** `send-whatsapp-otp` · `verify-whatsapp-otp` (راجع `docs/AUTH_SETUP.md` للتفعيل)

### Realtime
`offers` · `notifications` · `appointments` · `deals` · `requests`

### Storage
`offer_images` (Public bucket)

---


### الإدارة الداخلية والصلاحيات

تمت إضافة توثيق ومسارات للإدارة الداخلية:

- [`docs/INTERNAL_MANAGEMENT_ADAPTATION_PLAN.md`](docs/INTERNAL_MANAGEMENT_ADAPTATION_PLAN.md)
- [`docs/INTERNAL_MANAGEMENT_TEST_CHECKLIST.md`](docs/INTERNAL_MANAGEMENT_TEST_CHECKLIST.md)
- شاشة عمليات المكتب: `/admin/office-operations`
- شاشة إدارة الصلاحيات: `/admin/permissions`
- شاشة إدارة الوسائط والتصوير: `/admin/media-review`

> إذا كانت دالة الصلاحيات منفذة على السيرفر قبل إضافة إدارة الوسائط، نفّذ migration:
> `supabase/migrations/2026_06_10_add_media_review_permission.sql`

---

## 🚀 بدء التطوير

```bash
flutter pub get
flutter analyze
flutter run
```

للبناء للإنتاج (APK / App Bundle / iOS) راجع الدليل الكامل: [`BUILD_GUIDE.md`](BUILD_GUIDE.md)

---

## 📋 حالة المشروع

راجع [`docs/PROJECT_PLAN.md`](docs/PROJECT_PLAN.md) للخطة التفصيلية.

| المرحلة | الحالة |
|---|---|
| ✅ السيرفر (Supabase) | مكتمل |
| ✅ التنظيف (Firebase → Supabase) | مكتمل |
| ✅ شاشة السبلاش | مكتملة |
| ✅ المرحلة 1: شاشات المستخدم (**13 شاشة**) | مكتملة |
| ✅ المرحلة 2: لوحة السمسار (5 شاشات) | مكتملة |
| ✅ المرحلة 3: لوحة الإدارة (9 شاشات) | مكتملة |
| ✅ المرحلة 4: المنطق الخلفي (نقاط/باقات/مطابقة/streak/سوشال/صور) | مكتملة |
| ✅ المرحلة 5: التحسينات (Realtime/إشعارات/Offline/Shimmer/Splash) | مكتملة |
| ✅ المرحلة 6: إعداد البناء والأمان (Gradle/توقيع/iOS/دليل) | مُجهّزة |
| ✅ **المرحلة 7: المصادقة (WhatsApp OTP + Email Magic Link)** | مكتملة |
| ✅ **المرحلة 8: استكمال الشاشات المتبقية (packages/payment/edit/broker/request)** | مكتملة |
| ✅ **المرحلة 9: إصلاحات ما بعد الاختبار + إضافات** | مكتملة |
| ✅ **المرحلة 10 (A→E2+): مزايا متقدّمة (إقرار/spd/فيديو/خريطة/cron/FCM/triggers)** | مكتملة |
| ✅ **المرحلة 11: نظام قنوات الدفع اليدوي (Config-driven)** | مكتملة |
| ⏳ تنفيذ البناء والنشر للمتاجر | محلياً |

> **الإجمالي:** 38 شاشة · ~98% اكتمال · يتبقّى البناء فقط
> **التفاصيل:** [`docs/SCREENS_AUDIT.md`](docs/SCREENS_AUDIT.md) · [`docs/AUTH_SETUP.md`](docs/AUTH_SETUP.md)

> **للبناء والنشر:** راجع [`BUILD_GUIDE.md`](BUILD_GUIDE.md) · **للأمان:** [`docs/SECURITY_REVIEW.md`](docs/SECURITY_REVIEW.md)

---

جميع الحقوق محفوظة © 2026 — مشروع عقارات السويداء
