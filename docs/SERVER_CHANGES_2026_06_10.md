# تغييرات السيرفر — 2026-06-10

> هذا الملف يوثق كل تغييرات Supabase التي أُضيفت خلال مرحلة الإدارة الداخلية/الصلاحيات/المصور/QA.
> الهدف: معرفة ما تم تنفيذه، ولماذا، وكيف يمكن التراجع عنه عند الحاجة.

## قاعدة مهمة

لا تنفذ rollback مباشرة إلا إذا ظهر خلل مؤكد. بعض الدوال أصبحت مستخدمة من التطبيق، وحذفها سيكسر شاشات معينة.

## الملفات المرتبطة

| الملف | الغرض |
|---|---|
| `supabase/migrations/2026_06_10_internal_permissions.sql` | إضافة `users.perm` ودالة الصلاحيات الأساسية |
| `supabase/migrations/2026_06_10_add_media_review_permission.sql` | إضافة صلاحية `media_review` لدالة الصلاحيات |
| `supabase/migrations/2026_06_10_photography_tasks.sql` | جدول مهام التصوير وسياساته الأساسية |
| `supabase/migrations/2026_06_10_admin_user_role_and_phone_uniqueness.sql` | إصلاح تغيير الأدوار/الحالة ومنع تكرار الهاتف |
| `supabase/migrations/2026_06_10_offer_create_rpc_and_admin_quota.sql` | إنشاء العرض عبر RPC وإعفاء الإدارة من الحصة |
| `supabase/migrations/2026_06_10_fix_upsert_user_phone_normalization.sql` | تطبيع الهاتف داخل `upsert_user_after_otp` |
| `supabase/migrations/2026_06_10_photography_dev_auth_rpcs.sql` | دوال التصوير المتوافقة مع وضع التطوير |
| `supabase/migrations/2026_06_10_ensure_config_locs.sql` | ضمان وجود `locs` داخل `app_config.main` |
| `supabase/migrations/2026_06_10_logic_fixes_appointments_offers.sql` | إصلاح منطق المواعيد + توحيد pending offers + تشديد إنشاء العرض |
| `supabase/migrations/2026_06_10_logic_fixes_boosts_payments.sql` | إصلاح منطق boosts والمدفوعات |
| `supabase/migrations/2026_06_10_config_package_prices_and_fx.sql` | نقل أسعار الباقات وسعر الصرف إلى Config |
| `supabase/migrations/2026_06_10_auth_uid_alignment_guards.sql` | حراسة جزئية تربط uid المُرسل بـ `auth.uid()` متى كانت الجلسة الحقيقية متاحة |
| `supabase/migrations/2026_06_10_users_public_no_private_img.sql` | إزالة مسار صورة الهوية الخاصة من `users_public` |
| `supabase/migrations/2026_06_10_verification_dev_auth_rpcs.sql` | RPCs توثيق متوافقة مع وضع التطوير الحالي |
| `supabase/migrations/2026_06_11_drop_obsolete_verification_rpcs.sql` | حذف RPCs التوثيق القديمة غير المستخدمة |
| `supabase/migrations/2026_06_11_drop_obsolete_unused_rpcs.sql` | حذف RPCs قديمة غير مستخدمة بعد التحقق من عدم اعتماد التطبيق والسيرفر عليها |
| `supabase/migrations/2026_06_11_real_test_stabilization_internal_rpcs.sql` | تحويل دفعة إضافية من المسارات الحساسة إلى RPCs وتجهيز التطبيق للاختبار الحقيقي |
| `supabase/migrations/2026_06_11_real_test_stabilization_internal_rpcs.sql` | دفعة تثبيت إضافية قبل الاختبار الحقيقي لتحويل المسارات الحساسة إلى RPCs وتحسين بعض السياسات |

## تحديث لاحق — إصلاحات منطقية

تمت إضافة دفعة إصلاحات منطقية جديدة تركّز على:

- توحيد حالات المواعيد واعتماد `appointments.req_uid` لطالب الموعد.
- نقل منطق الحصة وكشف التكرار إلى `create_offer_internal`.
- جعل العرض الجديد يعود إلى `sts=1` (قيد المراجعة) بدل الالتباس السابق بين المسودة والمراجعة.
- جعل `purchase_offer_boost` يحسب الكلفة من `app_config.spd` على السيرفر بدلاً من قبولها من العميل.
- تشديد `approve_payment_final` ليتحقق من دور الإداري وحالة الدفعة وتمديد الباقة بشكل تراكمي.
- نقل أسعار الباقات (`pkg.*.pr`) وسعر الصرف (`fx.usd_syp`) إلى Config.
- إضافة حراسات جزئية تربط `auth.uid()` بالـuid المُرسل حين تكون جلسة Supabase Auth الحقيقية متاحة، مع الحفاظ على توافق وضع التطوير الحالي.
- إزالة مسار صورة الهوية الخاصة من `users_public` بعد فصل الهوية الخاصة عن أي avatar عام.
- إضافة RPCs متوافقة مع وضع التطوير لتقديم/اعتماد/رفض التوثيق دون كسر التدفق الحالي.
- إضافة تنظيف لاحق لحذف RPCs التوثيق القديمة بعد التأكد من اعتماد المسارات الجديدة على التطبيق والسيرفر.
- إضافة تنظيف إضافي لحذف `admin_update_user_permissions` و `verify_otp_safe` بعد فحص عدم وجود تبعيات داخلية وعدم وجود استخدام من التطبيق الحالي.
- تجهيز دفعة تثبيت إضافية قبل الاختبار الحقيقي لتحويل مسارات حساسة واسعة من direct DB operations إلى RPCs متوافقة مع نموذج المصادقة الحالي.

## التغييرات حسب النوع

### 1. أعمدة وفهارس

#### `users.perm`

```sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS perm JSONB NOT NULL DEFAULT '[]'::jsonb;
```

الغرض:

- تخزين الصلاحيات المخصصة للمستخدم.
- إذا كانت فارغة، يعتمد التطبيق صلاحيات الدور الافتراضية.

تأثير الحذف:

- سيكسر شاشة إدارة الصلاحيات.
- سيجعل التطبيق يعتمد فقط على `role`.

#### `ux_users_normalized_phone_active`

فهرس فريد يمنع تكرار رقم الهاتف بعد التطبيع.

الغرض:

- منع إنشاء أكثر من حساب لنفس الرقم بصيغ مختلفة.

تأثير الحذف:

- قد يعود خطر تكرار الحسابات لنفس رقم الهاتف.

---

### 2. دوال إدارة المستخدمين والصلاحيات

#### `admin_update_user_permissions`

دالة الصلاحيات الأساسية المعتمدة على `auth.uid()`.

#### `admin_update_user_permissions_by_admin`

نسخة متوافقة مع وضع التطوير الحالي، تقبل:

```sql
p_admin_uid
```

وتفحص دوره من جدول `users`.

#### `admin_update_user_role`

تغيير دور المستخدم من الإدارة.

#### `admin_set_user_status`

تغيير حالة المستخدم:

- نشط
- مجمّد
- محظور

#### `normalize_sy_phone`

تطبيع أرقام سوريا إلى صيغة موحدة.

---

### 3. دوال العروض

#### `create_offer_internal`

إنشاء عرض عبر RPC بدل `INSERT` مباشر.

الغرض:

- تفادي مشاكل RLS في وضع WhatsApp dev fallback.
- دعم إضافة عروض من الإدارة بدون قيود باقة مجانية.

تأثير الحذف:

- سيكسر `OfferProvider.addOffer` بعد آخر تعديلات.

---

### 4. مهام التصوير

#### جدول `photography_tasks`

جدول مهام التصوير.

#### دوال التصوير

- `create_photography_task_internal`
- `submit_photography_task_internal`
- `update_photography_task_status_internal`
- `attach_photography_media_to_offer_internal`

الغرض:

- إنشاء مهمة تصوير.
- إرسال التصوير من المصور.
- رفض/اعتماد التصوير من الإدارة.
- ربط صور التصوير بالعرض.

تأثير الحذف:

- سيكسر شاشة `/admin/photography-management`.
- سيكسر شاشة `/photographer/tasks`.

---

### 5. دوال الفحص QA


دالة فحص شاملة من شاشة:

```txt
```

الغرض:

- التحقق من الجداول والدوال والفهارس والتخزين والبيانات.

تأثير الحذف:

- لا يؤثر على وظائف المستخدمين الأساسية.

---

## كيف نتراجع؟

راجع ملف:

```txt
supabase/ROLLBACK_2026_06_10_INTERNAL_MANAGEMENT.sql
```

## تصنيف خطورة التراجع

| التغيير | يمكن التراجع؟ | ملاحظات |
|---|---|---|
| `create_offer_internal` | لا يفضل | التطبيق يعتمد عليه لإضافة العرض |
| `admin_update_user_role` | لا يفضل | إدارة المستخدمين تعتمد عليه |
| `admin_set_user_status` | لا يفضل | إدارة المستخدمين والتبليغات تعتمد عليه |
| `users.perm` | لا يفضل | يكسر الصلاحيات |
| `photography_tasks` | لا يفضل بعد الاستخدام | حذف الجدول يحذف مهام التصوير |
| `normalize_sy_phone` والفهرس | لا يفضل | يعيد خطر تكرار الحسابات |

## توصية

- إذا ظهرت مشكلة في الصلاحيات أو التصوير، الأفضل إصلاح الدالة المعنية لا حذفها.
- لا تحذف `photography_tasks` بعد بدء استخدامه إلا بعد أخذ نسخة احتياطية.

## تحديث لاحق — إزالة QA من النسخة النظيفة

تم حذف شاشة فحص النظام وملفات QA من التطبيق والمستودع بعد انتهاء الاستفادة منها. لحذف دالة الفحص من السيرفر استخدم:

```txt
supabase/migrations/2026_06_10_remove_qa_system_check.sql
```

هذا لا يؤثر على وظائف الإدارة أو الصلاحيات أو المصور، فقط يزيل دالة الفحص المؤقتة.
