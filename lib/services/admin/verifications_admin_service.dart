import '../../core/constants/db_constants.dart';
import '../../core/network/supabase_service.dart';
import '../../core/utils/error_utils.dart';

/// خدمة مراجعة طلبات التوثيق من طرف الإدارة.
class VerificationsAdminService {
  String? _lastError;
  String? get lastError => _lastError;

  void clearError() => _lastError = null;

  void _setError(Object? error) {
    _lastError = ErrorUtils.arabicMessage(error);
  }

  Future<List<Map<String, dynamic>>> getPendingVerifications() async {
    try {
      final res = await SupabaseService()
          .client
          .from(DbTables.users)
          .select()
          .eq('vrf', 1)
          .eq('i_del', 0)
          .order('ts_upd', ascending: true);
      clearError();
      return (res as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    } catch (e) {
      _setError(e);
      return [];
    }
  }

  Future<bool> approveVerification(String adminUid, String userId) async {
    try {
      await SupabaseService().client.rpc(
        'admin_approve_verification_by_admin',
        params: {'p_admin_uid': adminUid, 'p_target_uid': userId},
      );
      clearError();
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  Future<bool> rejectVerification(
    String adminUid,
    String userId, {
    String reason = '',
  }) async {
    try {
      await SupabaseService().client.rpc(
        'admin_reject_verification_by_admin',
        params: {
          'p_admin_uid': adminUid,
          'p_target_uid': userId,
          'p_reason': reason,
        },
      );
      clearError();
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }
}
