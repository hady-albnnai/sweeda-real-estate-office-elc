import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_constants.dart';
import '../core/network/firebase_service.dart';
import '../models/config_model.dart';

/// مزود Config — يُحمّل مرة واحدة ويُخزّن محلياً
class ConfigProvider extends ChangeNotifier {
  ConfigModel? _config;
  bool _isLoading = false;
  String? _error;

  ConfigModel? get config => _config;
  bool get isLoading => _isLoading;
  bool get isReady => _config != null;
  String? get error => _error;

  /// تحميل Config من Firestore
  Future<void> loadConfig() async {
    if (_config != null) return; // محمّل مسبقاً
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.config)
          .doc(ConfigKeys.main)
          .get();

      if (doc.exists) {
        _config = ConfigModel.fromJson(doc.data()!);
      } else {
        _error = 'Config غير موجود في Firestore';
      }
    } catch (e) {
      _error = 'فشل تحميل Config: $e';
    }

    _isLoading = false;
    notifyListeners();
  }
}
