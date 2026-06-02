import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_constants.dart';

/// نموذج المستخدم — user
/// الحقول بأسماء قصيرة لتقليل حجم البيانات (SPEC § naming)
class UserModel {
  final String uid;
  final String nm;           // الاسم
  final String ph;           // الهاتف
  final String ad;           // العنوان
  final int role;            // المستوى: 0=مستخدم, 1=وسيط, 2=مشرف, 3=نائب, 4=مدير
  final String sid;          // رقم الهوية
  final String img;          // URL صورة البطاقة
  final int pt;              // رصيد النقاط
  final int bg;              // البادج: 0=new, 1=bronze, 2=silver, 3=gold, 4=diamond
  final Timestamp? bgTs;     // تاريخ آخر ترقية للبادج
  final int bPkg;            // الباقة: 0=free, 1=silver, 2=gold
  final Timestamp? pkgEnd;   // تاريخ انتهاء الباقة
  final int brk;             // هل هو وسيط؟ 0=لا, 1=نعم
  final int brkCls;          // فئة الوساطة: 0=فرد, 1=مكتب, 2=شركة
  final String brkNm;        // الاسم التجاري
  final int sts;             // حالة الحساب: 0=نشط, 1=مجمّد, 2=محظور
  final String banRsn;       // سبب الحظر
  final Map<String, int> ntf;   // إعدادات الإشعارات
  final Map<String, int> stats; // إحصائيات
  final List<dynamic> wkLgn;    // آخر تسجيل دخول أسبوعي
  final int strk;            // streak counter
  final Timestamp? strkDt;   // آخر يوم streak
  final int iDel;            // 0=موجود, 1=محذوف
  final Timestamp tsCrt;     // تاريخ الإنشاء
  final Timestamp? tsUpd;    // تاريخ آخر تحديث

  UserModel({
    required this.uid,
    required this.nm,
    required this.ph,
    this.ad = '',
    this.role = 0,
    this.sid = '',
    this.img = '',
    this.pt = 0,
    this.bg = 0,
    this.bgTs,
    this.bPkg = 0,
    this.pkgEnd,
    this.brk = 0,
    this.brkCls = 0,
    this.brkNm = '',
    this.sts = 0,
    this.banRsn = '',
    Map<String, int>? ntf,
    Map<String, int>? stats,
    List<dynamic>? wkLgn,
    this.strk = 0,
    this.strkDt,
    this.iDel = 0,
    required this.tsCrt,
    this.tsUpd,
  })  : ntf = ntf ?? {'off': 0, 'app': 0, 'fin': 0, 'rat': 0},
        stats = stats ?? {'off': 0, 'req': 0, 'app': 0, 'dl': 0},
        wkLgn = wkLgn ?? [];

  /// تحويل من Firestore إلى Model
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      nm: data['nm'] ?? '',
      ph: data['ph'] ?? '',
      ad: data['ad'] ?? '',
      role: data['role'] ?? 0,
      sid: data['sid'] ?? '',
      img: data['img'] ?? '',
      pt: data['pt'] ?? 0,
      bg: data['bg'] ?? 0,
      bgTs: data['bgTs'] as Timestamp?,
      bPkg: data['bPkg'] ?? 0,
      pkgEnd: data['pkgEnd'] as Timestamp?,
      brk: data['brk'] ?? 0,
      brkCls: data['brkCls'] ?? 0,
      brkNm: data['brkNm'] ?? '',
      sts: data['sts'] ?? 0,
      banRsn: data['banRsn'] ?? '',
      ntf: Map<String, int>.from(data['ntf'] ?? {}),
      stats: Map<String, int>.from(data['stats'] ?? {}),
      wkLgn: data['wkLgn'] ?? [],
      strk: data['strk'] ?? 0,
      strkDt: data['strkDt'] as Timestamp?,
      iDel: data['iDel'] ?? 0,
      tsCrt: data['tsCrt'] as Timestamp,
      tsUpd: data['tsUpd'] as Timestamp?,
    );
  }

  /// تحويل إلى Map للتخزين في Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'nm': nm,
      'ph': ph,
      'ad': ad,
      'role': role,
      'sid': sid,
      'img': img,
      'pt': pt,
      'bg': bg,
      'bgTs': bgTs,
      'bPkg': bPkg,
      'pkgEnd': pkgEnd,
      'brk': brk,
      'brkCls': brkCls,
      'brkNm': brkNm,
      'sts': sts,
      'banRsn': banRsn,
      'ntf': ntf,
      'stats': stats,
      'wkLgn': wkLgn,
      'strk': strk,
      'strkDt': strkDt,
      'iDel': iDel,
      'tsCrt': tsCrt,
      'tsUpd': tsUpd ?? FieldValue.serverTimestamp(),
    };
  }

  // --- خصائص مساعدة ---
  bool get isActive => sts == UserStatus.active;
  bool get isFrozen => sts == UserStatus.frozen;
  bool get isBanned => sts == UserStatus.banned;
  bool get isBroker => brk == 1;
  bool get isDeleted => iDel == 1;
  bool get isAdmin => role >= UserRole.supervisor;

  String get roleName {
    switch (role) {
      case 0: return 'مستخدم';
      case 1: return 'وسيط';
      case 2: return 'مشرف';
      case 3: return 'نائب';
      case 4: return 'مدير';
      default: return 'غير معروف';
    }
  }

  String get badgeName {
    switch (bg) {
      case 0: return '🔰 جديد';
      case 1: return '🥉 برونزي';
      case 2: return '🥈 فضي';
      case 3: return '🥇 ذهبي';
      case 4: return '💎 ماسي';
      default: return '🔰 جديد';
    }
  }
}