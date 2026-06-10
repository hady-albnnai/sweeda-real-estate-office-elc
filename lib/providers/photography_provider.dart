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
      final response = await SupabaseService().client
          .from(DbTables.photographyTasks)
          .select()
          .eq('photographer_id', photographerId)
          .order('ts_crt', ascending: false);
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

  Future<bool> createTask({
    required OfferModel offer,
    required String photographerId,
    required String requestedBy,
    String notes = '',
    DateTime? scheduledAt,
  }) async {
    _setLoading(true);
    try {
      final task = PhotographyTaskModel(
        id: '',
        offId: offer.id,
        photographerId: photographerId,
        requestedBy: requestedBy,
        ttl: offer.ttl,
        notes: notes,
        loc: offer.loc,
        sts: 0,
        tsScheduled: scheduledAt,
        tsCrt: DateTime.now(),
      );
      await SupabaseService().client
          .from(DbTables.photographyTasks)
          .insert(task.toMap());
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateStatus(String taskId, int status, {String officeNote = ''}) async {
    try {
      final data = <String, dynamic>{
        'sts': status,
        'ts_upd': DateTime.now().toIso8601String(),
      };
      if (officeNote.isNotEmpty) data['office_note'] = officeNote;
      if (status == 3 || status == 4) data['ts_done'] = DateTime.now().toIso8601String();
      await SupabaseService().client
          .from(DbTables.photographyTasks)
          .update(data)
          .eq('id', taskId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<bool> submitTask({
    required String taskId,
    required List<String> media,
    String photographerNote = '',
  }) async {
    try {
      await SupabaseService().client
          .from(DbTables.photographyTasks)
          .update({
            'media': media,
            'photographer_note': photographerNote,
            'sts': 2,
            'ts_submit': DateTime.now().toIso8601String(),
            'ts_upd': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<bool> attachMediaToOffer(PhotographyTaskModel task) async {
    if (task.media.isEmpty) return false;
    try {
      final current = await SupabaseService().client
          .from(DbTables.offers)
          .select('imgs')
          .eq('id', task.offId)
          .maybeSingle();
      final existing = current != null && current['imgs'] != null
          ? List<String>.from(current['imgs'] as List)
          : <String>[];
      final merged = <String>{...existing, ...task.media}.toList();
      await SupabaseService().client
          .from(DbTables.offers)
          .update({'imgs': merged})
          .eq('id', task.offId);
      await updateStatus(task.id, 3, officeNote: 'تم اعتماد التصوير وربط الوسائط بالعرض');
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }
}
