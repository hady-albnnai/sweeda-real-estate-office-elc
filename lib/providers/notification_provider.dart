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
      final response = await SupabaseService().client
          .from(DbTables.notifications)
          .select()
          .eq('uid', userId)
          .eq('i_del', 0)
          .order('ts_crt', ascending: false);
      _notifications = (response as List).map((d) =>
          NotificationModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String)).toList();
      _unreadCount = _notifications.where((n) => !n.isRead).length;
    } catch (e) {
      debugPrint('❌ fetchNotifications error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await SupabaseService().client
          .from(DbTables.notifications)
          .update({'i_rd': 1})
          .eq('id', notificationId);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ markAsRead error: $e');
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      await SupabaseService().client
          .from(DbTables.notifications)
          .update({'i_rd': 1})
          .eq('uid', userId)
          .eq('i_rd', 0);
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ markAllAsRead error: $e');
    }
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
      await SupabaseService().client.from(DbTables.notifications).insert({
        'uid': userId, 'tp': type, 'ttl': title, 'bdy': body,
        'act': action, 'ref_id': refId,
      });
      return true;
    } catch (e) {
      debugPrint('❌ sendNotification error: $e');
      return false;
    }
  }

  Stream<List<Map<String, dynamic>>> notificationsStream(String userId) {
    return SupabaseService().client
        .from(DbTables.notifications)
        .stream(primaryKey: ['id'])
        .match({'uid': userId, 'i_del': 0})
        .order('ts_crt', ascending: false)
        .map((data) => data.map((d) => Map<String, dynamic>.from(d)).toList());
  }
}
