import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';

class AuthService {
  final GoTrueClient _auth = SupabaseService().auth;
  final SupabaseClient _client = SupabaseService().client;

  Future<Map<String, dynamic>> sendOTP(String phone) async {
    try {
      final fullPhone = '+963$phone';
      await _auth.signInWithOtp(phone: fullPhone);
      debugPrint('✅ OTP sent to $fullPhone');
      return {'success': true};
    } catch (e) {
      debugPrint('❌ sendOTP error: $e');
      try {
        final otpCode = await _client.rpc(
          DbFunctions.generateOtp,
          params: {'p_phone': '+963$phone'},
        );
        debugPrint('🔑 Fallback OTP: $otpCode');
        return {'success': true, 'fallbackOtp': otpCode};
      } catch (fallbackError) {
        return {'success': false, 'error': fallbackError.toString()};
      }
    }
  }

  Future<Map<String, dynamic>> verifyOTP(String phone, String code) async {
    try {
      final fullPhone = '+963$phone';
      final verifyResponse = await _auth.verifyOTP(
        phone: fullPhone, token: code, type: OtpType.sms,
      );

      if (verifyResponse.user == null) {
        return {'success': false, 'message': 'الرمز غير صحيح'};
      }

      bool isNewUser = false;
      String userId = verifyResponse.user!.id;

      final existingUsers = await _client
          .from(DbTables.users).select('id, nm, ph')
          .eq('ph', fullPhone).eq('i_del', 0);

      if (existingUsers.isEmpty) {
        isNewUser = true;
        final newUser = await _client.from(DbTables.users).insert({
          'ph': fullPhone, 'nm': '', 'role': 0, 'sts': 0, 'i_del': 0,
          'ts_crt': DateTime.now().toIso8601String(),
        }).select().single();
        userId = newUser['id'] as String;
        debugPrint('✅ New user created: $userId');
      } else {
        userId = existingUsers[0]['id'] as String;
        isNewUser = false;
        debugPrint('✅ Existing user found: $userId');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', userId);
      await prefs.setString('user_phone', fullPhone);

      return {'success': true, 'userId': userId, 'isNewUser': isNewUser};
    } catch (e) {
      debugPrint('❌ verifyOTP error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('user_phone');
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
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
}
