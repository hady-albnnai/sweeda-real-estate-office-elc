import '../../core/constants/db_constants.dart';
import '../../core/network/supabase_service.dart';
import '../../core/utils/error_utils.dart';
import '../../models/appointment_model.dart';
import '../../models/deal_model.dart';
import '../../models/offer_model.dart';
import '../../models/user_model.dart';

/// خدمة إحصائيات الإدارة والعدادات السريعة.
///
/// ملاحظة: هذه خطوة فصل معمارية أولى. مرحلة P5 ستستبدل العدّ عبر تحميل
/// القوائم بدوال RPC مجمعة أكثر كفاءة.
class StatsAdminService {
  String? _lastError;
  String? get lastError => _lastError;

  void clearError() => _lastError = null;

  void _setError(Object? error) {
    _lastError = ErrorUtils.arabicMessage(error);
  }

  Future<List<OfferModel>> _getAdminOffers(String adminUid) async {
    final response = await SupabaseService().client.rpc(
      'get_admin_offers_internal',
      params: {'p_admin_uid': adminUid, 'p_limit': 100},
    );
    return (response as List)
        .map((d) => OfferModel.fromSupabase(
            Map<String, dynamic>.from(d), d['id'] as String))
        .toList();
  }

  Future<List<UserModel>> _getAllUsers() async {
    final response = await SupabaseService()
        .client
        .from(DbTables.users)
        .select()
        .eq('i_del', 0)
        .order('ts_crt', ascending: false);
    return (response as List)
        .map((d) => UserModel.fromSupabase(
            Map<String, dynamic>.from(d), d['id'] as String))
        .toList();
  }

  Future<List<DealModel>> _getAllDeals(String adminUid) async {
    final response = await SupabaseService().client.rpc(
      'get_admin_deals_internal',
      params: {'p_admin_uid': adminUid},
    );
    return (response as List)
        .map((d) => DealModel.fromSupabase(
            Map<String, dynamic>.from(d), d['id'] as String))
        .toList();
  }

  Future<List<AppointmentModel>> _getAllAppointments(String adminUid) async {
    final response = await SupabaseService().client.rpc(
      'get_admin_appointments_internal',
      params: {'p_admin_uid': adminUid},
    );
    return (response as List)
        .map((d) => AppointmentModel.fromSupabase(
            Map<String, dynamic>.from(d), d['id'] as String))
        .toList();
  }

  Future<Map<String, dynamic>> getStats(String adminUid) async {
    try {
      final offers = await _getAdminOffers(adminUid);
      final users = await _getAllUsers();
      final deals = await _getAllDeals(adminUid);
      final appts = await _getAllAppointments(adminUid);

      clearError();
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
      _setError(e);
      return {};
    }
  }

  Future<Map<String, int>> getActionCounts(String adminUid) async {
    try {
      final pendingOffersResponse = await SupabaseService().client.rpc(
        'get_admin_pending_offers_internal',
        params: {'p_admin_uid': adminUid},
      );
      final pendingPayments = await SupabaseService().client.rpc(
        'get_admin_payments_internal',
        params: {'p_admin_uid': adminUid},
      );
      final openReports = await SupabaseService().client.rpc(
        'get_admin_reports_internal',
        params: {'p_admin_uid': adminUid},
      );
      final pendingVerifications = await SupabaseService()
          .client
          .from(DbTables.users)
          .select('id')
          .eq('vrf', 1)
          .eq('i_del', 0);

      clearError();
      return {
        'pendingOffers': (pendingOffersResponse as List).length,
        'pendingPayments': (pendingPayments as List)
            .where((p) => (p as Map)['sts'] == 0)
            .length,
        'openReports': (openReports as List)
            .where((r) => (r as Map)['sts'] == 0)
            .length,
        'pendingVerifications': (pendingVerifications as List).length,
      };
    } catch (e) {
      _setError(e);
      return {};
    }
  }
}
