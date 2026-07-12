# المرحلة 2 — النشر الحقيقي على Facebook + Instagram

**التاريخ:** 2026-07-13  
**الحالة البرمجية:** منفذة محلياً — تحتاج Migration + Edge Secrets + Deploy + اختبار Meta

## ما تم تنفيذه

- Edge Function جديدة: `publish-to-social`.
- ناشر مشترك: `supabase/functions/_shared/social_publisher.ts`.
- نشر Carousel حتى 10 صور:
  - Facebook: رفع الصور كـ unpublished ثم إنشاء Feed Post واحد بـ `attached_media`.
  - Instagram: إنشاء child containers ثم Carousel container ثم `media_publish`.
- زر **«نشر الآن على فيسبوك + إنستغرام»** ضمن قائمة مستقلة للعروض المعتمدة والجاهزة للنشر.
- إعداد إداري `socialPublishing.autoPublish` في `/admin/config` للنشر فور الموافقة (معطّل افتراضياً).
- تحديث `soc_pub = 2` فقط عندما تنجح المنصتان.
- جدول `social_publications` لتسجيل حالة كل منصة و`post_id` والخطأ وعدد المحاولات.
- حماية من النقر/التنفيذ المتزامن عبر `claim_social_publication` ومنع إعادة نشر المنصة التي نجحت عند إعادة المحاولة.
- الأسرار لا تحفظ في التطبيق أو `app_config` أو Git؛ تبقى Supabase Edge Secrets فقط.

## قيم `soc_pub`

| القيمة | المعنى |
|---|---|
| 0 | النشر الاجتماعي غير مفعّل |
| 1 | العرض معتمد وجاهز/قيد إعادة المحاولة |
| 2 | تم النشر بنجاح على Facebook وInstagram |

## متطلبات Meta

- Facebook Page رسمية.
- Instagram Professional/Business مربوط بالصفحة.
- Meta App مرتبطة بالأصول.
- Page Access Token مناسب وطويل العمر.
- الصلاحيات المطلوبة بحسب نوع التطبيق/الدخول، وأهمها:
  - `pages_manage_posts`
  - `pages_read_engagement`
  - `instagram_basic`
  - `instagram_content_publish`
- روابط صور عامة عبر HTTPS؛ Instagram لا يدعم منشور Feed نصياً بلا صورة.

> قد تحتاج الصلاحيات إلى Advanced Access/App Review إذا كان التطبيق سينشر لأصول لا يملكها مستخدمو/أدوار التطبيق. اختبر أولاً بأدوار التطبيق وأصول النشاط نفسه.

## الأسرار المطلوبة

نفّذ محلياً بعد تسجيل دخول Supabase CLI، ولا ترسل القيم في المحادثات أو تضعها في Git:

```bash
supabase secrets set \
  META_PAGE_ACCESS_TOKEN='...' \
  META_FACEBOOK_PAGE_ID='...' \
  META_INSTAGRAM_ACCOUNT_ID='...' \
  META_GRAPH_API_VERSION='v25.0'
```

`META_GRAPH_API_VERSION` اختياري؛ القيمة الافتراضية في الكود `v25.0` ويمكن تغييرها دون تعديل الكود.

## ترتيب النشر الإلزامي

```bash
# 1) طبّق قاعدة البيانات أولاً
supabase db push

# 2) اضبط الأسرار
supabase secrets set \
  META_PAGE_ACCESS_TOKEN='...' \
  META_FACEBOOK_PAGE_ID='...' \
  META_INSTAGRAM_ACCOUNT_ID='...' \
  META_GRAPH_API_VERSION='v25.0'

# 3) انشر الوظيفتين (admin-offers يستورد الناشر المشترك أيضاً)
supabase functions deploy publish-to-social
supabase functions deploy admin-offers
```

Migration المطلوبة:

- `supabase/migrations/2026_07_13_social_publishing_phase2.sql`

## خطة الاختبار الآمنة

1. اترك **النشر التلقائي معطّلاً** من `/admin/config`.
2. أضف عرض اختبار بصور عامة وفعّل خيار النشر الاجتماعي.
3. وافق على العرض؛ يجب أن يصبح `soc_pub=1` ويظهر في «جاهزة للنشر».
4. اضغط «نشر الآن» مرة واحدة.
5. تحقق من Carousel في Facebook وInstagram.
6. تحقق من:
   - `offers.soc_pub = 2`
   - صفّين في `social_publications` بحالة `published`
   - وجود `post_id` لكل منصة.
7. اضغط/استدعِ النشر مرة أخرى؛ يجب ألا ينشئ منشوراً مكرراً.
8. بعد نجاح الاختبار اليدوي يمكن تفعيل النشر التلقائي من الإدارة.

## معالجة الفشل الجزئي

إذا نجح Facebook وفشل Instagram مثلاً:

- يبقى `soc_pub=1`.
- تحفظ حالة Facebook كـ `published` وحالة Instagram كـ `failed`.
- عند إعادة المحاولة يتجاوز Facebook وينفذ Instagram فقط.
- لا تؤثر مشكلة Meta على نجاح الموافقة الأساسية على العرض.

## ملاحظات تشغيلية

- يتم تجاهل روابط الصور غير الصحيحة أو غير HTTPS.
- الحد الحالي 10 صور لكل منشور.
- نص Instagram يقص إلى 2200 محرف.
- Claim بحالة `publishing` يعتبر عالقاً وقابلاً لإعادة المحاولة بعد 10 دقائق.
- لا تُفعّل الوضع التلقائي قبل إتمام اختبار يدوي ناجح على الصفحتين.
