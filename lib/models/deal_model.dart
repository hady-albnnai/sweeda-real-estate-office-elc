import 'package:cloud_firestore/cloud_firestore.dart';

class DealModel {
  final String id;
  final String oId;      // Offer ID
  final String bId;      // Buyer ID
  final String sId;      // Seller ID
  final double prc;      // Final price
  final double com;      // Commission
  final DateTime dtC;    // Deal date
  final DateTime dtU;    // Updated date
  final List<String> docs; // Contract documents URLs

  DealModel({
    required this.id,
    required this.oId,
    required this.bId,
    required this.sId,
    required this.prc,
    required this.com,
    required this.dtC,
    required this.dtU,
    required this.docs,
  });

  Map<String, dynamic> toMap() {
    return {
      'oId': oId,
      'bId': bId,
      'sId': sId,
      'prc': prc,
      'com': com,
      'dtC': Timestamp.fromDate(dtC),
      'dtU': Timestamp.fromDate(dtU),
      'docs': docs,
    };
  }

  factory DealModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return DealModel(
      id: doc.id,
      oId: data['oId'] ?? '',
      bId: data['bId'] ?? '',
      sId: data['sId'] ?? '',
      prc: (data['prc'] ?? 0).toDouble(),
      com: (data['com'] ?? 0).toDouble(),
      dtC: (data['dtC'] as Timestamp).toDate(),
      dtU: (data['dtU'] as Timestamp).toDate(),
      docs: List<String>.from(data['docs'] ?? []),
    );
  }
}
