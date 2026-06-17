import 'package:flutter/foundation.dart';
import '../core/constants/db_constants.dart';
import '../core/network/supabase_service.dart';
import '../models/offer_model.dart';
import '../models/photography_task_model.dart';

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
      final response = await SupabaseService().client.rpc(
        'get_photographer_tasks_internal',
        params: {'p_photographer_uid': photographerId},
      );
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

  Future<bool> startTask(String photographerUid, String taskId) async {
    try {
      await SupabaseService().client.rpc(
        'start_photography_task_internal',
        params: {
          'p_photographer_uid': photographerUid,
          'p_task_id': taskId,
        },
      );
      notifyListeners();
      return true;
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
      await SupabaseService().client.rpc(
        'create_photography_task_internal',
        params: {
          'p_admin_uid': requestedBy,
          'p_offer_id': offer.id,
          'p_photographer_id': photographerId,
          'p_notes': notes,
          'p_ts_scheduled': scheduledAt?.toIso8601String(),
        },
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateStatus(String adminUid, String taskId, int status, {String officeNote = ''}) async {
    try {
      await SupabaseService().client.rpc(
        'update_photography_task_status_internal',
        params: {
          'p_admin_uid': adminUid,
          'p_task_id': taskId,
          'p_status': status,
          'p_office_note': officeNote,
        },
      );
      notifyListeners();
      return true;
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
      await SupabaseService().client.rpc(
        'submit_photography_task_internal',
        params: {
          'p_photographer_uid': photographerUid,
          'p_task_id': taskId,
          'p_media': media,
          'p_photographer_note': photographerNote,
        },
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<bool> attachMediaToOffer(String adminUid, PhotographyTaskModel task) async {
    if (task.media.isEmpty) return false;
    try {
      await SupabaseService().client.rpc(
        'attach_photography_media_to_offer_internal',
        params: {
          'p_admin_uid': adminUid,
          'p_task_id': task.id,
        },
      );
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }
}
