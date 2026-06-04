import 'package:flutter/foundation.dart';
import '../models/config_model.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';

class ConfigProvider extends ChangeNotifier {
  ConfigModel? _config;
  bool _isLoading = false;
  String? _error;

  ConfigModel? get config => _config;
  bool get isLoading => _isLoading;
  bool get isReady => _config != null;
  String? get error => _error;

  Future<void> loadConfig() async {
    if (_config != null) return;
    _isLoading = true; _error = null; notifyListeners();
    try {
      final response = await SupabaseService().client
          .from(DbTables.appConfig).select('value')
          .eq('key', ConfigKeys.main).maybeSingle();
      if (response != null && response['value'] != null) {
        _config = ConfigModel.fromJson(
          Map<String, dynamic>.from(response['value'] as Map));
      } else {
        _error = 'Config غير موجود في Supabase';
      }
    } catch (e) {
      _error = 'فشل تحميل Config: $e';
    }
    _isLoading = false; notifyListeners();
  }

  Future<bool> updateConfig(Map<String, dynamic> newConfig) async {
    try {
      await SupabaseService().client.from(DbTables.appConfig)
          .update({'value': newConfig}).eq('key', ConfigKeys.main);
      _config = ConfigModel.fromJson(newConfig);
      notifyListeners(); return true;
    } catch (e) {
      debugPrint('❌ updateConfig error: $e'); return false;
    }
  }

  void listenToConfigChanges() {
    SupabaseService().client.from(DbTables.appConfig)
        .stream(primaryKey: ['key']).listen((data) {
      for (var row in data) {
        if (row['key'] == ConfigKeys.main && row['value'] != null) {
          _config = ConfigModel.fromJson(
            Map<String, dynamic>.from(row['value'] as Map));
          notifyListeners();
        }
      }
    });
  }
}
