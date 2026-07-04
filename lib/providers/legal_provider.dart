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

  Map<String, dynamic>? _lawyerProfile;
  bool _profileSetupComplete = false;
  bool get profileSetupComplete => _profileSetupComplete;
  Map<String, dynamic>? get lawyerProfile => _lawyerProfile;

  List<Map<String, dynamic>> _availableExpediters = [];
  List<Map<String, dynamic>> get availableExpediters => _availableExpediters;
  List<ExpeditingTaskModel> _lawyerTasks = [];
  List<ExpeditingTaskModel> get lawyerTasks => _lawyerTasks;
  List<Map<String, dynamic>> _lawyerAppointments = [];
  List<Map<String, dynamic>> get lawyerAppointments => _lawyerAppointments;
  List<ExpeditingTaskModel> _expeditingTasks = [];
  List<ExpeditingTaskModel> get expeditingTasks => _expeditingTasks;

  Future<void> fetchActiveLawyers() async {
    _isLoading = true; _error = null; notifyListeners();
    try {
      final res = await SupabaseService().invokeFunction('legal-actions', body: {'action': 'get_active_lawyers'});
      final data = res.data as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        final list = data['lawyers'] as List? ?? [];
        _activeLawyers = list.map((e) => LawyerProfileModel.fromMap(Map<String, dynamic>.from(e as Map))).toList();
      } else { _error = data?['error']?.toString() ?? 'فشل'; }
    } catch (e) { _error = e.toString(); }
    finally { _isLoading = false; notifyListeners(); }
  }

  Future<bool> upsertLawyerProfile({required String targetUid, required String whatsappPhone, String officeAddress = '', String specialization = 'عقارات وسيارات', Map<String, dynamic> avl = const {}}) async {
    try {
      final res = await SupabaseService().invokeFunction('legal-actions', body: {
        'action': 'admin_upsert_lawyer', 'user_uid': targetUid, 'target_uid': targetUid,
        'whatsapp_phone': whatsappPhone, 'office_address': officeAddress,
        'specialization': specialization, 'avl': avl,
      });
      final data = res.data as Map<String, dynamic>?;
      if (data != null && data['success'] == true) { _profileSetupComplete = true; notifyListeners(); return true; }
      return false;
    } catch (e) { return false; }
  }

  /// تعود true فقط إذا وُجد ملف محامي برقم واتساب فعلي
  Future<bool> checkLawyerProfile(String uid) async {
    try {
      final res = await SupabaseService().invokeFunction('legal-actions', body: {'action': 'get_lawyer_profile', 'user_uid': uid});
      final data = res.data as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        final profile = data['profile'] as Map<String, dynamic>?;
        if (profile != null && profile['found'] == true) {
          final wa = (profile['whatsapp_phone'] ?? '').toString().trim();
          if (wa.isNotEmpty) { _lawyerProfile = profile; _profileSetupComplete = true; notifyListeners(); return true; }
        }
      }
      _profileSetupComplete = false; notifyListeners(); return false;
    } catch (e) { _profileSetupComplete = false; notifyListeners(); return false; }
  }

  Future<void> fetchAvailableExpediters() async {
    try {
      final res = await SupabaseService().invokeFunction('legal-actions', body: {'action': 'get_available_expediters', 'user_uid': ''});
      final data = res.data as Map<String, dynamic>?;
      _availableExpediters = (data != null && data['success'] == true)
          ? ((data['expediters'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? []) : [];
    } catch (_) { _availableExpediters = []; }
    notifyListeners();
  }

  Future<bool> createExpeditingTask({required String expediterUid, required int itemType, String targetPropertyNum = '', String targetZone = '', String notes = '', List<Map<String, dynamic>> checklist = const []}) async {
    try {
      final res = await SupabaseService().invokeFunction('legal-actions', body: {
        'action': 'create_expediting_task', 'user_uid': '',
        'expediter_uid': expediterUid, 'item_type': itemType,
        'target_property_num': targetPropertyNum, 'target_zone': targetZone,
        'lawyer_notes': notes, 'checklist': checklist,
      });
      final data = res.data as Map<String, dynamic>?;
      if (data != null && data['success'] == true) { await fetchLawyerTasks(); return true; }
      return false;
    } catch (e) { return false; }
  }

  Future<void> fetchLawyerTasks() async {
    try {
      final res = await SupabaseService().invokeFunction('legal-actions', body: {'action': 'get_lawyer_expediting_tasks', 'user_uid': ''});
      final data = res.data as Map<String, dynamic>?;
      _lawyerTasks = (data != null && data['success'] == true)
          ? ((data['tasks'] as List?)?.map((e) => ExpeditingTaskModel.fromMap(Map<String, dynamic>.from(e as Map))).toList() ?? []) : [];
    } catch (e) { _lawyerTasks = []; }
    notifyListeners();
  }

  Future<void> fetchLawyerAppointments() async {
    try {
      final res = await SupabaseService().invokeFunction('legal-actions', body: {'action': 'get_lawyer_appointments', 'user_uid': ''});
      final data = res.data as Map<String, dynamic>?;
      _lawyerAppointments = (data != null && data['success'] == true)
          ? ((data['appointments'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? []) : [];
    } catch (_) { _lawyerAppointments = []; }
    notifyListeners();
  }

  Future<List<ExpeditingTaskModel>> getExpeditingTasks({String? userUid}) async {
    try {
      final res = await SupabaseService().invokeFunction('legal-actions', body: {'action': 'get_my_expediting_tasks', 'user_uid': userUid ?? ''});
      final data = res.data as Map<String, dynamic>?;
      _expeditingTasks = (data != null && data['success'] == true)
          ? ((data['tasks'] as List?)?.map((e) => ExpeditingTaskModel.fromMap(Map<String, dynamic>.from(e as Map))).toList() ?? []) : [];
    } catch (e) { _expeditingTasks = []; }
    notifyListeners(); return _expeditingTasks;
  }

  Future<bool> updateChecklistItem({required String taskId, required String itemKey, required int status, String inputValue = '', String attachmentUrl = '', String notes = ''}) async {
    try {
      final res = await SupabaseService().invokeFunction('legal-actions', body: {
        'action': 'update_checklist_item', 'task_id': taskId, 'item_key': itemKey,
        'status': status, 'input_value': inputValue, 'attachment_url': attachmentUrl, 'notes': notes,
      });
      final data = res.data as Map<String, dynamic>?;
      return data != null && data['success'] == true;
    } catch (e) { return false; }
  }
}
