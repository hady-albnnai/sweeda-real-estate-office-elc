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
    final storedUserId = prefs.getString('user_id') ?? currentUser?.id;
    final jwt = auth.currentSession?.accessToken;

    final finalHeaders = Map<String, String>.from(headers ?? {});
    
    if (jwt != null) {
      // JWT is primary
      finalHeaders['Authorization'] = 'Bearer $jwt';
    } else if (sessionToken != null && sessionToken.isNotEmpty) {
      // Fallback to custom session token — Kong Gateway requires Bearer prefix
      finalHeaders['Authorization'] = sessionToken.startsWith('Bearer ') ? sessionToken : 'Bearer $sessionToken';
    }

    dynamic finalBody = body;
    if (body is Map) {
      final mapBody = Map<String, dynamic>.from(body);
      if (sessionToken != null && sessionToken.isNotEmpty && mapBody['staff_session_token'] == null) {
        mapBody['staff_session_token'] = sessionToken;
      }
      if (storedUserId != null && storedUserId.isNotEmpty) {
        if (functionName.startsWith('admin-') && mapBody['admin_uid'] == null && mapBody['adminUid'] == null) {
          mapBody['admin_uid'] = storedUserId;
        }
        if (!functionName.startsWith('admin-') && mapBody['user_uid'] == null && mapBody['userUid'] == null) {
          mapBody['user_uid'] = storedUserId;
        }
      }
      finalBody = mapBody;
    }

    debugPrint('👉 [NET_DEBUG] Invoking function "$functionName" | authHeader="${finalHeaders['Authorization'] != null ? finalHeaders['Authorization']!.substring(0, 15) + '...' : 'NONE'}" | body=$finalBody');
    try {
      final res = await client.functions.invoke(
        functionName,
        body: finalBody,
        headers: finalHeaders,
      );
      debugPrint('👉 [NET_DEBUG] Success "$functionName" | status=${res.status} | data=${res.data}');
      return res;
    } catch (e) {
      debugPrint('👉 [NET_DEBUG] ERROR invoking "$functionName": $e');
      rethrow;
    }
  }
}
