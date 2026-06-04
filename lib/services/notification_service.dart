import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: android);
    await _localNotif.initialize(initSettings);
    debugPrint('✅ NotificationService: initialized');
    _listenToNotifications();
  }

  static void _listenToNotifications() {
    try {
      final client = SupabaseService().client;
      final user = client.auth.currentUser;
      if (user == null) return;

      client.from(DbTables.notifications)
          .stream(primaryKey: ['id'])
          .match({'uid': user.id, 'i_del': 0})
          .listen((data) {
            for (var row in data) {
              _showLocalNotif(row['ttl'] ?? '', row['bdy'] ?? '');
            }
          });
      debugPrint('✅ NotificationService: Realtime listener active');
    } catch (e) {
      debugPrint('⚠️ NotificationService: Realtime error: $e');
    }
  }

  static Future<void> _showLocalNotif(String title, String body) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'sweeda_channel', 'عقارات السويداء',
        importance: Importance.high, priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      await _localNotif.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title, body,
        const NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('⚠️ Local notif error: $e');
    }
  }

  static Future<void> showNotification({
    required String title, required String body, String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'sweeda_channel', 'عقارات السويداء',
      importance: Importance.high, priority: Priority.high,
    );
    await _localNotif.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title, body,
      const NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  static Future<void> registerDeviceToken(String token) async {
    try {
      final client = SupabaseService().client;
      final user = client.auth.currentUser;
      if (user == null) return;
      await client.from(DbTables.userDevices).upsert({
        'uid': user.id, 'device_token': token,
        'platform': 'android', 'is_active': true,
        'ts_upd': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('⚠️ Device token error: $e');
    }
  }
}
