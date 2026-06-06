import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';

/// خدمة Firebase Cloud Messaging (FCM)
/// - تهيئة Firebase
/// - طلب أذونات الإشعارات
/// - الحصول على FCM token
/// - تسجيله في جدول user_devices
/// - معالجة الإشعارات الواردة (foreground / background / terminated)
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  late FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  String? _currentToken;
  bool _initialized = false;

  String? get currentToken => _currentToken;

  /// تهيئة Firebase + FCM — تُستدعى مرّة واحدة في main()
  static Future<void> initializeFirebase() async {
    try {
      await Firebase.initializeApp();
      debugPrint('✅ Firebase initialized');
    } catch (e) {
      debugPrint('❌ Firebase init error: $e');
      rethrow;
    }
  }

  /// تهيئة الـ FCM service الكاملة — تُستدعى بعد تسجيل دخول المستخدم
  Future<void> setup() async {
    if (_initialized) return;

    try {
      _messaging = FirebaseMessaging.instance;

      // 1) طلب الأذونات (iOS + Android 13+)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('🔔 FCM permission: ${settings.authorizationStatus}');

      // 2) إعدادات local notifications للـ foreground
      await _initLocalNotifications();

      // 3) الحصول على الـ token
      _currentToken = await _messaging.getToken();
      debugPrint('🔑 FCM Token (للنسخ والاختبار):');
      debugPrint('=' * 60);
      debugPrint(_currentToken ?? 'NULL');
      debugPrint('=' * 60);

      // 4) تسجيل التوكن في user_devices
      if (_currentToken != null) {
        await _registerDeviceToken(_currentToken!);
      }

      // 5) الاستماع لتغيير التوكن
      _messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('🔄 FCM Token refreshed');
        _currentToken = newToken;
        await _registerDeviceToken(newToken);
      });

      // 6) معالجة الإشعارات الواردة
      _setupMessageHandlers();

      _initialized = true;
      debugPrint('✅ FCMService setup complete');
    } catch (e) {
      debugPrint('❌ FCMService setup error: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(settings);
  }

  void _setupMessageHandlers() {
    // الإشعارات لما التطبيق مفتوح (foreground)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // الإشعارات لما المستخدم يضغط عليها من الخلفية
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // الإشعار اللي فتح التطبيق من حالة مغلقة
    _messaging.getInitialMessage().then((message) {
      if (message != null) _handleMessageOpenedApp(message);
    });
  }

  /// إشعار وصل والتطبيق مفتوح → نعرضه كـ local notification
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📨 FCM foreground: ${message.notification?.title}');
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'sweeda_default',
            'إشعارات عقارات السويداء',
            channelDescription: 'الإشعارات العامة',
            importance: Importance.high,
            priority: Priority.high,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: message.data.toString(),
      );
    }
  }

  /// المستخدم ضغط على إشعار → نتنقل للشاشة المناسبة
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('👆 FCM opened app: ${message.data}');
    // TODO: ربط navigation حسب message.data['type']
    // مثلاً: { type: 'offer', id: '...' } → context.push('/offer/$id')
  }

  /// تسجيل التوكن في جدول user_devices (مرتبط بالمستخدم الحالي)
  Future<void> _registerDeviceToken(String token) async {
    try {
      // نستخدم uid من SharedPreferences (لأن WhatsApp/Email OTP لا تنشئ Supabase Auth session)
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('user_id');

      if (uid == null) {
        debugPrint('⏸️ FCM token will register after login');
        return;
      }

      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : defaultTargetPlatform == TargetPlatform.android
              ? 'android'
              : 'web';

      await SupabaseService().client.from(DbTables.userDevices).upsert(
        {
          'uid': uid,
          'device_token': token,
          'platform': platform,
          'is_active': true,
          'ts_upd': DateTime.now().toIso8601String(),
        },
        onConflict: 'device_token',
      );
      debugPrint('✅ FCM token registered for $uid');
    } catch (e) {
      debugPrint('❌ register FCM token: $e');
    }
  }

  /// إعادة تسجيل التوكن (يُستدعى بعد تسجيل الدخول)
  Future<void> registerCurrentTokenForUser() async {
    if (_currentToken != null) {
      await _registerDeviceToken(_currentToken!);
    }
  }

  /// إلغاء تسجيل التوكن عند تسجيل الخروج
  Future<void> unregisterDevice() async {
    if (_currentToken == null) return;
    try {
      await SupabaseService()
          .client
          .from(DbTables.userDevices)
          .update({'is_active': false})
          .eq('device_token', _currentToken!);
      debugPrint('✅ FCM token unregistered');
    } catch (e) {
      debugPrint('❌ unregister FCM token: $e');
    }
  }
}

/// معالج الإشعارات بالخلفية (top-level function — مطلوب من Firebase)
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📨 FCM background: ${message.notification?.title}');
}
