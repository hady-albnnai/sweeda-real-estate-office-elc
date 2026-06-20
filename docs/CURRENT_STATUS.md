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
| Edge Functions إدارة الموظفين | `create-user` و`get-staff-id-images` منشورتان ومحدثتان لدعم صورتي الهوية وعرضهما بروابط مؤقتة |
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
| زر الرجوع للأدوار الداخلية | تمت إضافة زر رجوع موحد لشاشات المدير/النائب/الموظف/الوسيط/المصور/المنفذ، مع fallback آمن عند عدم وجود back stack |
| توحيد لوحة نائب المدير | تم إلغاء فصل `/deputy/dashboard` عملياً وجعل نائب المدير يستخدم نفس لوحة المدير `/admin/dashboard`، مع بقاء الفروقات عبر الصلاحيات ومنع إدارة النواب/المدير |
| توحيد شاشة موظف المكتب | تم توحيد دخول role=4 إلى `/employee/home` وإبقاء `/employee/dashboard` كتوافق خلفي فقط لنفس الشاشة، لتفادي اختلاف التجربة حسب نقطة الدخول |
| حذف شاشة موظف مكتب غير مستخدمة | تم حذف `lib/screens/admin/employee_dashboard_screen.dart` بعد توحيد موظف المكتب على `/employee/home` |
| فلو المنفذ والمصور | تمت إضافة Migration وكود لتصحيح طلبات إتمام المنفذ، بدء مهمة التصوير، منع تكرار مهام المصور، وجلب المهام عبر RPC |
| Database linter hardening | تم إصلاح `security_definer_view` و`function_search_path_mutable` بالكامل، وتشديد `otp_codes/user_devices` وسياسات public bucket listing، وقفل دوال OTP legacy و`admin_create_staff_user` و`admin_wipe_test_data` ودوال النقاط/الإشعارات/trigger/helper الداخلية |
| قفل دوال النقاط المباشرة | تم قفل `add_points` و`award_points_safe` عن العميل؛ قد تتوقف مكافآت النقاط المباشرة مؤقتاً إلى أن تُنقل إلى Edge Functions/Triggers موثوقة |
| قفل دوال الإشعارات المباشرة | تم قفل `notify_user` و`send_push_notification` عن العميل؛ يجب أن تُنشأ الإشعارات مستقبلاً عبر Triggers/Edge Functions موثوقة |
| خطة قفل RPC تدريجياً | تمت إضافة `docs/SECURITY_DEFINER_RPC_HARDENING_PLAN.md` لتوثيق الدوال المفتوحة المتبقية وتصنيفها وخطة نقلها إلى Edge Functions قبل قفلها |
| نقل إدارة العروض إلى Edge Function | `admin-offers` منشورة ومختبرة، وRPCs الخاصة بالعروض مقفلة عن العميل |
| نقل إدارة التوثيق إلى Edge Function | `admin-verifications` منشورة ومختبرة، وRPCs الخاصة بالتوثيق مقفلة عن العميل |
| نقل إدارة المدفوعات إلى Edge Function | `admin-payments` منشورة ومختبرة، وRPCs الخاصة بالمدفوعات مقفلة عن العميل |
| نقل إدارة المواعيد إلى Edge Function | تم النشر وتحديث التطبيق وقفل RPCs بنجاح |
| نقل إدارة التبليغات إلى Edge Function | تم النشر وتحديث التطبيق وقفل RPCs بنجاح |
| نقل إدارة الصفقات إلى Edge Function | تم النشر وتحديث التطبيق وقفل RPCs بنجاح |
| نقل مهام المنفذ والمصور إلى Edge Functions | تم النشر وتحديث التطبيق وقفل RPCs بنجاح |
| نقل إدارة عروض المستخدم إلى Edge Function | تمت إضافة `user-offers` وقفل RPCs الخاصة بها بعد الاختبار |
| نقل إدارة طلبات المستخدم إلى Edge Function | تمت إضافة `user-requests` وقفل RPCs الخاصة بها بعد الاختبار |
| نقل حجز وإدارة مواعيد المستخدم إلى Edge Function | تمت إضافة `user-appointments` وقفل RPCs الخاصة بها بعد الاختبار |
| نقل إشعارات المستخدم إلى Edge Function | تمت إضافة `user-notifications` وقفل RPCs الخاصة بها بعد الاختبار |
| نقل حساب المستخدم إلى Edge Function | تمت إضافة `user-account` وقفل RPCs الخاصة بها بعد الاختبار |

---

## آخر migrations مضافة

- `2026_06_17_lock_admin_appointment_rpcs.sql`
- `2026_06_17_lock_admin_payment_rpcs.sql`
- `2026_06_17_lock_admin_verification_rpcs.sql`
- `2026_06_17_lock_admin_offer_rpcs.sql`
- `2026_06_17_linter_security_hardening.sql`
- `2026_06_17_executor_photography_flow_fixes.sql`
- `2026_06_17_lock_otp_direct_rpcs.sql`
- `2026_06_17_secure_email_auth_internal.sql`
- `2026_06_16_staff_enhancements_and_wipe.sql`
- `2026_06_15_admin_employee_management_final.sql`
- `2026_06_15_staff_sessions_security.sql`
- `2026_06_15_lock_legacy_admin_rpcs.sql`
- `2026_06_15_admin_dashboard_stats.sql`

---

## Edge Functions الإدارية

- `create-user` (منشورة ومحدثة لدعم الحقول الإضافية وصورتي الهوية)
- `get-staff-id-images` (منشورة — روابط مؤقتة لصور هوية الموظف)
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

---

## تحديث التنقل والرجوع — 2026-06-17

- تمت إضافة `AppBackButton` كزر رجوع موحد.
- إذا كانت الشاشة مفتوحة فوق stack سابق يستخدم `pop`.
- إذا كانت الشاشة مفتوحة عبر `go` ولا يوجد مسار سابق، ينتقل إلى `/user/profile` كمسار آمن.
- تمت إضافته لشاشات الأدوار الداخلية الرئيسية: المدير، نائب المدير، موظف المكتب، الوسيط، المصور، والمنفذ.
- تم تعديل تنقل بطاقات نائب المدير وموظف المكتب من `go` إلى `push` حتى يظهر الرجوع من الشاشات الفرعية.

---

## تحديث صلاحيات وتجربة نائب المدير — 2026-06-17

- تم إلغاء التحويل الخاص الذي كان يرسل role=5 من `/admin/dashboard` إلى `/deputy/dashboard`.
- أصبحت لوحة نائب المدير هي نفس لوحة المدير `AdminDashboardScreen`.
- المسار القديم `/deputy/dashboard` بقي للتوافق، لكنه يعرض نفس لوحة الإدارة الموحدة.
- الفروقات بين المدير ونائب المدير أصبحت عبر الصلاحيات فقط، وليس عبر شاشة منفصلة.
- إدارة الموظفين تخفي إجراءات التعديل/التعطيل/إعادة كلمة السر/الحذف عن نائب المدير عندما يكون الهدف مديراً أو نائب مدير آخر.
- قيود السيرفر ما زالت هي الحماية النهائية: المدير فقط يستطيع إنشاء/إدارة النواب، ولا يمكن إدارة المدير الرئيسي من نائب المدير.

---

## تحديث تجربة موظف المكتب — 2026-06-17

- تم رصد وجود شاشتين لموظف المكتب: `/employee/home` و`/employee/dashboard`، ما كان يسبب اختلاف التجربة حسب مكان الدخول.
- تم اعتماد `/employee/home` كشاشة موحدة لموظف المكتب لأنها أشمل وتعرض عمليات المكتب اليومية حسب الصلاحيات.
- أي انتقال قديم إلى `/employee/dashboard` أصبح يفتح نفس شاشة `/employee/home` كتوافق خلفي.
- تم حذف ملف الشاشة القديمة غير المستخدمة `employee_dashboard_screen.dart`.
- عند محاولة role=4 فتح `/admin/dashboard` يتم تحويله الآن إلى `/employee/home`.
- زر "لوحة التحكم الإدارية" من صفحة الحساب للموظف يذهب إلى `/employee/home`.

---

## تحديث فلو المنفذ والمصور — 2026-06-17

- المنفذ لم يعد يستخدم دالة مكتب تعرض كل طلبات الإتمام، بل دالة `get_my_completion_requests` التي تعرض طلباته هو فقط.
- شاشة تنفيذ مهمة المنفذ أصبحت تجلب المهمة مباشرة عبر `get_executor_task_by_appointment`.
- المصور أصبح يبدأ المهمة فعلياً على السيرفر عبر `start_photography_task_internal`، فتتحول الحالة إلى قيد التنفيذ.
- مهام المصور القادمة أصبحت بعد اليوم فقط لمنع التكرار بين اليوم والقادمة.
- جلب مهام المصور أصبح عبر RPC `get_photographer_tasks_internal`.
- تم استبدال `hashCode` في شاشة المصور باستخدام `task.id` كمفتاح ثابت للصور والملاحظات المؤقتة.

---

## تحديث Database Linter Security — 2026-06-17

- تم تحويل `users_public` إلى `security_invoker=true`.
- تم ضبط `search_path` لكل دوال `public` بحيث لا يبقى أي `function_search_path_mutable`.
- تم قفل دوال OTP القديمة والجديدة الحساسة لتعمل عبر `service_role` فقط.
- تم قفل `admin_create_staff_user` بنسختيه لتعمل عبر Edge Function `create-user` فقط.
- تم قفل `admin_wipe_test_data` عن `anon/authenticated`.
- تم استبدال سياسة `otp_codes` المفتوحة بسياسة `service_role` فقط.
- تم استبدال سياسة `user_devices` المفتوحة بسياسات own-device أو `service_role`.
- تم حذف سياسات SELECT الواسعة من `config_assets` و`offer_images` لمنع listing للملفات.
- بقيت دوال `SECURITY DEFINER` أخرى مفتوحة بشكل مقصود مؤقتاً لأن التطبيق لا يزال يعتمد على RPC مباشرة؛ ستُنقل تدريجياً إلى Edge Functions قبل قفلها.

---

## تحديث أمان النقاط — 2026-06-17

- تم قفل `add_points` و`award_points_safe` عن `anon/authenticated` وتركهما لـ `service_role` فقط.
- السبب: لا يجوز للعميل تمرير `uid` أو عدد النقاط أو نوع الحدث ثم منح نفسه/غيره نقاطاً.
- الأثر المؤقت: بعض مكافآت النقاط المباشرة من التطبيق قد لا تُمنح حالياً، مثل نقاط المشاركة أو بعض أحداث النشاط.
- الوظائف الأساسية لا تتأثر: التسجيل، العروض، الحجز، الإدارة، الموظفون، التصوير، والتنفيذ.
- الحل المطلوب لاحقاً: بناء Edge Function أو Triggers موثوقة لمنح النقاط بناءً على حدث مثبت في قاعدة البيانات، وليس بناءً على طلب مباشر من العميل.

---

## تحديث أمان الإشعارات — 2026-06-17

- تم قفل `notify_user` و`send_push_notification` عن `anon/authenticated` وتركهما لـ `service_role` فقط.
- السبب: لا يجوز للعميل إنشاء إشعارات أو إرسال push لأي مستخدم مباشرة.
- الأثر المؤقت: بعض الإشعارات التي كانت تُنشأ من العميل مباشرة قد لا تُنشأ حالياً.
- الحل المطلوب لاحقاً: نقل إنشاء الإشعارات إلى Triggers أو Edge Functions موثوقة بعد تحقق الحدث الفعلي.
