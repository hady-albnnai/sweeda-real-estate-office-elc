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
        },
        verificationFailed: (FirebaseAuthException e) {
          print('Verification failed: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          // Handle code sent
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> verifyOTP(String code) async {
    try {
      // Note: In real app, we need verificationId from sendOTP
      // For simulation/prototype, we'll assume success or use dummy logic
      // In production, you'd use PhoneAuthProvider.credential(verificationId, smsCode)
      
      // Mocking successful login for prototype purposes
      // await _auth.signInWithCredential(...); 
      
      // Simulate user login
      _user = FirebaseAuth.instance.currentUser; 
      // This is a stub, real implementation needs the verificationId
      
      await _loadUserData();
      return true;
    } catch (e) {
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
