import '../network/supabase_service.dart';
import '../constants/db_constants.dart';
import '../../models/config_model.dart';
import '../../models/offer_model.dart';
import '../../models/user_model.dart';

/// خدمة المنطق الخلفي المركزية (Business Logic)
///
/// تجمع العمليات غير المرئية: النقاط، البادجات، الحصص، الباقات،
/// المطابقة التلقائية، Streak، وتوليد منشورات السوشال ميديا.
///
/// تعتمد على دوال RPC الموجودة في Supabase حيثما أمكن:
/// `add_points`, `update_user_badge`, `calculate_commission`, `check_offer_duplicate`.
class BusinessService {
  BusinessService._internal();
  static final BusinessService _instance = BusinessService._internal();
  factory BusinessService() => _instance;

  SupabaseService get _sb => SupabaseService();

  // ═══════════════════════════════════════
  // 4.3 نظام النقاط (عبر RPC add_points)
  // ═══════════════════════════════════════

  /// إضافة نقاط لمستخدم (تستدعي RPC التي تحدّث البادج تلقائياً)
  Future<bool> addPoints(String uid, int points) async {
    if (uid.isEmpty || points == 0) return false;
    try {
      await _sb.client.rpc(DbFunctions.addPoints, params: {
        'p_uid': uid,
        'p_pts': points,
      });
      return true;
    } catch (e) {// fallback: تحديث مباشر إن فشلت RPC
      return _addPointsFallback(uid, points);
    }
  }

  /// منح نقاط آمنة (تتحقق من الحدود اليومية لمنع التلاعب)
  Future<bool> awardPointsSafe(String uid, String eventType, int points) async {
    if (uid.isEmpty || points == 0) return false;
    try {
      final res = await _sb.client.rpc(DbFunctions.awardPointsSafe, params: {
        'p_uid': uid,
        'p_event_type': eventType,
        'p_points': points,
      });
      if (res['success'] == true) return true;return false;
    } catch (e) {return false;
    }
  }

  Future<bool> _addPointsFallback(String uid, int points) async {
    try {
      final row =
          await _sb.client.from(DbTables.users).select('pt').eq('id', uid).single();
      final current = (row['pt'] as int?) ?? 0;
      await _sb.client.from(DbTables.users).update({
        'pt': current + points,
        'ts_upd': DateTime.now().toIso8601String(),
      }).eq('id', uid);
      await _sb.client.rpc('update_user_badge', params: {'p_uid': uid});
      return true;
    } catch (e) {return false;
    }
  }

  /// منح نقاط حدث معيّن باستخدام مفاتيح الـ Config (pts.*)
  /// أمثلة المفاتيح: 'sgn','wkL','addO','dlD','strk','soc','att','ref'
  Future<bool> awardEvent(String uid, ConfigModel? config, String eventKey,
      {int fallback = 0}) async {
    final pts = _ptsFromConfig(config, eventKey, fallback);
    if (pts == 0) return false;
    return awardPointsSafe(uid, eventKey, pts);
  }

  int _ptsFromConfig(ConfigModel? config, String key, int fallback) {
    if (config == null) return fallback;
    final ptsMap = config.data['pts'];
    if (ptsMap is Map && ptsMap[key] is num) {
      return (ptsMap[key] as num).toInt();
    }
    return fallback;
  }

  /// خصم نقاط (عقوبة) — pen.* في الـ Config (قيم سالبة)
  Future<bool> applyPenalty(String uid, ConfigModel? config, String penKey,
      {int fallback = 0}) async {
    int pts = fallback;
    if (config != null) {
      final penMap = config.data['pen'];
      if (penMap is Map && penMap[penKey] is num) {
        pts = (penMap[penKey] as num).toInt();
      }
    }
    if (pts == 0) return false;
    return addPoints(uid, pts); // القيمة سالبة فتُخصم، لا نحتاج لسقف يومي للخصم
  }

  // ═══════════════════════════════════════
  // 4.4 نظام الباقات والحصص (Quotas)
  // ═══════════════════════════════════════

  /// التحقق من إمكانية نشر عرض جديد حسب حصة المستخدم/الوسيط والباقة.
  ///
  /// يُرجع خريطة: {allowed: bool, used: int, limit: int, reason: String}
  Future<Map<String, dynamic>> canPublishOffer({
    required String uid,
    required int role,
    required int packageType,
    ConfigModel? config,
  }) async {
    try {
      if (role >= 2) {
        return {
          'allowed': true,
          'used': 0,
          'limit': 999999,
          'reason': '',
        };
      }
      // 🔒 Phase 8: نحسب الفعّالة + المحذوفة حديثاً (آخر 24 ساعة)
      // لمنع ثغرة "احذف لتنشر" — Scam #4 في التقرير الأمني
      final since24h =
          DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();

      List active = [];
      List recentlyDeleted = [];
      try {
        active = await _sb.client
            .from(DbTables.offers)
            .select('id')
            .eq('usr_id', uid)
            .eq('i_del', 0)
            .inFilter('sts', [0, 1, 2, 5]);
      } catch (_) {}

      try {
        recentlyDeleted = await _sb.client
            .from(DbTables.offers)
            .select('id')
            .eq('usr_id', uid)
            .eq('i_del', 1)
            .gte('ts_upd', since24h);
      } catch (_) {}

      final used = active.length + recentlyDeleted.length;

      final limit = offerQuota(config, role: role, packageType: packageType);

      final allowed = used < limit;
      return {
        'allowed': allowed,
        'used': used,
        'limit': limit,
        'reason': allowed
            ? ''
            : 'وصلت للحد الأقصى ($limit عرض خلال 24 ساعة، شامل المحذوف). '
                'رقّ باقتك لنشر المزيد.',
      };
    } catch (e) {// 🔒 Phase 8: عند الفشل الكامل نمنع (fail-closed) بدل السماح للأمان
      return {
        'allowed': false,
        'used': 0,
        'limit': 0,
        'reason': 'تعذّر التحقق من حصتك (مشكلة مؤقتة في الاتصال أو الاستعلام). حاول لاحقاً أو رقّ باقتك.',
      };
    }
  }

  /// حساب حصة العروض: تعتمد على الباقة أولاً ثم على الدور (qta.u / qta.b)
  int offerQuota(ConfigModel? config,
      {required int role, required int packageType}) {
    if (role >= 2) return 999999;
    if (config != null) {
      // 1) حد الباقة (pkg.{type}.o) — له الأولوية
      final pkgMap = config.data['pkg'];
      if (pkgMap is Map && pkgMap['$packageType'] is Map) {
        final o = (pkgMap['$packageType'] as Map)['o'];
        if (o is num) return o.toInt();
      }
      // 2) حصة حسب الدور (qta.b للوسيط، qta.u للمستخدم)
      final isBroker = role == 1;
      final quotas = isBroker ? config.brokerQuotas : config.userQuotas;
      final o = quotas['o'];
      if (o is num) return o.toInt();
    }
    // قيم افتراضية آمنة
    return role == 1 ? 5 : 1;
  }

  /// حصة الطلبات (qta.u.r / qta.b.r)
  int requestQuota(ConfigModel? config, {required int role}) {
    if (config != null) {
      final quotas = role == 1 ? config.brokerQuotas : config.userQuotas;
      final r = quotas['r'];
      if (r is num) return r.toInt();
    }
    return role == 1 ? 5 : 3;
  }

  Future<Map<String, dynamic>> canPublishRequest({
    required String uid,
    required int role,
    ConfigModel? config,
  }) async {
    try {
      final existing = await _sb.client
          .from(DbTables.requests)
          .select('id')
          .eq('usr_id', uid)
          .eq('i_del', 0);
      final used = (existing as List).length;
      final limit = requestQuota(config, role: role);
      final allowed = used < limit;
      return {
        'allowed': allowed,
        'used': used,
        'limit': limit,
        'reason': allowed ? '' : 'وصلت للحد الأقصى ($limit طلب).',
      };
    } catch (e) {return {'allowed': false, 'used': 0, 'limit': 0, 'reason': 'تعذّر التحقق من حصتك، حاول لاحقاً.'};
    }
  }

  // ═══════════════════════════════════════
  // 4.2 المطابقة التلقائية (Requests ↔ Offers)
  // ═══════════════════════════════════════

  /// إيجاد العروض المنشورة المطابقة لطلب
  /// (حسب نوع العنصر + نوع المعاملة + العملة + نطاق السعر ±20%).
  Future<List<OfferModel>> matchOffersForRequest({
    required int elementType,
    required int transactionType,
    required double targetPrice,
    required int currency,
    double tolerance = 0.20,
  }) async {
    try {
      var q = _sb.client
          .from(DbTables.offers)
          .select()
          .eq('i_del', 0)
          .eq('i_pub', 1)
          .eq('typ', elementType)
          .eq('trx', transactionType)
          .eq('cur', currency);

      if (targetPrice > 0) {
        final min = targetPrice * (1 - tolerance);
        final max = targetPrice * (1 + tolerance);
        q = q.gte('prc', min).lte('prc', max);
      }

      final res = await q.order('ts_crt', ascending: false).limit(20);
      return (res as List)
          .map((d) =>
              OfferModel.fromSupabase(Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {return [];
    }
  }

  /// إيجاد الطلبات المطابقة لعرض (الاتجاه المعاكس).
  Future<List<Map<String, dynamic>>> matchRequestsForOffer({
    required int elementType,
    required int transactionType,
    required double price,
    required int currency,
    double tolerance = 0.20,
  }) async {
    try {
      var q = _sb.client
          .from(DbTables.requests)
          .select()
          .eq('i_del', 0)
          .eq('elm', elementType)
          .eq('typ', transactionType)
          .eq('cur', currency);
      if (price > 0) {
        final min = price * (1 - tolerance);
        final max = price * (1 + tolerance);
        q = q.gte('prc', min).lte('prc', max);
      }
      final res = await q.limit(20);
      return (res as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {return [];
    }
  }

  // ═══════════════════════════════════════
  // 4.5 نظام Streak (تسجيل دخول يومي متتالي)
  // ═══════════════════════════════════════

  /// تسجيل دخول اليوم وتحديث سلسلة الأيام المتتالية.
  /// يمنح نقاط Streak عند الاستمرار، ويعيد الحالة الجديدة.
  /// يستخدم توقيت سوريا (UTC+3) لتحديد بداية اليوم (بعد 12 ليلاً بدمشق).
  Future<Map<String, dynamic>> registerDailyStreak(
      String uid, ConfigModel? config) async {
    try {
      final strkPts = _ptsFromConfig(config, 'strk', 50);
      final result = await _sb.client.rpc(
        'register_daily_streak_internal',
        params: {
          'p_user_uid': uid,
          'p_points': strkPts,
        },
      );
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      return {'streak': 0, 'changed': false, 'awarded': false};
    }
  }

  // ═══════════════════════════════════════
  // 4.6 توليد نص منشور السوشال ميديا
  // ═══════════════════════════════════════

  /// توليد نص جاهز للنشر على وسائل التواصل من بيانات العرض.
  String generateSocialPost(OfferModel offer, {ConfigModel? config}) {
    final buffer = StringBuffer();
    final isProperty = offer.typ == 0;
    final trx = offer.trx == 0 ? 'للبيع' : 'للإيجار';
    final emoji = isProperty ? '🏠' : '🚗';
    final cur = offer.cur == 0 ? '\$' : 'ل.س';

    buffer.writeln('$emoji ${offer.ttl}');
    buffer.writeln('');
    buffer.writeln('📌 $trx');
    if (offer.prc > 0) {
      buffer.writeln('💰 السعر: ${_fmtPrice(offer.prc)} $cur');
    }
    final loc = offer.loc['d'];
    if (loc is String && loc.isNotEmpty) {
      buffer.writeln('📍 الموقع: $loc');
    }
    if (offer.descript.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln(offer.descript);
    }
    buffer.writeln('');
    buffer.writeln('📞 للتواصل والمعاينة عبر المكتب العقاري الالكتروني');

    // هاشتاغات
    buffer.writeln('');
    buffer.write('#عقارات_السويداء #السويداء ');
    buffer.write(isProperty ? '#عقارات #${offer.trx == 0 ? 'بيع' : 'إيجار'}' : '#سيارات #مركبات');

    return buffer.toString();
  }

  String _fmtPrice(double p) {
    final s = p.toStringAsFixed(0);
    // إضافة فواصل آلاف
    final re = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return s.replaceAllMapped(re, (m) => ',');
  }

  /// تعليم العرض بأنه جاهز/منشور على السوشال (soc_pub) + حفظ النص
  Future<bool> markSocialPublished(String offerId, String text,
      {String? userId}) async {
    try {
      if (userId == null || userId.isEmpty) return false;
      await _sb.client.rpc('mark_social_published_internal', params: {
        'p_user_uid': userId,
        'p_offer_id': offerId,
        'p_text': text,
      });
      return true;
    } catch (e) {return false;
    }
  }

  // ═══════════════════════════════════════
  // مساعد: كشف التكرار قبل النشر (RPC check_offer_duplicate)
  // ═══════════════════════════════════════
  Future<bool> isDuplicateOffer({
    required String title,
    required double price,
    required Map<String, dynamic> loc,
    required String uid,
  }) async {
    try {
      final res = await _sb.client.rpc('check_offer_duplicate', params: {
        'p_ttl': title,
        'p_prc': price,
        'p_loc': loc,
        'p_usr_id': uid,
      });
      return res == true;
    } catch (e) {return false;
    }
  }

  // ═══════════════════════════════════════
  // 4.7 إدارة إحصائيات المستخدم (Stats)
  // ═══════════════════════════════════════

  /// تحديث إحصائيات المستخدم (off, req, app, dl)
  Future<void> updateUserStat(String uid, String statKey) async {
    try {
      // جلب القيمة الحالية
      final row = await _sb.client.from(DbTables.users).select('stats').eq('id', uid).single();
      Map<String, dynamic> stats = Map<String, dynamic>.from(row['stats'] ?? {});
      
      // زيادة العداد بمقدار 1
      final currentVal = (stats[statKey] ?? 0) as int;
      stats[statKey] = currentVal + 1;

      await _sb.client.from(DbTables.users).update({
        'stats': stats,
        'ts_upd': DateTime.now().toIso8601String(),
      }).eq('id', uid);
    } catch (e) {}
  }

  // ═══════════════════════════════════════
  // 4.8 هوية المكتب (Office Identity)
  // مرجع: docs/LOGIC_SPEC.md — القسم الأول
  // ═══════════════════════════════════════

  /// تحويل بيانات المستخدم إلى تسمية مهنية تُعرض للعامة.
  /// تُخفي اسم المالك الحقيقي لحماية الخصوصية وتعزيز هوية "المكتب".
  ///
  /// قواعد التسمية:
  /// - وسيط + موثق رسمياً (vrf=2)        → "وسيط معتمد ✓"
  /// - وسيط + قيد التوثيق أو غير موثق   → "وسيط شريك"
  /// - مستخدم + موثق رسمياً              → "عميل موثق ✓"
  /// - مستخدم + رتبة ≥ خبير              → "عميل مميز ⭐"
  /// - مستخدم + رتبة ≥ نشط               → "عميل نشط"
  /// - مستخدم عادي                       → "عميل"
  String getUserPublicLabel(UserModel user) {
    final isBroker = user.isBroker; // يعتمد على حقل brk == 1
    final isOfficial = user.isVerifiedOfficial;
    final badge = user.bg;

    String label;
    if (isBroker) {
      label = isOfficial ? 'وسيط معتمد ✓' : 'وسيط شريك';
    } else {
      if (isOfficial) {
        label = 'عميل موثق ✓';
      } else if (badge >= 3) {
        label = 'عميل مميز ⭐';
      } else if (badge >= 1) {
        label = 'عميل نشط';
      } else {
        label = 'عميل';
      }
    }

    return 'منشور بواسطة المكتب العقاري الالكتروني • $label';
  }
}
