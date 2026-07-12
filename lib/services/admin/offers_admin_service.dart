import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/supabase_service.dart';
import '../../core/utils/error_utils.dart';
import '../../models/offer_model.dart';

/// خدمة مراجعة وإدارة العروض من طرف الإدارة.
class OffersAdminService {
  String? _lastError;
  String? get lastError => _lastError;

  void clearError() => _lastError = null;

  void _setError(Object? error) {
    _lastError = ErrorUtils.arabicMessage(error);
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  Future<Map<String, dynamic>> _invokeAdminOffers(
    String action,
    Map<String, dynamic> body,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionToken = prefs.getString('staff_session_token');
      if (sessionToken != null && sessionToken.isNotEmpty) {
        body['staff_session_token'] = sessionToken;
      }
      body['action'] = action;

      final res = await SupabaseService().invokeFunction('admin-offers', body: body);
      final data = _asMap(res.data);
      if (data == null) {
        _setError('EMPTY_RESPONSE');
        return {'success': false, 'error': 'EMPTY_RESPONSE'};
      }
      if (data['success'] == true) {
        clearError();
      } else {
        _setError(data['error'] ?? 'UNKNOWN_ERROR');
      }
      return data;
    } catch (e) {
      _setError(e);
      return {'success': false, 'error': ErrorUtils.normalize(e)};
    }
  }

  Future<List<OfferModel>> getPendingOffers(String adminUid) async {
    final data = await _invokeAdminOffers('list_pending', {'admin_uid': adminUid});
    if (data['success'] != true || data['offers'] is! List) return [];
    return (data['offers'] as List)
        .map((d) => OfferModel.fromSupabase(
            Map<String, dynamic>.from(d as Map), d['id'] as String))
        .toList();
  }

  Future<List<OfferModel>> getSocialQueue(String adminUid) async {
    final data = await _invokeAdminOffers('list_social_queue', {'admin_uid': adminUid});
    if (data['success'] != true || data['offers'] is! List) return [];
    return (data['offers'] as List)
        .map((d) => OfferModel.fromSupabase(
            Map<String, dynamic>.from(d as Map), d['id'] as String))
        .toList();
  }

  Future<bool> publishToSocial(String adminUid, String offerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final body = <String, dynamic>{
        'admin_uid': adminUid,
        'offer_id': offerId,
      };
      final sessionToken = prefs.getString('staff_session_token');
      if (sessionToken != null && sessionToken.isNotEmpty) {
        body['staff_session_token'] = sessionToken;
      }
      final res = await SupabaseService()
          .invokeFunction('publish-to-social', body: body);
      final data = _asMap(res.data);
      if (data?['success'] == true) {
        clearError();
        return true;
      }
      _setError(data?['error'] ?? 'SOCIAL_PUBLISH_FAILED');
      return false;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  Future<Map<String, dynamic>> reviewOffer(
    String adminUid,
    String offerId,
    bool approve, {
    String reason = '',
  }) async {
    final data = await _invokeAdminOffers('review', {
      'admin_uid': adminUid,
      'offer_id': offerId,
      'approve': approve,
      'reason': reason,
    });
    return data;
  }

  Future<bool> reviewOfferLegacy(
    String adminUid,
    String offerId,
    bool approve, {
    String reason = '',
  }) async {
    final data = await reviewOffer(adminUid, offerId, approve, reason: reason);
    return data['success'] == true;
  }

  Future<bool> setOfferPriority(
    String adminUid,
    String offerId,
    String priorityType,
  ) async {
    final data = await _invokeAdminOffers('set_priority', {
      'admin_uid': adminUid,
      'offer_id': offerId,
      'priority_type': priorityType,
      'duration_days': 30,
    });
    return data['success'] == true;
  }

  Future<bool> deleteOfferByAdmin(String adminUid, String offerId) async {
    final data = await _invokeAdminOffers('delete', {
      'admin_uid': adminUid,
      'offer_id': offerId,
    });
    return data['success'] == true;
  }

  Future<List<OfferModel>> getOffersForMediaReview(String adminUid) async {
    final data = await _invokeAdminOffers('list_media_review', {
      'admin_uid': adminUid,
      'limit': 100,
    });
    if (data['success'] != true || data['offers'] is! List) return [];
    return (data['offers'] as List)
        .map((d) => OfferModel.fromSupabase(
            Map<String, dynamic>.from(d as Map), d['id'] as String))
        .toList();
  }
}
