import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';

class NotificationProvider with ChangeNotifier {
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  int _unreadCount = 0;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _unreadCount;

  Future<void> fetchNotifications(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await SupabaseService().client.rpc(
        'get_user_notifications_internal',
        params: {'p_user_uid': userId},
      );
      _notifications = (response as List)
          .map((d) => NotificationModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
      _unreadCount = _notifications.where((n) => !n.isRead).length;
    } catch (e) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await SupabaseService().client.rpc(
        'mark_notification_read_internal',
        params: {
          'p_user_uid': userId,
          'p_notification_id': notificationId,
        },
      );
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1 && !_notifications[index].isRead) {
        _notifications[index] = NotificationModel.fromSupabase(
          {..._notifications[index].toMap(), 'i_rd': 1},
          _notifications[index].id,
        );
        _unreadCount = _notifications.where((n) => !n.isRead).length;
      }
      notifyListeners();
    } catch (e) {}
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      await SupabaseService().client.rpc(
        'mark_all_notifications_read_internal',
        params: {'p_user_uid': userId},
      );
      _notifications = _notifications
          .map((n) => NotificationModel.fromSupabase(
              {...n.toMap(), 'i_rd': 1}, n.id))
          .toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {}
  }

  Future<bool> sendNotification({
    required String userId,
    required int type,
    required String title,
    required String body,
    String action = '',
    String refId = '',
  }) async {
    try {
      await SupabaseService().client.rpc(
        'notify_user',
        params: {
          'p_uid': userId,
          'p_type': type,
          'p_title': title,
          'p_body': body,
          'p_ref_id': refId,
          'p_action': action,
        },
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Stream<List<Map<String, dynamic>>> notificationsStream(String userId) {
    return SupabaseService().client
        .from(DbTables.notifications)
        .stream(primaryKey: ['id'])
        .order('ts_crt', ascending: false)
        .map((data) =>
            data.map((d) => Map<String, dynamic>.from(d)).toList());
  }
}
