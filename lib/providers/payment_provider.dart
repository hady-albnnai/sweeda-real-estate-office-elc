import 'package:flutter/foundation.dart';
import '../models/payment_model.dart';
import '../core/network/supabase_service.dart';

class PaymentProvider with ChangeNotifier {
  List<PaymentModel> _payments = [];
  bool _isLoading = false;

  List<PaymentModel> get payments => _payments;
  bool get isLoading => _isLoading;

  Future<bool> makePayment(PaymentModel payment) async {
    try {
      await SupabaseService().client.rpc(
        'create_payment_internal',
        params: {
          'p_user_uid': payment.uid,
          'p_payment': payment.toMap(),
        },
      );
      await fetchPayments(payment.uid);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> fetchPayments(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await SupabaseService().client.rpc(
        'get_user_payments_internal',
        params: {'p_user_uid': userId},
      );
      _payments = (response as List)
          .map((d) => PaymentModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updatePaymentStatus(String paymentId, int newStatus,
      {String? approvedBy}) async {
    try {
      if (newStatus == 2 && approvedBy != null && approvedBy.isNotEmpty) {
        await SupabaseService().client.rpc(
          'admin_reject_payment_internal',
          params: {
            'p_admin_uid': approvedBy,
            'p_payment_id': paymentId,
          },
        );
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
