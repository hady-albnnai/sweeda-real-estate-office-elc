# 📋 خطة المشروع — عقارات السويداء

> **آخر تحديث:** 2026-06-06  
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
| ✅ **المرحلة 10 (A+B): المزايا الناقصة Critical** | **مكتملة** | إقرار + صورة هوية + صورة سند + تبليغ + ربط pen + stats triggers + wk_lgn + referral | — |
| ✅ **المرحلة 10 (C): ترقيات العروض spd** | **مكتملة** | shaشة boost + 5 ترقيات (ren/pin/bst/dsc5/fms) + شارات + ترتيب تلقائي | — |
| ✅ **المرحلة 10 (D): فيديو + خريطة + admin user details** | **مكتملة** | video_player+chewie + flutter_map+geolocator + شاشة UserDetails بـ 4 tabs | — |
| ✅ **المرحلة 10 (E1): Cron Jobs (pg_cron)** | **مكتملة** | 3 jobs نشطة: expire_offers + expire_boosts (يومياً) + reminders (كل ساعة) | — |
| ✅ **المرحلة 10 (E2): Firebase FCM** | **مكتملة** | Push Notifications تعمل 100% — Edge Function منشورة + Firebase project مفعّل + Service Account + أيقونة ذهبية + navigation + حفظ تلقائي في DB | — |
| ✅ **المرحلة 10 (E2+): ربط الإشعارات بالأحداث** | **مكتملة** | 6 Triggers + 7 دوال — موافقة/رفض عرض، حجز موعد، إكمال صفقة، موافقة دفعة، مطابقة عرض-طلب | — |
| ✅ **المرحلة 11: نظام قنوات الدفع** | **مكتملة** | 4 قنوات (الهرم + شام كاش + رصيد + بنك) Config-driven + شاشة إدارة + Migration #8 (channel + Storage buckets) + payment_screen ديناميكية + admin proof viewer | راجع `docs/PAYMENT_CHANNELS_PLAN.md` |
| ⏳ **المرحلة 12: أتمتة قبول الدفعات** | **قيد التخطيط** | دورة الاعتماد (Approval Workflow) → تحديث حالة الطلب → تحديث رصيد المستخدم تلقائياً → إشعار FCM | المرحلة القادمة |
| ⏳ **المرحلة 10 (E3): نشر سوشيال تلقائي** | **مؤجّلة** | Edge Function لنشر العروض المعتمدة على Facebook | يحتاج صفحة FB خارج سوريا |
| ⏸️ **WhatsApp Production (Meta 555)** | **مؤجّلة** | الكود جاهز 100% — مؤجّلة لحين إنشاء صفحة FB خارج سوريا للاستفادة من ميزات الإعلان والربح | راجع `docs/WHATSAPP_ACTIVATION_PLAN.md` |

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

### الجزء C: ترقيات العروض (spd)
| # | الميزة | التنفيذ |
|---|---|---|
| 10.9 | **ترقيات العروض (spd)** | شاشة `boost_offer_screen` + 5 ترقيات (ren/pin/bst/dsc5/fms) + شارات على البطاقة + ترتيب تلقائي |
| 10.10 | RPC `purchase_offer_boost` | يخصم النقاط + يفعّل الترقية + يسجّل في activity_log |
| 10.11 | RPC `expire_offer_boosts` | تُلغي الترقيات المنتهية تلقائياً (cron) |

> Migration: `supabase/migrations/2026_06_05_offer_boosts.sql`

### الجزء D: فيديو + خريطة + admin user details
| # | الميزة | التنفيذ |
|---|---|---|
| 10.12 | **فيديو للعرض** (`vdo`) | `video_player + chewie` + رفع في add_offer Step 3 + عرض في offer_detail |
| 10.13 | **خريطة + موقع دقيق** (`exact_loc`) | `flutter_map + latlong2 + geolocator` + LocationPicker + LocationViewer (OpenStreetMap مجاني) |
| 10.14 | **شاشة تفاصيل المستخدم للإدارة** | `user_details_screen` بـ 4 tabs (عروض/مواعيد/تبليغات/نشاط) + chips للحالة + اتصال/واتساب |

### الجزء E1: Cron Jobs (pg_cron)
| # | الميزة | التنفيذ |
|---|---|---|
| 10.15 | **pg_cron extension** | مفعّل على السيرفر |
| 10.16 | `daily-expire-offers` | يومياً 03:00 UTC → `expire_offers()` |
| 10.17 | `daily-expire-boosts` | يومياً 03:05 UTC → `expire_offer_boosts()` |
| 10.18 | `hourly-appointment-reminders` | كل ساعة → `send_appointment_reminders()` |

> Migration: `supabase/migrations/2026_06_05_cron_jobs.sql`

### الجزء E2: Firebase FCM Push Notifications
| # | الميزة | التنفيذ |
|---|---|---|
| 10.19 | **Firebase Project مفعّل** | sweeda-real-estate-elc — package `com.sweeda.realestate` |
| 10.20 | **google-services.json** | مرفوع في `android/app/google-services.json` |
| 10.21 | **Gradle plugin** | `com.google.gms.google-services 4.4.2` في settings + app |
| 10.22 | **Flutter packages** | `firebase_core ^3.6.0` + `firebase_messaging ^15.1.3` |
| 10.23 | **FCMService** | تهيئة + token + تسجيل في user_devices + معالج foreground/background/terminated |
| 10.24 | **Service Account credentials** | 3 secrets في Supabase: `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY` |
| 10.25 | **Edge Function** `send-push-notification` | منشورة + تستخدم FCM HTTP v1 API + تنظيف تلقائي للتوكنز الفاسدة |
| 10.26 | **RPC جديدة** | `get_user_device_tokens(uid)` + `notify_user(uid, type, title, body, ref_id, action)` |
| 10.27 | **أيقونة الإشعار** | `drawable/ic_notification.xml` (شفافة-أبيض) + لون ذهبي #D4AF37 |
| 10.28 | **Navigation handler** | الضغط على الإشعار يفتح الشاشة المناسبة حسب `data.type` |
| 10.29 | **حفظ تلقائي في DB** | كل إشعار يصل → يُحفظ في `notifications` ليظهر داخل التطبيق |
| 10.30 | **تنظيف التوكنز** | تشطيب القديمة عند تسجيل جديد + إلغاء الفاسدة من Edge Function |

> Migration: `supabase/migrations/2026_06_05_fcm_setup.sql`  
> Edge Function: `supabase/functions/send-push-notification/index.ts`  
> Flutter Service: `lib/services/fcm_service.dart`

**اختبار النجاح:**
```bash
# PowerShell:
{ "success": true, "sent": 1, "failed": 0, "total": 1 }
# الإشعار وصل، الأيقونة الذهبية ظاهرة، الضغط ينقل لشاشة العرض، يُحفظ داخل التطبيق ✅
```

### الجزء E2+: ربط الإشعارات بالأحداث التلقائية (2026-06-06)
| # | الحدث | الـ Trigger | المستلم | الإشعار |
|---|---|---|---|---|
| 10.31 | موافقة عرض (`sts: 1→2`) | `trg_offer_status_changed` | صاحب العرض | "✅ تم نشر عرضك" |
| 10.32 | رفض عرض (`sts: 1→3`) | `trg_offer_status_changed` | صاحب العرض | "❌ تم رفض عرضك: [السبب]" |
| 10.33 | انتهاء عرض (`sts: 2→4`) | `trg_offer_status_changed` | صاحب العرض | "⏰ انتهت صلاحية عرضك" |
| 10.34 | حجز عرض (`sts: 2→5`) | `trg_offer_status_changed` | صاحب العرض | "🔒 عرضك محجوز" |
| 10.35 | حجز موعد جديد (INSERT) | `trg_appointment_created` | المالك + السمسار | "📅 طلب معاينة جديد" |
| 10.36 | قبول الموعد (`sts: 0→1`) | `trg_appointment_status_changed` | طالب الموعد | "✅ تم تأكيد موعدك" |
| 10.37 | رفض الموعد (`sts: 0→2`) | `trg_appointment_status_changed` | طالب الموعد | "❌ تم رفض موعدك" |
| 10.38 | إكمال موعد (`sts: 0→3`) | `trg_appointment_status_changed` | طالب الموعد | "🎉 تمت المعاينة" |
| 10.39 | إلغاء موعد (`sts: 0→4`) | `trg_appointment_status_changed` | طالب الموعد | "⚠️ تم إلغاء الموعد" |
| 10.40 | عدم حضور (`sts: 1→5`) | `trg_appointment_status_changed` | طالب الموعد | "😞 سُجّل عدم حضور" |
| 10.41 | إكمال صفقة (`sts: 0→1`) | `trg_deal_completed` | البائع + المشتري + السمسار | "🎉 تمت الصفقة بنجاح" |
| 10.42 | موافقة دفعة (`sts: 0→1`) | `trg_payment_approved` | المستخدم | "✅ تم تفعيل اشتراكك" |
| 10.43 | رفض دفعة (`sts: 0→2`) | `trg_payment_approved` | المستخدم | "❌ تم رفض الدفعة" |
| 10.44 | عرض جديد منشور | `trg_offer_published_match_requests` | أصحاب الطلبات المطابقة (max 20) | "🎯 عرض جديد يطابق بحثك" |

**Helper function: `send_push_notification(uid, title, body, data)`**
- يقرأ URL + anon_key من `app_config.fcm`
- يستدعي Edge Function `send-push-notification` عبر `net.http_post`
- لا يفشل الـ trigger لو الإشعار فشل (مغلّف بـ `EXCEPTION WHEN OTHERS`)

> Migration: `supabase/migrations/2026_06_06_notification_triggers.sql`

---

## 💳 المرحلة 11: نظام قنوات الدفع اليدوي (✅ مكتملة — 2026-06-06)

> راجع `docs/PAYMENT_CHANNELS_PLAN.md` للخطة الكاملة.

### الفلسفة
**التطبيق يستقبل الطلبات — الإدارة تتحقق وتُفعّل يدوياً.**
السبب: لا توجد بوابة دفع تدعم سوريا (Stripe/PayPal محظورة).

### 4 قنوات معتمدة
| # | القناة | المفتاح | الأيقونة |
|---|---|---|---|
| 1 | الهرم للحوالات | `haram` | 🏛️ |
| 2 | شام كاش (مع QR) | `sham_cash` | 💚 |
| 3 | تحويل رصيد (سيرياتل/MTN) | `balance` | 📱 |
| 4 | تحويل بنكي | `bank` | 🏦 |

### ما تم تنفيذه
| # | الملف/الميزة | التنفيذ |
|---|---|---|
| 11.1 | `Migration #7` — `payChannels` في `app_config.main` | ✅ مطبّق على السيرفر — 4 قنوات بقيم افتراضية |
| 11.2 | `Migration #8` — `payments.channel` TEXT + buckets | ✅ عمود channel + bucket `config_assets` (عام) + `payment_proofs` (خاص + RLS) |
| 11.3 | `ConfigModel.payChannels` + `enabledPayChannels` | ✅ getter للقنوات + فلتر للمفعّلة فقط |
| 11.4 | `PaymentModel.channel` + `channelDisplayName()` | ✅ حقل جديد + دالة عرض عربي + توافق خلفي مع mtd |
| 11.5 | `payment_screen.dart` Config-Driven | ✅ يقرأ القنوات من config، يعرض بطاقة لكل قناة، تفاصيل ديناميكية، رفع QR، نصوص تعليمات |
| 11.6 | `payment_channels_editor_screen.dart` (شاشة admin جديدة) | ✅ تفعيل/تعطيل + تعديل كل الحقول + رفع QR لشام كاش |
| 11.7 | زر في `config_editor_screen` يفتح الشاشة | ✅ navTile مخصص |
| 11.8 | `payments_screen.dart` admin: عرض القناة + signed URL للإيصال | ✅ `channelDisplayName()` + `InteractiveViewer` للصور + signed URL لـ bucket خاص |
| 11.9 | تكامل مع notification trigger (`trg_payment_notify`) | ✅ موجود من E2+ — يُطلق إشعار تلقائي عند `approvePayment` |

### Storage Buckets
- `config_assets` (عام، 5MB، images) — QR شام كاش + أي أصل إداري
- `payment_proofs` (خاص، 10MB، images+pdf) — إيصالات المستخدمين
  - **RLS:** المستخدم يرفع داخل `{uid}/...` فقط، admin يقرأ الكل

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
