import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../core/network/firebase_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseService().db;
  
  User? _user;
  UserModel? _userModel;
  String? _currentUserPhone;
  String? _verificationId;
  bool _isNewUser = false;

  User? get currentUser => _user;
  UserModel? get userModel => _userModel;
  String? get currentUserPhone => _currentUserPhone;
  bool get isNewUser => _isNewUser;

  // Login and OTP
  Future<bool> sendOTP(String phone) async {
    try {
      _currentUserPhone = phone;
      await _auth.verifyPhoneNumber(
        phoneNumber: '+963$phone',
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          _user = FirebaseAuth.instance.currentUser;
          await _loadUserData();
        },
        verificationFailed: (FirebaseAuthException e) {
          print('Verification failed: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
      return true;
    } catch (e) {
      print('sendOTP error: $e');
      return false;
    }
  }

  Future<bool> verifyOTP(String code) async {
    try {
      if (_verificationId == null) {
        print('verifyOTP error: verificationId is null');
        return false;
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );

      final result = await _auth.signInWithCredential(credential);
      _user = result.user;
      await _loadUserData();
      return _user != null;
    } catch (e) {
      print('verifyOTP error: $e');
      return false;
    }
  }

  Future<void> _loadUserData() async {
    if (_user == null) return;
    
    DocumentSnapshot doc = await _db.collection('users').doc(_user!.uid).get();
    if (doc.exists) {
      _userModel = UserModel.fromFirestore(doc);
      _isNewUser = false;
    } else {
      _isNewUser = true;
    }
    notifyListeners();
  }

  Future<bool> completeProfile({required String name, required String sid}) async {
    try {
      if (_user == null) return false;
      
      await _db.collection('users').doc(_user!.uid).set({
        'name': name,
        'sid': sid,
        'role': 0, // Default: User
        'dtC': Timestamp.now(),
        'dtU': Timestamp.now(),
      });
      
      await _loadUserData();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    _user = null;
    _userModel = null;
    notifyListeners();
  }
}
