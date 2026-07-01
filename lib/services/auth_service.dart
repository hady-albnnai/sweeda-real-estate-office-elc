import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/supabase_service.dart';

/// قنوات تسجيل الدخول المدعومة
enum AuthChannel { email, sms }

class AuthService {
  final GoTrueClient _auth = SupabaseService().auth;
  final SupabaseClient _client = SupabaseService().client;

  // ════════════════════════════════════════════════════════════════════════
  // 📱 SMS OTP — عبر Edge Function (textbee.dev)
  // ════════════════════════════════════════════════════════════════════════

  /// إرسال رمز OTP عبر SMS (TextBee).
  Future<Map<String, dynamic>> sendSMSOTP(String phone) async {
    final fullPhone = _normalizePhone(phone);
    try {
      final res = await SupabaseService().invokeFunction(
        'send-sms-otp',
        body: {'phone': fullPhone},
      );

      final data = res.data as Map<String, dynamic>?;
      if (data == null) {
        return {'success': false, 'error': 'EMPTY_RESPONSE'};
      }

      if (data['success'] == true) {
        final devOtp = data['otp']?.toString();
        return {
          'success': true,
          'channel': 'sms',
          if (devOtp != null) 'fallbackOtp': devOtp,
        };
      }

      return {'success': false, 'error': data['error'] ?? 'UNKNOWN'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// التحقق من رمز OTP الـ SMS.
  /// لا ينفّذ verify/upsert مباشرة من العميل؛ كل العملية تتم داخل Edge Function.
  Future<Map<String, dynamic>> verifySMSOTP(String phone, String code) async {
    final fullPhone = _normalizePhone(phone);
    try {
      final res = await SupabaseService().invokeFunction(
        'verify-sms-otp',
        body: {'phone': fullPhone, 'code': code.trim()},
      );

      final data = res.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        return {
          'success': false,
          'error': data?['error'] ?? 'VERIFICATION_FAILED',
        };
      }

      final session = data['session'] as Map<String, dynamic>?;
      if (session != null && session['token_hash'] != null) {
        try {
          await _auth.verifyOTP(
            type: OtpType.email,
            tokenHash: session['token_hash'] as String,
          );
        } catch (e) {
          return {
            'success': false,
            'error': 'verifyOTP_error: ${e.toString()}',
          };
        }
      }

      final userId = data['userId'] as String;
      final isNew = data['isNew'] as bool? ?? false;
      await _persistSession(userId, phone: fullPhone);
      return {'success': true, 'userId': userId, 'isNewUser': isNew};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 📧 Email Magic Link — Supabase Auth المدمج
  // ════════════════════════════════════════════════════════════════════════

  /// إرسال رابط سحري إلى البريد الإلكتروني.
  /// المستخدم يضغط الرابط في إيميله ويعود للتطبيق عبر deep link.
  Future<Map<String, dynamic>> sendEmailMagicLink(String email) async {
    try {
      await _auth.signInWithOtp(
        email: email,
        emailRedirectTo: 'io.supabase.sweeda://login-callback',
      );return {'success': true, 'channel': 'email'};
    } catch (e) {return {'success': false, 'error': e.toString()};
    }
  }

  /// يُستدعى تلقائياً بعد ما يضغط المستخدم رابط الإيميل ويفتح التطبيق.
  /// لا ينشئ المستخدم من العميل مباشرة؛ يستدعي RPC آمنة تقرأ الإيميل من JWT.
  Future<Map<String, dynamic>> handleEmailSession() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'error': 'NO_SESSION'};
      }

      final result = await SupabaseService().invokeFunction(
        'user-account',
        body: {
          'action': 'handle_email_auth',
        },
      );
      final data = result.data is Map ? Map<String, dynamic>.from(result.data) : null;
      if (data == null || data['success'] != true) {
        return {'success': false, 'error': data?['error'] ?? 'EMAIL_AUTH_FAILED'};
      }

      final userId = data['user_id']?.toString();
      final email = data['email']?.toString() ?? user.email ?? '';
      if (userId == null || userId.isEmpty) {
        return {'success': false, 'error': 'NO_USER_ID'};
      }

      final isNew = data['is_new'] == true;
      await _persistSession(userId, email: email);
      return {'success': true, 'userId': userId, 'isNewUser': isNew};
    } catch (e) {return {'success': false, 'error': e.toString()};
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 🚪 خروج + Session helpers
  // ════════════════════════════════════════════════════════════════════════

  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final staffToken = prefs.getString('staff_session_token');

      if (userId != null && staffToken != null && staffToken.isNotEmpty) {
        try {
          await SupabaseService().invokeFunction(
            'user-account',
            body: {
              'action': 'revoke_staff_session',
              'user_uid': userId,
              'session_token': staffToken,
            },
          );
        } catch (e) {
      // تم تجاهل الخطأ عمداً للحفاظ على التدفق الحالي.
    }
      }

      await _auth.signOut();
      await prefs.remove('user_id');
      await prefs.remove('user_phone');
      await prefs.remove('user_email');
      await prefs.remove('auth_channel');
      await prefs.remove('staff_session_token');
      await prefs.remove('staff_session_expires_at');
    } catch (e) {
      // تم تجاهل الخطأ عمداً للحفاظ على التدفق الحالي.
    }
  }

  Future<String?> getStaffSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('staff_session_token');
  }

  Future<String?> getSavedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  Future<String?> getSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_phone');
  }

  Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_email');
  }

  // ════════════════════════════════════════════════════════════════════════
  // Helpers
  // ════════════════════════════════════════════════════════════════════════

  String _normalizePhone(String phone) {
    var value = phone.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    if (value.startsWith('+963')) return value;
    if (value.startsWith('00963')) return '+963${value.substring(5)}';
    if (value.startsWith('963')) return '+$value';
    if (value.startsWith('0')) return '+963${value.substring(1)}';
    if (value.startsWith('9')) return '+963$value';
    if (value.startsWith('+')) return value;
    return '+963$value';
  }

  Future<void> _persistSession(String userId,
      {String? phone, String? email}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    if (phone != null) await prefs.setString('user_phone', phone);
    if (email != null) await prefs.setString('user_email', email);
    await prefs.setString(
        'auth_channel', email != null ? 'email' : 'sms');
  }
}
