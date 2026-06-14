import '../../core/network/supabase_service.dart';
import '../../core/utils/error_utils.dart';
import '../../models/appointment_model.dart';
import '../../models/request_model.dart';

/// خدمة إدارة الطلبات والمواعيد من طرف الإدارة.
class AppointmentsAdminService {
  String? _lastError;
  String? get lastError => _lastError;

  void clearError() => _lastError = null;

  void _setError(Object? error) {
    _lastError = ErrorUtils.arabicMessage(error);
  }

  Future<List<RequestModel>> getAllRequests(String adminUid) async {
    try {
      final response = await SupabaseService().client.rpc(
        'get_admin_requests_internal',
        params: {'p_admin_uid': adminUid},
      );
      clearError();
      return (response as List)
          .map((d) => RequestModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {
      _setError(e);
      return [];
    }
  }

  Future<List<AppointmentModel>> getAllAppointments(String adminUid) async {
    try {
      final response = await SupabaseService().client.rpc(
        'get_admin_appointments_internal',
        params: {'p_admin_uid': adminUid},
      );
      clearError();
      return (response as List)
          .map((d) => AppointmentModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {
      _setError(e);
      return [];
    }
  }

  Future<bool> updateAppointmentStatus(
    String adminUid,
    String apptId,
    int status, {
    String adminNote = '',
  }) async {
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
      clearError();
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  Future<bool> forceAppointment(String apptId, String adminId) async {
    try {
      await SupabaseService().client.rpc(
        'admin_force_appointment_internal',
        params: {
          'p_admin_uid': adminId,
          'p_appointment_id': apptId,
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
