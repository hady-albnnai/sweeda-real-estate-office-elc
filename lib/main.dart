import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/network/firebase_service.dart';
import 'providers/config_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  final firebaseService = FirebaseService();
  await firebaseService.init();

  runApp(const MyApp());
}

// Since ConfigProvider.loadConfig() needs a context or to be called after runApp,
// we can handle it in a Splash screen or via a custom provider initialization.
// For now, we'll ensure it's called within the app flow.
