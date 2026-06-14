import '../../core/network/supabase_service.dart';
import '../../core/utils/error_utils.dart';
import '../../models/deal_model.dart';

/// خدمة إدارة الصفقات من طرف الإدارة.
class DealsAdminService {
  String? _lastError;
  String? get lastError => _lastError;

  void clearError() => _lastError = null;

  void _setError(Object? error) {
    _lastError = ErrorUtils.arabicMessage(error);
  }

  Future<List<DealModel>> getAllDeals(String adminUid) async {
    try {
      final response = await SupabaseService().client.rpc(
        'get_admin_deals_internal',
        params: {'p_admin_uid': adminUid},
      );
      clearError();
      return (response as List)
          .map((d) =>
              DealModel.fromSupabase(Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {
      _setError(e);
      return [];
    }
  }

  Future<bool> createDeal(String adminUid, DealModel deal) async {
    try {
      await SupabaseService().client.rpc(
        'create_deal_internal',
        params: {
          'p_admin_uid': adminUid,
          'p_deal': deal.toMap(),
        },
      );
      clearError();
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  Future<bool> completeDeal(
    String dealId,
    String adminId, {
    double? commission,
    String? note,
  }) async {
    try {
      await SupabaseService().client.rpc(
        'complete_deal_internal',
        params: {
          'p_admin_uid': adminId,
          'p_deal_id': dealId,
          'p_commission': commission,
          'p_note': note,
        },
      );
      clearError();
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }
}
