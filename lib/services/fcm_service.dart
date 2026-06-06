import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';
import '../core/router/app_router.dart';

/// خدمة Firebase Cloud Messaging (FCM)
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

  /// تهيئة الـ FCM service الكاملة
  Future<void> setup() async {
    if (_initialized) return;

    try {
      _messaging = FirebaseMessaging.instance;

      // 1) طلب الأذونات
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('🔔 FCM permission: ${settings.authorizationStatus}');

      // 2) إعدادات local notifications
      await _initLocalNotifications();

      // 3) الحصول على الـ token
      _currentToken = await _messaging.getToken();
      debugPrint('🔑 FCM Token (للنسخ والاختبار):');
      debugPrint('=' * 60);
      debugPrint(_currentToken ?? 'NULL');
      debugPrint('=' * 60);

      // 4) تسجيل التوكن
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
        AndroidInitializationSettings('@drawable/ic_notification');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // إنشاء قناة الإشعارات
    const channel = AndroidNotificationChannel(
      'sweeda_default',
      'إشعارات عقارات السويداء',
      description: 'الإشعارات العامة',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        // المستخدم ضغط على local notification
        _handleNotificationTap(response.payload);
      },
    );
  }

  void _setupMessageHandlers() {
    // الإشعارات لما التطبيق مفتوح
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    // الإشعارات لما المستخدم يضغط عليها من الخلفية
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    // الإشعار اللي فتح التطبيق من حالة مغلقة
    _messaging.getInitialMessage().then((message) {
      if (message != null) _handleMessageOpenedApp(message);
    });
  }

  /// إشعار وصل والتطبيق مفتوح → نعرضه + نحفظه في DB
  void _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📨 FCM foreground: ${message.notification?.title}');
    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      // 1) عرض local notification
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
            icon: '@drawable/ic_notification',
            color: const Color(0xFFD4AF37),
            styleInformation: BigTextStyleInformation(
              notification.body ?? '',
              contentTitle: notification.title,
            ),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: data.toString(),
      );
    }

    // 2) حفظ في DB ليظهر داخل التطبيق
    await _saveNotificationToDb(
      title: notification?.title ?? '',
      body: notification?.body ?? '',
      data: data,
    );
  }

  /// المستخدم ضغط على إشعار → نتنقل للشاشة المناسبة
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('👆 FCM opened app: ${message.data}');
    _navigateFromData(message.data);
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null) return;
    debugPrint('👆 Local notification tapped: $payload');
    // payload هو data.toString() — نعيد parse بسيط
    // لكن أسهل: نعتمد على FCM data مباشرة
  }

  /// التنقل حسب نوع الإشعار
  void _navigateFromData(Map<String, dynamic> data) {
    try {
      final type = data['type']?.toString() ?? '';
      final id = data['id']?.toString() ?? '';
      final router = AppRouter.router;

      switch (type) {
        case 'offer':
          if (id.isNotEmpty) router.push('/offer/$id');
          break;
        case 'appointment':
          router.push('/user/my-appointments');
          break;
        case 'request':
          if (id.isNotEmpty) router.push('/user/request/$id');
          break;
        case 'payment':
          router.push('/user/packages');
          break;
        case 'broker':
          router.push('/broker/dashboard');
          break;
        case 'admin':
          router.push('/admin/dashboard');
          break;
        default:
          // افتراضي: شاشة الإشعارات
          router.push('/user/notifications');
      }
    } catch (e) {
      debugPrint('⚠️ navigation from notification: $e');
    }
  }

  /// حفظ الإشعار في DB ليظهر داخل التطبيق
  Future<void> _saveNotificationToDb({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('user_id');
      if (uid == null) return;

      final typeStr = data?['type']?.toString() ?? '';
      // mapping من النص للرقم حسب schema notifications.tp
      final typeNum = _typeStringToInt(typeStr);

      await SupabaseService().client.rpc('notify_user', params: {
        'p_uid': uid,
        'p_type': typeNum,
        'p_title': title,
        'p_body': body,
        'p_ref_id': data?['id']?.toString() ?? '',
        'p_action': typeStr,
      });
      debugPrint('✅ notification saved to DB');
    } catch (e) {
      debugPrint('⚠️ save notification to DB: $e');
    }
  }

  int _typeStringToInt(String t) {
    switch (t) {
      case 'offer':
        return 0;
      case 'request':
        return 1;
      case 'appointment':
        return 2;
      case 'payment':
        return 3;
      case 'account':
      case 'broker':
      case 'admin':
        return 4;
      case 'rating':
        return 5;
      default:
        return 4;
    }
  }

  /// تسجيل التوكن في جدول user_devices
  /// + تشطيب كل التوكنز القديمة لنفس المستخدم (يضمن جهاز واحد نشط لكل user)
  Future<void> _registerDeviceToken(String token) async {
    try {
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

      final sb = SupabaseService().client;

      // 1) إلغاء أي توكن نشط آخر لنفس المستخدم (غير التوكن الحالي)
      try {
        await sb
            .from(DbTables.userDevices)
            .update({'is_active': false})
            .eq('uid', uid)
            .neq('device_token', token);
      } catch (e) {
        debugPrint('⚠️ deactivate old tokens: $e');
      }

      // 2) Upsert التوكن الحالي
      await sb.from(DbTables.userDevices).upsert(
        {
          'uid': uid,
          'device_token': token,
          'platform': platform,
          'is_active': true,
          'ts_upd': DateTime.now().toIso8601String(),
        },
        onConflict: 'device_token',
      );
      debugPrint('✅ FCM token registered for $uid (deactivated old tokens)');
    } catch (e) {
      debugPrint('❌ register FCM token: $e');
    }
  }

  Future<void> registerCurrentTokenForUser() async {
    if (_currentToken != null) {
      await _registerDeviceToken(_currentToken!);
    }
  }

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

/// معالج الإشعارات بالخلفية
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📨 FCM background: ${message.notification?.title}');
}
