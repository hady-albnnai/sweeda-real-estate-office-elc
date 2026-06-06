import 'package:flutter/foundation.dart';
import '../models/request_model.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';
import '../core/services/business_service.dart';

class RequestProvider with ChangeNotifier {
  List<RequestModel> _myRequests = [];
  bool _isLoading = false;

  List<RequestModel> get myRequests => _myRequests;
  bool get isLoading => _isLoading;

  Future<bool> addRequest(RequestModel request) async {
    try {
      await SupabaseService().client.from(DbTables.requests).insert(request.toMap());
      await fetchMyRequests(request.usrId);
      notifyListeners(); 
      
      // تحديث إحصائيات المستخدم (عدد الطلبات)
      await BusinessService().updateUserStat(request.usrId, 'req');
      
      return true;
    } catch (e) { debugPrint('❌ addRequest error: $e'); return false; }
  }

  Future<void> fetchMyRequests(String userId) async {
    _isLoading = true; notifyListeners();
    try {
      final response = await SupabaseService().client
          .from(DbTables.requests).select()
          .eq('usr_id', userId).eq('i_del', 0)
          .order('ts_crt', ascending: false);
      _myRequests = (response as List).map((d) =>
          RequestModel.fromSupabase(Map<String, dynamic>.from(d), d['id'] as String)).toList();
    } catch (e) { debugPrint('❌ fetchMyRequests error: $e'); }
    _isLoading = false; notifyListeners();
  }

  Future<bool> updateRequest(String reqId, Map<String, dynamic> data) async {
    try {
      await SupabaseService().client.from(DbTables.requests).update(data).eq('id', reqId);
      notifyListeners(); return true;
    } catch (e) { debugPrint('❌ updateRequest error: $e'); return false; }
  }

  Future<bool> softDeleteRequest(String reqId) => updateRequest(reqId, {'i_del': 1});
}
