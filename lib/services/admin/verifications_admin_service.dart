import 'package:shared_preferences/shared_preferences.dart';
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

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  Future<Map<String, dynamic>> _invokeAdminVerifications(
    String action,
    Map<String, dynamic> body,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionToken = prefs.getString('staff_session_token');
      if (sessionToken != null && sessionToken.isNotEmpty) {
        body['staff_session_token'] = sessionToken;
      }
      body['action'] = action;
      final res = await SupabaseService().invokeFunction('admin-verifications', body: body);
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

  Future<List<Map<String, dynamic>>> getPendingVerifications(String adminUid) async {
    final data = await _invokeAdminVerifications('list_pending', {'admin_uid': adminUid});
    if (data['success'] != true || data['users'] is! List) return [];
    return (data['users'] as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  Future<bool> approveVerification(String adminUid, String userId) async {
    final data = await _invokeAdminVerifications('approve', {
      'admin_uid': adminUid,
      'target_uid': userId,
    });
    return data['success'] == true;
  }

  Future<bool> rejectVerification(
    String adminUid,
    String userId, {
    String reason = '',
  }) async {
    final data = await _invokeAdminVerifications('reject', {
      'admin_uid': adminUid,
      'target_uid': userId,
      'reason': reason,
    });
    return data['success'] == true;
  }
}
