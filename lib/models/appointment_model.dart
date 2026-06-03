import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String id;
  final String uId;      // User ID (the one who booked)
  final String oId;      // Offer ID
  final String day;      // day (e.g., 'mon')
  final String time;     // time slot (e.g., '10-11')
  final int sts;         // status: 0=pending, 1=confirmed, 2=completed, 3=cancelled
  final int fbkOwn;      // Owner feedback: 1=accept, 2=reject, 3=deadline
  final int fbkReq;      // Requester feedback: 1=confirm, 2=cancel
  final DateTime dtC;    // Created date
  final DateTime dtU;    // Updated date

  AppointmentModel({
    required this.id,
    required this.uId,
    required this.oId,
    required this.day,
    required this.time,
    required this.sts,
    required this.fbkOwn,
    required this.fbkReq,
    required this.dtC,
    required this.dtU,
  });

  Map<String, dynamic> toMap() {
    return {
      'uId': uId,
      'oId': oId,
      'day': day,
      'time': time,
      'sts': sts,
      'fbkOwn': fbkOwn,
      'fbkReq': fbkReq,
      'dtC': Timestamp.fromDate(dtC),
      'dtU': Timestamp.fromDate(dtU),
    };
  }

  factory AppointmentModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AppointmentModel(
      id: doc.id,
      uId: data['uId'] ?? '',
      oId: data['oId'] ?? '',
      day: data['day'] ?? '',
      time: data['time'] ?? '',
      sts: data['sts'] ?? 0,
      fbkOwn: data['fbkOwn'] ?? 0,
      fbkReq: data['fbkReq'] ?? 0,
      dtC: (data['dtC'] as Timestamp).toDate(),
      dtU: (data['dtU'] as Timestamp).toDate(),
    );
  }
}
