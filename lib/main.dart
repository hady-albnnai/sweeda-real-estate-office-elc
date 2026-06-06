import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  } catch (e) {
    debugPrint('⚠️ Firebase init skipped: $e');
  }

  try {
    await Supabase.initialize(
      url: 'https://vsgkgnjtebjxyqwpuopz.supabase.co',
      publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZzZ2tnbmp0ZWJqeHlxd3B1b3B6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1NzA1MzYsImV4cCI6MjA5NjE0NjUzNn0.1i81x_ne8_AciPMWaRxc-8Z-no-lXudLATKcE0A4tUw',
    );
    debugPrint('✅ Supabase initialized successfully');
  } catch (e) {
    debugPrint('❌ Supabase initialization error: $e');
  }

  runApp(const MyApp());
}
