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

## الملفات المرجعية

| الملف | الغرض |
|---|---|
| `docs/TEST_CHECKLIST.md` | قائمة الاختبار — **ابدأ من هنا** |
| `docs/LOGIC_SPEC.md` | ميثاق المنطق (الدستور) |
| `docs/SOCIAL_AND_AUTH_SETUP.md` | تفعيل واتساب + فيسبوك + إنستغرام |
| `DEVELOPMENT_GUIDELINES.md` | قواعد التطوير الإلزامية |
| `supabase/FUNCTIONS_REFERENCE.md` | مرجع دوال السيرفر |
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
