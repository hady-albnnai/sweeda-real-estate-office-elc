# المكتب العقاري الالكتروني

تطبيق Flutter + Supabase لإدارة مكتب عقاري إلكتروني. بدأ المشروع على بيانات عقارات السويداء، وتم تجهيز الاسم والبنية للتوسع لاحقاً.

## الحالة الحالية

راجع أولاً:

```txt
docs/CURRENT_STATUS.md
```

هذا الملف هو مرجع البداية لأي محادثة أو تطوير قادم.

## أهم المسارات

| القسم | المسار |
|---|---|
| الزائر | `/home` |
| المستخدم | `/user/home` |
| الوسيط | `/broker/dashboard` |
| الإدارة | `/admin/dashboard` |
| عمليات المكتب | `/admin/office-operations` |
| إدارة الصلاحيات | `/admin/permissions` |
| إدارة الوسائط | `/admin/media-review` |
| إدارة مهام التصوير | `/admin/photography-management` |
| مهام المصور | `/photographer/tasks` |
| شاشة موظف المكتب | `/employee/home` |
| مهام المنفذ | `/executor/tasks` |
| تنفيذ مهمة | `/executor/execute/:id` |

## الملفات المرجعية المهمة

| الملف | الغرض |
|---|---|
| `docs/CURRENT_STATUS.md` | الوضع الحالي المختصر |
| `docs/NEXT_DEVELOPMENT_ITEMS.md` | المتبقي فقط |
| `docs/SPEC.md` | المواصفات التقنية |
| `docs/LOGIC_SPEC.md` | ميثاق المنطق |
| `docs/LOGIC_AUDIT_2026_06_10.md` | تقرير التدقيق المنطقي |
| `docs/LOGIC_REPAIR_TRACKER.md` | تتبّع إصلاحات المنطق بين المحادثات |
| `docs/POST_FIX_EXECUTION_AND_TEST_PLAN.md` | خطة التنفيذ والاختبار بعد الإصلاحات |
| `DEVELOPMENT_GUIDELINES.md` | قواعد التطوير الإلزامية |
| `supabase/FUNCTIONS_REFERENCE.md` | مرجع دوال السيرفر |
| `docs/SERVER_CHANGES_2026_06_10.md` | توثيق تغييرات السيرفر الأخيرة وخطة التراجع |
| `supabase/CHECK_ALL_MIGRATIONS.sql` | فحص حالة السيرفر |
| `docs/AUTH_SETUP.md` | إعداد المصادقة |
| `docs/WHATSAPP_ACTIVATION_PLAN.md` | تفعيل واتساب الإنتاجي |
| `docs/SECURITY_REVIEW.md` | مراجعة أمنية |
| `BUILD_GUIDE.md` | البناء والنشر |

## تشغيل المشروع

```bash
flutter pub get
flutter analyze
flutter run
```

## ملاحظات مهمة

- أي تعديل برمجي يجب أن يحدّث التوثيق المناسب.
- أي تعديل قاعدة بيانات يجب أن يكون داخل `supabase/migrations/` وأن ينعكس في `supabase/setup.sql` إذا كان دائماً.
- لا تترك `print` في الكود النهائي.
- لا تخزن أسرار أو Tokens داخل المستودع.

## المرحلة القادمة

المرحلة القادمة هي الاختبار الفعلي وإصلاح ما يظهر. راجع:

```txt
docs/NEXT_DEVELOPMENT_ITEMS.md
```
