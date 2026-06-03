import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';

/// Centralized Firebase services accessor.
/// Use [FirebaseService.initialize] once in main(), then access services
/// via the singleton instance: FirebaseService().db, .auth, .messaging
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  static bool _initialized = false;

  /// Initialize Firebase. Safe to call multiple times.
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _initialized = true;
      debugPrint('✅ FirebaseService: initialized');
    } catch (e) {
      debugPrint('❌ FirebaseService init error: $e');
      rethrow;
    }
  }

  FirebaseFirestore get db => FirebaseFirestore.instance;
  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseMessaging get messaging => FirebaseMessaging.instance;

  bool get isReady => _initialized;
}
