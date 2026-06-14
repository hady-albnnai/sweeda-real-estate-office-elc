import '../../core/constants/db_constants.dart';
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
      var q = SupabaseService().client
          .from(DbTables.users)
          .select()
          .eq('i_del', 0);
      if (search != null && search.isNotEmpty) {
        q = q.or('nm.ilike.%$search%,ph.ilike.%$search%');
      }
      final response = await q.order('ts_crt', ascending: false);
      clearError();
      return (response as List)
          .map((d) =>
              UserModel.fromSupabase(Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {
      _setError(e);
      return [];
    }
  }
}
