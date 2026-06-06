import 'package:supabase_flutter/supabase_flutter.dart';

/// نموذج المستخدم — أسماء الحقول القصيرة تطابق قاعدة البيانات
class UserModel {
  final String uid;
  final String nm;
  final String ph;
  final String? eml; // الإيميل (المرحلة 7)
  final String ad;
  final int role;
  final String sid;
  final String img;
  final int pt;
  final int bg;
  final DateTime? bgTs;
  final int bPkg;
  final DateTime? pkgEnd;
  final int brk;
  final int brkCls;
  final String brkNm;
  final int sts;
  final String banRsn;
  final Map<String, dynamic> ntf;
  final Map<String, dynamic> stats;
  final List<dynamic> wkLgn;
  final int strk;
  final DateTime? strkDt;
  final int iDel;
  final DateTime tsCrt;
  final DateTime? tsUpd;

  UserModel({
    required this.uid,
    required this.nm,
    required this.ph,
    this.eml,
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
    Map<String, dynamic>? ntf,
    Map<String, dynamic>? stats,
    List<dynamic>? wkLgn,
    this.strk = 0,
    this.strkDt,
    this.iDel = 0,
    required this.tsCrt,
    this.tsUpd,
  })  : ntf = ntf ?? {'off': 0, 'app': 0, 'fin': 0, 'rat': 0},
        stats = stats ?? {'off': 0, 'req': 0, 'app': 0, 'dl': 0},
        wkLgn = wkLgn ?? [];

  factory UserModel.fromSupabase(Map<String, dynamic> data, String id) {
    return UserModel(
      uid: id,
      nm: data['nm'] ?? '',
      ph: data['ph'] ?? '',
      eml: data['eml'] as String?,
      ad: data['ad'] ?? '',
      role: data['role'] ?? 0,
      sid: data['sid'] ?? '',
      img: data['img'] ?? '',
      pt: data['pt'] ?? 0,
      bg: data['bg'] ?? 0,
      bgTs: data['bg_ts'] != null ? DateTime.parse(data['bg_ts']) : null,
      bPkg: data['b_pkg'] ?? 0,
      pkgEnd: data['pkg_end'] != null ? DateTime.parse(data['pkg_end']) : null,
      brk: data['brk'] ?? 0,
      brkCls: data['brk_cls'] ?? 0,
      brkNm: data['brk_nm'] ?? '',
      sts: data['sts'] ?? 0,
      banRsn: data['ban_rsn'] ?? '',
      ntf: data['ntf'] != null
          ? Map<String, dynamic>.from(data['ntf'] as Map)
          : {'off': 0, 'app': 0, 'fin': 0, 'rat': 0},
      stats: data['stats'] != null
          ? Map<String, dynamic>.from(data['stats'] as Map)
          : {'off': 0, 'req': 0, 'app': 0, 'dl': 0},
      wkLgn: data['wk_lgn'] ?? [],
      strk: data['strk'] ?? 0,
      strkDt: data['strk_dt'] != null ? DateTime.parse(data['strk_dt']) : null,
      iDel: data['i_del'] ?? 0,
      tsCrt: DateTime.parse(data['ts_crt']),
      tsUpd: data['ts_upd'] != null ? DateTime.parse(data['ts_upd']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nm': nm, 'ph': ph, 'ad': ad, 'role': role, 'sid': sid,
      'img': img, 'pt': pt, 'bg': bg,
      'bg_ts': bgTs?.toIso8601String(), 'b_pkg': bPkg,
      'pkg_end': pkgEnd?.toIso8601String(), 'brk': brk,
      'brk_cls': brkCls, 'brk_nm': brkNm, 'sts': sts,
      'ban_rsn': banRsn, 'ntf': ntf, 'stats': stats,
      'wk_lgn': wkLgn, 'strk': strk,
      'strk_dt': strkDt?.toIso8601String(), 'i_del': iDel,
      'ts_crt': tsCrt.toIso8601String(),
      'ts_upd': tsUpd?.toIso8601String(),
    };
  }

  bool get isActive => sts == 0;
  bool get isFrozen => sts == 1;
  bool get isBanned => sts == 2;
  bool get isBroker => brk == 1;
  bool get isDeleted => iDel == 1;
  bool get isAdmin => role >= 2;

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

  /// الرتبة السلوكية (Trust) — مكتسبة بالنشاط والنقاط.
  /// ملاحظة: المعادن (برونزي/فضي/ذهبي) محجوزة للباقات المدفوعة فقط.
  /// مرجع: docs/LOGIC_SPEC.md — القسم الثاني.
  String get badgeName {
    switch (bg) {
      case 1: return '📈 نشط';
      case 2: return '🤝 موثوق';
      case 3: return '🎓 خبير';
      case 4: return '⭐ نخبة';
      default: return '🔰 جديد';
    }
  }

  /// هل بدأ المستخدم مسار التوثيق (رفع صورة هوية)؟
  /// مؤقتاً نعتمد على وجود img؛ لاحقاً سيُضاف حقل isVerified بعد مراجعة الإدارة.
  bool get hasStartedVerification => img.isNotEmpty;
}
