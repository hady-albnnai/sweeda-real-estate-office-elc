import 'package:flutter/foundation.dart';
import '../models/offer_model.dart';
import '../models/user_model.dart';
import '../models/appointment_model.dart';
import '../models/deal_model.dart';
import '../models/payment_model.dart';
import '../models/report_model.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';
import '../core/services/business_service.dart';

/// Provider لوحة الإدارة (role >= 2)
/// يجمع كل عمليات الإدارة: العروض، المستخدمون، المواعيد، الصفقات،
/// المدفوعات، التبليغات، الإحصائيات.
class AdminProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  // ═══════════════════════════════════════
  // 1) العروض (مراجعة)
  // ═══════════════════════════════════════
  Future<List<OfferModel>> getPendingOffers() async {
    try {
      final response = await SupabaseService().client
          .from(DbTables.offers)
          .select()
          .eq('sts', 0)
          .eq('i_del', 0)
          .order('ts_crt', ascending: false);
      return (response as List)
          .map((d) =>
              OfferModel.fromSupabase(Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {return [];
    }
  }

  Future<bool> reviewOffer(String offerId, bool approve, {String reason = ''}) async {
    try {
      final sb = SupabaseService().client;
      final now = DateTime.now().toIso8601String();

      // اجلب صاحب العرض قبل التحديث (لتطبيق pen عند الرفض)
      String? ownerUid;
      try {
        final r = await sb
            .from(DbTables.offers)
            .select('usr_id')
            .eq('id', offerId)
            .maybeSingle();
        ownerUid = r?['usr_id'] as String?;
      } catch (_) {}

      await sb.from(DbTables.offers).update({
        'sts': approve ? 2 : 3,
        'i_pub': approve ? 1 : 0,
        'rsn': reason,
        'ts_pub': approve ? now : null,
        'ts_upd': now,
      }).eq('id', offerId);

      // ─── تطبيق penalty rej3 (-1000 نقطة) بعد ثالث رفض متتالٍ ───
      if (!approve && ownerUid != null) {
        try {
          // عد العروض المرفوضة آخر 30 يوم لنفس المالك
          final since = DateTime.now()
              .subtract(const Duration(days: 30))
              .toIso8601String();
          final rejected = await sb
              .from(DbTables.offers)
              .select('id')
              .eq('usr_id', ownerUid)
              .eq('sts', 3)
              .gte('ts_upd', since);
          final count = (rejected as List).length;
          // كل 3 رفضات متتالية → عقوبة
          if (count > 0 && count % 3 == 0) {
            await sb.rpc('add_points',
                params: {'p_uid': ownerUid, 'p_pts': -1000});}
        } catch (e) {}
      }

      notifyListeners();
      return true;
    } catch (e) {return false;
    }
  }


  Future<List<OfferModel>> getOffersForMediaReview() async {
    try {
      final response = await SupabaseService().client
          .from(DbTables.offers)
          .select()
          .eq('i_del', 0)
          .order('ts_crt', ascending: false)
          .limit(100);
      return (response as List)
          .map((d) => OfferModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {return [];
    }
  }

  // ═══════════════════════════════════════
  // 2) المستخدمون (إدارة)
  // ═══════════════════════════════════════
  Future<List<UserModel>> getAllUsers({String? search}) async {
    try {
      var q = SupabaseService().client
          .from(DbTables.users)
          .select()
          .eq('i_del', 0);
      if (search != null && search.isNotEmpty) {
        q = q.or('nm.ilike.%$search%,ph.ilike.%$search%');
      }
      final response = await q.order('ts_crt', ascending: false);
      return (response as List)
          .map((d) =>
              UserModel.fromSupabase(Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {return [];
    }
  }

  Future<bool> updateUserRole(String uid, int newRole) async {
    try {
      await SupabaseService().client.from(DbTables.users).update({
        'role': newRole,
        'brk': newRole == 1 ? 1 : 0,
        'ts_upd': DateTime.now().toIso8601String(),
      }).eq('id', uid);
      notifyListeners();
      return true;
    } catch (e) {return false;
    }
  }

  /// تغيير حالة المستخدم: 0=نشط, 1=مجمّد, 2=محظور
  Future<bool> setUserStatus(String uid, int status, {String reason = ''}) async {
    try {
      await SupabaseService().client.from(DbTables.users).update({
        'sts': status,
        'ban_rsn': status == 0 ? '' : reason,
        'ts_upd': DateTime.now().toIso8601String(),
      }).eq('id', uid);
      notifyListeners();
      return true;
    } catch (e) {return false;
    }
  }

  Future<bool> banUser(String uid, String reason) => setUserStatus(uid, 2, reason: reason);
  Future<bool> freezeUser(String uid, String reason) => setUserStatus(uid, 1, reason: reason);
  Future<bool> activateUser(String uid) => setUserStatus(uid, 0);

  Future<bool> softDeleteUser(String uid) async {
    try {
      await SupabaseService().client.from(DbTables.users).update({
        'i_del': 1,
        'ts_upd': DateTime.now().toIso8601String(),
      }).eq('id', uid);
      notifyListeners();
      return true;
    } catch (e) {return false;
    }
  }


  Future<bool> updateUserPermissions(String uid, List<String> permissions) async {
    try {
      await SupabaseService().client.rpc(
        'admin_update_user_permissions',
        params: {
          'p_target_uid': uid,
          'p_perm': permissions,
        },
      );
      notifyListeners();
      return true;
    } catch (e) {return false;
    }
  }

  // ═══════════════════════════════════════
  // 3) المواعيد (إدارة)
  // ═══════════════════════════════════════
  Future<List<AppointmentModel>> getAllAppointments() async {
    try {
      final response = await SupabaseService().client
          .from(DbTables.appointments)
          .select()
          .order('dt', ascending: false);
      return (response as List)
          .map((d) => AppointmentModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {return [];
    }
  }

  Future<bool> updateAppointmentStatus(String apptId, int status,
      {String adminNote = ''}) async {
    try {
      final sb = SupabaseService().client;
      final data = <String, dynamic>{'sts': status};
      if (adminNote.isNotEmpty) data['admin_nt'] = adminNote;

      // اجلب بيانات الموعد قبل التحديث (لتطبيق pen)
      String? reqUid;
      String? offId;
      try {
        final r = await sb
            .from(DbTables.appointments)
            .select('req_id, own_id, off_id')
            .eq('id', apptId)
            .maybeSingle();
        // ملاحظة: req_id = طالب الموعد (clientside)
        // own_id = صاحب العرض
        reqUid = r?['own_id'] as String?; // المحاسَب عادةً = صاحب العرض
        offId = r?['off_id'] as String?;
      } catch (_) {}

      await sb.from(DbTables.appointments).update(data).eq('id', apptId);

      // ─── pen.noSh (-500): الحالة 5 = لم يحضر ───
      if (status == 5 && reqUid != null) {
        try {
          await sb.rpc('add_points',
              params: {'p_uid': reqUid, 'p_pts': -500});} catch (e) {}
      }

      // ─── pen.cnl3 (-300): بعد ثالث إلغاء متتالي ───
      if (status == 4 && reqUid != null) {
        try {
          final since = DateTime.now()
              .subtract(const Duration(days: 30))
              .toIso8601String();
          final canceled = await sb
              .from(DbTables.appointments)
              .select('id')
              .eq('own_id', reqUid)
              .eq('sts', 4)
              .gte('ts_crt', since);
          final count = (canceled as List).length;
          if (count > 0 && count % 3 == 0) {
            await sb.rpc('add_points',
                params: {'p_uid': reqUid, 'p_pts': -300});}
        } catch (e) {}
      }

      notifyListeners();
      return true;
    } catch (e) {return false;
    }
  }

  /// فرض موعد من قبل الإدارة
  Future<bool> forceAppointment(String apptId, String adminId) async {
    try {
      await SupabaseService().client.from(DbTables.appointments).update({
        'i_force': 1,
        'force_by': adminId,
        'sts': 1,
      }).eq('id', apptId);
      notifyListeners();
      return true;
    } catch (e) {return false;
    }
  }

  // ═══════════════════════════════════════
  // 4) الصفقات (إدارة)
  // ═══════════════════════════════════════
  Future<List<DealModel>> getAllDeals() async {
    try {
      final response = await SupabaseService().client
          .from(DbTables.deals)
          .select()
          .eq('i_del', 0)
          .order('ts_crt', ascending: false);
      return (response as List)
          .map((d) =>
              DealModel.fromSupabase(Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {return [];
    }
  }

  /// إنشاء صفقة (استمارة المندوب)
  Future<bool> createDeal(DealModel deal) async {
    try {
      await SupabaseService().client.from(DbTables.deals).insert(deal.toMap());
      notifyListeners();
      return true;
    } catch (e) {return false;
    }
  }

  /// إتمام صفقة (sts=1) + تسجيل العمولة
  Future<bool> completeDeal(String dealId, String adminId,
      {double? commission, String? note}) async {
    try {
      final deal = await SupabaseService().client
          .from(DbTables.deals)
          .select()
          .eq('id', dealId)
          .single();
      
      final sellUid = deal['sell_uid'] as String;
      final buyUid = deal['buy_uid'] as String;

      final data = <String, dynamic>{
        'sts': 1,
        'cmpl_by': adminId,
        'ts_cmpl': DateTime.now().toIso8601String(),
      };
      if (commission != null) data['com_val'] = commission;
      if (note != null) data['com_note'] = note;
      await SupabaseService()
          .client
          .from(DbTables.deals)
          .update(data)
          .eq('id', dealId);
      
      // تحديث إحصائيات الطرفين (عدد الصفقات)
      await BusinessService().updateUserStat(sellUid, 'dl');
      await BusinessService().updateUserStat(buyUid, 'dl');
      
      notifyListeners();
      return true;
    } catch (e) {return false;
    }
  }

  // ═══════════════════════════════════════
  // 5) المدفوعات (إدارة)
  // ═══════════════════════════════════════
  Future<List<PaymentModel>> getAllPayments({int? status}) async {
    try {
      var q = SupabaseService().client.from(DbTables.payments).select();
      if (status != null) q = q.eq('sts', status);
      final response = await q.order('ts_crt', ascending: false);
      return (response as List)
          .map((d) =>
              PaymentModel.fromSupabase(Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {return [];
    }
  }

  Future<bool> approvePayment(String paymentId, String adminId) async {
    try {
      final res = await SupabaseService().client.rpc(
        DbFunctions.approvePaymentFinal,
        params: {
          'p_payment_id': paymentId,
          'p_admin_id': adminId,
        },
      );

      if (res['success'] == true) {
        notifyListeners();
        return true;
      }return false;
    } catch (e) {return false;
    }
  }

  Future<bool> rejectPayment(String paymentId, String adminId) async {
    try {
      await SupabaseService().client.from(DbTables.payments).update({
        'sts': 2,
        'appr_by': adminId,
      }).eq('id', paymentId);
      notifyListeners();
      return true;
    } catch (e) {return false;
    }
  }

  // ═══════════════════════════════════════
  // 6) التبليغات (إدارة)
  // ═══════════════════════════════════════
  Future<List<ReportModel>> getAllReports({int? status}) async {
    try {
      var q = SupabaseService().client.from(DbTables.reports).select();
      if (status != null) q = q.eq('sts', status);
      final response = await q.order('ts_crt', ascending: false);
      return (response as List)
          .map((d) =>
              ReportModel.fromSupabase(Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {return [];
    }
  }

  /// اتخاذ إجراء على تبليغ
  /// action: 0=لا إجراء, 1=تحذير, 2=تجميد, 3=حظر
  Future<bool> handleReport(String reportId, int action, String adminId,
      {String note = '', int duration = 0}) async {
    try {
      await SupabaseService().client.from(DbTables.reports).update({
        'sts': 1, // تمت المعالجة
        'act': action,
        'act_dur': duration,
        'note': note,
        'act_by': adminId,
      }).eq('id', reportId);
      notifyListeners();
      return true;
    } catch (e) {return false;
    }
  }

  // ═══════════════════════════════════════
  // 7) الإحصائيات الشاملة
  // ═══════════════════════════════════════
  Future<Map<String, dynamic>> getStats() async {
    try {
      final offers = await SupabaseService()
          .client
          .from(DbTables.offers)
          .select('id, sts')
          .eq('i_del', 0);
      final users = await SupabaseService()
          .client
          .from(DbTables.users)
          .select('id, sts, role')
          .eq('i_del', 0);
      final deals = await SupabaseService()
          .client
          .from(DbTables.deals)
          .select('id, sts, com_val')
          .eq('i_del', 0);
      final appts = await SupabaseService()
          .client
          .from(DbTables.appointments)
          .select('id, sts');

      final offersList = offers as List;
      final usersList = users as List;
      final dealsList = deals as List;
      final apptsList = appts as List;

      return {
        'totalOffers': offersList.length,
        'pendingOffers': offersList.where((o) => (o['sts'] ?? 0) == 0).length,
        'publishedOffers': offersList.where((o) => (o['sts'] ?? 0) == 2).length,
        'totalUsers': usersList.length,
        'activeUsers': usersList.where((u) => (u['sts'] ?? 0) == 0).length,
        'bannedUsers': usersList.where((u) => (u['sts'] ?? 0) == 2).length,
        'brokers': usersList.where((u) => (u['role'] ?? 0) == 1).length,
        'totalDeals': dealsList.length,
        'completedDeals': dealsList.where((d) => (d['sts'] ?? 0) == 1).length,
        'totalCommission': dealsList
            .where((d) => (d['sts'] ?? 0) == 1)
            .fold<double>(
                0, (s, d) => s + (((d['com_val'] ?? 0) as num).toDouble())),
        'totalAppointments': apptsList.length,
        'completedAppointments':
            apptsList.where((a) => (a['sts'] ?? 0) == 2).length,
      };
    } catch (e) {return {};
    }
  }

  /// عدّاد سريع للعناصر التي تحتاج إجراء (للوحة الرئيسية)
  Future<Map<String, int>> getActionCounts() async {
    try {
      final pendingOffers = await SupabaseService()
          .client
          .from(DbTables.offers)
          .select('id')
          .eq('sts', 0)
          .eq('i_del', 0);
      final pendingPayments = await SupabaseService()
          .client
          .from(DbTables.payments)
          .select('id')
          .eq('sts', 0);
      final openReports = await SupabaseService()
          .client
          .from(DbTables.reports)
          .select('id')
          .eq('sts', 0);
      // 🛡️ طلبات التوثيق قيد المراجعة (vrf = 1)
      // مرجع: docs/LOGIC_SPEC.md §2.1
      final pendingVerifications = await SupabaseService()
          .client
          .from(DbTables.users)
          .select('id')
          .eq('vrf', 1)
          .eq('i_del', 0);
      return {
        'pendingOffers': (pendingOffers as List).length,
        'pendingPayments': (pendingPayments as List).length,
        'openReports': (openReports as List).length,
        'pendingVerifications': (pendingVerifications as List).length,
      };
    } catch (e) {return {};
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 🛡️ إدارة طلبات التوثيق (Verification Management)
  // مرجع: docs/LOGIC_SPEC.md §2.1
  // ═══════════════════════════════════════════════════════════════

  /// جلب المستخدمين الذين قدّموا طلب توثيق (vrf=1) لمراجعتهم.
  Future<List<Map<String, dynamic>>> getPendingVerifications() async {
    try {
      final res = await SupabaseService()
          .client
          .from(DbTables.users)
          .select()
          .eq('vrf', 1)
          .eq('i_del', 0)
          .order('ts_upd', ascending: true); // الأقدم أولاً (FIFO)
      return (res as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    } catch (e) {return [];
    }
  }

  /// اعتماد توثيق مستخدم: vrf 1 → 2 (موثق رسمياً).
  /// 🔒 Phase 8: يستدعي RPC admin_approve_verification الذي يفحص role>=2
  /// ويرسل الإشعار تلقائياً (لا client-side INSERT في notifications).
  Future<bool> approveVerification(String userId) async {
    try {
      await SupabaseService().client.rpc(
        'admin_approve_verification',
        params: {'p_target_uid': userId},
      );
      return true;
    } catch (e) {return false;
    }
  }

  /// رفض توثيق مستخدم: vrf 1 → 0 (يحتاج إعادة رفع).
  /// 🔒 Phase 8: عبر RPC admin_reject_verification — السبب يُحفظ في الإشعار.
  Future<bool> rejectVerification(String userId, {String reason = ''}) async {
    try {
      await SupabaseService().client.rpc(
        'admin_reject_verification',
        params: {'p_target_uid': userId, 'p_reason': reason},
      );
      return true;
    } catch (e) {return false;
    }
  }
}
