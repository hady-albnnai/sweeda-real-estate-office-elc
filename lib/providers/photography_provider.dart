import 'package:flutter/foundation.dart';
import '../core/constants/db_constants.dart';
import '../core/network/supabase_service.dart';
import '../models/offer_model.dart';
import '../models/photography_task_model.dart';
import '../services/auth_service.dart';

class PhotographyProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<List<PhotographyTaskModel>> getAllTasks({int? status}) async {
    try {
      var query = SupabaseService().client
          .from(DbTables.photographyTasks)
          .select();
      if (status != null) query = query.eq('sts', status);
      final response = await query.order('ts_crt', ascending: false);
      return (response as List)
          .map((row) => PhotographyTaskModel.fromSupabase(
                Map<String, dynamic>.from(row),
                row['id'] as String,
              ))
          .toList();
    } catch (e) {
      _error = e.toString();
      return [];
    }
  }

  Future<List<PhotographyTaskModel>> getPhotographerTasks(String photographerId) async {
    try {
      final token = await AuthService().getStaffSessionToken();
      final res = await SupabaseService().client.functions.invoke(
        'photographer-tasks',
        body: {
          'action': 'list',
          'user_uid': photographerId,
          'staff_session_token': token,
        },
      );
      final data = res.data;
      if (data == null || data['success'] != true) {
        _error = data?['error'] ?? 'Unknown error';
        return [];
      }
      return (data['tasks'] as List)
          .map((row) => PhotographyTaskModel.fromSupabase(
                Map<String, dynamic>.from(row),
                row['id'] as String,
              ))
          .toList();
    } catch (e) {
      _error = e.toString();
      return [];
    }
  }

  Future<bool> startTask(String photographerUid, String taskId) async {
    try {
      final token = await AuthService().getStaffSessionToken();
      final res = await SupabaseService().client.functions.invoke(
        'photographer-tasks',
        body: {
          'action': 'start',
          'user_uid': photographerUid,
          'staff_session_token': token,
          'task_id': taskId,
        },
      );
      final data = res.data;
      if (data != null && data['success'] == true) {
        notifyListeners();
        return true;
      }
      _error = data?['error'] ?? 'Unknown error';
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<bool> createTask({
    required OfferModel offer,
    required String photographerId,
    required String requestedBy,
    String notes = '',
    DateTime? scheduledAt,
  }) async {
    _setLoading(true);
    try {
      final token = await AuthService().getStaffSessionToken();
      final res = await SupabaseService().client.functions.invoke(
        'admin-photography',
        body: {
          'action': 'create',
          'admin_uid': requestedBy,
          'staff_session_token': token,
          'offer_id': offer.id,
          'photographer_id': photographerId,
          'notes': notes,
          'ts_scheduled': scheduledAt?.toIso8601String(),
        },
      );
      final data = res.data;
      _setLoading(false);
      
      if (data != null && data['success'] == true) {
        return true;
      }
      _error = data?['error'] ?? 'Unknown error';
      return false;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateStatus(String adminUid, String taskId, int status, {String officeNote = ''}) async {
    try {
      final token = await AuthService().getStaffSessionToken();
      final res = await SupabaseService().client.functions.invoke(
        'admin-photography',
        body: {
          'action': 'update_status',
          'admin_uid': adminUid,
          'staff_session_token': token,
          'task_id': taskId,
          'status': status,
          'office_note': officeNote,
        },
      );
      final data = res.data;
      if (data != null && data['success'] == true) {
        notifyListeners();
        return true;
      }
      _error = data?['error'] ?? 'Unknown error';
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<bool> submitTask({
    required String photographerUid,
    required String taskId,
    required List<String> media,
    String photographerNote = '',
  }) async {
    try {
      final token = await AuthService().getStaffSessionToken();
      final res = await SupabaseService().client.functions.invoke(
        'photographer-tasks',
        body: {
          'action': 'submit',
          'user_uid': photographerUid,
          'staff_session_token': token,
          'task_id': taskId,
          'media': media,
          'photographer_note': photographerNote,
        },
      );
      final data = res.data;
      if (data != null && data['success'] == true) {
        notifyListeners();
        return true;
      }
      _error = data?['error'] ?? 'Unknown error';
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<bool> attachMediaToOffer(String adminUid, PhotographyTaskModel task) async {
    if (task.media.isEmpty) return false;
    try {
      final token = await AuthService().getStaffSessionToken();
      final res = await SupabaseService().client.functions.invoke(
        'admin-photography',
        body: {
          'action': 'attach_media',
          'admin_uid': adminUid,
          'staff_session_token': token,
          'task_id': task.id,
        },
      );
      final data = res.data;
      if (data != null && data['success'] == true) {
        return true;
      }
      _error = data?['error'] ?? 'Unknown error';
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }
}
