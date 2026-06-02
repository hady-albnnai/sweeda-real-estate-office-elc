import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_constants.dart';
import '../models/user_model.dart';

/// مزود المصادقة — OTP عبر رقم الموبايل
class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  String? _verificationId;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  String? get error => _error;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isBroker => _user?.isBroker ?? false;

  /// تسجيل الدخول برقم الموبايل (إرسال OTP)
  Future<void> sendOTP(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (credential) async {
          await _signIn(credential);
        },
        verificationFailed: (error) {
          _error = 'فشل إرسال رمز التحقق: ${error.message}';
          _isLoading = false;
          notifyListeners();
        },
        codeSent: (verificationId, forceResendingToken) {
          _verificationId = verificationId;
          _isLoading = false;
          notifyListeners();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      _error = 'حدث خطأ: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// تأكيد OTP
  Future<bool> verifyOTP(String code) async {
    if (_verificationId == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await _signIn(credential);
      return true;
    } catch (e) {
      _error = 'رمز التحقق غير صحيح';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _signIn(PhoneAuthCredential credential) async {
    final result = await _auth.signInWithCredential(credential);
    if (result.user != null) {
      await _loadUser(result.user!.uid);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadUser(String uid) async {
    final doc = await _firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .get();

    if (doc.exists) {
      _user = UserModel.fromFirestore(doc);
    }
  }

  /// تسجيل الخروج
  Future<void> signOut() async {
    await _auth.signOut();
    _user = null;
    notifyListeners();
  }
}