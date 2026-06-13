import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';
import '../core/services/business_service.dart';
import '../core/services/device_service.dart';
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
  bool get isInternal => _userModel?.isInternal ?? false;
  bool get isPhotographer => _userModel?.isPhotographer ?? false;
  bool get isSupervisor => _userModel?.isSupervisor ?? false;
  bool get isEmployee => _userModel?.isEmployee ?? false;
  bool get isSenior => _userModel?.isSenior ?? false;
  bool get isManager => _userModel?.isManager ?? false;

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
        if (_currentOtp != null) {}
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {return false;
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
    } catch (e) {return false;
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
    } catch (e) {return false;
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
    } catch (e) {return false;
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
      // 🔒 Phase 8 fix: نستخدم RPC SECURITY DEFINER لتجاوز RLS
      // (تطبيقنا يستخدم OTP محلي لا يمر بـSupabase Auth → auth.uid()=NULL)
      final response = await SupabaseService()
          .client
          .rpc('get_user_full_by_id', params: {'p_uid': userId});
      if (response == null || (response as List).isEmpty) {return;
      }
      final row = Map<String, dynamic>.from(response.first);
      _userModel = UserModel.fromSupabase(row, userId);
      notifyListeners();
      DeviceService().registerWithServer();
    } catch (e) {}
  }

  Future<bool> completeProfile({required String name, required String sid}) async {
    try {
      if (_userModel == null) return false;
      await SupabaseService().client.rpc(
        'update_user_profile_internal',
        params: {
          'p_user_uid': _userModel!.uid,
          'p_payload': {
            'nm': name,
            'sid': sid,
          },
        },
      );
      await _loadUserData(_userModel!.uid);
      return true;
    } catch (e) {return false;
    }
  }

  Future<void> refreshUser() async {
    final userId = await AuthService().getSavedUserId();
    if (userId != null) await _loadUserData(userId);
  }

  String? _lastDailyStreakCheckDate;

  String _getSyriaDateString(DateTime dt) {
    final syria = dt.toUtc().add(const Duration(hours: 3));
    return '${syria.year.toString().padLeft(4, '0')}-'
        '${syria.month.toString().padLeft(2, '0')}-'
        '${syria.day.toString().padLeft(2, '0')}';
  }

  Future<Map<String, dynamic>> registerStreak(dynamic config) async {
    if (_userModel == null) return {'streak': 0, 'changed': false};
    // الإدارة لا تحتاج streak أو نقاط يومية
    if (_userModel!.isAdmin) return {'streak': 0, 'changed': false, 'awarded': false};

    final todayStr = _getSyriaDateString(DateTime.now());

    // Deep guard 1: use loaded userModel.strkDt (from DB on app start/login) as primary source of truth.
    // This prevents awards on every app open/close/kill-restart, even if _lastDailyStreakCheckDate is reset (new provider instance).
    if (_userModel!.strkDt != null) {
      final lastStr = _getSyriaDateString(_userModel!.strkDt!);
      if (lastStr == todayStr) {
        _lastDailyStreakCheckDate = todayStr; // sync in-memory for this session
        return {
          'streak': _userModel!.strk,
          'changed': false,
          'awarded': false,
        };
      }
    }

    // In-memory guard (for navigation/rebuilds within same session)
    if (_lastDailyStreakCheckDate == todayStr) {
      return {
        'streak': _userModel!.strk,
        'changed': false,
        'awarded': false,
      };
    }

    final result =
        await BusinessService().registerDailyStreak(_userModel!.uid, config);

    _lastDailyStreakCheckDate = todayStr;

    if (result['changed'] == true) {
      // immediate local update for strkDt so subsequent guards (even without full refresh) see it
      // then refresh from server for full consistency
      await _loadUserData(_userModel!.uid);
    }

    // فحص تسجيل الدخول الأسبوعي (يُستدعى فقط إذا مررنا الجارد اليومي)
    await _checkWeeklyLogin(config);
    return result;
  }

  /// يستدعي RPC register_weekly_login لمنح نقاط wkL أسبوعياً
  Future<void> _checkWeeklyLogin(dynamic config) async {
    if (_userModel == null) return;
    try {
      final pts = config?.weeklyLoginPoints ?? 100;
      final granted = await SupabaseService().client.rpc(
        'register_weekly_login',
        params: {'p_uid': _userModel!.uid, 'p_pts': pts},
      );
      if (granted == true) {await _loadUserData(_userModel!.uid);
      }
    } catch (e) {}
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
    _lastDailyStreakCheckDate = null;
    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    try {
      final userId = await AuthService().getSavedUserId();
      if (userId != null) await _loadUserData(userId);
    } catch (e) {}
  }
}
