import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج العرض — offer
class OfferModel {
  final String offId;
  final int typ;            // 0=عقار, 1=سيارة
  final int trx;            // 0=بيع, 1=إيجار
  final int cat;            // النوع الرئيسي
  final int sub;            // النوع الفرعي
  final String ttl;         // العنوان
  final num prc;            // السعر
  final int cur;            // 0=$, 1=ل.س
  final Map<String, dynamic> loc; // {r:0, d:""}
  final String desc;        // الوصف
  final List<String> imgs;  // الصور (max 6)
  final String vdo;         // رابط الفيديو
  final int docTp;          // نوع سند الملكية
  final String docImg;      // صورة السند
  final String exactLoc;    // الموقع الدقيق
  final Map<String, dynamic> specs; // المواصفات
  final String usrId;       // الناشر
  final String brkId;       // الوسيط
  final int brkPct;         // نسبة عمولة الوسيط
  final num? com;           // عمولة معدلة
  final int sts;            // الحالة
  final String rsn;         // سبب الرفض
  final int vws;            // المشاهدات
  final int fvs;            // المفضلة
  final int iPub;           // 0=غير منشور, 1=منشور
  final int iSoc;           // 0=لا, 1=نشر على السوشيال ميديا
  final int socPub;         // 0=لم ينشر, 1=تم النشر
  final String socTxt;      // نص المنشور الجاهز
  final int iDup;           // 0=غير مكرر, 1=مكرر
  final String dupOf;       // offer ID المكرر
  final Map<String, dynamic> avl; // المواعيد المتاحة
  final int iDel;
  final Timestamp tsCrt;
  final Timestamp? tsPub;
  final Timestamp? tsEnd;
  final Timestamp? tsRen;

  OfferModel({
    required this.offId,
    required this.typ,
    required this.trx,
    required this.cat,
    required this.sub,
    required this.ttl,
    required this.prc,
    this.cur = 1,
    Map<String, dynamic>? loc,
    this.desc = '',
    List<String>? imgs,
    this.vdo = '',
    this.docTp = 0,
    this.docImg = '',
    this.exactLoc = '',
    Map<String, dynamic>? specs,
    required this.usrId,
    this.brkId = '',
    this.brkPct = 0,
    this.com,
    this.sts = 0,
    this.rsn = '',
    this.vws = 0,
    this.fvs = 0,
    this.iPub = 0,
    this.iSoc = 0,
    this.socPub = 0,
    this.socTxt = '',
    this.iDup = 0,
    this.dupOf = '',
    Map<String, dynamic>? avl,
    this.iDel = 0,
    required this.tsCrt,
    this.tsPub,
    this.tsEnd,
    this.tsRen,
  })  : loc = loc ?? {'r': 0, 'd': ''},
        imgs = imgs ?? [],
        specs = specs ?? {},
        avl = avl ?? {};

  factory OfferModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OfferModel(
      offId: doc.id,
      typ: data['typ'] ?? 0,
      trx: data['trx'] ?? 0,
      cat: data['cat'] ?? 0,
      sub: data['sub'] ?? 0,
      ttl: data['ttl'] ?? '',
      prc: data['prc'] ?? 0,
      cur: data['cur'] ?? 1,
      loc: Map<String, dynamic>.from(data['loc'] ?? {}),
      desc: data['desc'] ?? '',
      imgs: List<String>.from(data['imgs'] ?? []),
      vdo: data['vdo'] ?? '',
      docTp: data['docTp'] ?? 0,
      docImg: data['docImg'] ?? '',
      exactLoc: data['exactLoc'] ?? '',
      specs: Map<String, dynamic>.from(data['specs'] ?? {}),
      usrId: data['usrId'] ?? '',
      brkId: data['brkId'] ?? '',
      brkPct: data['brkPct'] ?? 0,
      com: data['com'],
      sts: data['sts'] ?? 0,
      rsn: data['rsn'] ?? '',
      vws: data['vws'] ?? 0,
      fvs: data['fvs'] ?? 0,
      iPub: data['iPub'] ?? 0,
      iSoc: data['iSoc'] ?? 0,
      socPub: data['socPub'] ?? 0,
      socTxt: data['socTxt'] ?? '',
      iDup: data['iDup'] ?? 0,
      dupOf: data['dupOf'] ?? '',
      avl: Map<String, dynamic>.from(data['avl'] ?? {}),
      iDel: data['iDel'] ?? 0,
      tsCrt: data['tsCrt'] as Timestamp,
      tsPub: data['tsPub'] as Timestamp?,
      tsEnd: data['tsEnd'] as Timestamp?,
      tsRen: data['tsRen'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'typ': typ,
      'trx': trx,
      'cat': cat,
      'sub': sub,
      'ttl': ttl,
      'prc': prc,
      'cur': cur,
      'loc': loc,
      'desc': desc,
      'imgs': imgs,
      'vdo': vdo,
      'docTp': docTp,
      'docImg': docImg,
      'exactLoc': exactLoc,
      'specs': specs,
      'usrId': usrId,
      'brkId': brkId,
      'brkPct': brkPct,
      'com': com,
      'sts': sts,
      'rsn': rsn,
      'vws': vws,
      'fvs': fvs,
      'iPub': iPub,
      'iSoc': iSoc,
      'socPub': socPub,
      'socTxt': socTxt,
      'iDup': iDup,
      'dupOf': dupOf,
      'avl': avl,
      'iDel': iDel,
      'tsCrt': tsCrt,
      'tsPub': tsPub,
      'tsEnd': tsEnd,
      'tsRen': tsRen,
    };
  }

  bool get isPublished => iPub == 1;
  bool get isDeleted => iDel == 1;
  bool get isProperty => typ == 0;
  bool get isVehicle => typ == 1;
  bool get isSell => trx == 0;
  bool get isRent => trx == 1;
  String get statusText {
    switch (sts) {
      case 0: return 'مسودة';
      case 1: return 'قيد المراجعة';
      case 2: return 'منشور';
      case 3: return 'مرفوض';
      case 4: return 'منتهي';
      case 5: return 'محجوز';
      case 6: return 'مكتمل';
      default: return 'غير معروف';
    }
  }
}