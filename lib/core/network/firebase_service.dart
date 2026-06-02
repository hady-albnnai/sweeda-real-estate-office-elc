import 'package:firebase_core/firebase_core.dart';

/// خدمة Firebase الأساسية
class FirebaseService {
  static FirebaseApp? _app;
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    if (_initialized) return;

    _app = await Firebase.initializeApp(
      // سيتم إعداد options من google-services.json لاحقاً
      options: DefaultFirebaseOptions.currentPlatform,
    );

    _initialized = true;
  }
}
