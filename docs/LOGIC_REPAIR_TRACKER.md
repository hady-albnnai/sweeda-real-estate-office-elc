# تتبّع إصلاح المنطق — مرجع المحادثة المستمر

> آخر تحديث: 2026-06-11
> حالة الملف: **مرجع العمل الرسمي لإصلاح المنطق**
> هذا الملف أُنشئ ليبقى مرجعاً ثابتاً بين المحادثات، ويجب تحديثه **بعد كل إصلاح**.

---

## 1) الغرض من هذا الملف

هذا الملف هو **لوحة المتابعة الرسمية** لإصلاح مشاكل المنطق في المشروع.

يُستخدم من أجل:

- معرفة ما الذي تم اكتشافه.
- معرفة ما الذي بدأ إصلاحه وما الذي انتهى.
- ترك مرجع واضح للمحادثة القادمة إذا انقطعت المحادثة الحالية لأي سبب.
- منع ضياع السياق بين الجلسات.

**القاعدة:**
لا يُعتبر أي إصلاح منجزاً فعلياً ما لم يتم تحديث هذا الملف بعده.

---

## 2) الدستور/المرجع الأعلى المعتمد

تمت مراجعة المرجع الأعلى للمشروع مرة أخرى، واعتماده كأساس لأي إصلاح:

### المراجع الملزمة
- `docs/LOGIC_SPEC.md` ← **الدستور الأعلى للمنطق**
- `docs/SPEC.md`
- `docs/CURRENT_STATUS.md`
- `DEVELOPMENT_GUIDELINES.md`
- `supabase/FUNCTIONS_REFERENCE.md`
- `docs/SECURITY_REVIEW.md`
- `docs/LOGIC_AUDIT_2026_06_10.md` ← تقرير التدقيق الحالي

### مبادئ دستورية يجب عدم خرقها أثناء الإصلاح
1. **منطق المكتب هو المرجع**: التطبيق ليس منصة إعلانات فقط، بل مكتب يدير العملية.
2. **المنطق الحساس يجب أن يكون في السيرفر** لا في العميل.
3. **كل ما هو مالي أو نقاط أو صلاحيات يجب أن يكون محصناً ضد التلاعب.**
4. **الخصوصية إلزامية**: لا تسريب لبيانات المستخدمين أو الملاك للعامة.
5. **الحالات (statuses) يجب أن تكون موحّدة** بين الكود، الواجهة، والقاعدة.
6. **لا hardcoded** في السلوك التجاري والمالي متى كان يجب أن يأتي من Config.
7. **أي تعديل يجب أن ينعكس على التوثيق** قبل اعتباره منتهياً.

---

## 3) مصدر المشاكل المعتمدة حالياً

المشاكل المدرجة هنا مستخرجة من:

- `docs/LOGIC_AUDIT_2026_06_10.md`

إذا ظهر أثناء الإصلاح خلل جديد غير مذكور، يجب إضافته هنا فوراً.

---

## 4) سلم الحالات المستخدم في هذا الملف

| الحالة | المعنى |
|---|---|
| `OPEN` | لم يبدأ العمل عليه بعد |
| `IN_PROGRESS` | جارٍ إصلاحه الآن |
| `BLOCKED` | متوقف بسبب اعتماد/قرار/تعقيد آخر |
| `FIXED_CODE` | تم إصلاح الكود لكن لم يُراجع التوثيق بعد |
| `FIXED_VERIFIED` | تم إصلاحه ومراجعته منطقياً وتحديث التوثيق |
| `DEFERRED` | مؤجل لمرحلة لاحقة بقرار واضح |

---

## 5) ترتيب الإصلاح المعتمد

### أولوية العمل
1. مشاكل **المواعيد**
2. مشاكل **الـ statuses** وعدم التوحيد
3. مشاكل **الصلاحيات وRPCs الداخلية**
4. مشاكل **النقاط والـ boosts**
5. مشاكل **الدفع والباقات**
6. مشاكل **العروض والحصص والتكرار**
7. مشاكل **الخصوصية/القراءة العامة**
8. المشاكل المتوسطة وما بعدها

---

## 6) لوحة الإصلاح الرئيسية

| ID | الأولوية | المشكلة | المرجع | الملفات المتوقعة | الحالة | ملاحظات |
|---|---|---|---|---|---|---|
| L-01 | Critical | مسار حجز المواعيد لا يحفظ الوقت المختار فعلياً، وشاشة "مواعيدي" تعتمد حقلاً خاطئاً | `docs/LOGIC_AUDIT_2026_06_10.md` | `lib/widgets/book_appointment_sheet.dart`, `lib/providers/appointment_provider.dart`, شاشات المواعيد, migrations/docs | `FIXED_VERIFIED` | تم تمرير اليوم/الوقت المختار، واعتماد `appointments.req_uid` لطالب الموعد |
| L-02 | Critical | حالات المواعيد غير موحّدة بين الإدارة/الوسيط/المستخدم | نفس المرجع | `lib/providers/broker_provider.dart`, `lib/screens/admin/appointments_management_screen.dart`, `lib/screens/broker/broker_appointments_screen.dart`, `lib/screens/user/my_appointments_screen.dart`, `lib/screens/admin/user_details_screen.dart`, SQL/docs | `FIXED_VERIFIED` | العقدة الرسمية الآن: 0 انتظار، 1 مؤكد، 2 مكتمل، 3 ملغي، 4 مرفوض، 5 لم يحضر |
| S-01 | Critical | RPCs إدارية/داخلية تثق بـ `admin_uid` القادم من العميل | نفس المرجع + `docs/SECURITY_REVIEW.md` | `supabase/migrations/2026_06_10_admin_user_role_and_phone_uniqueness.sql`, `supabase/migrations/2026_06_10_photography_dev_auth_rpcs.sql`, `supabase/migrations/2026_06_10_auth_uid_alignment_guards.sql`, `supabase/migrations/2026_06_10_verification_dev_auth_rpcs.sql`, `supabase/setup.sql`, docs | `BLOCKED` | تم تشديد المسارات قدر الإمكان وإضافة توافق للتوثيق، لكن الإغلاق الكامل يتطلب إنهاء الاعتماد على dev fallback |
| P-01 | Critical | `purchase_offer_boost` يثق بالكلفة القادمة من العميل | نفس المرجع | `supabase/migrations/2026_06_05_offer_boosts.sql`, `lib/screens/user/boost_offer_screen.dart`, docs | `FIXED_VERIFIED` | السيرفر صار يحسب الكلفة من `app_config.spd` |
| Pay-01 | High | `approve_payment_final` لا يتحقق كفاية من صلاحية الأدمن وحالة الدفعة | نفس المرجع | `supabase/migrations/2026_06_06_payment_approval_logic.sql`, `lib/providers/admin_provider.dart`, docs | `FIXED_VERIFIED` | أضيف التحقق من الدور + pending state + التمديد التراكمي للباقة |
| O-01 | High | `create_offer_internal` لا يفرض الحصة/التكرار/الهوية على السيرفر | نفس المرجع | `supabase/migrations/2026_06_10_offer_create_rpc_and_admin_quota.sql`, `lib/providers/offer_provider.dart`, docs | `FIXED_VERIFIED` | أضيفت الحصة + كشف التكرار + التحقق من الحقول + إرجاع العرض إلى `sts=1` |
| O-02 | High | المستخدم يستطيع إعادة نشر/تجديد عرض بطريقة تتجاوز منطق المكتب | نفس المرجع + `docs/LOGIC_SPEC.md` | `lib/screens/user/edit_offer_screen.dart`, docs | `FIXED_VERIFIED` | تم إيقاف النشر المباشر من شاشة التعديل وربط التجديد بمسار الترقية بالنقاط |
| O-03 | High | حالات العروض نفسها غير موحّدة (`0` مسودة/قيد مراجعة) | نفس المرجع | `lib/core/utils/app_utils.dart`, شاشات العروض، الإدارة، docs | `FIXED_VERIFIED` | تم تثبيت العقدة: `0=مسودة`, `1=قيد المراجعة`، وكل مسارات المراجعة تعتمد `1` |
| ST-01 | Medium | الإحصائيات تتحدّث مرتين: trigger + client manual update | نفس المرجع | `lib/providers/offer_provider.dart`, `lib/providers/request_provider.dart`, `lib/providers/admin_provider.dart`, وربما `BusinessService` | `FIXED_VERIFIED` | تم حذف التحديث اليدوي في المسارات المغطاة من triggers |
| R-01 | Medium | شاشة تفاصيل الطلب تستخدم `req.typ` بدل `req.elm` في المطابقة | نفس المرجع | `lib/screens/user/request_detail_screen.dart`, `lib/screens/user/add_request_screen.dart`, `lib/core/services/business_service.dart` | `FIXED_VERIFIED` | تم اعتماد `(elm + typ)` في المطابقة بدل الحقل الخاطئ |
| CFG-01 | Medium | أسعار الباقات/سعر الصرف ما زالت hardcoded وليست Config-driven | نفس المرجع + `docs/SPEC.md` | `lib/screens/user/packages_screen.dart`, `lib/screens/user/payment_screen.dart`, `app_config`, docs | `FIXED_VERIFIED` | أضيفت `pkg.*.pr` و `fx.usd_syp` للـConfig مع fallback آمن |
| V-01 | Medium | منطق صورة الهوية الخاصة غير متماسك مع العرض في الواجهة | نفس المرجع | `lib/screens/auth/setup_profile_screen.dart`, `lib/screens/user/profile_screen.dart`, `lib/screens/admin/user_details_screen.dart`, storage/docs | `FIXED_VERIFIED` | تم فصل صورة الهوية الخاصة عن avatar العام في الواجهات الأساسية |
| PRIV-01 | Medium | الكود لا يلتزم بالكامل باستخدام `users_public` للقراءة العامة | نفس المرجع + `docs/SECURITY_REVIEW.md` | `lib/providers/offer_provider.dart`, `lib/screens/visitor/offer_detail_screen.dart`, استعلامات/مهاجرات العرض العام | `FIXED_VERIFIED` | تم تحويل القراءة العامة الأساسية إلى `users_public` وإزالة `img` منها بعد فصل الهوية الخاصة |
| UX-01 | Low | حقول معلنة كإلزامية لكنها غير مفروضة برمجياً بالكامل | نفس المرجع | `lib/screens/user/add_offer_screen.dart`, `lib/screens/user/add_request_screen.dart` | `FIXED_VERIFIED` | تم فرض هاتف التواصل/هاتف العميل فعلياً |
| CFG-02 | Low | ما زالت هناك قيم fallback/مدن hardcoded في بعض الواجهات | نفس المرجع | `lib/screens/user/add_offer_screen.dart` وغيرها | `FIXED_VERIFIED` | تم تحويل قوائم المناطق إلى قراءة من Config وإزالة fallbackات المحلية الأثقل |
| U-01 | Medium | شاشة "عروضي" كانت تعتمد قائمة العروض المنشورة العامة بدلاً من جلب عروض المستخدم كاملة | مشكلة مكتشفة أثناء الإصلاح | `lib/screens/user/my_offers_screen.dart` | `FIXED_VERIFIED` | تم تحويلها إلى جلب مباشر لكل عروض المستخدم عبر `fetchUserOffers` |

---

## 7) سجل التنفيذ الزمني

> هذا القسم يجب تحديثه بعد كل خطوة فعلية.

### 2026-06-10
- تم إنشاء ملف التتبع هذا.
- تم اعتماد `docs/LOGIC_AUDIT_2026_06_10.md` كمرجع المشاكل الحالي.

### 2026-06-11
- تم إصلاح `L-01` و `L-02`:
  - تمرير اليوم/الوقت المختار فعلياً عند الحجز.
  - اعتماد `appointments.req_uid` لطالب الموعد.
  - توحيد حالات المواعيد في الشاشات والـproviders والمرجع التوثيقي.
- تم إصلاح `P-01`:
  - `purchase_offer_boost` لم يعد يقبل الكلفة من العميل.
  - الكلفة أصبحت تُحسب من `app_config.spd` على السيرفر.
- تم إصلاح `Pay-01`:
  - `approve_payment_final` صار يتحقق من دور الإداري ومن أن الدفعة pending.
  - تفعيل الباقة أصبح تراكميّاً فوق `pkg_end` الحالي عند الحاجة.
- تم إصلاح `O-01` و `O-02` و `O-03`:
  - `create_offer_internal` صار يفرض الحصة وكشف التكرار والحقول الإلزامية.
  - العرض الجديد/المعدل يعود إلى `sts=1` (قيد المراجعة).
  - إيقاف التجديد/إعادة النشر المباشر من شاشة تعديل العرض.
- تم إصلاح `ST-01`:
  - حذف التحديث اليدوي المزدوج لبعض الإحصائيات والاعتماد على triggers.
- تم إصلاح `R-01`:
  - المطابقة صارت تعتمد `elm + typ` بدل الحقل الخاطئ.
- تم إصلاح `CFG-01`:
  - إضافة `pkg.*.pr` و `fx.usd_syp` إلى Config.
- تم إصلاح `V-01` و `PRIV-01`:
  - فصل صورة الهوية الخاصة عن عرض الـavatar العام في الواجهات الأساسية.
  - تحويل القراءة العامة الأساسية إلى `users_public`.
  - إزالة `img` من `users_public` حتى لا يتسرّب مسار الهوية الخاصة.
- تم إصلاح `UX-01`:
  - فرض حقول الهاتف الإلزامية فعلياً.
- تم اكتشاف وإصلاح `U-01`:
  - شاشة "عروضي" كانت تجلب العروض العامة المنشورة فقط، وتم تحويلها إلى جلب عروض المستخدم الكاملة.
- تم إغلاق `CFG-02`:
  - تم تحويل قائمة المناطق في إضافة العرض إلى قراءة من Config.
  - تم إزالة fallbackات المواقع والمدن المحلية الأثقل من الواجهة.
- تم تشديد إضافي في `S-01`:
  - أضيفت مطابقة `auth.uid()` أيضاً لمسار `submit_photography_task_internal` عند توفر الجلسة الحقيقية.
- تم إنشاء مرجع تنفيذي للاختبار بعد الإصلاحات:
  - `docs/POST_FIX_EXECUTION_AND_TEST_PLAN.md`
- تم إنشاء ملف SQL مجمّع جاهز للتنفيذ على السيرفر:
  - `supabase/RUN_ME_LOGIC_FIXES_2026_06_11.sql`
- تم إنشاء migration تنظيف إضافية لحذف RPCs التوثيق القديمة غير المستخدمة:
  - `supabase/migrations/2026_06_11_drop_obsolete_verification_rpcs.sql`
- تم تحديث الملفات المرجعية التالية:
  - `docs/SPEC.md`
  - `docs/LOGIC_SPEC.md`
  - `docs/CURRENT_STATUS.md`
  - `docs/FEATURES_AUDIT.md`
  - `docs/NEXT_DEVELOPMENT_ITEMS.md`
  - `docs/SERVER_CHANGES_2026_06_10.md`
  - `supabase/FUNCTIONS_REFERENCE.md`
  - `supabase/CHECK_ALL_MIGRATIONS.sql`
- تمت إضافة RPCs متوافقة مع وضع التطوير لمسار التوثيق (`request_verification_by_uid` / `admin_approve_verification_by_admin` / `admin_reject_verification_by_admin`) حتى لا يبقى هذا المسار مكسوراً في الاختبار الحالي.
- بقي `S-01` بحالة `BLOCKED` جزئياً لأن الإغلاق الكامل يتطلب التخلص من مسار dev fallback الحالي أو ربطه بجلسة Supabase Auth حقيقية.

---

## 8) قاعدة التحديث بعد كل إصلاح

عند إنهاء أي إصلاح، يجب تحديث العناصر التالية هنا:

1. تغيير الحالة في الجدول الرئيسي.
2. إضافة سطر في **سجل التنفيذ الزمني** يذكر:
   - ما الذي تم إصلاحه
   - ما الملفات التي تعدلت
   - هل تم تحديث التوثيق أم لا
3. إذا نتجت مشكلة جديدة، تُضاف كبند جديد في الجدول.
4. إذا تغيّر ترتيب الأولويات، يتم تعديله هنا مباشرة.

---

## 9) نقطة الانطلاق للمحادثة القادمة

إذا انقطعت المحادثة، ابدأ من هنا مباشرة:

- اقرأ أولاً:
  - `docs/LOGIC_REPAIR_TRACKER.md`
  - `docs/LOGIC_AUDIT_2026_06_10.md`
  - `docs/LOGIC_SPEC.md`
- ثم تابع من أول بند حالته `OPEN` أو `IN_PROGRESS` حسب السجل.

### الحالة الحالية المختصرة للمحادثة
- تم تنفيذ دفعة إصلاحات منطقية كبيرة وتحديث التوثيق المرجعي.
- جميع البنود المسجلة في التدقيق أصبحت `FIXED_VERIFIED` ما عدا `S-01`.
- `S-01` ما يزال **محجوباً جزئياً** بسبب نموذج المصادقة التطويري الحالي، رغم أنه تم تشديده قدر الإمكان داخل المستودع.
