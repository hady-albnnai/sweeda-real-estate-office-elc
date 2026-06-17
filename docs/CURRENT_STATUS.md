# الحالة الحالية — المكتب العقاري الإلكتروني

**آخر تحديث:** 2026-06-17
**الفرع:** `main`
**الحالة العامة:** إصلاحات الأولويات P1/P2/P3/P4 وجزء من P5 مطبقة ومرفوعة، بانتظار تشغيل تحليل Flutter والاختبار العملي الكامل.

---

## آخر تعديلات مهمة

| المجال | الحالة |
|---|---|
| تنظيم الدخول والمصادقة | اعتماد نظام القائمتين (دخول/تسجيل) مع شعار عملاق ومسار SMS حصراً (2026-06-16) |
| إعداد الحساب الإلزامي | إضافة تأكيد حفظ البيانات قبل تعيين اسم المستخدم وكلمة المرور |
| تحديث شاشة السبلاش | تكبير الشعار (85% من العرض) وتحديث الخطوط لنوع Cairo 900 وMontserrat |
| إعادة هيكلة إدارة الموظفين | مطبقة على الكود والسيرفر (تشمل العنوان والرقم الوطني وصورتي الهوية وجه/قفا) |
| تنظيف النظام (Wipe) | تم تنفيذ مسح شامل للبيانات التجريبية (2026-06-16) |
| إعادة تصميم شاشة حسابي للزائر | استخدام نظام القوائم المنسدلة (Expandable) بأسلوب فخم ومنظم |
| Edge Functions إدارة الموظفين | `create-user` محدثة بالكود، وتمت إضافة `get-staff-id-images`؛ يلزم نشرهما بعد السحب |
| Staff Sessions Security | مطبقة ومتحقق منها |
| إغلاق RPCs القديمة الحساسة | مطبق |
| إصلاح كشف الاحتيال | تم إصلاح خطأ FORBIDDEN عبر RPC جديد |
| توحيد الأخطاء الأولي | مطبق على المسارات الحساسة الأساسية |
| تفكيك `AdminProvider` | الخدمات الأساسية مستخرجة |
| إحصائيات لوحة الإدارة | `get_admin_dashboard_stats` مطبقة ومتحقق منها |
| CI | مضاف عبر GitHub Actions: `flutter analyze` و`flutter test` عند push/PR على `main` |
| SQL verification | تمت إضافة وتشغيل `supabase/tests/admin_security_verification.sql` بنجاح — لا توجد grants خطرة والجلسة الوهمية تفشل كما يجب |
| دليل الاختبار اليدوي حسب الدور | تمت إضافة `docs/MANUAL_TEST_PLAN_BY_ROLE.md` كمرجع تفصيلي للاختبار الجماعي لكل الأدوار |
| تأمين تسجيل الإيميل | تم نقل upsert مستخدم الإيميل من العميل إلى RPC آمنة `handle_email_auth_internal` تعتمد على JWT وتمنع التكرار |
| تأمين تسجيل الهاتف | تم نقل تحقق SMS OTP وإنشاء المستخدم إلى Edge Function `verify-sms-otp` تمهيداً لإغلاق RPCs المباشرة عن العميل |
| خطة الدومين والإيميل | تمت إضافة `docs/DOMAIN_EMAIL_SETUP_PLAN.md` كمرجع شراء وربط الدومين مع Resend وSupabase |

---

## آخر migrations مضافة

- `2026_06_17_lock_otp_direct_rpcs.sql`
- `2026_06_17_secure_email_auth_internal.sql`
- `2026_06_16_staff_enhancements_and_wipe.sql`
- `2026_06_15_admin_employee_management_final.sql`
- `2026_06_15_staff_sessions_security.sql`
- `2026_06_15_lock_legacy_admin_rpcs.sql`
- `2026_06_15_admin_dashboard_stats.sql`

---

## Edge Functions الإدارية

- `create-user` (منشورة سابقاً، وآخر نسخة بالكود تدعم صورتي الهوية — تحتاج deploy)
- `get-staff-id-images` (جديدة — تحتاج deploy)
- `update-user-role`
- `toggle-user-status`
- `reset-user-password`
- `delete-user`
- `update-user-permissions`

---

## خدمات الإدارة المستخرجة من `AdminProvider`

- `StaffAdminService`
- `UsersAdminService`
- `OffersAdminService`
- `AppointmentsAdminService`
- `DealsAdminService`
- `PaymentsAdminService`
- `ReportsAdminService`
- `StatsAdminService`
- `VerificationsAdminService`

---

## ما يجب تنفيذه قبل إعلان 100%

- [x] تشغيل `flutter analyze` محلياً — لا توجد مشاكل.
- [x] إضافة اختبارات وحدة أساسية لـ `PermissionService` و`ErrorUtils` و`InputValidators`.
- [x] تشغيل `flutter test` — النتيجة: All tests passed.
- [x] إصلاح overflow في أيقونة أقسام الإدارة في لوحة المدير (`AdminDashboardScreen`).
- [x] إصلاح أخطاء التحليل في `BecomeBrokerScreen` (إزالة RadioGroup غير الموجود) و `UserDetailsScreen`.
- [ ] تنفيذ اختبار عملي كامل لإدارة الموظفين (بعد التنظيف).
- [x] تنفيذ `supabase/tests/admin_security_verification.sql` بعد إصلاحات P1/P2/P5 ونجاحه.
- [x] التأكد أن المدير يستطيع الدخول بـ `main_admin` وأن الجلسة تصدر بشكل صحيح.
- [ ] اختبار أن Edge Functions ترفض الطلبات بدون `staff_session_token`.
- [x] تطبيق نظام الملف الشخصي المزدوج (موظف vs عميل).
- [x] إضافة حقول (الرقم الوطني، العنوان، صورتي الهوية وجه/قفا) لإضافة الموظف.
- [x] إضافة عرض تفاصيل الموظف وصور هويته للمدير/نائب المدير.
- [x] تصفير النظام من البيانات التجريبية.
- [x] إصلاح أخطاء الصياغة والاستيراد (Imports) في `OfferCard` و `SplashScreen` و `FraudSuspectsScreen` و `AddEmployeeDialog`.
- [x] إضافة دليل اختبار يدوي شامل حسب الدور: `docs/MANUAL_TEST_PLAN_BY_ROLE.md`.

---

## ملاحظات أمنية

- لا يتم الاعتماد على `admin_uid` وحده في Edge Functions الإدارية.
- الدوال القديمة الحساسة مغلقة عن `anon/authenticated` وتعمل عبر `service_role` فقط.
- `soft_delete` العام مغلق عن العميل.
- `pwd` لا يكشف كهاش، ويعود فقط كـ flag في دوال القراءة.

---

## ملاحظة تحليل Flutter

تم ضبط `analysis_options.yaml` لتجاهل بعض قواعد المعلومات UI المؤجلة مثل deprecations و`prefer_const`، مع إبقاء الأخطاء والتحذيرات البنيوية ظاهرة. الهدف الحالي هو تثبيت الإصلاحات الأمنية والمعمارية ثم تنظيف UI تدريجياً.

---

## تحديث تنقل الإدارة

تمت إضافة مسار `/admin/operations-dashboard` للوصول إلى لوحة العمليات والأقسام القديمة من زر داخل شاشة إدارة الموظفين، حتى لا تبقى إدارة الموظفين شاشة معزولة عن باقي أقسام الإدارة.
---

## تحديث وجهة المدير الرئيسية

تم تعديل `/admin/dashboard` ليكون لوحة قيادة المدير (`AdminDashboardScreen`) بدلاً من فتح إدارة الموظفين مباشرة. أصبحت إدارة الموظفين متاحة كبطاقة داخل لوحة المدير وعبر `/admin/employee-management`.

---

## Input Validation & Abuse Hardening

تمت إضافة طبقة تحقق أولية للمدخلات في Flutter وSQL. تشمل helpers للسيرفر وتحديث RPCs مهمة مثل إنشاء العرض والطلب وتحديث الملف الشخصي وإنشاء الموظف. الحالة: مطبقة ومتحقق منها على السيرفر؛ دوال `app_*` موجودة، والاختبارات الإيجابية نجحت، وتم التأكد من الحفاظ على منطق `added_by` و`v_effective_pkg` في `create_offer_internal`.
---

## تحسينات تجربة المستخدم الأخيرة

- [x] Offer Expiration and Reminders -> Implemented proper display of expiration counter in the UI, and fixed database functions for `expire_offers` and `send_renewal_reminders` to accurately notify users 3 days before their offers expire.
- [x] Login Redirection Issue (Password Auth) -> Fixed the routing issue after successful login to navigate based on role.
- [x] Profile Redirection Issue -> Fixed the bottom navigation bar and home screen routing so logged-in users go to their dashboard/profile correctly instead of falling back to the login screen.
- تكبير شعار شاشة السبلاش ليأخذ مساحة أكبر من الشاشة بشكل متجاوب.
- تعديل تنقل أقسام لوحة المدير لاستخدام `push` بدلاً من `go` حتى تظهر أسهم الرجوع عند الدخول إلى شاشات الإدارة الفرعية.
---

## تحديث تجربة أقسام الإدارة

- تم إنشاء شاشة مستقلة `/admin/sections` لأقسام الإدارة بدلاً من Bottom Sheet، حتى يعمل الرجوع من الشاشات الفرعية إلى قائمة الأقسام.
- تم إبقاء إدارة الموظفين داخل أقسام الإدارة فقط، وإزالة بطاقتها المباشرة من لوحة المدير.
- تم تعديل إدارة المستخدمين لتعرض العملاء والوسطاء فقط (`role 0/1`) وعدم عرض أعضاء الإدارة والموظفين الداخليين.
- تم إصلاح overflow في ملخص مركز عمليات المكتب عبر ارتفاع ثابت للكروت.

---

## تحديث إدارة الموظفين — 2026-06-17

- إضافة الموظف أصبحت تدعم اختيار صورتين للهوية: وجه وقفا.
- يتم إرسال صور الهوية إلى Edge Function `create-user` كـ Base64 ثم رفعها من السيرفر إلى `ids_private` عبر `service_role` لتجنب مشاكل RLS.
- `users.img` قد يحتوي مساراً واحداً قديماً أو JSON Array لمسارين عند وجود صورتين.
- تمت إضافة Edge Function `get-staff-id-images` لإرجاع signed URLs مؤقتة لصور هوية الموظف.
- شاشة إدارة الموظفين أصبحت تحتوي خيار **عرض التفاصيل**: بيانات الموظف + زر عرض صور الهوية مع زوم وتصفح.
- صلاحية عرض التفاصيل الحساسة محصورة بالمدير ونائب المدير، مع منع نائب المدير من عرض بيانات إدارة عليا أخرى.

---

## تحديث تسجيل الإيميل — 2026-06-17

- تم إيقاف إنشاء/جلب مستخدم الإيميل من التطبيق مباشرة عبر select/insert.
- التطبيق يستدعي الآن RPC: `handle_email_auth_internal`.
- الدالة تقرأ الإيميل من `auth.jwt()` ولا تسمح للعميل بتمريره، مما يمنع spoofing.
- تمت إضافة unique index للإيميل بصيغة `lower(trim(eml))` للحسابات النشطة.
- تمت إزالة unique constraint الخام عن `users.ph` واستبداله بفهرس unique على الهاتف غير الفارغ بعد التطبيع، حتى لا تتعارض حسابات الإيميل التي لا تملك هاتفاً.
- مستخدم الإيميل الجديد ينشأ بـ `users.id = auth.uid()` لتحسين توافق RLS المستقبلي.

---

## تحديث تسجيل الهاتف — 2026-06-17

- لم يعد التطبيق يستدعي `verify_otp_v2` أو `upsert_user_after_otp` مباشرة أثناء تحقق SMS.
- تمت إضافة Edge Function جديدة: `verify-sms-otp`.
- بعد نشر الدالة وتطبيق قفل RPCs، تصبح دوال OTP/upsert المباشرة متاحة لـ `service_role` فقط.
- يوجد فهرس unique على الهاتف بعد التطبيع لمنع أكثر من حساب نشط بنفس الرقم مهما اختلفت صيغة الإدخال.
