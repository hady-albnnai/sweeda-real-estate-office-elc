import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// نقطة الوصول المركزية لـ Supabase
/// نقطة الوصول المركزية لـ Supabase
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static bool _initialized = false;

  /// تهيئة Supabase — تُستدعى مرة واحدة في main()
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    if (_initialized) return;
    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
        debug: kDebugMode,
      );
      _initialized = true;
      debugPrint('✅ SupabaseService: initialized');
    } catch (e) {
      debugPrint('❌ SupabaseService init error: $e');
      rethrow;
    }
  }

  /// الوصول لـ Supabase Client
  SupabaseClient get client => Supabase.instance.client;

  /// الوصول لـ Auth
  GoTrueClient get auth => Supabase.instance.client.auth;

  /// الوصول لـ Storage
  SupabaseStorageClient get storage => Supabase.instance.client.storage;

  /// المستخدم الحالي
  User? get currentUser => auth.currentUser;

  /// Stream للمستخدم الحالي
  Stream<AuthState> get authStateChanges => auth.onAuthStateChange;

  /// هل التطبيق جاهز؟
  bool get isReady => _initialized;
}
