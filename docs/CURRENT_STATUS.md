# الحالة الحالية — المكتب العقاري الإلكتروني

**آخر تحديث:** 2026-06-15
**الفرع:** `main`
**الحالة العامة:** إصلاحات الأولويات P1/P2/P3/P4 وجزء من P5 مطبقة ومرفوعة، بانتظار تشغيل تحليل Flutter والاختبار العملي الكامل.

---

## آخر تعديلات مهمة

| المجال | الحالة |
|---|---|
| إعادة هيكلة إدارة الموظفين | مطبقة على الكود والسيرفر |
| Edge Functions إدارة الموظفين | منشورة |
| Staff Sessions Security | مطبقة ومتحقق منها |
| إغلاق RPCs القديمة الحساسة | مطبق |
| توحيد الأخطاء الأولي | مطبق على المسارات الحساسة الأساسية |
| تفكيك `AdminProvider` | الخدمات الأساسية مستخرجة |
| إحصائيات لوحة الإدارة | `get_admin_dashboard_stats` مطبقة ومتحقق منها |
| CI | مخطط — يحتاج توكن GitHub بصلاحية `workflow` لإضافة GitHub Actions |
| SQL verification | تمت إضافة `supabase/tests/admin_security_verification.sql` |

---

## آخر migrations مضافة

- `2026_06_15_admin_employee_management_final.sql`
- `2026_06_15_staff_sessions_security.sql`
- `2026_06_15_lock_legacy_admin_rpcs.sql`
- `2026_06_15_admin_dashboard_stats.sql`

---

## Edge Functions الإدارية المنشورة

- `create-user`
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

- [ ] تشغيل `flutter analyze` محلياً أو عبر CI وإصلاح أي أخطاء.
- [ ] تشغيل `flutter test`.
- [ ] تنفيذ اختبار عملي كامل لإدارة الموظفين.
- [ ] تنفيذ `supabase/tests/admin_security_verification.sql` بعد أي تعديل أمني لاحق.
- [ ] التأكد أن المدير يستطيع الدخول بـ `main_admin` وأن الجلسة تصدر بشكل صحيح.
- [ ] اختبار أن Edge Functions ترفض الطلبات بدون `staff_session_token`.

---

## ملاحظات أمنية

- لا يتم الاعتماد على `admin_uid` وحده في Edge Functions الإدارية.
- الدوال القديمة الحساسة مغلقة عن `anon/authenticated` وتعمل عبر `service_role` فقط.
- `soft_delete` العام مغلق عن العميل.
- `pwd` لا يكشف كهاش، ويعود فقط كـ flag في دوال القراءة.
