import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// نقطة الوصول المركزية لـ Supabase
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static bool _initialized = false;
  static String? _url;
  static String? _publishableKey;

  /// تهيئة Supabase — تُستدعى مرة واحدة في main()
  static Future<void> initialize({
    required String url,
    required String publishableKey,
  }) async {
    if (_initialized) return;
    try {
      await Supabase.initialize(
        url: url,
        publishableKey: publishableKey,
        debug: kDebugMode,
      );
      _url = url;
      _publishableKey = publishableKey;
      _initialized = true;
    } catch (e) {
      rethrow;
    }
  }

  /// URL الخاص بـ Supabase project
  static String? get url => _url;

  /// Publishable/Anon Key
  static String? get publishableKey => _publishableKey;

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

  /// استدعاء Edge Function مع إضافة توكن الجلسة المخصص إذا لزم الأمر
  Future<dynamic> invokeFunction(
    String functionName, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionToken = prefs.getString('staff_session_token');
    final jwt = auth.currentSession?.accessToken;

    final finalHeaders = Map<String, String>.from(headers ?? {});
    
    if (jwt != null) {
      // JWT is primary
      finalHeaders['Authorization'] = 'Bearer $jwt';
    } else if (sessionToken != null && sessionToken.isNotEmpty) {
      // Fallback to custom session token
      finalHeaders['Authorization'] = sessionToken;
    }

    return await client.functions.invoke(
      functionName,
      body: body,
      headers: finalHeaders,
    );
  }
}
