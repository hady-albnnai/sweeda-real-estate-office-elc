import 'package:flutter/foundation.dart';
import '../models/executor_task_model.dart';
import '../core/network/supabase_service.dart';
import '../services/auth_service.dart';

/// Provider مهام المنفذ الميداني (المشرف)
class ExecutorProvider with ChangeNotifier {

  // ═══════════════════════════════════════
  // مهام المنفذ
  // ═══════════════════════════════════════

  Future<List<ExecutorTaskModel>> getMyTasks(String userId) async {
    try {
      final token = await AuthService().getStaffSessionToken();
      final res = await SupabaseService().client.functions.invoke(
        'executor-tasks',
        body: {
          'action': 'get_my_tasks',
          'user_uid': userId,
          'staff_session_token': token,
        },
      );
      final data = res.data;
      if (data == null || data['success'] != true) return [];
      return _parseList(data['tasks']);
    } catch (e) {
      return [];
    }
  }

  Future<List<ExecutorTaskModel>> getPostponedTasks(String userId) async {
    try {
      final token = await AuthService().getStaffSessionToken();
      final res = await SupabaseService().client.functions.invoke(
        'executor-tasks',
        body: {
          'action': 'get_postponed_tasks',
          'user_uid': userId,
          'staff_session_token': token,
        },
      );
      final data = res.data;
      if (data == null || data['success'] != true) return [];
      return _parseList(data['tasks']);
    } catch (e) {
      return [];
    }
  }

  Future<List<ExecutorTaskModel>> getCompletedTasks(String userId) async {
    try {
      final token = await AuthService().getStaffSessionToken();
      final res = await SupabaseService().client.functions.invoke(
        'executor-tasks',
        body: {
          'action': 'get_completed_tasks',
          'user_uid': userId,
          'staff_session_token': token,
        },
      );
      final data = res.data;
      if (data == null || data['success'] != true) return [];
      return _parseList(data['tasks']);
    } catch (e) {
      return [];
    }
  }

  Future<ExecutorTaskModel?> getTaskByAppointment(String userId, String appointmentId) async {
    try {
      final token = await AuthService().getStaffSessionToken();
      final res = await SupabaseService().client.functions.invoke(
        'executor-tasks',
        body: {
          'action': 'get_task_by_appointment',
          'user_uid': userId,
          'staff_session_token': token,
          'appointment_id': appointmentId,
        },
      );
      final data = res.data;
      if (data == null || data['success'] != true) return null;
      final list = _parseList(data['tasks']);
      return list.isEmpty ? null : list.first;
    } catch (e) {
      return null;
    }
  }

  // ═══════════════════════════════════════
  // إجراءات المنفذ
  // ═══════════════════════════════════════

  /// تأجيل مهمة
  Future<bool> postponeTask(String userId, String appointmentId,
      DateTime newDate, String notes) async {
    try {
      final token = await AuthService().getStaffSessionToken();
      final res = await SupabaseService().client.functions.invoke(
        'executor-tasks',
        body: {
          'action': 'update_task_outcome',
          'user_uid': userId,
          'staff_session_token': token,
          'appointment_id': appointmentId,
          'outcome': 'postpone',
          'notes': notes,
          'new_date': newDate.toIso8601String(),
        },
      );
      final data = res.data;
      return data != null && data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// رفض مهمة
  Future<bool> rejectTask(String userId, String appointmentId,
      String reason, String notes) async {
    try {
      final token = await AuthService().getStaffSessionToken();
      final res = await SupabaseService().client.functions.invoke(
        'executor-tasks',
        body: {
          'action': 'update_task_outcome',
          'user_uid': userId,
          'staff_session_token': token,
          'appointment_id': appointmentId,
          'outcome': 'reject',
          'notes': notes,
          'rejection_reason': reason,
        },
      );
      final data = res.data;
      return data != null && data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// طلب إتمام المعاملة
  Future<bool> requestCompletion(
      String userId, String appointmentId, String notes) async {
    try {
      final token = await AuthService().getStaffSessionToken();
      final res = await SupabaseService().client.functions.invoke(
        'executor-tasks',
        body: {
          'action': 'request_completion',
          'user_uid': userId,
          'staff_session_token': token,
          'appointment_id': appointmentId,
          'notes': notes,
        },
      );
      final data = res.data;
      return data != null && data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // ═══════════════════════════════════════
  // طلبات الإتمام المعلقة (للمنفذ)
  // ═══════════════════════════════════════

  Future<List<Map<String, dynamic>>> getMyCompletionRequests(String userId) async {
    try {
      final token = await AuthService().getStaffSessionToken();
      final res = await SupabaseService().client.functions.invoke(
        'executor-tasks',
        body: {
          'action': 'get_my_completion_requests',
          'user_uid': userId,
          'staff_session_token': token,
        },
      );
      final data = res.data;
      if (data == null || data['success'] != true) return [];
      return List<Map<String, dynamic>>.from(data['requests'] as List);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPendingRequests(String adminUid) async {
    try {
      final token = await AuthService().getStaffSessionToken();
      final res = await SupabaseService().client.functions.invoke(
        'executor-tasks',
        body: {
          'action': 'get_pending_requests',
          'user_uid': adminUid, // نرسل الـ ID كـ user_uid لأن الدالة تتوقع ذلك
          'staff_session_token': token,
        },
      );
      final data = res.data;
      if (data == null || data['success'] != true) return [];
      return List<Map<String, dynamic>>.from(data['requests'] as List);
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
      final token = await AuthService().getStaffSessionToken();
      final res = await SupabaseService().client.functions.invoke(
        'executor-tasks',
        body: {
          'action': 'process_completion_request',
          'user_uid': adminUid,
          'staff_session_token': token,
          'request_id': requestId,
          'decision': decision,
          'office_notes': officeNotes,
        },
      );
      final data = res.data;
      if (data != null && data['success'] == true) {
        notifyListeners();
        return true;
      }
      return false;
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
