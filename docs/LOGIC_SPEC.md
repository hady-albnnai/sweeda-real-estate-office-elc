# 📜 ميثاق المنطق النهائي — تطبيق عقارات السويداء

> هذا المستند يحدد القواعد المنطقية التي تحكم عمل التطبيق،
> لضمان تحوله من منصة إعلانية إلى **مكتب عقاري إلكتروني** متكامل.
> أي تعديل برمجي يخالف هذا الميثاق يُرفض.

---

## 🏢 أولاً: فلسفة "المكتب العقاري" (Office Identity)

- التطبيق ليس وسيطاً سلبياً، بل هو **المكتب** الذي يدير العملية.
- **قاعدة النشر:** لا يظهر اسم صاحب العقار/السيارة للعامة.
  العرض يُنشر باسم المكتب.
- **التسمية الديناميكية:** يُستبدل اسم المستخدم بـ "وصف الحالة"
  بناءً على (الدور + الرتبة + التوثيق) عبر دالة
  `BusinessService.getUserPublicLabel(user)`.
- **مركزية التواصل:** جميع الطلبات والاتصالات تمر عبر إدارة المكتب لضمان:
  1. حماية خصوصية الملاك.
  2. ضمان تحصيل عمولات المكتب.
  3. فلترة الجادين من غير الجادين.

### قواعد التسمية الحالية
| الحالة | التسمية الظاهرة |
|--------|------------------|
| وسيط + بدأ التوثيق | وسيط معتمد ✓ |
| وسيط + لم يبدأ | وسيط شريك |
| مستخدم + بدأ التوثيق | عميل موثق ✓ |
| مستخدم + رتبة ≥ خبير | عميل مميز ⭐ |
| مستخدم + رتبة ≥ نشط | عميل نشط |
| مستخدم عادي | عميل |

الصيغة النهائية: `منشور بواسطة المكتب • <التسمية>`

---

## 🛡️ ثانياً: التوثيق والموثوقية (Verification vs Trust)

### 1. التوثيق الرسمي (Verification — ✓)
- **المستخدم العادي:** رفع الهوية **اختياري**.
- **الوسيط:** رفع الهوية والوثائق التجارية **إلزامي**.
  لا يمكن تفعيل حساب الوسيط دون مراجعة إدارية.
- شارة "موثق" تظهر فقط بعد مراجعة إدارية رسمية.

#### حقل `users.vrf` (تم تنفيذه)
| القيمة | المعنى |
|--------|--------|
| `0` | غير موثق (افتراضي) |
| `1` | قيد المراجعة (المستخدم رفع وثائقه) |
| `2` | موثق رسمياً (الإدارة وافقت) |

- ملف الـ migration: `supabase/migrations/2026_06_06_user_verification_status.sql`
- الحقل في الكود: `UserModel.vrf` + المساعدات
  `hasStartedVerification` و `isVerifiedOfficial`.

### 2. الموثوقية السلوكية (Trust — ⭐)
سلم المراتب بناءً على النقاط (يحل محل سلم المعادن السابق):

| المستوى | الاسم | الرمز | النقاط | الدلالة |
|---------|-------|------|--------|---------|
| 0 | جديد | 🔰 | 0 | بدأ رحلته الآن |
| 1 | نشط | 📈 | 10,000 | يتفاعل بانتظام |
| 2 | موثوق | 🤝 | 20,000 | أثبت جديته بصفقات ناجحة |
| 3 | خبير | 🎓 | 30,000 | سجل حافل بالصفقات |
| 4 | نخبة | ⭐ | 40,000 | أعلى درجات الثقة |

> ❗ المعادن (برونزي/فضي/ذهبي) محجوزة **فقط** للباقات المدفوعة (`pkg`)،
> ولا تُستخدم أبداً للمراتب السلوكية (`bdg`).

---

## 💰 ثالثاً: النظام المالي والتحفيزي

### 1. الباقات (الاستثمار المادي — `pkg`)
- تبقى بأسماء المعادن: مجاني / فضي / ذهبي.
- تحدد صلاحيات الحساب (عدد العروض، مدة الظهور).

### 2. النقاط (الاستثمار السلوكي — `pts`)
- تُكسب من:
  - تسجيل دخول يومي (50 نقطة، مفتاح `strk`).
  - إضافة عرض (`addO`).
  - إتمام صفقة (`dlD`).
  - دعوة صديق (`ref`) — كود إحالة في setup_profile.
  - النشر على السوشال (`soc`).
- تُستخدم لـ: ترقية العروض (Boost/Pin/Featured) عبر `purchase_offer_boost`،
  رفع الرتبة السلوكية تلقائياً.

### 3.2 نظام الإحالة (Referral)
- كل مستخدم له كود فريد = أول 8 أحرف من uid (uppercase).
- يُدخل المستخدم الجديد كود محيله في setup_profile.
- يُستدعى RPC `apply_referral(p_new_uid, p_referrer_code)` تلقائياً.
- الطرفان يحصلان على نقاط الإحالة (`pts.ref` ≈ 1500).
- يُحدّث `users.ref_cnt` للمحيل تلقائياً.

### 3.3 نظام التقييم (Rating)
- جدول `ratings(reviewer_uid, target_uid, stars 1-5, comment)`.
- يُعرض زر التقييم في `my_appointments_screen` للمواعيد المنتهية (sts=2).
- Widget `RatingDialog.show()` مشترك للاستخدام في أي مكان.
- Trigger `trg_rating_bonus` يمنح المستهدف 200 نقطة تلقائياً عند تقييم 5 نجوم.
- لا يمكن تقييم النفس + يجب تسجيل الدخول.

## 📄 §4 الأداء والقابلية للتوسع

### 4.2 Pagination
- `OfferProvider.pageSize = 20`.
- `loadMoreOffers()` تستخدم Supabase `.range(from, to)`.
- في `home_screen` يُربط عبر `NotificationListener<ScrollNotification>`
  يطلق تحميل صفحة جديدة قبل 200 بكسل من النهاية.
- منع التكرار: استبعاد العروض الموجودة مسبقاً قبل الإضافة.
- معطّل تلقائياً أثناء البحث (`_isSearching`).

---

## 🚫 رابعاً: الأمان والسيطرة

- **الحظر الفوري:** عند تغيير `sts` إلى محظور، يُطرد المستخدم
  فوراً عبر Realtime.
- **قفل البيانات:** بمجرد توثيق الحساب رسمياً، تُقفل حقول الهوية،
  ولا تُعدّل إلا بطلب مراجعة إداري.
- **حماية الخصوصية:** بيانات الاتصال (هاتف/إيميل) لا تظهر للعامة،
  تظهر فقط للإدارة وللوسيط المعتمد بعد موافقة الإدارة.
- **منع التلاعب بالعملات:** سعر الباقة بالدولار، وأي تحويل لليرة
  يتم آلياً حسب سعر الصرف المعتمد في `app_config`.

---

## 🔗 المراجع التقنية

| المفهوم | الموقع في الكود |
|---------|------------------|
| توليد التسمية المهنية | `lib/core/services/business_service.dart` → `getUserPublicLabel()` |
| اسم الرتبة السلوكية | `lib/models/user_model.dart` → `badgeName` |
| إثراء قوائم العروض بالتسمية | `lib/providers/offer_provider.dart` → `_enrichOwnerLabels()` |
| عرض التسمية في تفاصيل العرض | `lib/screens/visitor/offer_detail_screen.dart` |
| عرض التسمية في بطاقات العروض | `lib/widgets/offer_card.dart` |
| حالة بدء التوثيق | `lib/models/user_model.dart` → `hasStartedVerification` |
| التوثيق الرسمي المعتمد | `lib/models/user_model.dart` → `isVerifiedOfficial` (vrf=2) |
| Migration التوثيق | `supabase/migrations/2026_06_06_user_verification_status.sql` |
| طلب التوثيق من المستخدم | `lib/screens/user/profile_screen.dart` → `_requestVerification()` |
| مراجعة الإدارة لطلبات التوثيق | `lib/screens/admin/verifications_review_screen.dart` |
| اعتماد/رفض التوثيق | `lib/providers/admin_provider.dart` → `approveVerification` / `rejectVerification` |
| توضيح الحجز عبر المكتب | `lib/widgets/book_appointment_sheet.dart` |
| إشعار نتيجة التوثيق | `lib/providers/admin_provider.dart` → `_notifyVerificationResult()` |
| شارة التوثيق في تفاصيل المستخدم (إدارة) | `lib/screens/admin/user_details_screen.dart` |
| إلزام الوسيط الجديد بالتوثيق | `lib/screens/user/become_broker_screen.dart` |
| تطبيق كود الإحالة عند التسجيل | `lib/screens/auth/setup_profile_screen.dart` → `apply_referral` RPC |
| ترقية العرض بالنقاط (Boost) | `lib/screens/user/boost_offer_screen.dart` → `purchase_offer_boost` RPC |
| زر "ترقية بالنقاط" في تفاصيل العرض | `lib/screens/visitor/offer_detail_screen.dart` (للمالك) |
| الإقرار والتعهد قبل النشر | `lib/screens/user/add_offer_screen.dart` → `_showPledgeDialog` |
| Dialog التقييم المشترك | `lib/widgets/rating_dialog.dart` → `RatingDialog.show()` |
| زر التقييم بعد موعد منتهٍ | `lib/screens/user/my_appointments_screen.dart` (sts=2) |
| Pagination للعروض | `lib/providers/offer_provider.dart` → `loadMoreOffers()` |
| Infinite scroll | `lib/screens/visitor/home_screen.dart` → `NotificationListener` |

---

**توقيع:** هذا المنطق هو المرجع الأعلى لكل تعديل برمجي في التطبيق.
عند أي تعارض بين كود وميثاق، يُقدَّم الميثاق ويُعدَّل الكود.
