import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';
import '../core/router/app_router.dart';
import '../core/utils/error_utils.dart';

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
  String? _lastError;

  String? get currentToken => _currentToken;
  String? get lastError => _lastError;

  void clearError() => _lastError = null;

  void _setError(Object? error) {
    _lastError = ErrorUtils.arabicMessage(error);
  }

  /// تهيئة Firebase + FCM — تُستدعى مرّة واحدة في main()
  static Future<void> initializeFirebase() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      FCMService()._setError(e);
      rethrow;
    }
  }

  /// تهيئة الـ FCM service الكاملة
  Future<void> setup() async {
    if (_initialized) return;

    try {
      _messaging = FirebaseMessaging.instance;

      // 1) طلب الأذونات
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );// 2) إعدادات local notifications
      await _initLocalNotifications();

      // 3) الحصول على الـ token
      _currentToken = await _messaging.getToken();// 4) تسجيل التوكن
      if (_currentToken != null) {
        await _registerDeviceToken(_currentToken!);
      }

      // 5) الاستماع لتغيير التوكن
      _messaging.onTokenRefresh.listen((newToken) async {_currentToken = newToken;
        await _registerDeviceToken(newToken);
      });

      // 6) معالجة الإشعارات الواردة
      _setupMessageHandlers();

      _initialized = true;
    } catch (e) {
      _setError(e);
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
  void _handleForegroundMessage(RemoteMessage message) async {final notification = message.notification;
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
  void _handleMessageOpenedApp(RemoteMessage message) {_navigateFromData(message.data);
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null) return;// parse الـ payload (format: {key: value, key2: value2})
    try {
      // إزالة الأقواس والـ spaces
      final cleaned = payload.replaceAll('{', '').replaceAll('}', '').trim();
      if (cleaned.isEmpty) return;
      final data = <String, dynamic>{};
      for (final pair in cleaned.split(',')) {
        final parts = pair.split(':');
        if (parts.length >= 2) {
          data[parts[0].trim()] = parts.sublist(1).join(':').trim();
        }
      }
      _navigateFromData(data);
    } catch (e) {
      _setError(e);
    }
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
      _setError(e);
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

      // Phase 8: RPC 'notify_user' is locked. Local messages shouldn't duplicate DB triggers.
      // await SupabaseService().client.rpc('notify_user', params: {...});
    } catch (e) {
      _setError(e);
    }
  }

  /// تسجيل التوكن في جدول user_devices
  /// + تشطيب كل التوكنز القديمة لنفس المستخدم (يضمن جهاز واحد نشط لكل user)
  Future<void> _registerDeviceToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('user_id');

      if (uid == null) {return;
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
        _setError(e);
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
    } catch (e) {
      _setError(e);
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
    } catch (e) {
      _setError(e);
    }
  }
}

/// معالج الإشعارات بالخلفية
/// مهم: Firebase Messaging SDK يعرض الإشعار تلقائياً عند background/terminated
/// فلا نحتاج local notification هنا — يكفي init الـ engine.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();// ملاحظة: لا تستدعِ flutter_local_notifications هنا — Firebase يعرضها تلقائياً
}
