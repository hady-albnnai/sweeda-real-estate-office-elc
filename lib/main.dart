import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'core/config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- إعدادات الشاشة ---
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // --- تهيئة Firebase ---
  await AppConfig.initialize();

  // --- تشغيل التطبيق ---
  runApp(const SweedaRealEstateApp());
}