import 'package:flutter/foundation.dart';
import '../models/request_model.dart';
import '../core/network/supabase_service.dart';

class RequestProvider with ChangeNotifier {
  List<RequestModel> _myRequests = [];
  bool _isLoading = false;

  List<RequestModel> get myRequests => _myRequests;
  bool get isLoading => _isLoading;

  Future<Map<String, dynamic>> canPublishRequest(String userId) async {
    try {
      final response = await SupabaseService().client.functions.invoke(
        'user-requests',
        body: {
          'action': 'can_publish',
          'user_uid': userId,
        },
      );
      final data = response.data;
      if (data is Map && data['success'] == true && data['result'] is Map) {
        return Map<String, dynamic>.from(data['result'] as Map);
      }
      return {
        'allowed': false,
        'used': 0,
        'limit': 0,
        'reason': data is Map ? (data['error']?.toString() ?? '') : '',
      };
    } catch (e) {
      return {
        'allowed': false,
        'used': 0,
        'limit': 0,
        'reason': 'تعذّر التحقق من حصتك، حاول لاحقاً.',
      };
    }
  }

  Future<bool> addRequest(RequestModel request) async {
    try {
      final response = await SupabaseService().client.functions.invoke(
        'user-requests',
        body: {
          'action': 'create',
          'user_uid': request.usrId,
          'request': request.toMap(),
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) return false;

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
      final response = await SupabaseService().client.functions.invoke(
        'user-requests',
        body: {
          'action': 'list',
          'user_uid': userId,
        },
      );
      final data = response.data;
      if (data != null && data['success'] == true) {
        final list = data['requests'] as List;
        _myRequests = list
            .map((d) => RequestModel.fromSupabase(
                Map<String, dynamic>.from(d), d['id'] as String))
            .toList();
      }
    } catch (e) {
      // تم تجاهل الخطأ عمداً للحفاظ على التدفق الحالي.
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateRequest(
      String userId, String reqId, Map<String, dynamic> data) async {
    try {
      final response = await SupabaseService().client.functions.invoke(
        'user-requests',
        body: {
          'action': 'update',
          'user_uid': userId,
          'request_id': reqId,
          'patch': data,
        },
      );
      final resData = response.data;
      if (resData == null || resData['success'] != true) return false;

      await fetchMyRequests(userId);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> cancelRequest(String userId, String reqId,
      {String reason = ''}) async {
    try {
      final response = await SupabaseService().client.functions.invoke(
        'user-requests',
        body: {
          'action': 'cancel',
          'user_uid': userId,
          'request_id': reqId,
          'reason': reason,
        },
      );
      final resData = response.data;
      if (resData == null || resData['success'] != true) return false;

      await fetchMyRequests(userId);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> renewRequest(String userId, String reqId) async {
    try {
      final response = await SupabaseService().client.functions.invoke(
        'user-requests',
        body: {
          'action': 'renew',
          'user_uid': userId,
          'request_id': reqId,
        },
      );
      final resData = response.data;
      if (resData == null || resData['success'] != true) return false;

      await fetchMyRequests(userId);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// توافق خلفي: لم يعد الحذف العادي يمسح السجل، بل يلغي الطلب مع حفظ المسؤولية.
  Future<bool> softDeleteRequest(String userId, String reqId) =>
      cancelRequest(userId, reqId);
}