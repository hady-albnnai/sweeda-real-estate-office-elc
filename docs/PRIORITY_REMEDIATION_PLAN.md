# خطة الإصلاح ذات الأولوية — المكتب العقاري الإلكتروني

**التاريخ:** 2026-06-15
**الحالة:** خطة عمل جديدة معتمدة بعد مراجعة خارجية ناقدة
**النطاق:** أمان، اعتمادية، تنظيم معماري، اختبارات، وتوثيق
**المراجع الإلزامية:**
- `docs/LOGIC_SPEC.md`
- `DEVELOPMENT_GUIDELINES.md`
- `supabase/FUNCTIONS_REFERENCE.md`
- `docs/TEST_CHECKLIST.md`

---

## 0) ملخص تنفيذي

بعد اكتمال إعادة هيكلة إدارة الموظفين ونشر RPCs وEdge Functions، تبيّن أن المشروع وظيفياً متقدم، لكنه يحتاج إصلاحات ذات أولوية قبل اعتباره جاهزاً إنتاجياً بشكل آمن.

أهم مشكلة يجب البدء بها ليست شكل الواجهة، بل **نموذج الثقة والصلاحيات**:

> لا يجوز أن تعتمد العمليات الحساسة على `admin_uid` أو `user_uid` مرسل من العميل دون جلسة موثوقة أو تحقق سيرفر حقيقي.

لذلك ستكون الأولوية الأولى هي بناء طبقة جلسات/مصادقة آمنة للموظفين والإدارة، ثم ربط Edge Functions بها، ثم تنظيف الأخطاء والصلاحيات والهيكلة.

---

## 1) ترتيب الأولويات

| الأولوية | المجال | الهدف | الحالة |
|---|---|---|---|
| P0 | تثبيت خط الأساس | توثيق الوضع الحالي وعدم كسر ما تم نشره | جاهز للبدء |
| P1 | أمان الإدارة والمصادقة | إلغاء الثقة بـ `admin_uid` وحده | مطبق على السيرفر — بانتظار اختبار عمليات Edge Functions |
| P2 | إغلاق RPCs الخطرة | تقليل صلاحيات `anon/authenticated` للدوال الحساسة | مطبّق على السيرفر — بانتظار اختبار تكاملي |
| P3 | معالجة الأخطاء | منع ابتلاع الأخطاء بصمت | قيد التنفيذ: أساس AppResult/ErrorUtils مضاف |
| P4 | تفكيك AdminProvider | فصل الخدمات والمسؤوليات | قيد التنفيذ: الخدمات الأساسية مستخرجة |
| P5 | إحصائيات ودوال مجمعة | تقليل تحميل القوائم الكبيرة | أداء وقابلية توسع |
| P6 | اختبارات وCI | تشغيل تحليل واختبارات تلقائية | قبل إعلان الاستقرار |
| P7 | تنظيف وتوثيق طويل الأمد | توحيد الحالة والمرجعيات | مستمر |

---

# P0 — تثبيت خط الأساس قبل الإصلاح

## الهدف

تثبيت حالة المشروع الحالية كخط أساس واضح قبل أي تعديل أمني عميق.

## المهام

- [ ] تنفيذ اختبار عملي سريع للتأكد أن إدارة الموظفين المنشورة حالياً تعمل:
  - `create-user`
  - `update-user-role`
  - `toggle-user-status`
  - `reset-user-password`
  - `delete-user`
- [ ] تسجيل نتائج الاختبار في `docs/TEST_CHECKLIST.md`.
- [ ] عدم إعلان 100% حتى تنجح الاختبارات.
- [ ] حفظ أي أخطاء تظهر كقائمة Issues داخل خطة التنفيذ.

## Definition of Done

- لدينا موظف اختبار تم إنشاؤه ثم حذفه منطقياً.
- تم التأكد أن `activity_log` يسجل العمليات.
- تم التأكد أن المدير الرئيسي لا يمكن حذفه أو تعديله عبر الدوال الجديدة.

---

# P1 — إصلاح أمان المصادقة وجلسات الإدارة

## المشكلة

حالياً عدة عمليات حساسة تعتمد على `admin_uid` أو `user_uid` مرسل من العميل. إذا لم تكن هناك جلسة Supabase Auth حقيقية، فإن `auth.uid()` داخل الدوال قد يكون `NULL`، وبالتالي لا يوجد ربط قوي بين الطلب والفاعل الحقيقي.

## القرار المعتمد للمرحلة الحالية

نبدأ بحل عملي آمن دون هدم النظام الحالي:

> بناء نظام جلسات داخلي للموظفين والإدارة `staff_sessions`، ثم ربط Edge Functions الحساسة به.

هذا الحل أسرع وأقل مخاطرة من نقل كل النظام فوراً إلى Supabase Auth، مع إبقاء خيار الترحيل إلى Supabase Auth لاحقاً.

## التصميم المقترح

### جدول جديد

`staff_sessions`

حقول مقترحة:

| الحقل | النوع | الغرض |
|---|---|---|
| `id` | UUID | معرف الجلسة |
| `user_id` | UUID | الموظف/المدير |
| `token_hash` | TEXT | هاش التوكن، لا نخزن التوكن الصريح |
| `role_snapshot` | INT | الدور لحظة إصدار الجلسة |
| `expires_at` | TIMESTAMPTZ | انتهاء الجلسة |
| `revoked` | INT | 0/1 |
| `created_at` | TIMESTAMPTZ | وقت الإنشاء |
| `last_used_at` | TIMESTAMPTZ | آخر استخدام |
| `device_id` | TEXT | اختياري |
| `ip` | TEXT/INET | اختياري |

### RPCs جديدة

- `create_staff_session_after_password_login(p_user_uid, p_device_id)`
- `validate_staff_session(p_user_uid, p_token)`
- `revoke_staff_session(p_user_uid, p_token)`
- `revoke_all_staff_sessions(p_user_uid)`

### تعديل login

`login_with_password` أو طبقة AuthProvider يجب أن تستلم:

```json
{
  "success": true,
  "user_id": "...",
  "session_token": "...",
  "expires_at": "..."
}
```

ويخزن Flutter:

- `user_id`
- `staff_session_token`
- `session_expires_at`

### تعديل Edge Functions الإدارية

كل دالة إدارية يجب أن تستقبل وتتحقق من:

- `admin_uid`
- `staff_session_token`

ولا تنفذ أي عملية إذا فشل التحقق.

الدوال المعنية:

- `create-user`
- `update-user-role`
- `toggle-user-status`
- `reset-user-password`
- `delete-user`

## المهام

- [x] إنشاء migration لجداول ودوال الجلسات.
- [x] تعديل `login_with_password` لإصدار جلسة للموظفين الداخليين.
- [x] تعديل `AuthProvider.loginWithPassword` لتخزين التوكن.
- [x] تعديل `AuthService.signOut` لإلغاء الجلسة وحذفها محلياً.
- [x] تعديل `AdminProvider` لإرسال `staff_session_token` مع كل Edge Function حساسة.
- [x] تعديل Edge Functions للتحقق من الجلسة قبل تنفيذ RPC الحساسة.
- [ ] إضافة revoke عند تسجيل الخروج.
- [ ] إضافة انتهاء صلاحية للجلسة.
- [ ] اختبار أن من يعرف `admin_uid` فقط لا يستطيع تنفيذ أي عملية بعد إعادة نشر Edge Functions.

## Definition of Done

- لا يمكن استدعاء أي Edge Function إدارية بمجرد معرفة `admin_uid`.
- كل عملية إدارية تحتاج `staff_session_token` صالح.
- الجلسة تنتهي أو تلغى بشكل صحيح.
- إذا تغيرت حالة المستخدم إلى مجمد/محظور، تفشل الجلسة.

---

# P2 — إغلاق وتنظيف RPCs الحساسة القديمة

## المشكلة

بعض الدوال القديمة ما زالت ممنوحة لـ `anon/authenticated` لأنها مستخدمة في شاشات قديمة:

- `admin_update_user_role`
- `admin_set_user_status`

تم تقويتها، لكن ما زالت من حيث المبدأ تقبل `p_admin_uid` من العميل.

## القرار

بعد تطبيق P1، يتم نقل كل الشاشات الحساسة إلى Edge Functions + جلسات الموظفين، ثم إغلاق الدوال القديمة عن العميل.

## المهام

- [x] حصر استخدامات `admin_update_user_role`, `admin_set_user_status`, `soft_delete`.
- [x] نقل استدعاءات تغيير الدور/الحالة من `AdminProvider` إلى Edge Functions محمية بجلسة موظف.
- [x] إضافة Edge Function `update-user-permissions` لصلاحيات المستخدمين.
- [x] تجهيز migration لإغلاق EXECUTE عن `anon/authenticated` للدوال الحساسة القديمة.
- [x] توثيق الحالة في `FUNCTIONS_REFERENCE.md`.
- [x] تطبيق migration `2026_06_15_lock_legacy_admin_rpcs.sql` على السيرفر.
- [x] نشر Edge Function `update-user-permissions` وإعادة نشر `update-user-role` و`toggle-user-status`.

## Definition of Done

- لا توجد دالة حساسة تغير `role/sts/i_del/pwd` قابلة للاستدعاء من العميل مباشرة دون جلسة آمنة.
- كل تعديل إداري حساس يمر عبر Edge Function أو RPC محمية بجلسة موظف.

---

# P3 — نظام أخطاء موحد ومنع ابتلاع الأخطاء

## المشكلة

الكود يحتوي على عدد كبير من:

```dart
catch (e) {}
catch (e) { return false; }
catch (e) { return []; }
```

وهذا يخفي الأعطال ويصعّب الاختبار.

## التصميم المقترح

إنشاء نموذج نتيجة موحد:

```dart
class AppResult<T> {
  final bool success;
  final T? data;
  final String? errorCode;
  final String? message;
}
```

أو على الأقل توحيد الأخطاء داخل Providers.

## المهام

- [x] إنشاء `lib/core/utils/app_result.dart`.
- [x] إنشاء `lib/core/utils/error_utils.dart` لتطبيع رسائل الأخطاء.
- [x] البدء بالمسارات الحساسة في `AuthProvider` و`AdminProvider`.
- [x] عدم ابتلاع أخطاء Edge Functions داخل مسارات إدارة الموظفين/الصلاحيات.
- [x] عرض رسائل أوضح عبر `AdminProvider.error` و`AuthProvider.lastError`.
- [x] توسيع النمط إلى `PaymentProvider` و`OfferProvider`.
- [x] إضافة تتبع أخطاء أولي إلى `StorageService` و`FCMService`.
- [ ] لاحقاً: ربط Crashlytics أو جدول `client_errors`.

## Definition of Done

- لا توجد أخطاء صامتة في مسارات الإدارة والدفع والمصادقة.
- كل فشل حساس يظهر برسالة أو يسجل داخلياً.

---

# P4 — تفكيك AdminProvider وتنظيم طبقة الخدمات

## المشكلة

`AdminProvider` أصبح مسؤولاً عن مجالات كثيرة جداً، وهذا يصعّب الصيانة.

## الهيكل المقترح

```text
lib/services/admin/
  staff_admin_service.dart
  users_admin_service.dart
  offers_admin_service.dart
  payments_admin_service.dart
  reports_admin_service.dart
  stats_admin_service.dart

lib/providers/admin/
  staff_admin_provider.dart
  payments_admin_provider.dart
  reports_admin_provider.dart
```

أو بشكل تدريجي دون كسر الواجهات الحالية.

## المهام

- [x] استخراج Staff Admin إلى `StaffAdminService`.
- [x] استخراج Payments Admin إلى `PaymentsAdminService`.
- [x] استخراج Reports Admin إلى `ReportsAdminService`.
- [x] استخراج Offers Admin إلى `OffersAdminService`.
- [x] استخراج Stats Admin إلى `StatsAdminService`.
- [x] استخراج Appointments Admin إلى `AppointmentsAdminService`.
- [x] استخراج Deals Admin إلى `DealsAdminService`.
- [ ] إبقاء `AdminProvider` كواجهة توافقية مؤقتاً.
- [ ] تحديث الشاشات تدريجياً.

## Definition of Done

- لا يتجاوز أي Provider مسؤولية واحدة كبيرة.
- يمكن اختبار كل Service بشكل منفصل.
- شاشات الإدارة لا تعتمد على Provider ضخم واحد لكل شيء.

---

# P5 — إحصائيات مجمعة وأداء الداشبوردات

## المشكلة

بعض الإحصائيات تعتمد على تحميل قوائم ثم عدّها في Flutter، وهذا لا يتوسع.

## الحل

إنشاء RPCs مجمعة:

- `get_admin_dashboard_stats(p_admin_uid)`
- `get_employee_dashboard_stats(p_user_uid)`
- `get_deputy_dashboard_stats(p_user_uid)`

## المهام

- [ ] تصميم JSON ثابت لكل داشبورد.
- [ ] نقل العدّ للسيرفر.
- [ ] تقليل تحميل القوائم الكبيرة.
- [ ] إضافة فهارس عند الحاجة.

## Definition of Done

- الداشبوردات تستخدم RPC إحصائية واحدة أو اثنتين كحد أقصى.
- لا يتم تحميل كل المستخدمين/العروض فقط لحساب عدد.

---

# P6 — اختبارات وتحليل تلقائي

## المشكلة

لا يوجد حالياً ضمان آلي كافٍ بعد التعديلات.

## المهام

### Flutter

- [ ] تشغيل `flutter analyze`.
- [ ] تشغيل `flutter test`.
- [ ] إضافة Unit Tests لـ:
  - `PermissionService`
  - `UserModel.fromSupabase`
  - routing decisions إن أمكن

### SQL

- [ ] إنشاء `supabase/tests/admin_employee_management_verification.sql`.
- [ ] إضافة استعلامات تحقق بعد كل patch.

### CI

- [ ] إضافة GitHub Actions:
  - `flutter pub get`
  - `flutter analyze`
  - `flutter test`

## Definition of Done

- أي PR أو push يظهر فشل التحليل/الاختبار مبكراً.
- يوجد اختبار تحقق SQL لكل دوال الإدارة الحساسة.

---

# P7 — التوثيق والحالة الحالية

## المشكلة

التوثيق جيد لكنه موزع، وقد يحصل تضارب بين ملفات الخطة والتقدم والمرجع.

## الحل

إنشاء ملف حالة مركزي:

`docs/CURRENT_STATUS.md`

يحتوي دائماً على:

- آخر commit مطبق.
- آخر migration مطبق.
- Edge Functions المنشورة.
- ما ينتظر الاختبار.
- التحذيرات المفتوحة.

## المهام

- [ ] إنشاء `docs/CURRENT_STATUS.md`.
- [ ] ربطه من README.
- [ ] تحديثه بعد كل مرحلة.
- [ ] جعل `FUNCTIONS_REFERENCE.md` مرجعاً تقنياً فقط، وليس ملف حالة عام.

## Definition of Done

- أي مطور يفتح المشروع يعرف الحالة خلال دقيقة.
- لا يوجد تضارب بين "مكتمل" و"قيد الاختبار".

---

# 2) ترتيب التنفيذ المقترح من الآن

## الخطوة 1 — اختبار خط الأساس الحالي

قبل إصلاح P1، نختبر ما نشرناه حتى لا نبني فوق شيء مكسور.

- [ ] اختبار `create-user`.
- [ ] اختبار `login_with_password` للموظف الجديد.
- [ ] اختبار `update-user-role`.
- [ ] اختبار `toggle-user-status`.
- [ ] اختبار `reset-user-password`.
- [ ] اختبار `delete-user`.

## الخطوة 2 — تنفيذ P1 جلسات الموظفين

بعد التأكد أن الوظائف الحالية تعمل، نضيف طبقة الجلسات الآمنة.

## الخطوة 3 — إغلاق RPCs القديمة

بعد نقل الشاشات الحساسة، نغلق الدوال القديمة.

## الخطوة 4 — الأخطاء والهيكلة

نبدأ بتقليل `catch (e) {}` وتفكيك AdminProvider.

---

# 3) قرارات معمارية معتمدة

1. لا نثق بأي `uid` مرسل من العميل في العمليات الحساسة دون جلسة موثوقة.
2. Edge Functions الإدارية يجب أن تتحقق من جلسة الموظف.
3. `PermissionService` للواجهة فقط وليس للأمان النهائي.
4. أي تغيير `role/sts/i_del/pwd` يجب أن يكون محمياً سيرفرياً.
5. لا يتم إعلان 100% دون اختبار عملي وتوثيق النتيجة.
6. `setup.sql` وmigrations و`FUNCTIONS_REFERENCE.md` يجب أن تبقى متسقة.

---

# 4) Definition of Done للخطة الجديدة بالكامل

- [ ] لا توجد عملية إدارية حساسة تعتمد على `admin_uid` وحده.
- [ ] Edge Functions الإدارية تتطلب جلسة موظف صالحة.
- [ ] الدوال القديمة الحساسة مغلقة أو محمية بالكامل.
- [ ] الأخطاء في Auth/Admin/Payments لا تُبتلع بصمت.
- [ ] AdminProvider مفكك أو أصبح واجهة خفيفة.
- [ ] الداشبوردات تستخدم RPCs مجمعة فعالة.
- [ ] `flutter analyze` يعمل دون أخطاء.
- [ ] الاختبارات الأساسية موجودة.
- [ ] `CURRENT_STATUS.md` موجود ومحدث.
- [ ] التوثيق لا يتعارض مع حالة السيرفر.

---

**ملاحظة تنفيذية:**
نبدأ بالخطة من اختبار خط الأساس الحالي، ثم P1 مباشرة. لا ننفذ P2 قبل P1 كي لا نكسر شاشات قديمة تعتمد على RPCs legacy.
