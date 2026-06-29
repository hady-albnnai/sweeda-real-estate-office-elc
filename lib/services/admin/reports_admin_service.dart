import '../../core/network/supabase_service.dart';
import '../../core/utils/error_utils.dart';
import '../../models/report_model.dart';
import '../auth_service.dart';

/// خدمة إدارة التبليغات للإدارة.
class ReportsAdminService {
  String? _lastError;
  String? get lastError => _lastError;

  void clearError() => _lastError = null;

  void _setError(Object? error) {
    _lastError = ErrorUtils.arabicMessage(error);
  }

  Future<List<ReportModel>> getAllReports(String adminUid, {int? status}) async {
    try {
      final token = await AuthService().getStaffSessionToken();
      final response = await SupabaseService().invokeFunction(
        'admin-reports',
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

      var list = (data['reports'] as List)
          .map((d) => ReportModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
          
      if (status != null) {
        list = list.where((r) => r.sts == status).toList();
      }
      
      clearError();
      return list;
    } catch (e) {
      _setError(e);
      return [];
    }
  }

  /// اتخاذ إجراء على تبليغ.
  /// action: 0=لا إجراء, 1=تحذير, 2=تجميد, 3=حظر
  Future<bool> handleReport(
    String reportId,
    int action,
    String adminId, {
    String note = '',
    int duration = 0,
  }) async {
    try {
      final token = await AuthService().getStaffSessionToken();
      final response = await SupabaseService().invokeFunction(
        'admin-reports',
        body: {
          'action': 'handle',
          'admin_uid': adminId,
          'staff_session_token': token,
          'report_id': reportId,
          'report_action': action,
          'note': note,
          'duration': duration,
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
