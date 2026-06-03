import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/network/firebase_service.dart';
import 'providers/config_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase using the static method
  await FirebaseService.initialize();

  runApp(const MyApp());
}
