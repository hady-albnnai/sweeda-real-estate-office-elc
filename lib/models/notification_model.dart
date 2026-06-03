import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String title;
  final String msg;
  final int type;      // Notification type
  final String link;   // Deep link to specific screen/offer
  final bool read;     // read status
  final DateTime dtC;  // Created date

  NotificationModel({
    required this.id,
    required this.title,
    required this.msg,
    required this.type,
    required this.link,
    required this.read,
    required this.dtC,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'msg': msg,
      'type': type,
      'link': link,
      'read': read,
      'dtC': Timestamp.fromDate(dtC),
    };
  }

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      title: data['title'] ?? '',
      msg: data['msg'] ?? '',
      type: data['type'] ?? 0,
      link: data['link'] ?? '',
      read: data['read'] ?? false,
      dtC: (data['dtC'] as Timestamp).toDate(),
    );
  }
}
