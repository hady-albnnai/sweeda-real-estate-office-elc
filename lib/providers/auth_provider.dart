import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';
import '../core/services/business_service.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';

class AuthProvider with ChangeNotifier {
  UserModel? _userModel;
  String? _currentPhone;
  String? _currentEmail;
  String? _currentOtp;
  AuthChannel _channel = AuthChannel.whatsapp;
  bool _isNewUser = false;

  UserModel? get userModel => _userModel;
  String? get currentPhone => _currentPhone;
  String? get currentEmail => _currentEmail;
  String? get currentOtp => _currentOtp;
  AuthChannel get channel => _channel;
  bool get isNewUser => _isNewUser;
  bool get isLoggedIn => _userModel != null;
  bool get isAdmin => _userModel?.isAdmin ?? false;
  bool get isBroker => _userModel?.isBroker ?? false;

  // ════════════════════════════════════════════════════════════════════
  // 📱 WhatsApp
  // ════════════════════════════════════════════════════════════════════

  Future<bool> sendWhatsAppOTP(String phone) async {
    try {
      _currentPhone = phone;
      _channel = AuthChannel.whatsapp;
      final result = await AuthService().sendWhatsAppOTP(phone);
      if (result['success'] == true) {
        _currentOtp = result['fallbackOtp'] as String?;
        if (_currentOtp != null) {
          debugPrint('🔑 OTP for development: $_currentOtp');
        }
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ sendWhatsAppOTP error: $e');
      return false;
    }
  }

  Future<bool> verifyWhatsAppOTP(String code) async {
    try {
      if (_currentPhone == null) return false;
      final result =
          await AuthService().verifyWhatsAppOTP(_currentPhone!, code);
      if (result['success'] == true) {
        _isNewUser = result['isNewUser'] as bool? ?? false;
        await _loadUserData(result['userId'] as String);
        // تسجيل FCM token للمستخدم الجديد
        await FCMService().registerCurrentTokenForUser();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ verifyWhatsAppOTP error: $e');
      return false;
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // 📧 Email Magic Link
  // ════════════════════════════════════════════════════════════════════

  Future<bool> sendEmailMagicLink(String email) async {
    try {
      _currentEmail = email;
      _channel = AuthChannel.email;
      final result = await AuthService().sendEmailMagicLink(email);
      notifyListeners();
      return result['success'] == true;
    } catch (e) {
      debugPrint('❌ sendEmailMagicLink error: $e');
      return false;
    }
  }

  /// يُستدعى تلقائياً عند فتح التطبيق من deep link الماجيك لينك
  Future<bool> handleEmailSession() async {
    try {
      final result = await AuthService().handleEmailSession();
      if (result['success'] == true) {
        _isNewUser = result['isNewUser'] as bool? ?? false;
        await _loadUserData(result['userId'] as String);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ handleEmailSession error: $e');
      return false;
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // 🔁 توافقية مع الكود القديم
  // ════════════════════════════════════════════════════════════════════

  @Deprecated('استخدم sendWhatsAppOTP')
  Future<bool> sendOTP(String phone) => sendWhatsAppOTP(phone);

  @Deprecated('استخدم verifyWhatsAppOTP')
  Future<bool> verifyOTP(String code) => verifyWhatsAppOTP(code);

  // ════════════════════════════════════════════════════════════════════
  // المستخدم
  // ════════════════════════════════════════════════════════════════════

  Future<void> _loadUserData(String userId) async {
    try {
      final response = await SupabaseService()
          .client
          .from(DbTables.users)
          .select()
          .eq('id', userId)
          .single();
      _userModel = UserModel.fromSupabase(response, userId);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ _loadUserData error: $e');
    }
  }

  Future<bool> completeProfile({required String name, required String sid}) async {
    try {
      if (_userModel == null) return false;
      await SupabaseService().client.from(DbTables.users).update({
        'nm': name,
        'sid': sid,
        'ts_upd': DateTime.now().toIso8601String(),
      }).eq('id', _userModel!.uid);
      await _loadUserData(_userModel!.uid);
      return true;
    } catch (e) {
      debugPrint('❌ completeProfile error: $e');
      return false;
    }
  }

  Future<void> refreshUser() async {
    final userId = await AuthService().getSavedUserId();
    if (userId != null) await _loadUserData(userId);
  }

  Future<Map<String, dynamic>> registerStreak(dynamic config) async {
    if (_userModel == null) return {'streak': 0, 'changed': false};
    final result =
        await BusinessService().registerDailyStreak(_userModel!.uid, config);
    if (result['changed'] == true) {
      await _loadUserData(_userModel!.uid);
    }
    // فحص تسجيل الدخول الأسبوعي
    await _checkWeeklyLogin(config);
    return result;
  }

  /// يستدعي RPC register_weekly_login لمنح نقاط wkL أسبوعياً
  Future<void> _checkWeeklyLogin(dynamic config) async {
    if (_userModel == null) return;
    try {
      final pts = config?.weeklyLoginPoints ?? 500;
      final granted = await SupabaseService().client.rpc(
        'register_weekly_login',
        params: {'p_uid': _userModel!.uid, 'p_pts': pts},
      );
      if (granted == true) {
        debugPrint('✅ wk_lgn granted +$pts to ${_userModel!.uid}');
        await _loadUserData(_userModel!.uid);
      }
    } catch (e) {
      debugPrint('⚠️ register_weekly_login failed: $e');
    }
  }

  Future<void> logout() async {
    // إلغاء FCM token قبل تسجيل الخروج
    await FCMService().unregisterDevice();
    await AuthService().signOut();
    _userModel = null;
    _currentPhone = null;
    _currentEmail = null;
    _currentOtp = null;
    _isNewUser = false;
    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    try {
      final userId = await AuthService().getSavedUserId();
      if (userId != null) await _loadUserData(userId);
    } catch (e) {
      debugPrint('⚠️ checkAuthStatus error: $e');
    }
  }
}
