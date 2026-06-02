import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// خدمة الإشعارات — FCM + داخلية
class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // طلب الإذن
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // الحصول على token
    final token = await FirebaseMessaging.instance.getToken();
    print('FCM Token: $token');

    // الاستماع للإشعارات
    FirebaseMessaging.onMessage.listen(_handleMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);
  }

  static void _handleMessage(RemoteMessage message) {
    // عرض الإشعار محلياً
  }

  static void _handleMessageOpened(RemoteMessage message) {
    // التوجيه إلى الشاشة المناسبة
    final action = message.data['act'];
    final refId = message.data['refId'];
    // التنقل حسب action
  }
}