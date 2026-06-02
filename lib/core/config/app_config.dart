import '../network/firebase_service.dart';

/// فئة التهيئة الأساسية للتطبيق
/// 
/// تتبع فلسفة "كل شيء يُقرأ من Config":
/// - تحميل Firebase
/// - تحميل Config من Firestore
/// - تخزين Config محلياً
class AppConfig {
  static bool _initialized = false;
  static bool _configLoaded = false;

  static bool get isInitialized => _initialized;
  static bool get isConfigLoaded => _configLoaded;

  /// تهيئة Firebase وجلب Config
  static Future<void> initialize() async {
    if (_initialized) return;

    // 1. تهيئة Firebase
    await FirebaseService.initialize();

    // 2. تحميل Config من Firestore
    await _loadConfig();

    _initialized = true;
  }

  static Future<void> _loadConfig() async {
    // سيتم تنفيذها في ConfigProvider
    _configLoaded = true;
  }
}
