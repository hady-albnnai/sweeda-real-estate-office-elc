import 'package:cloud_firestore/cloud_firestore.dart';

class RequestModel {
  final String id;
  final String uId;      // User ID
  final int type;        // type (Property/Car)
  final int trans;       // transaction (Sell/Rent/etc)
  final int cat;         // category
  final double prc;      // target price
  final String loc;      // location
  final String desc;     // description
  final String spec;     // specifications (JSON or string)
  final DateTime dtC;    // Created date
  final DateTime dtU;    // Updated date
  final int sts;         // status: 0=pending, 1=active, 2=completed, 3=cancelled

  RequestModel({
    required this.id,
    required this.uId,
    required this.type,
    required this.trans,
    required this.cat,
    required this.prc,
    required this.loc,
    required this.desc,
    required this.spec,
    required this.dtC,
    required this.dtU,
    required this.sts,
  });

  Map<String, dynamic> toMap() {
    return {
      'uId': uId,
      'type': type,
      'trans': trans,
      'cat': cat,
      'prc': prc,
      'loc': loc,
      'desc': desc,
      'spec': spec,
      'dtC': Timestamp.fromDate(dtC),
      'dtU': Timestamp.fromDate(dtU),
      'sts': sts,
    };
  }

  factory RequestModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return RequestModel(
      id: doc.id,
      uId: data['uId'] ?? '',
      type: data['type'] ?? 0,
      trans: data['trans'] ?? 0,
      cat: data['cat'] ?? 0,
      prc: (data['prc'] ?? 0).toDouble(),
      loc: data['loc'] ?? '',
      desc: data['desc'] ?? '',
      spec: data['spec'] ?? '',
      dtC: (data['dtC'] as Timestamp).toDate(),
      dtU: (data['dtU'] as Timestamp).toDate(),
      sts: data['sts'] ?? 0,
    );
  }
}
