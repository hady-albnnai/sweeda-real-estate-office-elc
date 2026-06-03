import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Made static so it can be called as FirebaseService.initialize()
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      print('Firebase initialization error: $e');
    }
  }

  FirebaseFirestore get db => FirebaseFirestore.instance;
  FirebaseAuth get auth => FirebaseAuth.instance;
}
