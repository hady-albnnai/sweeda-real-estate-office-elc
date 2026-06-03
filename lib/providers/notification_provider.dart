import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../core/network/firebase_service.dart';

class NotificationProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseService().db;
  List<NotificationModel> _notifications = [];
  List<NotificationModel> get notifications => _notifications;

  Future<void> fetchNotifications(String uId) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('notifications')
          .where('uId', isEqualTo: uId)
          .orderBy('dtC', descending: true)
          .get();

      _notifications = snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
      notifyListeners();
    } catch (e) {
      print('Error fetching notifications: $e');
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).update({'read': true});
      notifyListeners();
    } catch (e) {
      print('Error marking as read: $e');
    }
  }
}
