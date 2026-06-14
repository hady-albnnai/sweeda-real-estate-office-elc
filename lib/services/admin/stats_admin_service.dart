import '../../core/network/supabase_service.dart';
import '../../core/utils/error_utils.dart';

/// خدمة إحصائيات الإدارة والعدادات السريعة.
///
/// يستخدم RPC مجمعة لتجنب تحميل قوائم كبيرة لمجرد العد.
class StatsAdminService {
  String? _lastError;
  String? get lastError => _lastError;

  void clearError() => _lastError = null;

  void _setError(Object? error) {
    _lastError = ErrorUtils.arabicMessage(error);
  }

  Future<Map<String, dynamic>> getStats(String adminUid) async {
    try {
      final response = await SupabaseService().client.rpc(
        'get_admin_dashboard_stats',
        params: {'p_admin_uid': adminUid},
      );
      clearError();
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      _setError(e);
      return {};
    }
  }

  Future<Map<String, int>> getActionCounts(String adminUid) async {
    final stats = await getStats(adminUid);
    if (stats.isEmpty) return {};
    return {
      'pendingOffers': (stats['pendingOffers'] as num? ?? 0).toInt(),
      'pendingPayments': (stats['pendingPayments'] as num? ?? 0).toInt(),
      'openReports': (stats['openReports'] as num? ?? 0).toInt(),
      'pendingVerifications': (stats['pendingVerifications'] as num? ?? 0).toInt(),
    };
  }
}
