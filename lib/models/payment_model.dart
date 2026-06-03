import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentModel {
  final String id;
  final String uId;      // User ID
  final double amt;      // Amount
  final String method;   // payment method (e.g., 'ShamCash', 'Transfer')
  final int sts;         // status: 0=pending, 1=success, 2=rejected
  final String ref;      // reference number or image URL
  final DateTime dtC;    // Created date
  final DateTime dtU;    // Updated date

  PaymentModel({
    required this.id,
    required this.uId,
    required this.amt,
    required this.method,
    required this.sts,
    required this.ref,
    required this.dtC,
    required this.dtU,
  });

  Map<String, dynamic> toMap() {
    return {
      'uId': uId,
      'amt': amt,
      'method': method,
      'sts': sts,
      'ref': ref,
      'dtC': Timestamp.fromDate(dtC),
      'dtU': Timestamp.fromDate(dtU),
    };
  }

  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PaymentModel(
      id: doc.id,
      uId: data['uId'] ?? '',
      amt: (data['amt'] ?? 0).toDouble(),
      method: data['method'] ?? '',
      sts: data['sts'] ?? 0,
      ref: data['ref'] ?? '',
      dtC: (data['dtC'] as Timestamp).toDate(),
      dtU: (data['dtU'] as Timestamp).toDate(),
    );
  }
}
