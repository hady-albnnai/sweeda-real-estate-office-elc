import '../../core/network/supabase_service.dart';
import '../../core/utils/error_utils.dart';
import '../../models/report_model.dart';

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
      final response = await SupabaseService().client.rpc(
        'get_admin_reports_internal',
        params: {'p_admin_uid': adminUid},
      );
      var list = (response as List)
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
      await SupabaseService().client.rpc(
        'admin_handle_report_internal',
        params: {
          'p_admin_uid': adminId,
          'p_report_id': reportId,
          'p_action': action,
          'p_note': note,
          'p_duration': duration,
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
