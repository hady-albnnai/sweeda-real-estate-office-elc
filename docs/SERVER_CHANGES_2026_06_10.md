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
| `supabase/migrations/2026_06_10_qa_system_check.sql` | فحص النظام الأولي |
| `supabase/migrations/2026_06_10_extend_qa_system_check.sql` | فحص النظام الموسع |
| `supabase/migrations/2026_06_10_ensure_config_locs.sql` | ضمان وجود `locs` داخل `app_config.main` |

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

#### `qa_system_check`

دالة فحص شاملة من شاشة:

```txt
/admin/qa
```

الغرض:

- التحقق من الجداول والدوال والفهارس والتخزين والبيانات.

تأثير الحذف:

- سيكسر شاشة فحص النظام فقط.
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
| `qa_system_check` | نعم، آمن نسبياً | يكسر شاشة QA فقط |
| `create_offer_internal` | لا يفضل | التطبيق يعتمد عليه لإضافة العرض |
| `admin_update_user_role` | لا يفضل | إدارة المستخدمين تعتمد عليه |
| `admin_set_user_status` | لا يفضل | إدارة المستخدمين والتبليغات تعتمد عليه |
| `users.perm` | لا يفضل | يكسر الصلاحيات |
| `photography_tasks` | لا يفضل بعد الاستخدام | حذف الجدول يحذف مهام التصوير |
| `normalize_sy_phone` والفهرس | لا يفضل | يعيد خطر تكرار الحسابات |

## توصية

- إذا ظهرت مشكلة في QA فقط، يمكن تعديل أو حذف `qa_system_check` دون لمس باقي النظام.
- إذا ظهرت مشكلة في الصلاحيات أو التصوير، الأفضل إصلاح الدالة المعنية لا حذفها.
- لا تحذف `photography_tasks` بعد بدء استخدامه إلا بعد أخذ نسخة احتياطية.
