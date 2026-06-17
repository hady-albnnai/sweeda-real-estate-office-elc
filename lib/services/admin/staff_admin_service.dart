import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/supabase_service.dart';
import '../../core/utils/error_utils.dart';
import '../../models/user_model.dart';

/// خدمة إدارة الموظفين والعمليات الإدارية الحساسة.
///
/// هذه الخدمة تفصل منطق Edge Functions/RPCs عن AdminProvider، وتضمن إرسال
/// staff_session_token مع العمليات الحساسة بعد إصلاح P1/P2.
class StaffAdminService {
  String? _lastError;
  String? get lastError => _lastError;

  void clearError() => _lastError = null;

  void _setError(Object? error) {
    _lastError = ErrorUtils.arabicMessage(error);
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  Future<Map<String, dynamic>> _invokeStaffFunction(
    String name,
    Map<String, dynamic> body,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionToken = prefs.getString('staff_session_token');
      if (sessionToken != null && sessionToken.isNotEmpty) {
        body['staff_session_token'] = sessionToken;
      }

      final res = await SupabaseService().client.functions.invoke(name, body: body);
      final data = _asMap(res.data);
      if (data == null) {
        _setError('EMPTY_RESPONSE');
        return {'success': false, 'error': 'EMPTY_RESPONSE'};
      }

      if (data['success'] == true) {
        clearError();
      } else {
        _setError(data['error'] ?? 'UNKNOWN_ERROR');
      }
      return data;
    } catch (e) {
      _setError(e);
      return {'success': false, 'error': ErrorUtils.normalize(e)};
    }
  }

  Future<List<UserModel>> getAllStaffUsers(String adminUid) async {
    try {
      final response = await SupabaseService().client.rpc(
        'get_all_staff_users',
        params: {'p_admin_uid': adminUid},
      );
      clearError();
      return (response as List)
          .map((d) => UserModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {
      _setError(e);
      return [];
    }
  }

  Future<Map<String, dynamic>> createStaffUser({
    required String adminUid,
    required String fullName,
    required String phone,
    String email = '',
    String username = '',
    required int role,
    String address = '',
    String sid = '',
    String img = '',
    String idImageBase64 = '',
    String idImageContentType = 'image/jpeg',
  }) {
    return _invokeStaffFunction('create-user', {
      'admin_uid': adminUid,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'username': username,
      'role': role,
      'address': address,
      'sid': sid,
      'img': img,
      'id_image_base64': idImageBase64,
      'id_image_content_type': idImageContentType,
    });
  }

  Future<bool> updateUserRole(String adminUid, String uid, int newRole) async {
    final data = await _invokeStaffFunction('update-user-role', {
      'admin_uid': adminUid,
      'user_id': uid,
      'role': newRole,
    });
    return data['success'] == true;
  }

  Future<bool> setUserStatus(
    String adminUid,
    String uid,
    int status, {
    String reason = '',
  }) async {
    final data = await _invokeStaffFunction('toggle-user-status', {
      'admin_uid': adminUid,
      'user_id': uid,
      'status': status,
      'reason': reason,
    });
    return data['success'] == true;
  }

  Future<bool> updateUserPermissions(
    String adminUid,
    String uid,
    List<String> permissions,
  ) async {
    final data = await _invokeStaffFunction('update-user-permissions', {
      'admin_uid': adminUid,
      'user_id': uid,
      'permissions': permissions,
    });
    return data['success'] == true;
  }

  Future<Map<String, dynamic>> resetStaffPassword({
    required String adminUid,
    required String targetUid,
  }) {
    return _invokeStaffFunction('reset-user-password', {
      'admin_uid': adminUid,
      'user_id': targetUid,
    });
  }

  Future<bool> deleteStaffUser(String adminUid, String targetUid) async {
    final data = await _invokeStaffFunction('delete-user', {
      'admin_uid': adminUid,
      'user_id': targetUid,
    });
    return data['success'] == true;
  }

  Future<Map<String, dynamic>> getStaffStatsInternal(String userUid) async {
    try {
      final response = await SupabaseService().client.rpc(
        'get_staff_stats_internal',
        params: {'p_user_uid': userUid},
      );
      clearError();
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      _setError(e);
      return {};
    }
  }
}
