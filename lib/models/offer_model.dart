import 'package:cloud_firestore/cloud_firestore.dart';

class OfferModel {
  final String id;
  final String uId;      // User ID of the owner
  final String title;    // Title of the offer
  final int type;        // 1: Property, 2: Car
  final int trans;       // 1: Sell, 2: Rent
  final int cat;         // Category ID
  final double prc;      // Price
  final String loc;      // Location
  final String desc;     // Description
  final String spec;     // Specifications
  final List<String> imgs; // Images URLs
  final int sts;         // Status: 0=Pending, 1=Published, etc.
  final int iPub;        // Is Published
  final Map<String, List<String>> avl; // Availability
  final DateTime dtC;    // Created date
  final DateTime dtU;    // Updated date

  OfferModel({
    required this.id,
    required this.uId,
    required this.title,
    required this.type,
    required this.trans,
    required this.cat,
    required this.prc,
    required this.loc,
    required this.desc,
    required this.spec,
    required this.imgs,
    required this.sts,
    required this.iPub,
    required this.avl,
    required this.dtC,
    required this.dtU,
  });

  Map<String, dynamic> toMap() {
    return {
      'uId': uId,
      'title': title,
      'type': type,
      'trans': trans,
      'cat': cat,
      'prc': prc,
      'loc': loc,
      'desc': desc,
      'spec': spec,
      'imgs': imgs,
      'sts': sts,
      'iPub': iPub,
      'avl': avl,
      'dtC': Timestamp.fromDate(dtC),
      'dtU': Timestamp.fromDate(dtU),
    };
  }

  factory OfferModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return OfferModel(
      id: doc.id,
      uId: data['uId'] ?? '',
      title: data['title'] ?? 'بدون عنوان',
      type: data['type'] ?? 1,
      trans: data['trans'] ?? 1,
      cat: data['cat'] ?? 0,
      prc: (data['prc'] ?? 0).toDouble(),
      loc: data['loc'] ?? '',
      desc: data['desc'] ?? '',
      spec: data['spec'] ?? '',
      imgs: List<String>.from(data['imgs'] ?? []),
      sts: data['sts'] ?? 0,
      iPub: data['iPub'] ?? 0,
      avl: Map<String, List<String>>.from(data['avl'] ?? {}),
      dtC: (data['dtC'] as Timestamp).toDate(),
      dtU: (data['dtU'] as Timestamp).toDate(),
    );
  }
}
