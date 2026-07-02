import 'package:flutter/foundation.dart';
import '../models/payment_model.dart';
import '../core/network/supabase_service.dart';
import '../core/utils/error_utils.dart';

class PaymentProvider with ChangeNotifier {
  List<PaymentModel> _payments = [];
  bool _isLoading = false;
  String? _error;

  List<PaymentModel> get payments => _payments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setError(Object? error) {
    _error = ErrorUtils.arabicMessage(error);
  }

  void _clearError() {
    _error = null;
  }

  Future<bool> makePayment(PaymentModel payment) async {
    try {
      final response = await SupabaseService().invokeFunction(
        'user-account',
        body: {
          'action': 'create_payment',
          'user_uid': payment.uid,
          'payment': payment.toMap(),
        },
      );
      final data = response.data is Map ? Map<String, dynamic>.from(response.data) : null;
      if (data == null || data['success'] != true) {
        throw Exception(data?['error']?.toString() ?? 'CREATE_PAYMENT_FAILED');
      }

      await fetchPayments(payment.uid);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> fetchPayments(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _clearError();
      final response = await SupabaseService().invokeFunction(
        'user-account',
        body: {
          'action': 'user_payments',
          'user_uid': userId,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception('Error fetching payments');
      _payments = (data['payments'] as List)
          .map((d) => PaymentModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {
      _setError(e);
    }
    _isLoading = false;
    notifyListeners();
  }

  // updatePaymentStatus حُذفت — غير مستخدمة
  // الموافقة: admin_provider.approvePayment → approve_payment_final RPC
  // الرفض:    admin_provider.rejectPayment  → admin_reject_payment_internal RPC
}
