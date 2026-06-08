import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'core/services/local_cache_service.dart';
import 'services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة بيانات التواريخ بالعربية (لـ DateFormat)
  await initializeDateFormatting('ar', null);

  // تهيئة التخزين المحلي (Hive) — للكاش ودعم العمل دون اتصال
  await LocalCacheService.initialize();

  // تهيئة Firebase (للـ FCM Push Notifications)
  try {
    await FCMService.initializeFirebase();
    // تسجيل معالج الإشعارات بالخلفية
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  } catch (e) {}

  runApp(const MyApp());
}
