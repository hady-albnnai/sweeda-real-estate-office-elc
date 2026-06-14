import 'package:flutter/foundation.dart';
import '../models/offer_model.dart';
import '../models/user_model.dart';
import '../models/appointment_model.dart';
import '../models/deal_model.dart';
import '../models/payment_model.dart';
import '../models/report_model.dart';
import '../models/request_model.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';
import '../core/utils/error_utils.dart';
import '../services/admin/staff_admin_service.dart';
import '../services/admin/payments_admin_service.dart';
import '../services/admin/reports_admin_service.dart';

/// Provider لوحة الإدارة (role >= UserRole.minAdmin)
/// يجمع كل عمليات الإدارة: العروض، المستخدمون، المواعيد، الصفقات،
/// المدفوعات، التبليغات، الإحصائيات.
class AdminProvider with ChangeNotifier {
  final StaffAdminService _staffAdmin = StaffAdminService();
  final PaymentsAdminService _paymentsAdmin = PaymentsAdminService();
  final ReportsAdminService _reportsAdmin = ReportsAdminService();

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setError(Object? error) {
    _error = ErrorUtils.arabicMessage(error);
    notifyListeners();
  }

  void _clearErrorSilently() {
    _error = null;
  }

  void _syncServiceError(String? err) {
    if (err == null) {
      _clearErrorSilently();
    } else {
      _error = err;
    }
  }

  void _syncStaffError() => _syncServiceError(_staffAdmin.lastError);
  void _syncPaymentsError() => _syncServiceError(_paymentsAdmin.lastError);
  void _syncReportsError() => _syncServiceError(_reportsAdmin.lastError);

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  // ═══════════════════════════════════════
  // 1) العروض (مراجعة)
  // ═══════════════════════════════════════
  Future<List<OfferModel>> getPendingOffers(String adminUid) async {
    try {
      final response = await SupabaseService().client.rpc(
        'get_admin_pending_offers_internal',
        params: {'p_admin_uid': adminUid},
      );
      return (response as List)
          .map((d) => OfferModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> reviewOffer(String adminUid, String offerId, bool approve,
      {String reason = ''}) async {
    try {
      await SupabaseService().client.rpc(
        'admin_review_offer_internal',
        params: {
          'p_admin_uid': adminUid,
          'p_offer_id': offerId,
          'p_approve': approve,
          'p_reject_reason': reason,
        },
      );
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<OfferModel>> getOffersForMediaReview(String adminUid) async {
    try {
      final response = await SupabaseService().client.rpc(
        'get_admin_offers_internal',
        params: {
          'p_admin_uid': adminUid,
          'p_limit': 100,
        },
      );
      return (response as List)
          .map((d) => OfferModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {
      return [];
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

  Future<bool> updateUserRole(String adminUid, String uid, int newRole) async {
    final ok = await _staffAdmin.updateUserRole(adminUid, uid, newRole);
    _syncStaffError();
    if (ok) notifyListeners();
    return ok;
  }

  /// تغيير حالة المستخدم: 0=نشط, 1=مجمّد, 2=محظور
  Future<bool> setUserStatus(String adminUid, String uid, int status, {String reason = ''}) async {
    final ok = await _staffAdmin.setUserStatus(adminUid, uid, status, reason: reason);
    _syncStaffError();
    if (ok) notifyListeners();
    return ok;
  }

  Future<bool> banUser(String adminUid, String uid, String reason) => setUserStatus(adminUid, uid, 2, reason: reason);
  Future<bool> freezeUser(String adminUid, String uid, String reason) => setUserStatus(adminUid, uid, 1, reason: reason);
  Future<bool> activateUser(String adminUid, String uid) => setUserStatus(adminUid, uid, 0);

  Future<bool> softDeleteUser(String uid) async {
    // تم إغلاق soft_delete العام عن العميل. استخدم deleteStaffUser مع adminUid.
    return false;
  }


  Future<bool> updateUserPermissions(String adminUid, String uid, List<String> permissions) async {
    final ok = await _staffAdmin.updateUserPermissions(adminUid, uid, permissions);
    _syncStaffError();
    if (ok) notifyListeners();
    return ok;
  }

  // ═══════════════════════════════════════
  // 🆕 إدارة الموظفين (Employee Management)
  // ═══════════════════════════════════════
  Future<List<UserModel>> getAllStaffUsers(String adminUid) async {
    final users = await _staffAdmin.getAllStaffUsers(adminUid);
    _syncStaffError();
    return users;
  }

  Future<Map<String, dynamic>> createStaffUser({
    required String adminUid,
    required String fullName,
    required String phone,
    String email = '',
    String username = '',
    required int role,
  }) async {
    final data = await _staffAdmin.createStaffUser(
      adminUid: adminUid,
      fullName: fullName,
      phone: phone,
      email: email,
      username: username,
      role: role,
    );
    _syncStaffError();
    if (data['success'] == true) notifyListeners();
    return data;
  }

  /// تغيير دور الموظف عبر Edge Function فقط.
  Future<bool> changeUserRole(String adminUid, String targetUid, int newRole) async {
    final ok = await _staffAdmin.updateUserRole(adminUid, targetUid, newRole);
    _syncStaffError();
    if (ok) notifyListeners();
    return ok;
  }

  /// تفعيل/تجميد/حظر الموظف عبر Edge Function فقط.
  Future<bool> toggleUserStatus(
    String adminUid,
    String targetUid,
    int newStatus, {
    String reason = '',
  }) async {
    final ok = await _staffAdmin.setUserStatus(
      adminUid,
      targetUid,
      newStatus,
      reason: reason,
    );
    _syncStaffError();
    if (ok) notifyListeners();
    return ok;
  }

  Future<Map<String, dynamic>> resetStaffPassword({
    required String adminUid,
    required String targetUid,
  }) async {
    final data = await _staffAdmin.resetStaffPassword(
      adminUid: adminUid,
      targetUid: targetUid,
    );
    _syncStaffError();
    if (data['success'] == true) notifyListeners();
    return data;
  }

  /// حذف موظف (soft delete) عبر Edge Function فقط.
  Future<bool> deleteStaffUser(String adminUid, String targetUid) async {
    final ok = await _staffAdmin.deleteStaffUser(adminUid, targetUid);
    _syncStaffError();
    if (ok) notifyListeners();
    return ok;
  }

  Future<Map<String, dynamic>> getStaffStatsInternal(String userUid) async {
    final stats = await _staffAdmin.getStaffStatsInternal(userUid);
    _syncStaffError();
    return stats;
  }

  // ═══════════════════════════════════════
  // 3) المواعيد (إدارة)
  // ═══════════════════════════════════════
  Future<List<RequestModel>> getAllRequests(String adminUid) async {
    try {
      final response = await SupabaseService().client.rpc(
        'get_admin_requests_internal',
        params: {'p_admin_uid': adminUid},
      );
      return (response as List)
          .map((d) => RequestModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<AppointmentModel>> getAllAppointments(String adminUid) async {
    try {
      final response = await SupabaseService().client.rpc(
        'get_admin_appointments_internal',
        params: {'p_admin_uid': adminUid},
      );
      return (response as List)
          .map((d) => AppointmentModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> updateAppointmentStatus(String adminUid, String apptId, int status,
      {String adminNote = ''}) async {
    try {
      await SupabaseService().client.rpc(
        'admin_update_appointment_status_internal',
        params: {
          'p_admin_uid': adminUid,
          'p_appointment_id': apptId,
          'p_status': status,
          'p_admin_note': adminNote,
        },
      );
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// فرض موعد من قبل الإدارة
  Future<bool> forceAppointment(String apptId, String adminId) async {
    try {
      await SupabaseService().client.rpc(
        'admin_force_appointment_internal',
        params: {
          'p_admin_uid': adminId,
          'p_appointment_id': apptId,
        },
      );
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ═══════════════════════════════════════
  // 4) الصفقات (إدارة)
  // ═══════════════════════════════════════
  Future<List<DealModel>> getAllDeals(String adminUid) async {
    try {
      final response = await SupabaseService().client.rpc(
        'get_admin_deals_internal',
        params: {'p_admin_uid': adminUid},
      );
      return (response as List)
          .map((d) =>
              DealModel.fromSupabase(Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// إنشاء صفقة (استمارة المندوب)
  Future<bool> createDeal(String adminUid, DealModel deal) async {
    try {
      await SupabaseService().client.rpc(
        'create_deal_internal',
        params: {
          'p_admin_uid': adminUid,
          'p_deal': deal.toMap(),
        },
      );
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// إتمام صفقة (sts=1) + تسجيل العمولة
  Future<bool> completeDeal(String dealId, String adminId,
      {double? commission, String? note}) async {
    try {
      await SupabaseService().client.rpc(
        'complete_deal_internal',
        params: {
          'p_admin_uid': adminId,
          'p_deal_id': dealId,
          'p_commission': commission,
          'p_note': note,
        },
      );
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ═══════════════════════════════════════
  // 5) المدفوعات (إدارة)
  // ═══════════════════════════════════════
  Future<List<PaymentModel>> getAllPayments(String adminUid, {int? status}) async {
    final list = await _paymentsAdmin.getAllPayments(adminUid, status: status);
    _syncPaymentsError();
    return list;
  }

  Future<bool> approvePayment(String paymentId, String adminId) async {
    final ok = await _paymentsAdmin.approvePayment(paymentId, adminId);
    _syncPaymentsError();
    if (ok) notifyListeners();
    return ok;
  }

  Future<bool> rejectPayment(String paymentId, String adminId) async {
    final ok = await _paymentsAdmin.rejectPayment(paymentId, adminId);
    _syncPaymentsError();
    if (ok) notifyListeners();
    return ok;
  }

  // ═══════════════════════════════════════
  // 6) التبليغات (إدارة)
  // ═══════════════════════════════════════
  Future<List<ReportModel>> getAllReports(String adminUid, {int? status}) async {
    final list = await _reportsAdmin.getAllReports(adminUid, status: status);
    _syncReportsError();
    return list;
  }

  /// اتخاذ إجراء على تبليغ
  /// action: 0=لا إجراء, 1=تحذير, 2=تجميد, 3=حظر
  Future<bool> handleReport(String reportId, int action, String adminId,
      {String note = '', int duration = 0}) async {
    final ok = await _reportsAdmin.handleReport(
      reportId,
      action,
      adminId,
      note: note,
      duration: duration,
    );
    _syncReportsError();
    if (ok) notifyListeners();
    return ok;
  }

  // ═══════════════════════════════════════
  // 7) الإحصائيات الشاملة
  // ═══════════════════════════════════════
  Future<Map<String, dynamic>> getStats(String adminUid) async {
    try {
      final offers = await getOffersForMediaReview(adminUid);
      final users = await getAllUsers();
      final deals = await getAllDeals(adminUid);
      final appts = await getAllAppointments(adminUid);

      return {
        'totalOffers': offers.length,
        'pendingOffers': offers.where((o) => o.sts == 1).length,
        'publishedOffers': offers.where((o) => o.sts == 2).length,
        'totalUsers': users.length,
        'activeUsers': users.where((u) => u.sts == 0).length,
        'bannedUsers': users.where((u) => u.sts == 2).length,
        'brokers': users.where((u) => u.role == UserRole.broker).length,
        'totalDeals': deals.length,
        'completedDeals': deals.where((d) => d.sts == 1).length,
        'totalCommission': deals
            .where((d) => d.sts == 1)
            .fold<double>(0, (s, d) => s + d.comVal),
        'totalAppointments': appts.length,
        'completedAppointments': appts.where((a) => a.sts == 2).length,
      };
    } catch (e) {
      return {};
    }
  }

  /// عدّاد سريع للعناصر التي تحتاج إجراء (للوحة الرئيسية)
  Future<Map<String, int>> getActionCounts(String adminUid) async {
    try {
      final pendingOffers = await getPendingOffers(adminUid);
      final pendingPayments = await getAllPayments(adminUid, status: 0);
      final openReports = await getAllReports(adminUid, status: 0);
      final pendingVerifications = await SupabaseService()
          .client
          .from(DbTables.users)
          .select('id')
          .eq('vrf', 1)
          .eq('i_del', 0);
      return {
        'pendingOffers': pendingOffers.length,
        'pendingPayments': pendingPayments.length,
        'openReports': openReports.length,
        'pendingVerifications': (pendingVerifications as List).length,
      };
    } catch (e) {
      return {};
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
  /// يستخدم نسخة متوافقة مع وضع التطوير الحالي، وتربط `p_admin_uid`
  /// بـ `auth.uid()` متى كانت الجلسة الحقيقية متاحة.
  Future<bool> approveVerification(String adminUid, String userId) async {
    try {
      await SupabaseService().client.rpc(
        'admin_approve_verification_by_admin',
        params: {'p_admin_uid': adminUid, 'p_target_uid': userId},
      );
      return true;
    } catch (e) {return false;
    }
  }

  /// رفض توثيق مستخدم: vrf 1 → 0 (يحتاج إعادة رفع).
  Future<bool> rejectVerification(String adminUid, String userId,
      {String reason = ''}) async {
    try {
      await SupabaseService().client.rpc(
        'admin_reject_verification_by_admin',
        params: {
          'p_admin_uid': adminUid,
          'p_target_uid': userId,
          'p_reason': reason,
        },
      );
      return true;
    } catch (e) {return false;
    }
  }
}
