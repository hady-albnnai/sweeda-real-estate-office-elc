# ⚖️ وثيقة المواصفات المعمارية لنظام الاستشارات القانونية وتدقيق الثبوتيات (Legal & Expediting System Spec)

> **المشروع:** تطبيق عقارات السويداء (`sweeda-real-estate-office-elc`)
> **الإصدار:** 1.0.0
> **التاريخ:** 2026-07-04
> **الحالة:** وثيقة اعتماد معمارية (Approved Architecture Blueprint)

---

## 🏛️ 1. الهيكل التنظيمي وإدارة الأدوار (Role Architecture)

وفقاً للتصميم المؤسسي المعتمد، يتم توسيع هيكل الأدوار (`UserRole`) ليشمل الأقسام القانونية والتنفيذية المستقلة:

```dart
class UserRole {
  static const int user = 0;          // مستخدم عادي
  static const int broker = 1;       // وسيط عقاري
  static const int photographer = 2; // مصور ميداني
  static const int supervisor = 3;   // مشرف ميداني للمعاينة
  static const int employee = 4;     // موظف مكتب إداري
  static const int deputy = 5;       // نائب مدير
  static const int manager = 6;      // مدير عام التطبيق
  
  // 🆕 الأدوار الجديدة المعتمدة
  static const int lawyer = 7;       // محامي مختص (استشارات وتدقيق عقود)
  static const int expediter = 8;    // معقب معاملات (توسعة مستقبلية لاستخراج الدوائر الرسمية)
}
```

---

## 🗄️ 2. مخطط قاعدة البيانات لملفات المحامين (`lawyer_profiles`)

تم اعتماد إنشاء جدول منفصل ومستقل لملفات المحامين يحفظ أوقات دوامهم وبيانات الاتصال المعتمدة:

```sql
CREATE TABLE IF NOT EXISTS public.lawyer_profiles (
    uid UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    whatsapp_phone TEXT NOT NULL,          -- رقم الواتساب المعتمد للاستشارات الصوتية
    office_address TEXT DEFAULT '',        -- عنوان مكتب المحامي للاجتماعات الحضورية
    specialization TEXT DEFAULT 'عقارات وسيارات', -- التخصص الدقيق
    avl JSONB DEFAULT '{}'::jsonb,         -- أوقات الدوام المتاحة للمواعيد المكتبية (مثل العروض)
    active_tasks_count INT DEFAULT 0,      -- عداد المهام النشطة لتوزيع الحمل الآلي (Round-Robin)
    is_active BOOLEAN DEFAULT TRUE,        -- حالة التوافر لاستقبال طلبات جديدة
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- سياسات الأمان RLS
ALTER TABLE public.lawyer_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public can read active lawyer availability" ON public.lawyer_profiles FOR SELECT USING (is_active = TRUE);
CREATE POLICY "Lawyers can update their own schedule" ON public.lawyer_profiles FOR UPDATE USING (auth.uid() = uid);
CREATE POLICY "Admins full access" ON public.lawyer_profiles FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role >= 5)
);
```

---

## ⚙️ 3. محرك التوزيع الآلي للمهام (Least-Loaded Auto-Assignment Engine)

يحاكي نظام توزيع الاستشارات القانونية وباقات التحقق نظام المنفذين الميدانيين؛ حيث لا يتم إرهاق محامي واحد، بل تُوزع الطلبات بالتساوي عبر دالة التوزيع الآلي عند اعتماد الدفع:

```sql
-- منطق اختيار المحامي الأقل حملاً عند اعتماد إيصال الدفع
SELECT uid INTO v_assigned_lawyer_uid
FROM public.lawyer_profiles
WHERE is_active = TRUE
ORDER BY active_tasks_count ASC, updated_at ASC
LIMIT 1;
```

* **تحديث الحمل:** فور التحويل، يتم زيادة عداد المحامي المختار (`active_tasks_count = active_tasks_count + 1`).
* **إغلاق المهمة:** عند انتهاء الاستشارة أو توقيع العقد، يضغط المحامي أو الإدارة على **"إتمام المعاملة"** فينقُص العداد برمجياً ليتيح له استقبال مهام جديدة.

---

## 💬 4. مسار الاستشارات الهاتفية الصوتية عبر واتساب (Voice Consultation Flow)

* **الرسوم المعتمدة:** 50,000 ل.س (لكل ربع ساعة استشارة).
* **آلية العمل:**
  1. يطلب العميل الخدمة ويرفع الإيصال المالي.
  2. تقوم الإدارة باعتماد الإيصال فيقوم النظام آلياً بربط الطلب بالمحامي الأقل حملاً.
  3. يظهر للعميل في التطبيق زر تفاعلي فوري: **"تحدث صوتياً مع المحامي عبر واتساب 💬⚖️"**.
  4. عند الضغط، يستدعي التطبيق دالة الـ `url_launcher`:
     ```dart
     final url = 'https://wa.me/$lawyerWhatsappPhone?text=${Uri.encodeComponent("مرحباً أستاذ، استشارتي رقم #$requestId المعتمدة من مكتب عقارات السويداء...")}';
     ```
  5. يتم تبادل الملاحظات الصوتية (Voice Notes) والمستندات بسرعة فائقة وموثوقية تامة دون كشف رقم العميل للعموم.

---

## 🏛️ 5. مسار المواعيد المكتبية الحضورية (Office Appointments Flow)

* **الرسوم المعتمدة:** 200,000 ل.س (جلسة استشارة لغاية ساعة واحدة).
* **آلية العمل:**
  1. يقوم المحامي بضبط جدول أوقاته في ملفه (`lawyer_profiles.avl`) بنسق الـ JSONB (مثلاً: `{"mon": ["10:00-14:00"], "wed": ["16:00-19:00"]}`).
  2. يختار العميل اليوم والوقت المتاح تماماً كما يحجز موعد معاينة العقار.
  3. بعد دفع 200 ألف واعتماد الإيصال، يُحجز الوقت رسمياً في تقويم المحامي ويصل إشعار للطرفين بتأكيد الجلسة والعنوان.

---

## 📜 6. باقة التحقق الشامل وتنظيم العقود (Full Title & Contract Package)

* **الرسوم المعتمدة:** 700,000 ل.س (باقة قطعية متكاملة).
* **الخدمات المشمولة في الباقة:**
  1. **التحقق من سندات الملكية:** استخراج وتدقيق الطابو الأخضر، حكم المحكمة، براءة الذمة، وخلو العقار أو السيارة من الإشارات القضائية والحجوزات.
  2. **الصياغة القانونية المحكمة:** كتابة عقد بيع قطعي أو عقد إيجار موثق قانونياً يحمي البائع والمشتري بنسبة 100%.
  3. **التجهيز لتعقيب المعاملات (التوسعة المستقبلية):** إرسال الثبوتيات المدققة لموظفي تعقيب المعاملات (`Role = 8 معقب`) لإتمام الفراغ في الدوائر العقارية ومواصلات المرور.

---

## ✅ الاعتماد والمتابعة
تُعتبر هذه الخطة هي المرجع المعتمد لتنفيذ برمجيات وتطبيقات القسم القانوني في المستودع خلال المراحل التشغيلية القادمة.
