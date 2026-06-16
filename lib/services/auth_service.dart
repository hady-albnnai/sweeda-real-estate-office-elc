import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';

/// قنوات تسجيل الدخول المدعومة
enum AuthChannel { whatsapp, email, sms }

class AuthService {
  final GoTrueClient _auth = SupabaseService().auth;
  final SupabaseClient _client = SupabaseService().client;

  // ════════════════════════════════════════════════════════════════════════
  // 📱 WhatsApp OTP — عبر Edge Function (Meta WhatsApp Cloud API)
  // ════════════════════════════════════════════════════════════════════════

  /// إرسال رمز OTP عبر واتساب.
  /// [phone] رقم محلي بدون مفتاح (مثلاً 09XXXXXXXX) أو بصيغة دولية كاملة.
  Future<Map<String, dynamic>> sendWhatsAppOTP(String phone) async {
    final fullPhone = _normalizePhone(phone);
    try {
      final res = await _client.functions.invoke(
        'send-whatsapp-otp',
        body: {'phone': fullPhone},
      );

      final data = res.data as Map<String, dynamic>?;
      if (data == null) {
        return {'success': false, 'error': 'EMPTY_RESPONSE'};
      }

      if (data['success'] == true) {
        // وضع التطوير: يرجّع الـ OTP لو ما إعدّاد Meta
        final devOtp = data['otp']?.toString();
        if (devOtp != null) {}
        return {
          'success': true,
          'channel': 'whatsapp',
          if (devOtp != null) 'fallbackOtp': devOtp,
        };
      }

      return {'success': false, 'error': data['error'] ?? 'UNKNOWN'};
    } catch (e) {// Fallback: استخدم RPC المحلية مباشرة (للتطوير فقط)
      return _devFallbackOtp(fullPhone);
    }
  }

  /// التحقق من رمز OTP الواتساب.
  Future<Map<String, dynamic>> verifyWhatsAppOTP(
      String phone, String code) async {
    final fullPhone = _normalizePhone(phone);
    try {
      final res = await _client.functions.invoke(
        'verify-whatsapp-otp',
        body: {'phone': fullPhone, 'code': code},
      );

      final data = res.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        return {
          'success': false,
          'error': data?['error'] ?? 'VERIFICATION_FAILED',
        };
      }

      // استرجاع session من token_hash المعاد
      final session = data['session'] as Map<String, dynamic>?;
      if (session != null && session['token_hash'] != null) {
        try {
          await _auth.verifyOTP(
            type: OtpType.magiclink,
            tokenHash: session['token_hash'] as String,
          );
        } catch (e) {
      // تم تجاهل الخطأ عمداً للحفاظ على التدفق الحالي.
    }
      }

      final userId = data['userId'] as String;
      final isNew = data['isNew'] as bool? ?? false;

      await _persistSession(userId, phone: fullPhone);

      return {'success': true, 'userId': userId, 'isNewUser': isNew};
    } catch (e) {// Fallback: التحقق المحلي مباشرة (للتطوير)
      return _devFallbackVerify(fullPhone, code);
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
  /// يتأكد من وجود user في جدول users (يُنشئه لو جديد).
  Future<Map<String, dynamic>> handleEmailSession() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'error': 'NO_SESSION'};
      }

      final email = user.email ?? '';
      if (email.isEmpty) {
        return {'success': false, 'error': 'NO_EMAIL'};
      }

      // ابحث في جدولنا
      final existing = await _client
          .from(DbTables.users)
          .select('id')
          .eq('eml', email)
          .eq('i_del', 0);

      String userId;
      bool isNew;

      if (existing.isEmpty) {
        final inserted = await _client.from(DbTables.users).insert({
          'nm': '',
          'ph': '',
          'eml': email,
          'role': 0,
          'sts': 0,
          'i_del': 0,
          'ts_crt': DateTime.now().toIso8601String(),
        }).select().single();
        userId = inserted['id'] as String;
        isNew = true;
      } else {
        userId = existing[0]['id'] as String;
        isNew = false;
      }

      await _persistSession(userId, email: email);
      return {'success': true, 'userId': userId, 'isNewUser': isNew};
    } catch (e) {return {'success': false, 'error': e.toString()};
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 🔁 طرق توافقية مع الكود القديم (تم إبقاؤها)
  // ════════════════════════════════════════════════════════════════════════

  /// طريقة قديمة — توجّه الآن إلى WhatsApp (للتوافق فقط)
  @Deprecated('استخدم sendWhatsAppOTP بدلاً من ذلك')
  Future<Map<String, dynamic>> sendOTP(String phone) =>
      sendWhatsAppOTP(phone);

  /// طريقة قديمة — توجّه الآن إلى WhatsApp (للتوافق فقط)
  @Deprecated('استخدم verifyWhatsAppOTP بدلاً من ذلك')
  Future<Map<String, dynamic>> verifyOTP(String phone, String code) =>
      verifyWhatsAppOTP(phone, code);

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
          await _client.rpc('revoke_staff_session', params: {
            'p_user_uid': userId,
            'p_token': staffToken,
          });
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
        'auth_channel', email != null ? 'email' : 'whatsapp');
  }

  // ───────── Dev fallback (لما تكون Edge Function ما تشتغل بعد) ─────────

  // Dev fallback — معدل ليتطابق مع الدوال الموجودة فعلياً على السيرفر
  // (generate_otp و verify_otp الأساسيين موجودين، الـ v2 غير موجودة)
  Future<Map<String, dynamic>> _devFallbackOtp(String fullPhone) async {
    try {
      final code = await _client.rpc(
        'generate_otp',
        params: {'p_phone': fullPhone},
      );
      return {'success': true, 'fallbackOtp': code, 'channel': 'whatsapp'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _devFallbackVerify(
      String fullPhone, String code) async {
    try {
      final ok = await _client.rpc(
        'verify_otp',
        params: {'p_phone': fullPhone, 'p_code': code},
      );
      if (ok != true) {
        return {'success': false, 'error': 'INVALID_CODE'};
      }
      // استخدام upsert_user_after_otp (موجود على السيرفر)
      final rows = await _client.rpc(
        'upsert_user_after_otp',
        params: {'p_identifier': fullPhone, 'p_channel': 'whatsapp'},
      );
      final row = (rows as List).first as Map<String, dynamic>;
      await _persistSession(row['user_id'] as String, phone: fullPhone);
      return {
        'success': true,
        'userId': row['user_id'],
        'isNewUser': row['is_new'] ?? false,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
