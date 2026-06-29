import '../../core/network/supabase_service.dart';
import '../../core/utils/error_utils.dart';
import '../../models/deal_model.dart';
import '../auth_service.dart';

/// خدمة إدارة الصفقات من طرف الإدارة.
class DealsAdminService {
  String? _lastError;
  String? get lastError => _lastError;

  void clearError() => _lastError = null;

  void _setError(Object? error) {
    _lastError = ErrorUtils.arabicMessage(error);
  }

  Future<List<DealModel>> getAllDeals(String adminUid) async {
    try {
      final token = await AuthService().getStaffSessionToken();
      final response = await SupabaseService().invokeFunction(
        'admin-deals',
        body: {
          'action': 'list',
          'admin_uid': adminUid,
          'staff_session_token': token,
        },
      );

      final data = response.data;
      if (data == null || data['success'] != true) {
        _setError(data?['error'] ?? 'حدث خطأ غير معروف');
        return [];
      }

      clearError();
      return (data['deals'] as List)
          .map((d) =>
              DealModel.fromSupabase(Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {
      _setError(e);
      return [];
    }
  }

  Future<bool> createDeal(String adminUid, DealModel deal) async {
    try {
      final token = await AuthService().getStaffSessionToken();
      final response = await SupabaseService().invokeFunction(
        'admin-deals',
        body: {
          'action': 'create',
          'admin_uid': adminUid,
          'staff_session_token': token,
          'deal': deal.toMap(),
        },
      );

      final data = response.data;
      if (data == null || data['success'] != true) {
        _setError(data?['error'] ?? 'حدث خطأ غير معروف');
        return false;
      }

      clearError();
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  Future<bool> completeDeal(
    String dealId,
    String adminId, {
    double? commission,
    String? note,
  }) async {
    try {
      final token = await AuthService().getStaffSessionToken();
      final response = await SupabaseService().invokeFunction(
        'admin-deals',
        body: {
          'action': 'complete',
          'admin_uid': adminId,
          'staff_session_token': token,
          'deal_id': dealId,
          'commission': commission,
          'note': note,
        },
      );

      final data = response.data;
      if (data == null || data['success'] != true) {
        _setError(data?['error'] ?? 'حدث خطأ غير معروف');
        return false;
      }

      clearError();
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }
}
