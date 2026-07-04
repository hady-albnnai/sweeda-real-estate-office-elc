import 'package:flutter/material.dart';
import '../models/lawyer_profile_model.dart';
import '../models/expediting_task_model.dart';
import '../core/network/supabase_service.dart';

class LegalProvider with ChangeNotifier {
  List<LawyerProfileModel> _activeLawyers = [];
  bool _isLoading = false;
  String? _error;

  List<LawyerProfileModel> get activeLawyers => _activeLawyers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchActiveLawyers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await SupabaseService().invokeFunction('legal-actions', body: {'action': 'get_active_lawyers'});
      final data = res.data as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        final list = data['lawyers'] as List? ?? [];
        _activeLawyers = list.map((e) => LawyerProfileModel.fromMap(Map<String, dynamic>.from(e as Map))).toList();
      } else {
        _error = data?['error']?.toString() ?? 'فشل جلب المحامين';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> upsertLawyerProfile({
    required String targetUid,
    required String whatsappPhone,
    String officeAddress = '',
    String specialization = 'عقارات وسيارات',
    Map<String, dynamic> avl = const {},
  }) async {
    try {
      final res = await SupabaseService().invokeFunction('legal-actions', body: {
        'action': 'admin_upsert_lawyer',
        'target_uid': targetUid,
        'whatsapp_phone': whatsappPhone,
        'office_address': officeAddress,
        'specialization': specialization,
        'avl': avl,
      });
      final data = res.data as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        await fetchActiveLawyers();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateChecklistItem({
    required String taskId,
    required String itemKey,
    required int status,
    String inputValue = '',
    String attachmentUrl = '',
    String notes = '',
  }) async {
    try {
      final res = await SupabaseService().invokeFunction('legal-actions', body: {
        'action': 'update_checklist_item',
        'task_id': taskId,
        'item_key': itemKey,
        'status': status,
        'input_value': inputValue,
        'attachment_url': attachmentUrl,
        'notes': notes,
      });
      final data = res.data as Map<String, dynamic>?;
      return data != null && data['success'] == true;
    } catch (e) {
      return false;
    }
  }
}
