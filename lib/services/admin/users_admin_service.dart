import '../../core/network/supabase_service.dart';
import '../../core/utils/error_utils.dart';
import '../../models/user_model.dart';

/// خدمة قراءة المستخدمين العامة للإدارة.
/// العمليات الحساسة على المستخدمين تبقى في StaffAdminService عبر Edge Functions.
class UsersAdminService {
  String? _lastError;
  String? get lastError => _lastError;

  void clearError() => _lastError = null;

  void _setError(Object? error) {
    _lastError = ErrorUtils.arabicMessage(error);
  }

  Future<List<UserModel>> getAllUsers({String? search}) async {
    try {
      final response = await SupabaseService().invokeFunction(
        'admin-dashboard',
        body: {
          'action': 'admin_users',
          'search': search ?? '',
        },
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : null;
      if (data == null || data['success'] != true || data['users'] is! List) {
        _setError(data?['error']?.toString() ?? 'FETCH_FAILED');
        return [];
      }
      clearError();
      return (data['users'] as List)
          .map((d) => UserModel.fromSupabase(
              Map<String, dynamic>.from(d as Map), d['id'] as String))
          .toList();
    } catch (e) {
      _setError(e);
      return [];
    }
  }
}
