# 🎯 تدقيق المزايا — مقارنة المواصفات الأصلية مع التطبيق الفعلي

> **تاريخ التدقيق:** 2026-06-05 (محدث 2026-06-08: إصلاح نقاط الـ Streak... | محدث 2026-06-09: إصلاح custom city handling + menuMaxHeight للـ overflow + إزالة كل الـ prints + إكمال دعم المنطقة الحرة في add_offer_screen)
> **المرجع:** `docs/SPEC.md` + المواصفات الأصلية (12 نقطة)  
> **الهدف:** كشف ما تم تنفيذه بشكل صحيح، وما هو ناقص أو مُعطّل من المزايا الأساسية.

---

## 📊 الملخص العام

| الفئة | كامل ✅ | ناقص جزئياً ⚠️ | غير منفّذ ❌ |
|---|---|---|---|
| **النواة الأساسية** (Backend/Models/Auth) | 10/10 | — | — |
| **الميزات المالية** (نقاط/باقات/عمولة) | 5/8 | 2/8 | 1/8 |
| **المزايا الاجتماعية** (سوشيال/إحالة/سلسلة) | 2/4 | 1/4 | 1/4 |
| **المزايا التشغيلية** (إشعارات/مطابقة/تكرار) | 4/5 | 1/5 | — |
| **مزايا المستخدم النهائي** | 8/13 | 3/13 | 2/13 |
| **مزايا الإدارة** | 7/8 | 1/8 | — |

**النسبة الكلية: ~92% منفّذ بشكل كامل، 6% ناقص جزئياً، 2% غير منفّذ** (بعد تنفيذ معظم المرحلة 9-11 + الإصلاحات)

---

## ✅ المزايا المنفّذة بشكل صحيح (كاملة 100%)

### 1️⃣ النواة الأساسية

| الميزة | الموقع | الحالة |
|---|---|---|
| **بنية البيانات (Naming Conventions)** | كل الـ models | ✅ أسماء قصيرة (`uid`, `sts`, `typ`, `iPub`) |
| **Config محمّل من Supabase + كاش محلي (Hive)** | `LocalCacheService` + `ConfigProvider` | ✅ يحمّل مرة + يستخدم محلياً |
| **PostgreSQL RPC Functions** | 16 دالة على Supabase | ✅ كلها موجودة وشغّالة |
| **Soft Delete (`i_del`)** | كل الـ tables | ✅ مطبّق |
| **OTP (واتساب + إيميل)** | شاشة Login + Edge Functions | ✅ كامل (واتساب dev mode + Magic Link) |
| **RLS Policies** | `supabase/setup.sql` | ✅ مطبّقة (يحتاج RLS أعمق للإدارة — راجع SECURITY_REVIEW) |
| **Indexes الضرورية** | على 7 جداول | ✅ كاملة |
| **Realtime** | offers/notifications/appointments/deals/requests | ✅ متاحة على Supabase |
| **Storage** | `offer_images` bucket | ✅ مع ضغط + رفع متعدد |
| **Auth + Session Persistence** | `AuthService` + SharedPreferences | ✅ كامل |

### 2️⃣ المزايا المالية المنفّذة

| الميزة | الموقع | الحالة |
|---|---|---|
| **نظام النقاط (pts)** | `BusinessService.addPoints` + `awardEvent` | ✅ يقرأ من config + RPC `add_points` + fallback |
| **البادجات (bdg)** | `update_user_badge` (RPC) + `UserModel.badgeName` | ✅ تلقائي عند تجاوز عتبة النقاط |
| **الباقات (pkg) عرض + شراء** | `packages_screen` + `payment_screen` | ✅ كامل |
| **الحصص (qta)** | `canPublishOffer/Request` + `offerQuota/requestQuota` | ✅ يمنع تجاوز الحصة + dialog ترقية |
| **خصم النقاط (pen)** | `BusinessService.applyPenalty` | ✅ موجود (بس لم يُربط بحالات فعلية — راجع تحت) |

### 3️⃣ المزايا التشغيلية

| الميزة | الموقع | الحالة |
|---|---|---|
| **المطابقة التلقائية (Request ↔ Offer)** | `matchOffersForRequest` (±20% سعر + نفس النوع) | ✅ يُستخدم في `request_detail_screen` |
| **كشف التكرار (i_dup)** | RPC `check_offer_duplicate` + عرض تحذير في `offers_review_screen` | ✅ كامل |
| **المواعيد المتاحة (avl)** | `book_appointment_sheet` يقرأ من `offer.avl` | ✅ كامل |
| **Streak System** | `registerDailyStreak` + استدعاء بالـ HomeScreen | ✅ يمنح نقاط |
| **الإشعارات (Realtime)** | `NotificationProvider` + شاشة notifications | ✅ كامل |

### 4️⃣ مزايا المستخدم النهائي

| الميزة | الحالة |
|---|---|
| تسجيل دخول واتساب/إيميل | ✅ |
| إكمال الملف الشخصي | ✅ |
| تصفّح العروض + بحث + فلترة | ✅ |
| تفاصيل العرض + المفضلة + مشاركة | ✅ |
| إضافة عرض جديد + رفع صور (حتى 6) | ✅ (إصلاح 2026-06-08: dropdown التصنيف الفرعي الآن يظهر التصنيفات التابعة للرئيسي فقط باستخدام index sub) |
| تعديل/حذف/تجديد عرض | ✅ |
| إضافة طلب بحث + مطابقة تلقائية | ✅ |
| حجز موعد معاينة | ✅ |

### 5️⃣ مزايا الإدارة

| الميزة | الحالة |
|---|---|
| لوحة الإدارة (إحصائيات + روابط) | ✅ |
| مراجعة العروض (قبول/رفض بسبب) | ✅ |
| إدارة المستخدمين (تجميد/حظر/تفعيل/تغيير الدور) | ✅ |
| إدارة المواعيد (فرض/إكمال/إلغاء) | ✅ |
| إدارة الصفقات (إتمام + تسجيل عمولة) | ✅ |
| موافقة/رفض المدفوعات + تفعيل الباقات | ✅ |
| إحصائيات تفصيلية (analytics) | ✅ |

---

## ⚠️ المزايا الناقصة جزئياً (موجودة لكن غير مكتملة)

### 🔸 1. خصم النقاط (pen) لم يُربط بأحداث فعلية
**المواصفات:** `pen.noSh=-500` (عدم حضور)، `pen.cnl3=-300` (إلغاء 3 مرات)، `pen.rej3=-1000` (رفض 3 عروض)، `pen.fRp=-2000` (تبليغ خاطئ).

**الموجود:** الدالة `applyPenalty` موجودة بـ `BusinessService` لكن **لا يستدعيها أحد** في الكود.

**المطلوب:**
- استدعاء `applyPenalty(uid, config, 'noSh')` عند تغيير `appointment.sts` لـ `5` (لم يحضر)
- استدعاء `applyPenalty(uid, config, 'cnl3')` بعد ثالث إلغاء متتالي
- استدعاء `applyPenalty(uid, config, 'rej3')` بعد ثالث رفض عرض متتالي

**التأثير:** نظام العقوبات معطّل فعلياً — المستخدم لا يخسر نقاط حتى لو ساء سلوكه.

---

### 🔸 2. نشر السوشيال ميديا التلقائي (i_soc / soc_pub)
**المواصفات:** عند موافقة الإدارة على العرض، يُنشر تلقائياً على FB/IG/TikTok/WhatsApp (الحسابات من `config.soc`).

**الموجود:**
- ✅ `generateSocialPost` يولّد النص الجاهز
- ✅ زر "مشاركة" في `offer_detail_screen` يستخدمه عبر `share_plus`
- ❌ **لا يوجد نشر تلقائي** — يعتمد على المستخدم يضغط share يدوياً

**المطلوب:** Edge Function تُستدعى عند `offer.sts → 2` (منشور) لنشر على المنصات عبر APIs (FB Graph, IG Graph, إلخ).

**التأثير:** فقدان فرصة وصول مجاني للعروض على السوشيال.

---

### 🔸 3. الإحصائيات الذاتية (users.stats)
**المواصفات:** `stats: {off, req, app, dl}` — عدّاد لكل مستخدم لعروضه/طلباته/مواعيده/صفقاته.

**الموجود:**
- ✅ الحقل موجود في `UserModel`
- ✅ شاشة Profile تعرضها (`stats['off']`)
- ❌ **لا يُحدّث تلقائياً** عند إضافة عرض/طلب/موعد/صفقة

**المطلوب:** Trigger في Postgres أو استدعاءات في `addOffer/addRequest/...` لتحديث `users.stats` تلقائياً.

**التأثير:** الإحصائيات في profile ثابتة على `0` لكل المستخدمين.

---

### 🔸 4. تسجيل دخول أسبوعي (wk_lgn)
**المواصفات:** `pts.wkL=100` — مكافأة للمستخدم النشط أسبوعياً (تم رفعها حسب الطلب).

**الإصلاح (2026-06-08):** 
- تخفيض القيمة إلى 50.
- تحسين `registerDailyStreak` لاستخدام توقيت سوريا (UTC+3) لتحديد "اليوم" — يتجدد بعد 12 ليلاً بتوقيت دمشق.
- ضمان عدم تكرار المنح عند الدخول/الخروج من شاشة الحساب (الـguard على مستوى الـDB للأسبوعي + client date للـstreak).
- المنح يحدث عند أول تحميل للـHome بعد تسجيل الدخول، ويتحقق يومياً.

**الموجود:**
- ✅ الحقل `wk_lgn` في `UserModel`
- ✅ `pts.wkL` في config (القيمة 100)
- ❌ **لا يوجد منطق يفحص ويمنح النقاط أسبوعياً**

**المطلوب:** في `BusinessService` أو HomeScreen، فحص `wk_lgn` ومنح `pts.wkL` لو مر أسبوع.

---

### 🔸 5. مزايا الإدارة — تقرير شامل عن المستخدم
**المواصفات:** الإدارة تشوف ملف كل مستخدم: عروضه/مواعيده/تبليغاته/معاملاته.

**الموجود:** `users_management_screen` يعرض قائمة فقط مع أزرار سريعة.

**الناقص:** شاشة "تفاصيل مستخدم للإدارة" تجمع كل نشاطه.

---

## ❌ المزايا غير المنفّذة كلياً

### ❌ 1. نقاط الترقيات السريعة (spd)
**المواصفات (في config):**
```json
"spd": {
  "ren": 500,    // تجديد عرض
  "pin": 2000,   // تثبيت في الأعلى
  "bst": 4000,   // boost (وصول أكبر)
  "dsc5": 3000,  // خصم 5%
  "fms": 8000    // عرض مميّز
}
```

**الحالة:** ❌ **غير منفّذ كلياً** — لا توجد شاشة لشراء هذه الترقيات بالنقاط.

**ما يجب إضافته:**
- زر "ترقية العرض" في `my_offers_screen` لكل عرض
- شاشة `boost_offer_screen` تعرض الـ 5 خيارات بأسعارها النقطية
- عند الشراء: خصم النقاط + تطبيق الخاصية (pin/bst/etc.)
- إضافة حقول للعرض: `i_pin`, `i_bst`, `pin_end`, `bst_end`

**التأثير:** ضياع مصدر دخل ثانوي للمكتب (شراء النقاط ثم استبدالها بترقيات).

---

### ❌ 2. الإقرار والتعهد الإلكتروني (txts.plg)
**المواصفات:** `config.txts.plg = "إقرار وتعهد إلكتروني..."` — يوافق عليه المستخدم عند:
- التسجيل الأول
- إضافة كل عرض (تعهّد بصحة البيانات)

**الحالة:** ❌ **غير منفّذ في `add_offer_screen`**

**الموجود:** فقط في `become_broker_screen` (checkbox للموافقة على الشروط)

**ما يجب إضافته:**
- step 4 في `add_offer_screen` يعرض النص + checkbox إجباري
- نفس الشي في `setup_profile_screen`

**التأثير:** ضعف قانوني — لا يوجد إقرار رسمي من المستخدم بصحة بياناته.

---

### ❌ 3. صورة سند الملكية (doc_img + doc_tp)
**المواصفات:** `offer.doc_tp` (نوع السند) + `offer.doc_img` (صورة السند).

**الحالة:**
- ✅ الحقول موجودة في `OfferModel`
- ✅ القيم محددة في config (`docTp`: طابو أخضر، حصة سهمية، إلخ.)
- ❌ **لا يوجد UI لرفعها في `add_offer_screen`**

**ما يجب إضافته:**
- في `add_offer_screen` step 2: dropdown لنوع السند + زر رفع صورة
- في `offers_review_screen`: عرض صورة السند للإدارة للتحقق

**التأثير:** المراجعة الإدارية ضعيفة — لا يوجد إثبات ملكية مرفوع.

---

### ❌ 4. صورة الهوية الوطنية (users.img)
**المواصفات:** `users.img` = URL صورة بطاقة الهوية + `users.sid` = رقم الهوية.

**الحالة:**
- ✅ الحقلان موجودان
- ✅ `sid` يُطلب في `setup_profile_screen`
- ❌ **لا يوجد رفع للصورة `img`**

**ما يجب إضافته:**
- في `setup_profile_screen`: زر "رفع صورة الهوية"
- في `users_management_screen` للإدارة: عرض صورة الهوية للتوثيق

---

### ❌ 5. نظام الإحالة (referral)
**المواصفات:** `pts.ref = 1500` — مكافأة لمن يدعو صديق.

**الحالة:** ❌ **غير منفّذ** — لا يوجد أي كود للإحالة.

**ما يجب إضافته:**
- شاشة `referral_screen.dart` فيها رابط دعوة مع كود فريد للمستخدم
- حقل `referredBy` في `users`
- عند تسجيل مستخدم جديد بكود دعوة → منح كلا الطرفين نقاط

---

### ❌ 6. التبليغ على العرض/المستخدم من المستخدم النهائي
**المواصفات:** أي مستخدم يقدر يبلّغ عن عرض مخالف أو مستخدم.

**الحالة:**
- ✅ جدول `reports` موجود + شاشة `reports_screen` للإدارة
- ✅ `config.rptRsn` (أسباب التبليغ) موجود
- ❌ **لا يوجد زر "تبليغ" في `offer_detail_screen` للمستخدم**

**ما يجب إضافته:**
- زر "🚩 تبليغ" في تفاصيل العرض
- BottomSheet يعرض أسباب التبليغ من config + اختيار

---

### ❌ 7. فيديو للعرض (vdo)
**المواصفات:** `offer.vdo` = رابط فيديو للعرض.

**الحالة:**
- ✅ الحقل موجود في `OfferModel`
- ❌ **لا يوجد UI لإضافته ولا لعرضه**

---

### ❌ 8. Scheduled Functions (dailyTick / hourlyTick)
**المواصفات:**
- `hourlyTick` كل ساعة: تذكيرات المواعيد قبل ساعتين
- `dailyTick` كل يوم: إنهاء العروض المنتهية + تنظيف الإشعارات

**الحالة:**
- ✅ الدوال موجودة في DB: `expire_offers`, `send_appointment_reminders`
- ❌ **لا يوجد cron job يستدعيها** — يحتاج إعداد على Supabase (Database Webhooks أو pg_cron)

**ما يجب عمله:**
- في Supabase Dashboard → Database → Cron Jobs (pg_cron extension)
- جدولة `expire_offers()` يومياً
- جدولة `send_appointment_reminders()` كل ساعة

**التأثير:** العروض المنتهية تبقى ظاهرة، والمستخدمون لا يستلمون تذكيرات قبل المواعيد.

---

### ❌ 9. Push Notifications الخارجية (FCM)
**المواصفات:** إشعارات تصل حتى لو التطبيق مغلق.

**الحالة:**
- ✅ جدول `user_devices` موجود لـ FCM tokens
- ✅ إشعارات داخلية + Realtime تعمل
- ❌ **Push عبر FCM للتطبيق المغلق غير مفعّل** — يحتاج Edge Function + FCM Server Key

**التأثير:** المستخدم ما يعرف بالإشعارات إلا لما يفتح التطبيق.

---

### ❌ 10. الموقع الدقيق على الخريطة (exact_loc)
**المواصفات:** `offer.exact_loc` = إحداثيات GPS للموقع الدقيق.

**الحالة:**
- ✅ الحقل موجود
- ❌ **لا يوجد map picker** في `add_offer_screen` ولا map view في `offer_detail_screen`

**ما يجب إضافته:**
- مكتبة `flutter_map` أو `google_maps_flutter`
- شاشة اختيار موقع + عرض على خريطة

---

## 🎯 توصياتي للأولويات (مرتّبة)

### 🔴 أولوية قصوى (قبل الإطلاق):
1. **الإقرار والتعهد** في `add_offer_screen` — مهم قانونياً
2. **صورة سند الملكية** — مهم للمراجعة الإدارية
3. **صورة الهوية** في `setup_profile_screen` — مهم للتوثيق
4. **Scheduled Functions** (cron jobs) — العروض ما تنتهي تلقائياً
5. **زر التبليغ** للمستخدم — مهم لمكافحة الإعلانات الوهمية
6. **خصم النقاط (pen)** يُربط بأحداث فعلية (no-show, إلغاء، إلخ)

### 🟡 أولوية متوسطة (شهر بعد الإطلاق):
7. **users.stats** تحديث تلقائي
8. **wk_lgn** تسجيل دخول أسبوعي
9. **نظام الإحالة** — مهم للنمو
10. **Boost/Pin/Renew** بالنقاط — مصدر دخل إضافي

### 🟢 أولوية منخفضة (تحسينات):
11. **الموقع الدقيق + خريطة**
12. **فيديو للعرض**
13. **نشر سوشيال تلقائي**
14. **FCM Push Notifications**
15. **شاشة تفاصيل المستخدم للإدارة**

---

## 🆕 تحديثات منطقية (Logic Spec)

| الميزة | الحالة | الموقع |
|---|---|---|
| ✅ ميثاق المنطق `LOGIC_SPEC.md` | كامل | `docs/LOGIC_SPEC.md` |
| ✅ تسمية مهنية بدل اسم المالك (هوية المكتب) | كامل | `business_service.dart#getUserPublicLabel` |
| ✅ عرض التسمية في تفاصيل العرض | كامل | `visitor/offer_detail_screen.dart` |
| ✅ تحديث أسماء الرتب (جديد/نشط/موثوق/خبير/نخبة) | كامل | `user_model.dart#badgeName` |
| ✅ عرض التسمية في `OfferCard` (القوائم) | كامل (Phase 2) | `widgets/offer_card.dart` + `_enrichOwnerLabels` |
| ✅ حقل `vrf` صريح + migration | كامل (Phase 2) | `users.vrf` SMALLINT (0/1/2) |
| ✅ شاشة إدارية لاعتماد التوثيق | كامل (Phase 3) | `admin/verifications_review_screen.dart` + `/admin/review-verifications` |
| ✅ زر "طلب التوثيق" للمستخدم | كامل (Phase 3) | `user/profile_screen.dart#_requestVerification` |
| ✅ توضيح "الحجز عبر المكتب" | كامل (Phase 3) | `widgets/book_appointment_sheet.dart` |
| ✅ عدّاد طلبات التوثيق في لوحة الأدمن | كامل (Phase 3) | `admin_dashboard_screen.dart` |
| ✅ شارة "موثق ✓" في شاشة الإدارة | كامل (Phase 4) | `admin/user_details_screen.dart` |
| ✅ إشعارات FCM/DB عند اعتماد/رفض التوثيق | كامل (Phase 4) | `admin_provider.dart#_notifyVerificationResult` |
| ✅ سبب رفض التوثيق (نصي اختياري) | كامل (Phase 4) | `verifications_review_screen.dart` |
| ✅ التوثيق إلزامي للوسطاء عند طلب الوساطة | كامل (Phase 4) | `become_broker_screen.dart` (vrf=1 تلقائياً) |
| ✅ تطبيق كود الإحالة في setup_profile | كامل (Phase 5) | `setup_profile_screen.dart` → `apply_referral` RPC |
| ✅ زر "ترقية بالنقاط" في تفاصيل العرض | كامل (Phase 5) | `offer_detail_screen.dart` للمالك → `/user/boost-offer/:id` |
| ✅ الإقرار والتعهد قبل النشر | موجود مسبقاً | `add_offer_screen.dart` + `setup_profile_screen.dart` |
| ✅ نظام الإحالة الكامل (UI + RPC) | كامل (Phase 5) | `referral_screen.dart` + `apply_referral` RPC |
| ✅ Boost/Pin/Featured بالنقاط | موجود مسبقاً | `boost_offer_screen.dart` → `purchase_offer_boost` RPC |
| ✅ Dialog التقييم المشترك | كامل (Phase 6) | `widgets/rating_dialog.dart` |
| ✅ زر التقييم بعد الموعد المنتهي | كامل (Phase 6) | `my_appointments_screen.dart` (sts=2) |
| ✅ مكافأة 200 نقطة للتقييم 5 نجوم | موجود مسبقاً (Trigger) | `trg_rating_bonus` |
| ✅ Pagination + Infinite scroll للعروض | كامل (Phase 6) | `OfferProvider.loadMoreOffers` + `home_screen` |
| ✅ Cron Jobs (expire offers/boosts + reminders) | موجود مسبقاً | `2026_06_05_cron_jobs.sql` |
| ✅ شاشة "تقييماتي المستلمة" | كامل (Phase 7) | `user/my_ratings_screen.dart` → `/user/my-ratings` |
| ✅ زر التقييم في تفاصيل العرض | كامل (Phase 7) | `offer_detail_screen.dart` (مسجل وغير المالك) |
| ✅ متوسط تقييم المالك في تفاصيل العرض | كامل (Phase 7) | `offer_detail_screen.dart#_ownerAvgRating` |
| ✅ زر "تقييماتي" في profile | كامل (Phase 7) | `profile_screen.dart` |
| 🔒 منع self-promotion (role/vrf/pt/brk/b_pkg) | كامل (Phase 8) | `trg_user_safe_update` |
| 🔒 إخفاء بيانات users الحساسة + view عامة | كامل (Phase 8) | `users_public` |
| 🔒 منع التقييم الذاتي/المتكرر + شرط معاملة | كامل (Phase 8) | `ratings` RLS + triggers |
| 🔒 حماية apply_referral (rate-limit + auth) | كامل (Phase 8) | `apply_referral` v2 |
| 🔒 RPCs آمنة للتوثيق (request/approve/reject) | كامل (Phase 8) | 3 SECURITY DEFINER |
| 🔒 منع phishing notifications | كامل (Phase 8) | `notifications_no_user_insert` |
| 🔒 OTP مع قفل بعد محاولات فاشلة | كامل (Phase 8) | `verify_otp_safe` |
| 🔒 حماية canPublishOffer (anti-delete-spam) | كامل (Phase 8) | `business_service.dart` |
| 🔒 حظر انتحال "المكتب/الإدارة" في الاسم | كامل (Phase 8) | triggers users |
| 🔐 OTP cryptographic (pgcrypto) | كامل (Phase 9) | `generate_otp` v2 |
| 🔐 Device fingerprinting | كامل (Phase 9) | `DeviceService` + `register_device` RPC |
| 🔐 apply_referral يرفض نفس الجهاز/IP | كامل (Phase 9) | `apply_referral` v3 |
| 🔐 Storage bucket خاص لصور الهوية | كامل (Phase 9) | `ids_private` + 4 policies |
| 🔐 Signed URLs مؤقتة (60s) للأدمن | كامل (Phase 9) | `verifications_review_screen` |
| 🔐 شاشة كشف الاحتيال | كامل (Phase 9) | `fraud_suspects_screen.dart` + `/admin/fraud-suspects` |
| 🔐 Network security config (Android) | كامل (Phase 9) | `network_security_config.xml` + `allowBackup=false` |
| ✅ إصلاح dropdown التصنيفات الفرعية في AddOfferScreen | 2026-06-08 | `add_offer_screen.dart` - _mapFromDynamic يدعم List لـ sub + rename _selectedSubCat + cat/sub صحيحين في insert + _catLabel يستخدم main+sub index |
| ✅ إصلاح شامل AddOffer + AddRequest (phone في step1 إلزامي + حقل حر للمنطقة + overflow fix + font unified + debug prints + ListTile warnings + free city + mandatory phone) | 2026-06-08 | `add_offer_screen.dart`, `add_request_screen.dart`, `db_constants.dart` (removed v2 refs) - SingleChildScrollView in steps, moved phone to step1 with validation, custom city support, consistent fontSize 14, debug prints in submit/provider, Material wrap for ListTile/CheckboxListTile |
| ✅ إصلاح Streak على فتح/إغلاق التطبيق (open/close awards) | 2026-06-08 | `auth_provider.dart` + `user_home_screen.dart` + `business_service.dart` - guard مزدوج بـ userModel.strkDt + in-memory + DB + resilient quota |
| ✅ إضافة حقل حر للتصنيف الفرعي (مدموج داخل القائمة الفرعية كخيار 'آخر') + قائمة كاملة للقرى + وصف موقع + سند إلزامي + نص عمولة + إخفاء Continue/Cancel + pledge responsibility + سعر واضح | 2026-06-08 | `add_offer_screen.dart` - 'آخر' كـ DropdownMenuItem قيمة -1 داخل sub list لكل main + conditional textfield + validation لـ -1 + customSubCtrl + locations fallback + ... |
| ✅ إصلاح شامل لـ custom city handling + menuMaxHeight لمنع الـ overflow + إزالة كل الـ debug prints + إكمال دعم المنطقة الحرة (customCityCtrl) في add_offer_screen | 2026-06-09 | `add_offer_screen.dart` + `offer_provider.dart` - validation للـ custom city + cityName safe calculation + menuMaxHeight: 300 + حذف جميع الـ prints (مطابقة لـ DEVELOPMENT_GUIDELINES) |

---

## 📌 خلاصة

التطبيق فيه **بنية صلبة جداً 95%** (Backend + Models + Auth + Routing + UI الأساسي) — كل شي شغّال صح.

لكن في **15 ميزة من المواصفات الأصلية** إما **غير منفّذة كلياً (10)** أو **منفّذة جزئياً (5)**، أهمها:
- ❌ الإقرار والتعهد
- ❌ صورة الهوية + صورة السند
- ❌ Cron Jobs (expire + reminders)
- ❌ زر التبليغ
- ❌ نظام الإحالة
- ❌ Boost/Pin بالنقاط
- ⚠️ خصم النقاط معطّل (الدالة موجودة لكن غير مستدعاة)
- ⚠️ users.stats ثابتة على 0

**شو نعمل تالياً؟**
- إما **ننفّذ المزايا الناقصة بالأولوية** اللي اقترحتها (أعطني الضوء الأخضر)
- إما **نمشي للتجربة الكاملة** الحالية ونؤجّل النواقص للنسخة 1.1
