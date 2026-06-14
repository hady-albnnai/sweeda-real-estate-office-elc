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

  Future<List<OfferModel>> getPendingOffers(String adminUid) async {
    try {
      final response = await SupabaseService().client.rpc(
        'get_admin_pending_offers_internal',
        params: {'p_admin_uid': adminUid},
      );
      clearError();
      return (response as List)
          .map((d) => OfferModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {
      _setError(e);
      return [];
    }
  }

  Future<bool> reviewOffer(
    String adminUid,
    String offerId,
    bool approve, {
    String reason = '',
  }) async {
    try {
      await SupabaseService().client.rpc(
        'admin_review_offer_internal',
        params: {
          'p_admin_uid': adminUid,
          'p_offer_id': offerId,
          'p_approve': approve,
          'p_reject_reason': reason,
        },
      );
      clearError();
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  Future<List<OfferModel>> getOffersForMediaReview(String adminUid) async {
    try {
      final response = await SupabaseService().client.rpc(
        'get_admin_offers_internal',
        params: {
          'p_admin_uid': adminUid,
          'p_limit': 100,
        },
      );
      clearError();
      return (response as List)
          .map((d) => OfferModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {
      _setError(e);
      return [];
    }
  }
}
