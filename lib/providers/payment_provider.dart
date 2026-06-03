import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_model.dart';
import '../core/network/firebase_service.dart';

class PaymentProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseService().db;
  List<PaymentModel> _payments = [];
  List<PaymentModel> get payments => _payments;

  Future<bool> makePayment(PaymentModel payment) async {
    try {
      DocumentReference docRef = _db.collection('payments').doc();
      await docRef.set(payment.toMap());
      notifyListeners();
      return true;
    } catch (e) {
      print('Payment error: $e');
      return false;
    }
  }

  Future<void> fetchPayments(String uId) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('payments')
          .where('uId', isEqualTo: uId)
          .get();
      _payments = snapshot.docs.map((doc) => PaymentModel.fromFirestore(doc)).toList();
      notifyListeners();
    } catch (e) {
      print('Error fetching payments: $e');
    }
  }
}
