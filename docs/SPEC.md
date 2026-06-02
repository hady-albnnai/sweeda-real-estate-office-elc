# مستند مواصفات تطبيق "عقارات السويداء"
> مكتب عقاري إلكتروني — محافظة السويداء (مبدئياً)
> تطبيق موبايل — Backend: Firebase (Firestore + Auth + FCM + Cloud Functions)
> هذه النسخة **نهائية ومعتمدة للتسليم للمبرمج**

---

## 🧠 فلسفة التصميم (مهم جداً للمبرمج)

> **كل شيء يُقرأ من Config — التطبيق مجرد "عارض" للإعدادات.**

- التطبيق لا يحتوي على أي أرقام أو نصوص ثابتة في الكود (Hardcoded).
- عند بدء التشغيل، يُحمّل `config` مرة واحدة ويُخزّن محلياً (Cache).
- أي تعديل في Config = تعديل في سلوك التطبيق فوراً. بدون تحديث للمتجر.
- استخدم **أسماء حقول قصيرة** (حتى 3 أحرف) لتقليل حجم البيانات المنقولة.
- استخدم **Cloud Functions لمعظم المنطق** — قلّل حجم التطبيق وزيّن الأمان.

---

## 🔖 اصطلاحات التسمية (Naming Conventions)

| الأصل | الكود | مثال |
|-------|-------|------|
| المعرفات | حقول قصيرة (2-4 أحرف) | `uid`, `sid`, `sts`, `typ` |
| التايمستامب | `ts` + اسم الحدث | `tsCrt`, `tsPub`, `tsEnd` |
| الحالات (Status) | أرقام (وليس نصوص) | `0`=مسودة, `1`=نشط, `2`=مكتمل |
| المراجع (Refs) | اسم المجموعة + `Id` | `usrId`, `offId`, `appId` |
| البوليان | حرف `i` قبل الاسم | `iPub` = منشور؟, `iDel` = محذوف؟ |

---

## 💰 استراتيجية توفير التكلفة (Cost-Saving Strategy)

### ⚡ مبادئ أساسية:
1. **التطبيق لا يعمل دون Config** — يُحمّل config عند كل start ويُخزّن محلياً.
2. **تجنّب Subcollections** — استخدم Maps داخل المستند نفسه لتجنب قراءات إضافية.
3. **Counters داخل المستند** — لا تقم بعمل `.count()` على Collection أبداً.
4. **الحذف الناعم (Soft Delete)** — استخدم布尔 `iDel` بدلاً من حذف المستندات.
5. **TTL Policies** — الإشعارات وأنشطة المستخدم تُحذف تلقائياً بعد 30 يوم.

### 🔥 Cloud Functions (المحرك الفعلي للتطبيق):
> **لا تعتمد على العميل لتنفيذ المنطق الحساس.** كل العمليات المهمة تذهب عبر Cloud Function للتأكد من صحتها ولتسجيلها.

| الـ Function | Trigger | ماذا تفعل |
|-------------|---------|----------|
| `onNewOffer` | offer.create | تفحص تكرار العرض، تبدأ المطابقة التلقائية، تُرسل إشعار للإدارة |
| `onOfferApproved` | offer.update → iPub=true | تُنشئ إشعاراً للناشر، تبدأ المطابقة، تُنشئ منشور السوشيال ميديا (إن وافق) |
| `onAppointmentCreated` | appointment.create | تُرسل إشعارات لجميع الأطراف، تتحقق من الحدود |
| `onAppointmentComplete` | appointment.sts=2 | تُنشئ بطاقة الموعد، تُرسل إشعارات |
| `onDealInitiated` | offer.sts=5 (محجوز) | تُلغي باقي المواعيد، تُرسل إشعارات، تحتسب العمولة |
| `onDealCompleted` | deal.create | تُفعّل النقاط والمكافآت، تُحدّث إحصائيات المستخدم |
| `onUserReport` | report.create | تُرسل تنبيه للإدارة |
| `hourlyTick` | Scheduled (كل ساعة) | تُرسل تذكيرات المواعيد القريبة (قبل ساعتين) |
| `dailyTick` | Scheduled (كل يوم) | تُنهي العروض المنتهية، تُرسل إشعارات التجديد، تنظف الإشعارات القديمة |
| `compressImage` | offer.create (عبر Extension) | تضغط الصور تلقائياً لتوفير المساحة |

---

## 🗂️ هيكل Firestore النهائي (مُحسّن للتكلفة)

```
firestore/
│
├── ⚙️ config/                    ← [مستند واحد] كل إعدادات التطبيق
│   └── main/                     ← جميع الإعدادات في مستند واحد (لا داعي للتقسيم)
│
├── 👤 users/{uid}
│   ├── nm                        ← الاسم (name)
│   ├── ph                        ← الهاتف (phone)
│   ├── ad                        ← العنوان (address)
│   ├── role                      ← المستوى: 0=مستخدم, 1=وسيط, 2=مشرف, 3=نائب, 4=مدير
│   ├── sid                       ← رقم الهوية/البطاقة (ID number)
│   ├── img                       ← URL صورة البطاقة (optional)
│   ├── pt                        ← رصيد النقاط (points total)
│   ├── bg                        ← البادج الحالي: 0=new, 1=bronze, 2=silver, 3=gold, 4=diamond (number)
│   ├── bgTs                      ← تاريخ آخر ترقية للبادج (timestamp)
│   ├── bPkg                      ← الباقة الحالية: 0=free, 1=silver, 2=gold
│   ├── pkgEnd                    ← تاريخ انتهاء الباقة (timestamp)
│   ├── brk                       ← هل هو وسيط؟: 0=لا, 1=نعم
│   ├── brkCls                    ← فئة الوساطة (broker class): 0=فرد, 1=مكتب, 2=شركة
│   ├── brkNm                     ← الاسم التجاري (business name)
│   ├── sts                       ← حالة الحساب: 0=نشط, 1=مجمّد, 2=محظور
│   ├── banRsn                    ← سبب الحظر (string, empty if not banned)
│   ├── ntf                       ← إعدادات الإشعارات (map): {off:0, app:0, fin:0, rat:0} (0=مفعل, 1=مكتوم)
│   ├── stats                     ← إحصائيات (map): {off:0, req:0, app:0, dl:0}
│   ├── wkLgn                     ← آخر تسجيل دخول أسبوعي (timestamp array للمرونة)
│   ├── strk                      ← streak counter (عدد الأيام المتتالية)
│   ├── strkDt                    ← آخر يوم streak (timestamp)
│   ├── iDel                      ← 0=موجود, 1=محذوف
│   ├── tsCrt                     ← تاريخ الإنشاء
│   └── tsUpd                     ← تاريخ آخر تحديث
│
├── 🏠 offers/{offId}
│   ├── typ                       ← نوع العرض: 0=عقار, 1=سيارة
│   ├── trx                       ← نوع المعاملة: 0=بيع, 1=إيجار
│   ├── cat                       ← النوع الرئيسي (number, يقابله اسم في config)
│   ├── sub                       ← النوع الفرعي (number)
│   ├── ttl                       ← العنوان (title)
│   ├── prc                       ← السعر/الأجرة (price)
│   ├── cur                       ← العملة: 0=$, 1=ل.س
│   ├── loc                       ← الموقع (map): {r:0, d:""} ← r=region number, d=description حر
│   ├── desc                      ← الوصف (description)
│   ├── imgs                      ← روابط الصور [url1,url2,...] (array, max 6)
│   ├── vdo                       ← رابط الفيديو (optional)
│   ├── docTp                     ← نوع سند الملكية (number)
│   ├── docImg                    ← رابط صورة السند (string, optional, secret)
│   ├── exactLoc                  ← الموقع الدقيق (string, secret for admin only)
│   ├── specs                     ← المواصفات (map):
│   │   │                          لـ عقار: {ar:0, fl:0, fr:0, fn:0, dr:0, ps:0}
│   │   │                          (area, floor, furnished, finish, direction, position)
│   │   └                          لـ سيارة: {br:0, md:"", yr:0, km:0, fu:0, gr:0, tr:0, cc:0, ps:0, cl:0, st:0}
│   │                              (brand, model, year, km, fuel, gear, trans, cc, pass, color, state)
│   ├── usrId                     ← ref to users/{uid} (الناشر)
│   ├── brkId                     ← ref to user/{uid} (الوسيط إن وجد, optional)
│   ├── brkPct                    ← نسبة عمولة الوسيط (0-5, optional)
│   ├── com                       ← عمولة المكتب المعدّلة (optional, override)
│   ├── sts                       ← الحالة: 0=مسودة, 1=قيد المراجعة, 2=منشور, 3=مرفوض, 4=منتهي, 5=محجوز, 6=مكتمل
│   ├── rsn                       ← سبب الرفض (string, empty if not rejected)
│   ├── vws                       ← عدد المشاهدات (counter)
│   ├── fvs                       ← عدد الإضافات للمفضلة (counter)
│   ├── iPub                      ← 0=غير منشور, 1=منشور
│   ├── iSoc                      ← 0=لا, 1=نشر على السوشيال ميديا (checkbox)
│   ├── socPub                    ← 0=لم ينشر بعد, 1=تم النشر
│   ├── socTxt                    ← نص المنشور الجاهز (string, يملؤها Cloud Function)
│   ├── iDup                      ← 0=غير مكرر, 1=مكرر محتمل (يضبطها النظام)
│   ├── dupOf                     ← offer ID إذا كان مكرراً (optional)
│   ├── avl                       ← المواعيد المتاحة (map): {mon:["9-10","10-11"], tue:[],...}
│   ├── iDel                      ← 0=موجود, 1=محذوف
│   ├── tsCrt                     ← تاريخ الإنشاء
│   ├── tsPub                     ← تاريخ النشر
│   ├── tsEnd                     ← تاريخ الانتهاء (30 يوم بعد النشر)
│   └── tsRen                     ← تاريخ آخر تجديد
│
├── 📋 requests/{reqId}
│   ├── typ                       ← 0=شراء, 1=استئجار
│   ├── elm                       ← 0=عقار, 1=سيارة
│   ├── clNm                      ← اسم الزبون (client name)
│   ├── clPh                      ← هاتف الزبون
│   ├── prc                       ← السعر (سعر واحد)
│   ├── cur                       ← العملة: 0=$, 1=ل.س
│   ├── notes                     ← ملاحظات (optional)
│   ├── specs                     ← المواصفات (map, حسب النوع عقار/سيارة)
│   ├── usrId                     ← ref to users/{uid}
│   ├── sts                       ← 0=قيد المراجعة, 1=نشط, 2=مكتمل, 3=ملغي
│   ├── matches                   ← التطابقات (map): {off1:85, off2:72, ...} ← offerId → نسبة التطابق
│   ├── iDel                      ← 0=موجود, 1=محذوف
│   └── tsCrt
│
├── 📅 appointments/{appId}
│   ├── offId                     ← ref to offers/{offId}
│   ├── reqId                     ← ref to requests/{reqId} (optional)
│   ├── bkrId                     ← ref to users/{uid} (الوسيط إن وجد)
│   ├── ownId                     ← ref to users/{uid} (صاحب العرض)
│   ├── bkrId                     ← ref to users/{uid} (الوسيط, optional)
│   ├── dt                        ← تاريخ ووقت الموعد (timestamp)
│   ├── dtEnd                     ← نهاية الموعد (timestamp, +1 hour from dt)
│   ├── sts                       ← 0=قيد الانتظار, 1=مؤكد, 2=منتهي, 3=ملغي
│   ├── cnlBy                     ← مَن ألغى (user ID, optional)
│   ├── cnlRsn                    ← سبب الإلغاء
│   ├── fbkOwn                    ← رأي صاحب العرض: 0=لا رد, 1=قبول, 2=رفض, 3=مهلة
│   ├── fbkReq                    ← رأي طالب الحجز: 0=لا رد, 1=قبول, 2=رفض, 3=مهلة
│   ├── fbkOwnDt                  ← تاريخ رد صاحب العرض (timestamp أو وقت المهلة)
│   ├── fbkReqDt                  ← تاريخ رد طالب الحجز (timestamp أو وقت المهلة)
│   ├── fbkOwnDur                 ← المهلة بالأيام لصاحب العرض (1-3)
│   ├── fbkReqDur                 ← المهلة بالأيام لطالب الحجز (1-3)
│   ├── adminNt                   ← ملاحظات الإدارة
│   ├── iForce                    ← 0=عادي, 1=إنهاء قسري (admin override)
│   ├── forceBy                   ← user ID of admin who forced
│   ├── rmnd24                    ← 0=لم يُرسل, 1=أُرسل تذكير 24 ساعة
│   ├── rmnd2                     ← 0=لم يُرسل, 1=أُرسل تذكير ساعتين
│   ├── rmndQtr                   ← 0=لم يُرسل, 1=أُرسل تذكير ربع المهلة
│   ├── rmndEnd                   ← 0=لم يُرسل, 1=أُرسل تذكير بانتهاء المهلة
│   └── tsCrt
│
├── 🔔 notifications/{ntfId}
│   ├── uid                       ← ref to users/{uid}
│   ├── tp                        ← النوع: 0=عروض, 1=طلبات, 2=مواعيد, 3=مالية, 4=حسابي, 5=تقييم
│   ├── ttl                       ← العنوان (title)
│   ├── bdy                       ← النص (body)
│   ├── act                       ← action route (شاشة التوجيه في التطبيق)
│   ├── refId                     ← ID المرجعي (offerId, appId, ...)
│   ├── iRd                       ← 0=غير مقروء, 1=مقروء
│   ├── iDel                      ← 0=موجود, 1=محذوف (TTL: 30 يوم)
│   └── tsCrt
│
├── 💰 payments/{payId}
│   ├── uid                       ← ref to users/{uid}
│   ├── tp                        ← 0=باقة, 1=boost, 2=غرامة
│   ├── pkg                       ← 0=free, 1=silver, 2=gold (إن كان tp=0)
│   ├── amt                       ← المبلغ
│   ├── cur                       ← العملة: 0=$, 1=ل.س, 2=نقاط
│   ├── mtd                       ← طريقة الدفع: 0=شام كاش, 1=حوالة, 2=نقاط
│   ├── proof                     ← رابط صورة الإيصال (optional)
│   ├── ref                       ← رقم العملية/الحوالة (optional)
│   ├── sts                       ← 0=قيد المراجعة, 1=مفعّل, 2=ملغي
│   ├── apprBy                    ← user ID of admin who approved
│   └── tsCrt
│
├── 📢 reports/{rptId}
│   ├── repUid                    ← ref to users/{uid} (المبلّغ)
│   ├── tgtUid                    ← ref to users/{uid} (المُبلَّغ عنه)
│   ├── tgtTp                     ← نوع الهدف: 0=مستخدم, 1=عرض, 2=تعليق
│   ├── tgtId                     ← ID الهدف (offerId, أو userId)
│   ├── rsn                       ← سبب التبليغ (number, يقابله نص في config)
│   ├── det                       ← تفاصيل إضافية (optional)
│   ├── sts                       ← 0=مفتوح, 1=قيد المراجعة, 2=مُتَّخذ إجراء, 3=مرفوض
│   ├── act                       ← الإجراء: 0=لا شيء, 1=إنذار, 2=تجميد, 3=حظر
│   ├── actDur                    ← مدة التجميد بالأيام (إن كان act=2)
│   ├── note                      ← ملاحظات الإدارة
│   ├── actBy                     ← user ID of admin
│   └── tsCrt
│
├── 📊 deals/{dlId}
│   ├── offId                     ← ref to offers/{offId}
│   ├── appId                     ← ref to appointments/{appId}
│   ├── sellUid                   ← ref to users/{uid} (بائع/مؤجر)
│   ├── buyUid                    ← ref to users/{uid} (مشتري/مستأجر)
│   ├── brkUid                    ← ref to users/{uid} (وسيط, optional)
│   ├── finPrc                    ← الثمن النهائي الفعلي
│   ├── cur                       ← العملة: 0=$, 1=ل.س
│   ├── comPct                    ← نسبة العمولة الفعلية
│   ├── comVal                    ← قيمة العمولة
│   ├── comNote                   ← ملاحظات الخصم
│   ├── form                      ← استمارة المندوب (map):
│   │   ├── sellNm                ← اسم البائع
│   │   ├── sellId                ← هوية البائع
│   │   ├── sellPh                ← هاتف البائع
│   │   ├── buyNm                 ← اسم المشتري
│   │   ├── buyId                 ← هوية المشتري
│   │   ├── buyPh                 ← هاتف المشتري
│   │   ├── docs                  ← [url1,url2] روابط العقود والمرفقات
│   │   ├── note                  ← ملاحظات مندوب التطبيق
│   │   └── follow                ← متابعات مطلوبة من الشركة
│   ├── sts                       ← 0=بانتظار الإنجاز, 1=مكتمل, 2=ملغي
│   ├── cmplBy                    ← user ID of admin who completed
│   ├── iDel                      ← 0=موجود, 1=محذوف
│   └── tsCrt, tsCmpl
│
├── 📊 activity_log/{logId}
│   ├── uid                       ← ref to users/{uid} (المنفّذ)
│   ├── act                       ← النشاط (number)
│   ├── det                       ← تفاصيل
│   ├── refId                     ← ID المرجعي
│   ├── refCol                    ← اسم المجموعة المرجعية
│   ├── iDel                      ← TTL: 90 يوم
│   └── tsCrt
│
└── 📈 stats/{statId}
    ├── tp                        ← نوع الإحصاء: 0=عام, 1=شهري, 2=يومي
    ├── dt                        ← التاريخ (timestamp)
    ├── cnt                       ← القيمة (number)
    └── عن طريق Cloud Functions تُحدّث يومياً
```

---

## ⚙️ مستند Config (المستند الوحيد اللي يتحكم بكل شيء)

### 🔥 كل ما يلي موجود في مستند واحد: `config/main`

```javascript
{
  // —— نقاط الاكتساب ——
  "pts": {
    "sgn": 1000,           // signup bonus
    "wkL": 500,            // weekly login
    "addO": 500,           // add offer
    "att": 300,            // attendance
    "dlD": 2000,           // deal done
    "ref": 1500,           // referral
    "strk": 200,           // streak bonus
    "soc": 100,            // social share agreement
    "like": {"p":5,"l":10},     // points, daily limit
    "shr": {"p":10,"l":5},
    "cmt": {"p":20,"l":3},
    "gft": {"max":500,"pw":1}   // gift max points, per week
  },

  // —— خصم/صرف النقاط ——
  "pen": {
    "noSh": -500,
    "cnl3": -300,
    "rej3": -1000,
    "fRp": -2000,
    "ban": -40000
  },
  "spd": {
    "ren": 500,
    "pin": 2000,
    "bst": 4000,
    "dsc5": 3000,
    "fms": 8000
  },

  // —— البادجات ——
  "bdg": {
    "0": {"nm":"🔰 جديد","p":0,"d":0},
    "1": {"nm":"🥉 برونزي","p":10000,"d":10},
    "2": {"nm":"🥈 فضي","p":20000,"d":15},
    "3": {"nm":"🥇 ذهبي","p":30000,"d":20,"eS":1},
    "4": {"nm":"💎 ماسي","p":40000,"d":20,"eS":1,"fA":1}
  },

  // —— الباقات ——
  "pkg": {
    "0": {"nm":"مجاني","o":5,"d":30,"pr":0,"pr":0},
    "1": {"nm":"فضي","o":15,"d":45,"pr":null,"pr":1},
    "2": {"nm":"ذهبي","o":40,"d":60,"pr":null,"pr":2}
  },

  // —— العمولة ——
  "com": {
    "sl": 3,              // sell percentage
    "rn": "hm",           // rent: half month
    "ml": 2               // matching multiplier
  },

  // —— الحدود (Quotas) ——
  "qta": {
    "u": {"o":1,"r":3,"a":3},      // user: offers, requests/month, appointments/month
    "b": {"o":5,"r":5,"a":3}       // broker: same
  },

  // —— السوشيال ميديا ——
  "soc": {
    "fb": "",
    "ig": "",
    "tk": "",
    "wa": ""
  },

  // —— الإعلانات ——
  "ads": {
    "mx": 5,               // max active
    "dd": 7,               // default duration days
    "pr": null              // price
  },

  // —— أسباب التبليغ (يظهر للمستخدم) ——
  "rptRsn": [
    "إعلان وهمي / غير موجود",
    "احتيال / نصب",
    "معلومات مضللة",
    "مضايقة / سلوك غير لائق",
    "عرض مكرر",
    "آخر"
  ],

  // —— نصوص التطبيق (قابلة للتعديل) ——
  "txts": {
    "plg": "📋 إقرار وتعهد إلكتروني — عقارات السويداء\n\nأقرّ أنا الموقع أدناه...\n[النص الكامل للتعهد]",
    "warnApp": "⚠️ هذا العرض عليه (X) مواعيد سابقة\nقد يتم بيعه قبل موعدك إذا ضغط أحدهم 'إتمام المعاملة'\nهل تريد حجز موعد مع العلم بذلك؟",
    "visBlk": "أنت بحاجة لتسجيل الدخول للقيام بهذا الإجراء",
    "bnRsn": "تم حظر حسابك نهائياً. للاستفسار التواصل مع الإدارة.",
    "frzRsn": "تم تجميد حسابك مدة (X) يوم. السبب: (Y)"
  },

  // —— أنواع العقارات الفرعية ——
  "catProp": {
    "0": {"nm":"سكني","sub":["شقة سكنية","دار عربي","فيلا","مزرعة","بناء كامل","سطح"]},
    "1": {"nm":"تجاري","sub":["محل تجاري","معرض","مركز تجاري","مكتب","مستودع"]},
    "2": {"nm":"زراعي","sub":["أرض زراعية","مزرعة دواجن","مزرعة مواشي","مشتل"]},
    "3": {"nm":"صناعي","sub":["منشأة صناعية","ورشة","مصنع","أرض صناعية"]}
  },

  // —— أنواع السيارات ——
  "catVeh": {
    "0": {"nm":"سيارة","sub":["سيدان","دفع رباعي","هاتشباك","كوبيه","مكشوفة"]},
    "1": {"nm":"شاحنة","sub":["شاحنة صغيرة","شاحنة كبيرة","نقل عام"]},
    "2": {"nm":"دراجة نارية","sub":["دراجة عادية","دراجة رياضية","دراجة كهربائية"]},
    "3": {"nm":"معدات ثقيلة","sub":["جرّار","حفّارة","حصّادة","درّاسة"]},
    "4": {"nm":"باصات/نقل","sub":["باص سكانيا","باص 24 راكب","ميكروباص","فان"]}
  },

  // —— أنواع سند الملكية ——
  "docTp": {
    "0": "طابو أخضر",
    "1": "حصة سهمية-حكم محكمة",
    "2": "حصة سهمية-كاتب بالعدل",
    "3": "مستملك",
    "4": "تسلسل عقود",
    "5": "جمعيات سكنية",
    "6": "نمرة قديمة",
    "7": "نمرة جديدة",
    "8": "وارد"
  },

  // —— قائمة المناطق ——
  "locs": [مناطق السويداء من ملف locations.json],

  // —— قائمة الماركات ——
  "brnds": ["تويوتا","هوندا","نيسان","هيونداي","كيا","مرسيدس","بي إم دبليو","فولكس فاجن","رينو","فورد","شيفروليه","مازدا","ميتسوبيشي","سوزوكي","جيب","بيجو","سيتروين","أوبل","سكودا","سيات","دايو","فيات","لادا","جيلي","شيري","MG","هافال","BYD","جريت وول","سانج يونغ","سوبارو","لكزس","إنفينيتي","لاند روفر","أودي","أخرى"],

  // —— قائمة الألوان ——
  "clrs": ["أبيض","أسود","فضي","رمادي","أحمر","أزرق","أخضر","أصفر","بيج","بني","ذهبي","برتقالي","بنفسجي","كحلي","عسلي","نحاسي"],

  // —— صلاحيات الأدوار ——
  "roles": {
    "0": {"nm":"مستخدم"},
    "1": {"nm":"وسيط"},
    "2": {"nm":"مشرف"},
    "3": {"nm":"نائب"},
    "4": {"nm":"مدير"}
  }
}
```

---

## 🔒 قواعد الأمان (Security Rules) — موجزة

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ⚙️ config: الجميع يقرأ، فقط المدير يكتب
    match /config/{doc} {
      allow read: if true;
      allow write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role >= 4;
    }

    // 👤 users: صاحب الحساب والإدارة فقط
    match /users/{uid} {
      allow read: if request.auth != null && 
        (request.auth.uid == uid || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role >= 2);
      allow create: if request.auth.uid == uid;
      allow update: if request.auth.uid == uid || 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role >= 2;
      allow delete: if request.auth.uid == uid; // فقط لحذف الحساب الذاتي
    }

    // 🏠 offers: الجميع يقرأ، الناشر والإدارة يكتبون
    match /offers/{offId} {
      allow read: if true; // الزائر يقرأ أيضاً
      allow create: if request.auth != null;
      allow update: if request.auth != null && 
        (request.auth.uid == resource.data.usrId || 
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role >= 2);
      allow delete: if false; // لا حذف، استخدم iDel
    }

    // 📅 appointments: الأطراف المعنية والإدارة
    match /appointments/{appId} {
      allow read: if request.auth != null && (
        request.auth.uid == resource.data.ownId ||
        request.auth.uid == resource.data.reqId ||
        request.auth.uid == resource.data.bkrId ||
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role >= 2
      );
      allow create: if request.auth != null;
      allow update: if request.auth != null;
      allow delete: if false;
    }

    // 🔔 notifications: صاحبها والإدارة
    match /notifications/{ntfId} {
      allow read: if request.auth != null && 
        (request.auth.uid == resource.data.uid || 
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role >= 2);
      allow write: if request.auth != null; // محدودة لكن Cloud Function هو الأساس
    }

    // 📢 reports: المبلّغ يكتب، الإدارة تقرأ وتعدّل
    match /reports/{rptId} {
      allow read: if request.auth != null && 
        (request.auth.uid == resource.data.repUid || 
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role >= 2);
      allow create: if request.auth != null;
      allow update: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role >= 2;
      allow delete: if false;
    }

    // 🚫 باقي المجموعات: الإدارة فقط
    match /{collection}/{doc} {
      allow read, write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role >= 2;
    }
  }
}
```

---

## 📊 الـ Indexes الضرورية فقط (لتوفير التكلفة)

| Collection | الحقول | الغرض |
|-----------|-------|-------|
| offers | `typ`, `sts`, `prc`, `tsPub` | عرض العقارات/السيارات حسب السعر والتاريخ |
| offers | `sts`, `trx`, `tsPub` | عرض البيع/الإيجار |
| offers | `usrId`, `sts` | عروض مستخدم معين |
| appointments | `ownId`, `sts`, `dt` | مواعيد صاحب العرض |
| appointments | `reqId`, `sts`, `dt` | مواعيد طالب الحجز |
| notifications | `uid`, `iRd`, `tsCrt` | إشعارات المستخدم |
| deals | `sellUid`, `sts` | صفقات البائع |
| deals | `buyUid`, `sts` | صفقات المشتري |

**ملاحظة:** لا تضف Indexes غير مستخدمة — كل Index يكلف فلوس.

---

## 📌 خلاصة التوفير

| الاستراتيجية | التوفير |
|-------------|---------|
| أسماء حقول قصيرة (3-4 أحرف) | 40-60% من حجم البيانات المنقولة |
| Config يُحمّل مرّة ويُخزّن محلياً | آلاف القراءات في الشهر |
| Counters بدلاً من count() | 99% من عمليات العد |
| TTL على الإشعارات | تخزين أقل ⇒ فلوس أقل |
| Cloud Functions بدلاً من client logic | كتابات أقل + منطق آمن |
| لا Subcollections | قراءات أقل |

---

## ✅ كل النقاط المعتمدة (1-12) — جميعها جاهزة

- [x] النقطة 1: الزائر — ✅ معتمدة
- [x] النقطة 2: المستخدم والتفعيل (OTP) — ✅ معتمدة
- [x] النقطة 3: الهيكل العام للواجهة — ✅ معتمدة
- [x] النقطة 4: تبويب العروض — ✅ معتمدة
- [x] النقطة 5: تبويب الطلبات — ✅ معتمدة
- [x] النقطة 6: رفع العرض والمراجعة — ✅ معتمدة
- [x] النقطة 7: حجز المواعيد — ✅ معتمدة
- [x] النقطة 8: موافقة الوسيط وصاحب العرض — ✅ معتمدة
- [x] النقطة 9: الوسيط ولوحته — ✅ معتمدة
- [x] النقطة 10: لوحة الإدارة والصلاحيات — ✅ معتمدة
- [x] النقطة 11: الإشعارات (داخلية + FCM) — ✅ معتمدة
- [x] النقطة 12: نموذج البيانات (Firestore + Config) — ✅ **معتمد ومكتمل**

---

## 📁 ملف locations.json

✅ موجود في `docs/locations.json` — **معتمد وجاهز.**
