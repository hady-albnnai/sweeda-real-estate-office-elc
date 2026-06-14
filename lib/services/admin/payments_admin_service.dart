import '../../core/constants/db_constants.dart';
import '../../core/network/supabase_service.dart';
import '../../core/utils/error_utils.dart';
import '../../models/payment_model.dart';

/// خدمة إدارة المدفوعات للإدارة.
/// تفصل منطق RPCs المالية عن AdminProvider لتقليل تضخمه.
class PaymentsAdminService {
  String? _lastError;
  String? get lastError => _lastError;

  void clearError() => _lastError = null;

  void _setError(Object? error) {
    _lastError = ErrorUtils.arabicMessage(error);
  }

  Future<List<PaymentModel>> getAllPayments(String adminUid, {int? status}) async {
    try {
      final response = await SupabaseService().client.rpc(
        'get_admin_payments_internal',
        params: {'p_admin_uid': adminUid},
      );
      var list = (response as List)
          .map((d) => PaymentModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
      if (status != null) {
        list = list.where((p) => p.sts == status).toList();
      }
      clearError();
      return list;
    } catch (e) {
      _setError(e);
      return [];
    }
  }

  Future<bool> approvePayment(String paymentId, String adminId) async {
    try {
      final res = await SupabaseService().client.rpc(
        DbFunctions.approvePaymentFinal,
        params: {
          'p_payment_id': paymentId,
          'p_admin_id': adminId,
        },
      );

      final ok = res is Map && res['success'] == true;
      if (ok) clearError();
      if (!ok) _setError(res is Map ? res['error'] : 'UNKNOWN_ERROR');
      return ok;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  Future<bool> rejectPayment(String paymentId, String adminId) async {
    try {
      await SupabaseService().client.rpc(
        'admin_reject_payment_internal',
        params: {
          'p_admin_uid': adminId,
          'p_payment_id': paymentId,
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
