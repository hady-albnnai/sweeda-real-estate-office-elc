import 'package:flutter/foundation.dart';
import '../models/payment_model.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';

class PaymentProvider with ChangeNotifier {
  List<PaymentModel> _payments = [];
  bool _isLoading = false;

  List<PaymentModel> get payments => _payments;
  bool get isLoading => _isLoading;

  Future<bool> makePayment(PaymentModel payment) async {
    try {
      await SupabaseService().client.from(DbTables.payments).insert(payment.toMap());
      await fetchPayments(payment.uid);
      notifyListeners(); return true;
    } catch (e) { debugPrint('❌ makePayment error: $e'); return false; }
  }

  Future<void> fetchPayments(String userId) async {
    _isLoading = true; notifyListeners();
    try {
      final response = await SupabaseService().client
          .from(DbTables.payments).select()
          .eq('uid', userId).order('ts_crt', ascending: false);
      _payments = (response as List).map((d) =>
          PaymentModel.fromSupabase(Map<String, dynamic>.from(d), d['id'] as String)).toList();
    } catch (e) { debugPrint('❌ fetchPayments error: $e'); }
    _isLoading = false; notifyListeners();
  }

  Future<bool> updatePaymentStatus(String paymentId, int newStatus, {String? approvedBy}) async {
    try {
      final data = <String, dynamic>{'sts': newStatus};
      if (approvedBy != null) data['appr_by'] = approvedBy;
      await SupabaseService().client.from(DbTables.payments).update(data).eq('id', paymentId);
      notifyListeners(); return true;
    } catch (e) { debugPrint('❌ updatePaymentStatus error: $e'); return false; }
  }
}
