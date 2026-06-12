import 'package:flutter/foundation.dart';
import '../models/executor_task_model.dart';
import '../core/network/supabase_service.dart';

/// Provider مهام المنفذ الميداني (المشرف)
class ExecutorProvider with ChangeNotifier {

  // ═══════════════════════════════════════
  // مهام المنفذ
  // ═══════════════════════════════════════

  Future<List<ExecutorTaskModel>> getMyTasks(String userId) async {
    try {
      final res = await SupabaseService().client.rpc(
        'get_my_tasks',
        params: {'p_user_uid': userId},
      );
      return _parseList(res);
    } catch (e) {
      return [];
    }
  }

  Future<List<ExecutorTaskModel>> getPostponedTasks(String userId) async {
    try {
      final res = await SupabaseService().client.rpc(
        'get_postponed_tasks',
        params: {'p_user_uid': userId},
      );
      return _parseList(res);
    } catch (e) {
      return [];
    }
  }

  Future<List<ExecutorTaskModel>> getCompletedTasks(String userId) async {
    try {
      final res = await SupabaseService().client.rpc(
        'get_completed_tasks',
        params: {'p_user_uid': userId},
      );
      return _parseList(res);
    } catch (e) {
      return [];
    }
  }

  // ═══════════════════════════════════════
  // إجراءات المنفذ
  // ═══════════════════════════════════════

  /// تأجيل مهمة
  Future<bool> postponeTask(String userId, String appointmentId,
      DateTime newDate, String notes) async {
    try {
      await SupabaseService().client.rpc('update_task_outcome', params: {
        'p_user_uid': userId,
        'p_appointment_id': appointmentId,
        'p_outcome': 'postpone',
        'p_notes': notes,
        'p_new_date': newDate.toIso8601String(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// رفض مهمة
  Future<bool> rejectTask(String userId, String appointmentId,
      String reason, String notes) async {
    try {
      await SupabaseService().client.rpc('update_task_outcome', params: {
        'p_user_uid': userId,
        'p_appointment_id': appointmentId,
        'p_outcome': 'reject',
        'p_notes': notes,
        'p_rejection_reason': reason,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// طلب إتمام المعاملة
  Future<bool> requestCompletion(
      String userId, String appointmentId, String notes) async {
    try {
      await SupabaseService().client.rpc(
        'request_completion_by_appointment',
        params: {
          'p_user_uid': userId,
          'p_appointment_id': appointmentId,
          'p_notes': notes,
        },
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // ═══════════════════════════════════════
  // طلبات الإتمام المعلقة (للمنفذ)
  // ═══════════════════════════════════════

  Future<List<Map<String, dynamic>>> getPendingRequests(String userId) async {
    try {
      final res = await SupabaseService().client.rpc(
        'get_all_pending_completion_requests',
        params: {'p_admin_uid': userId},
      );
      if (res == null) return [];
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      return [];
    }
  }

  // ═══════════════════════════════════════
  // إجراءات المكتب
  // ═══════════════════════════════════════

  /// معالجة طلب إتمام (موافقة / رفض)
  Future<bool> processCompletionRequest(String adminUid, String requestId,
      String decision, String officeNotes) async {
    try {
      await SupabaseService().client.rpc('process_completion_request', params: {
        'p_admin_uid': adminUid,
        'p_request_id': requestId,
        'p_decision': decision,
        'p_office_notes': officeNotes,
      });
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  List<ExecutorTaskModel> _parseList(dynamic res) {
    if (res == null) return [];
    return (res as List)
        .map((d) => ExecutorTaskModel.fromMap(Map<String, dynamic>.from(d)))
        .toList();
  }
}
