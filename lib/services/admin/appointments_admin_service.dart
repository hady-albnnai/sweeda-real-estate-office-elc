import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/supabase_service.dart';
import '../../core/utils/error_utils.dart';
import '../../models/appointment_model.dart';
import '../../models/request_model.dart';
import '../../services/auth_service.dart';

/// خدمة إدارة الطلبات والمواعيد من طرف الإدارة.
class AppointmentsAdminService {
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

  Future<Map<String, dynamic>> _invokeAdminAppointments(
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
      final res = await SupabaseService().client.functions.invoke('admin-appointments', body: body);
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

  Future<List<RequestModel>> getAllRequests(String adminUid) async {
    try {
      final token = await AuthService().getStaffSessionToken();
      final response = await SupabaseService().client.functions.invoke(
        'admin-dashboard',
        body: {
          'action': 'admin_requests',
          'admin_uid': adminUid,
          'staff_session_token': token,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception('Error fetching requests');
      clearError();
      return (data['requests'] as List)
          .map((d) => RequestModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {
      _setError(e);
      return [];
    }
  }

  Future<bool> closeRequest({
    required String adminUid,
    required String requestId,
    required int status,
    String reason = 'closed_by_admin',
    String note = '',
  }) async {
    try {
      final token = await AuthService().getStaffSessionToken();
      final response = await SupabaseService().client.functions.invoke(
        'admin-dashboard',
        body: {
          'action': 'close_request',
          'admin_uid': adminUid,
          'staff_session_token': token,
          'request_id': requestId,
          'status': status,
          'reason': reason,
          'note': note,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) {
        _setError(data is Map ? data['error'] : 'CLOSE_REQUEST_FAILED');
        return false;
      }
      clearError();
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  Future<List<AppointmentModel>> getAllAppointments(String adminUid) async {
    final data = await _invokeAdminAppointments('list', {'admin_uid': adminUid});
    if (data['success'] != true || data['appointments'] is! List) return [];
    return (data['appointments'] as List)
        .map((d) => AppointmentModel.fromSupabase(
            Map<String, dynamic>.from(d as Map), d['id'] as String))
        .toList();
  }

  Future<bool> updateAppointmentStatus(
    String adminUid,
    String apptId,
    int status, {
    String adminNote = '',
  }) async {
    final data = await _invokeAdminAppointments('update_status', {
      'admin_uid': adminUid,
      'appointment_id': apptId,
      'status': status,
      'admin_note': adminNote,
    });
    return data['success'] == true;
  }

  Future<bool> forceAppointment(String apptId, String adminId) async {
    final data = await _invokeAdminAppointments('force', {
      'admin_uid': adminId,
      'appointment_id': apptId,
    });
    return data['success'] == true;
  }
}