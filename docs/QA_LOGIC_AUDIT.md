# فحص QA منطقي وبرمجي للتطبيق

> التاريخ: 2026-06-10
> ملاحظة: لم يتم تشغيل Flutter فعلياً داخل بيئة الوكيل لأن Flutter/Dart SDK غير متوفرين. هذا الفحص يعتمد على مراجعة الكود، المسارات، الدوال، والـ migrations.

## حدود الفحص

لم يتم تنفيذ:

```bash
flutter analyze
flutter run
```

بسبب غياب Flutter SDK في البيئة الحالية.

تم تنفيذ:

- فحص Git للحالة الحالية.
- فحص استدعاءات routes.
- فحص استدعاءات RPC.
- فحص توافق بعض المسارات مع `GoRouter`.
- فحص توافق وضع التطوير الحالي مع RLS قدر الإمكان.
- فحص وجود `print` في الكود.
- فحص الملفات المرجعية القديمة وإعادة هيكلتها سابقاً.

## مشاكل تم اكتشافها وإصلاحها أثناء الفحص

### 1. روابط إعداد الملف الشخصي كانت خاطئة

كانت بعض الشاشات توجه إلى:

```txt
/auth/setup-profile
```

بينما المسار الصحيح هو:

```txt
/setup-profile
```

تم الإصلاح في:

- `lib/screens/user/profile_screen.dart`
- `lib/screens/user/become_broker_screen.dart`

### 2. منع تكرار الهاتف لم يكن كاملاً في مسار dev fallback

كان `upsert_user_after_otp` يبحث عن `ph = p_identifier` مباشرة، وبالتالي قد يسمح بتكرار نفس الهاتف إذا اختلفت الصيغة.

تم إصلاحه ليستخدم:

```sql
normalize_sy_phone(p_identifier)
```

الملف:

- `supabase/migrations/2026_06_10_fix_upsert_user_phone_normalization.sql`

### 3. شاشة إضافة العرض للإدارة كانت تعرض حد باقة مزعج

حسابات الإدارة `role >= 2` كانت تظهر لها صيغة حد الباقة.

تم تعديل النص ليظهر:

```txt
حساب إداري — إضافة العروض غير محدودة
```

الملف:

- `lib/screens/user/add_offer_screen.dart`

### 4. إنشاء العرض كان يحتاج RPC بسبب وضع التطوير

تم سابقاً إضافة:

```sql
create_offer_internal
```

وتعديل:

- `lib/providers/offer_provider.dart`

حتى لا يفشل إنشاء العرض بسبب RLS عندما لا يكون `auth.uid()` متوفراً في dev fallback.

### 5. مهام التصوير كانت تعتمد على INSERT/UPDATE مباشر

بسبب RLS ووضع التطوير، تم تحويل عمليات التصوير إلى RPCs:

- `create_photography_task_internal`
- `submit_photography_task_internal`
- `update_photography_task_status_internal`
- `attach_photography_media_to_offer_internal`

وتم تعديل:

- `lib/providers/photography_provider.dart`
- `lib/screens/admin/photography_management_screen.dart`
- `lib/screens/photographer/photographer_tasks_screen.dart`

## نقاط بقيت تحتاج اختبار فعلي

### 1. تسجيل الدخول

يجب اختبار:

- WhatsApp dev fallback.
- Email Magic Link.
- هل يتم تحميل `userModel` بعد الدخول بشكل صحيح.
- هل يظهر اختصار الإدارة/المصور/الوسيط بالأعلى حسب الحساب.

### 2. الإدارة

اختبر:

- تغيير دور مستخدم.
- تفعيل/تجميد/حظر مستخدم.
- حفظ صلاحيات مستخدم.
- فتح/منع المسارات حسب الصلاحية.

### 3. إضافة عرض

اختبر من حساب مدير:

- عدم ظهور حد باقة مجاني.
- إنشاء عرض جديد.
- رفع الصور.
- وصول العرض لقائمة مراجعة العروض.

### 4. المصور

اختبر:

- منح مستخدم صلاحية `photographer_tasks`.
- إنشاء مهمة تصوير من الإدارة.
- دخول المصور إلى `/photographer/tasks`.
- رفع صور وإرسالها.
- اعتماد وربط الصور بالعرض.

### 5. منع تكرار الهاتف

اختبر نفس الرقم بالصيغ:

- `09xxxxxxxx`
- `9639xxxxxxxx`
- `009639xxxxxxxx`
- `+9639xxxxxxxx`

يجب أن يعود لنفس الحساب ولا ينشئ حساباً جديداً.

## مخاطر مؤجلة للإنتاج

### 1. دوال dev-mode

بعض الدوال تقبل `p_admin_uid` لتناسب وضع التطوير الحالي. عند تفعيل Auth إنتاجي حقيقي، يفضل تشديدها لاحقاً بالاعتماد على `auth.uid()` فقط.

### 2. WhatsApp Production

ما زال تفعيل WhatsApp الإنتاجي مرتبطاً بخطة:

- `docs/WHATSAPP_ACTIVATION_PLAN.md`
- `docs/AUTH_SETUP.md`

### 3. Flutter analyze

يجب تشغيل:

```bash
flutter analyze
```

محلياً بعد السحب، لأن بيئة الوكيل لا تحتوي Flutter SDK.

## خلاصة الفحص

تم إصلاح عدة مشاكل منطقية قبل الاختبار، خصوصاً حول:

- المسارات.
- إنشاء العرض.
- تكرار الهاتف.
- مهام التصوير مع RLS.

المرحلة التالية هي الاختبار الفعلي على جهازك وإرسال أي خطأ يظهر.
