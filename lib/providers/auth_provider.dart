import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  UserModel? _userModel;
  String? _currentPhone;
  String? _currentOtp;
  bool _isNewUser = false;

  UserModel? get userModel => _userModel;
  String? get currentPhone => _currentPhone;
  String? get currentOtp => _currentOtp;
  bool get isNewUser => _isNewUser;
  bool get isLoggedIn => _userModel != null;
  bool get isAdmin => _userModel?.isAdmin ?? false;
  bool get isBroker => _userModel?.isBroker ?? false;

  Future<bool> sendOTP(String phone) async {
    try {
      _currentPhone = phone;
      final result = await AuthService().sendOTP(phone);
      if (result['success'] == true) {
        _currentOtp = result['fallbackOtp'] as String?;
        if (_currentOtp != null) {
          debugPrint('🔑 OTP for development: $_currentOtp');
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ sendOTP error: $e');
      return false;
    }
  }

  Future<bool> verifyOTP(String code) async {
    try {
      if (_currentPhone == null) return false;
      final result = await AuthService().verifyOTP(_currentPhone!, code);
      if (result['success'] == true) {
        _isNewUser = result['isNewUser'] as bool;
        await _loadUserData(result['userId'] as String);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ verifyOTP error: $e');
      return false;
    }
  }

  Future<void> _loadUserData(String userId) async {
    try {
      final response = await SupabaseService().client
          .from(DbTables.users).select().eq('id', userId).single();
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
        'nm': name, 'sid': sid,
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

  Future<void> logout() async {
    await AuthService().signOut();
    _userModel = null; _currentPhone = null; _currentOtp = null; _isNewUser = false;
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
