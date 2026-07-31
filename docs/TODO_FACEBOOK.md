# 📢 تذكير: تفعيل النشر التلقائي على فيسبوك

> **التاريخ:** 2026-07-31
> **الحالة:** ⏳ بانتظار الوصول للصفحة (خارج سوريا)

## المطلوب

| المفتاح | الوصف | الحالة |
|---|---|---|
| `META_FACEBOOK_PAGE_ID` | الرقم التعريفي لصفحة الفيسبوك | ⏳ |
| `META_PAGE_ACCESS_TOKEN` | توكن وصول طويل الأمد | ⏳ |

## الصفحة
- **الرابط:** https://www.facebook.com/share/1Cg2aRfnRL/
- **محفوظة بالإعدادات:** `app_config.txts.facebook` ✅

## كيف تُضبط المفاتيح
1. Meta for Developers → إنشاء App
2. ربط App بالصفحة
3. إنشاء Page Access Token طويل الأمد
4. تنفيذ:
```bash
supabase secrets set META_FACEBOOK_PAGE_ID=<page_id> META_PAGE_ACCESS_TOKEN=<token> --project-ref vsgkgnjtebjxyqwpuopz
```

## ملاحظة
- النظام جاهز تقنياً (`social_publisher.ts`)
- العروض تتجهز للنشر (`i_soc=1` + `soc_txt`) بس ما بتننشر فعلياً حتى تُضبط المفاتيح
- عند ضبط المفاتيح: العروض المنشورة (sts=2) بتننشر تلقائياً عند المراجعة
