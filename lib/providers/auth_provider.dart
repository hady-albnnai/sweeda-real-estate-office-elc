import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../core/network/supabase_service.dart';
import '../core/services/business_service.dart';
import '../core/services/device_service.dart';
import '../core/utils/error_utils.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';

class AuthProvider with ChangeNotifier {
  UserModel? _userModel;
  String? _currentPhone;
  String? _currentEmail;
  String? _currentOtp;
  AuthChannel _channel = AuthChannel.sms;
  bool _isNewUser = false;

  String? _lastError;

  UserModel? get userModel => _userModel;
  String? get currentPhone => _currentPhone;
  String? get currentEmail => _currentEmail;
  String? get currentOtp => _currentOtp;
  AuthChannel get channel => _channel;
  bool get isNewUser => _isNewUser;
  bool get isLoggedIn => _userModel != null;
  String? get lastError => _lastError;
  bool get isAdmin => _userModel?.isAdmin ?? false;
  bool get isBroker => _userModel?.isBroker ?? false;
  bool get isInternal => _userModel?.isInternal ?? false;
  bool get isPhotographer => _userModel?.isPhotographer ?? false;
  bool get isSupervisor => _userModel?.isSupervisor ?? false;
  bool get isEmployee => _userModel?.isEmployee ?? false;
  bool get isSenior => _userModel?.isSenior ?? false;
  bool get isManager => _userModel?.isManager ?? false;

  // ════════════════════════════════════════════════════════════════════
  // 🔑 اسم مستخدم + كلمة مرور
  // ════════════════════════════════════════════════════════════════════

  /// تسجيل الدخول باسم مستخدم/رقم هاتف + كلمة مرور
  Future<bool> loginWithPassword(String identifier, String password) async {
    try {
      // تنظيف أي جلسات قديمة لضمان عدم تعارض التوكنات
      await AuthService().signOut();
      
      _lastError = null;
      final result = await SupabaseService().invokeFunction('user-account', body: {'action': 'login_with_password', 'identifier': identifier, 'password': password});

      final respData = result.data is Map ? Map<String, dynamic>.from(result.data) : null;
      final data = respData?['result'] is Map ? Map<String, dynamic>.from(respData!['result']) : respData;
      if (data == null || data['success'] != true) {
        _lastError = 'فشل تسجيل الدخول';
        return false;
      }

      final userId = data['user_id'] as String;
      _isNewUser = false;
      await _loadUserData(userId);

      // حفظ الجلسة محلياً
      final prefs = await _getPrefs();
      await prefs.setString('user_id', userId);
      await prefs.setString('auth_channel', 'password');

      final staffSession = data['staff_session'];
      if (staffSession is Map && staffSession['success'] == true) {
        final token = staffSession['session_token']?.toString();
        final expiresAt = staffSession['expires_at']?.toString();
        if (token != null && token.isNotEmpty) {
          await prefs.setString('staff_session_token', token);
        }
        if (expiresAt != null && expiresAt.isNotEmpty) {
          await prefs.setString('staff_session_expires_at', expiresAt);
        }
      } else {
        await prefs.remove('staff_session_token');
        await prefs.remove('staff_session_expires_at');
      }

      // تسجيل FCM token
      await FCMService().registerCurrentTokenForUser();

      notifyListeners();
      return true;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('USER_NOT_FOUND')) {
        _lastError = 'لم يتم العثور على حساب بهذا الاسم أو الرقم';
      } else if (msg.contains('WRONG_PASSWORD')) {
        _lastError = 'كلمة المرور غير صحيحة';
      } else if (msg.contains('NO_PASSWORD_SET')) {
        _lastError = 'لم يتم تعيين كلمة مرور لهذا الحساب، سجّل دخولك عبر واتساب أولاً';
      } else if (msg.contains('USER_BANNED')) {
        _lastError = 'حسابك محظور';
      } else if (msg.contains('USER_FROZEN')) {
        _lastError = 'حسابك مجمّد مؤقتاً';
      } else {
        _lastError = ErrorUtils.arabicMessage(e);
      }
      return false;
    }
  }

  Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  // ════════════════════════════════════════════════════════════════════
  // 📱 WhatsApp
  // ════════════════════════════════════════════════════════════════════

  Future<bool> sendSMSOTP(String phone) async {
    try {
      final result = await AuthService().sendSMSOTP(phone);
      if (result['success'] == true) {
        if (result['fallbackOtp'] != null) {
          _lastError = 'DEBUG: ${result['fallbackOtp']}';
        }
        notifyListeners();
        return true;
      }
      _lastError = result['error'];
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifySMSOTP(String code) async {
    try {
      // تنظيف أي جلسات قديمة قبل بدء جلسة جديدة عبر OTP
      await AuthService().signOut();
      
      if (_currentPhone == null) return false;
      final result = await AuthService().verifySMSOTP(_currentPhone!, code);
      if (result['success'] == true) {
        final userId = result['userId'];
        _isNewUser = result['isNewUser'] ?? false;
        await _loadUserData(userId);
        return true;
      }
      _lastError = result['error'];
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

