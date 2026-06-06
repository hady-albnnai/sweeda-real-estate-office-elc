import 'package:flutter/foundation.dart';
import '../network/supabase_service.dart';
import '../constants/db_constants.dart';
import '../../models/config_model.dart';
import '../../models/offer_model.dart';

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
    } catch (e) {
      debugPrint('❌ addPoints error: $e');
      // fallback: تحديث مباشر إن فشلت RPC
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
      if (res['success'] == true) return true;
      debugPrint('⚠️ awardPointsSafe: ${res['error']}');
      return false;
    } catch (e) {
      debugPrint('❌ awardPointsSafe error: $e');
      return false;
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
    } catch (e) {
      debugPrint('❌ addPoints fallback error: $e');
      return false;
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
      // عدد العروض الفعّالة الحالية للمستخدم
      final existing = await _sb.client
          .from(DbTables.offers)
          .select('id')
          .eq('usr_id', uid)
          .eq('i_del', 0)
          .inFilter('sts', [0, 1, 2, 5]); // مسودة/مراجعة/منشور/محجوز
      final used = (existing as List).length;

      final limit = offerQuota(config, role: role, packageType: packageType);

      final allowed = used < limit;
      return {
        'allowed': allowed,
        'used': used,
        'limit': limit,
        'reason': allowed
            ? ''
            : 'وصلت للحد الأقصى ($limit عرض). رقّ باقتك لنشر المزيد.',
      };
    } catch (e) {
      debugPrint('❌ canPublishOffer error: $e');
      // عند الفشل نسمح بدل ما نمنع المستخدم خطأً
      return {'allowed': true, 'used': 0, 'limit': 0, 'reason': ''};
    }
  }

  /// حساب حصة العروض: تعتمد على الباقة أولاً ثم على الدور (qta.u / qta.b)
  int offerQuota(ConfigModel? config,
      {required int role, required int packageType}) {
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
    } catch (e) {
      debugPrint('❌ canPublishRequest error: $e');
      return {'allowed': true, 'used': 0, 'limit': 0, 'reason': ''};
    }
  }

  // ═══════════════════════════════════════
  // 4.2 المطابقة التلقائية (Requests ↔ Offers)
  // ═══════════════════════════════════════

  /// إيجاد العروض المنشورة المطابقة لطلب (حسب النوع + نطاق السعر ±20%).
  Future<List<OfferModel>> matchOffersForRequest({
    required int type,
    required double targetPrice,
    double tolerance = 0.20,
  }) async {
    try {
      var q = _sb.client
          .from(DbTables.offers)
          .select()
          .eq('i_del', 0)
          .eq('i_pub', 1)
          .eq('typ', type);

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
    } catch (e) {
      debugPrint('❌ matchOffersForRequest error: $e');
      return [];
    }
  }

  /// إيجاد الطلبات المطابقة لعرض (الاتجاه المعاكس) + تخزين أعدادها في matches.
  Future<List<Map<String, dynamic>>> matchRequestsForOffer({
    required int type,
    required double price,
    double tolerance = 0.20,
  }) async {
    try {
      var q = _sb.client
          .from(DbTables.requests)
          .select()
          .eq('i_del', 0)
          .eq('typ', type);
      if (price > 0) {
        final min = price * (1 - tolerance);
        final max = price * (1 + tolerance);
        q = q.gte('prc', min).lte('prc', max);
      }
      final res = await q.limit(20);
      return (res as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('❌ matchRequestsForOffer error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════
  // 4.5 نظام Streak (تسجيل دخول يومي متتالي)
  // ═══════════════════════════════════════

  /// تسجيل دخول اليوم وتحديث سلسلة الأيام المتتالية.
  /// يمنح نقاط Streak عند الاستمرار، ويعيد الحالة الجديدة.
  Future<Map<String, dynamic>> registerDailyStreak(
      String uid, ConfigModel? config) async {
    try {
      final row = await _sb.client
          .from(DbTables.users)
          .select('strk, strk_dt')
          .eq('id', uid)
          .single();

      final int currentStreak = (row['strk'] as int?) ?? 0;
      final DateTime? lastDate =
          row['strk_dt'] != null ? DateTime.tryParse(row['strk_dt'] as String) : null;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int newStreak;
      bool awarded = false;

      if (lastDate == null) {
        newStreak = 1;
      } else {
        final last = DateTime(lastDate.year, lastDate.month, lastDate.day);
        final diff = today.difference(last).inDays;
        if (diff == 0) {
          // سُجّل اليوم مسبقاً — لا تغيير
          return {
            'streak': currentStreak,
            'changed': false,
            'awarded': false,
          };
        } else if (diff == 1) {
          newStreak = currentStreak + 1; // يوم متتالٍ
        } else {
          newStreak = 1; // انقطعت السلسلة
        }
      }

      await _sb.client.from(DbTables.users).update({
        'strk': newStreak,
        'strk_dt': today.toIso8601String(),
        'ts_upd': now.toIso8601String(),
      }).eq('id', uid);

      // منح نقاط Streak (pts.strk)
      final strkPts = _ptsFromConfig(config, 'strk', 200);
      if (strkPts != 0) {
        await addPoints(uid, strkPts);
        awarded = true;
      }

      return {'streak': newStreak, 'changed': true, 'awarded': awarded};
    } catch (e) {
      debugPrint('❌ registerDailyStreak error: $e');
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
    buffer.writeln('📞 للتواصل والمعاينة عبر تطبيق عقارات السويداء');

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
  Future<bool> markSocialPublished(String offerId, String text) async {
    try {
      await _sb.client.from(DbTables.offers).update({
        'soc_pub': 1,
        'soc_txt': text,
        'ts_upd': DateTime.now().toIso8601String(),
      }).eq('id', offerId);
      return true;
    } catch (e) {
      debugPrint('❌ markSocialPublished error: $e');
      return false;
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
    } catch (e) {
      debugPrint('⚠️ isDuplicateOffer error: $e');
      return false;
    }
  }
}
