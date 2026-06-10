import 'package:flutter/foundation.dart';
import '../models/request_model.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';

class RequestProvider with ChangeNotifier {
  List<RequestModel> _myRequests = [];
  bool _isLoading = false;

  List<RequestModel> get myRequests => _myRequests;
  bool get isLoading => _isLoading;

  Future<bool> addRequest(RequestModel request) async {
    try {
      await SupabaseService().client.rpc(
        'create_request_internal',
        params: {
          'p_user_uid': request.usrId,
          'p_request': request.toMap(),
        },
      );
      await fetchMyRequests(request.usrId);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> fetchMyRequests(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await SupabaseService().client.rpc(
        'get_user_requests_internal',
        params: {'p_user_uid': userId},
      );
      _myRequests = (response as List)
          .map((d) => RequestModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateRequest(
      String userId, String reqId, Map<String, dynamic> data) async {
    try {
      await SupabaseService().client.rpc(
        'update_request_internal',
        params: {
          'p_user_uid': userId,
          'p_request_id': reqId,
          'p_patch': data,
        },
      );
      await fetchMyRequests(userId);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> softDeleteRequest(String userId, String reqId) async {
    try {
      await SupabaseService().client.rpc(
        'soft_delete_request_internal',
        params: {
          'p_user_uid': userId,
          'p_request_id': reqId,
        },
      );
      await fetchMyRequests(userId);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }
}
