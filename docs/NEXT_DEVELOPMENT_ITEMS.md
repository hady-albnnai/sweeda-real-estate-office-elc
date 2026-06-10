# المهام المتبقية غير المنفذة / المؤجلة

> هذا الملف هو المرجع الوحيد للمهام غير المنفذة حالياً.

**مهم:** حالة إصلاحات المنطق نفسها تُتابَع في:

```txt
docs/LOGIC_REPAIR_TRACKER.md
```

وخطة التنفيذ العملي بعد هذه الإصلاحات موجودة في:

```txt
docs/POST_FIX_EXECUTION_AND_TEST_PLAN.md
```

> حالياً: معظم إصلاحات المنطق داخل المستودع أصبحت منفذة وموثقة، والمتبقي الأهم هو تشديد المصادقة/الصلاحيات بالكامل عند الانتقال من وضع التطوير إلى Auth إنتاجي حقيقي.

وأحدث دفعة migrations منطقية الجاهزة للتنفيذ هي:

```txt
supabase/migrations/2026_06_10_logic_fixes_appointments_offers.sql
supabase/migrations/2026_06_10_logic_fixes_boosts_payments.sql
supabase/migrations/2026_06_10_config_package_prices_and_fx.sql
supabase/migrations/2026_06_10_auth_uid_alignment_guards.sql
supabase/migrations/2026_06_10_users_public_no_private_img.sql
supabase/migrations/2026_06_10_verification_dev_auth_rpcs.sql
supabase/migrations/2026_06_11_drop_obsolete_verification_rpcs.sql
supabase/migrations/2026_06_11_drop_obsolete_unused_rpcs.sql
supabase/migrations/2026_06_11_real_test_stabilization_internal_rpcs.sql
```

وللتنفيذ السريع يوجد ملف مجمّع جاهز:

```txt
supabase/RUN_ME_LOGIC_FIXES_2026_06_11.sql
```

## 1. الاختبار الفعلي بعد السحب

الحالة: لم يتم الاختبار محلياً على جهاز المستخدم بعد آخر دفعات التطوير.

المطلوب:

```bash
git pull origin main
flutter pub get
flutter analyze
flutter run
```

ثم الاختبار حسب:

```txt
```

## 2. تفعيل WhatsApp OTP الإنتاجي

الحالة: يوجد dev fallback، والـ Edge Functions موجودة لكنها تحتاج تفعيل Meta فعلي.

المرجع:

```txt
docs/WHATSAPP_ACTIVATION_PLAN.md
docs/AUTH_SETUP.md
```

المطلوب لاحقاً:

- إعداد Meta Business.
- إعداد WhatsApp Cloud API.
- ضبط secrets على Supabase.
- نشر Edge Functions.
- اختبار أن `auth.uid()` يعمل في الجلسات الإنتاجية.

## 3. مراجعة RLS / Auth بعد الانتقال من وضع التطوير للإنتاج

الحالة: تم تشديد عدد كبير من RPCs داخل المستودع، لكن بقي جزء من الحماية **جزئياً** بسبب استمرار وضع التطوير الحالي.

عند تفعيل Auth إنتاجي حقيقي، يمكن لاحقاً تشديد الدوال لتعود للاعتماد على `auth.uid()` فقط وإلغاء الاعتماد على الـUID القادم من العميل بالكامل.

المرجع:

```txt
docs/SECURITY_REVIEW.md
```

## 4. اختبار نظام المصور

الحالة: منفذ برمجياً، يحتاج اختبار عملي.

المطلوب:

- منح مستخدم صلاحية `photographer_tasks`.
- إنشاء مهمة تصوير من `/admin/photography-management`.
- دخول المصور إلى `/photographer/tasks`.
- رفع صور وإرسالها للمكتب.
- اعتماد وربط الصور بالعرض.

## 5. تعميم التطبيق لكل سوريا لاحقاً

الحالة: الاسم صار عاماً، لكن البيانات/config ما زالت مرتبطة بالسويداء.

المطلوب لاحقاً:

- تحديث `docs/locations.json` أو Config ليشمل المحافظات السورية.
- تحديث نصوص التسويق والواجهات من عقارات السويداء إلى المكتب العقاري الالكتروني حسب القرار التجاري.

## 6. النشر والبناء

الحالة: لم يتم البناء داخل بيئة الوكيل لعدم توفر Flutter SDK.

المرجع:

```txt
BUILD_GUIDE.md
```

المطلوب:

- تشغيل `flutter analyze`.
- تشغيل التطبيق على Android.
- بناء APK/AAB.
- اختبار الإشعارات والروابط العميقة.
