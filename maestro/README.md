# اختبارات واجهة التطبيق الواقعية (Maestro)

هذه الاختبارات تفتح التطبيق على جهاز Android/محاكي وتتفاعل معه كأن المستخدم يضغط يدوياً.

## 1) المتطلبات

- التطبيق مثبت أو قابل للتشغيل على جهاز Android.
- تفعيل USB debugging إذا كان الاختبار على موبايل حقيقي.
- تثبيت Maestro على جهاز الاختبار.

رابط التثبيت:

```text
https://maestro.mobile.dev/getting-started/installing-maestro
```

> إذا كنت تعمل على Windows ولم يعمل Maestro مباشرة، شغّله من WSL أو Git Bash حسب تعليمات Maestro.

## 2) تشغيل اختبار فتح التطبيق فقط

```bash
maestro test maestro/flows/00_smoke_launch.yaml
```

ملاحظة: هذا الاختبار يستخدم `clearState: true` ويكتفي بالتأكد أن التطبيق يُفتح بدون انهيار ثم يلتقط Screenshot. لا نعتمد حالياً على نصوص عربية في Smoke test لأن PowerShell/Maestro على Windows قد يشوه الترميز أو يختلف كشف النصوص العربية حسب الجهاز.

## 3) تشغيل اختبار تسجيل الدخول

استبدل القيم ببيانات حساب اختبار:

```bash
maestro test maestro/flows/01_login_password.yaml \
  -e E2E_USERNAME="hady" \
  -e E2E_PASSWORD="PUT_PASSWORD" \
  -e E2E_EXPECT="لوحة الإدارة"
```

أمثلة `E2E_EXPECT`:

| الدور | القيمة المتوقعة |
|---|---|
| مدير/نائب | `لوحة الإدارة` |
| محامي | `لوحة المحامي` |
| معقب | `مهام تعقيب المعاملات` |
| موظف مكتب | `عمليات المكتب` أو النص الظاهر في شاشة الموظف |

## 4) اختبار إرسال مهمة من محامي إلى معقب

يفترض وجود حساب محامي وحساب معقب جاهزين، وأن المعقب يظهر باسمه/رقمه في قائمة الاختيار.

```bash
maestro test maestro/flows/02_lawyer_create_expediting_task.yaml \
  -e LAWYER_USERNAME="lawyer_test_01" \
  -e LAWYER_PASSWORD="PUT_PASSWORD" \
  -e EXPEDITER_LABEL="معقب اختبار" \
  -e TASK_NUMBER="12345" \
  -e TASK_ZONE="السويداء"
```

## 5) اختبار دخول المعقب ورؤية المهمة

```bash
maestro test maestro/flows/03_expediter_open_task.yaml \
  -e EXPEDITER_USERNAME="expediter_test_01" \
  -e EXPEDITER_PASSWORD="PUT_PASSWORD" \
  -e TASK_NUMBER="12345"
```

## ملاحظات مهمة

- هذه الاختبارات لا تضع كلمات مرور داخل المستودع. مرّرها دائماً عبر `-e`.
- إذا تغير نص زر أو عنوان في الواجهة، يجب تحديث النص داخل ملفات YAML.
- رفع الصور من المعرض يحتاج flow منفصل حسب جهاز الاختبار ومعرض الصور، لذلك نبدأ أولاً بتسجيل الدخول والتنقل وإرسال المهمة.
- الهدف من هذه المرحلة تقليل الضغط اليدوي، وليس استبدال كل الاختبارات من أول يوم.
