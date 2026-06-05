import 'package:flutter/foundation.dart';
import '../models/config_model.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';
import '../core/services/local_cache_service.dart';

/// مزوّد إعدادات التطبيق الديناميكية (app_config / key=main)
///
/// استراتيجية التحميل:
/// 1. تحميل فوري من كاش Hive (إن وُجد) للعرض السريع/دون اتصال
/// 2. تحديث من Supabase في الخلفية + حفظ النسخة الجديدة في الكاش
class ConfigProvider extends ChangeNotifier {
  ConfigModel? _config;
  bool _isLoading = false;
  String? _error;
  bool _fromCache = false;

  ConfigModel? get config => _config;
  bool get isLoading => _isLoading;
  bool get isReady => _config != null;
  bool get fromCache => _fromCache;
  String? get error => _error;

  /// تحميل الإعدادات (كاش أولاً ثم تحديث من السيرفر)
  Future<void> loadConfig({bool force = false}) async {
    if (_config != null && !force) return;

    // 1) محاولة التحميل من الكاش المحلي للعرض الفوري
    final cached = LocalCacheService().getConfig();
    if (cached != null && _config == null) {
      _config = ConfigModel.fromJson(cached);
      _fromCache = true;
      notifyListeners();
    }

    // 2) التحديث من Supabase
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await SupabaseService()
          .client
          .from(DbTables.appConfig)
          .select('value')
          .eq('key', ConfigKeys.main)
          .maybeSingle();
      if (response != null && response['value'] != null) {
        final data = Map<String, dynamic>.from(response['value'] as Map);
        _config = ConfigModel.fromJson(data);
        _fromCache = false;
        // حفظ في الكاش
        await LocalCacheService().saveConfig(data);
      } else if (_config == null) {
        _error = 'Config غير موجود في Supabase';
      }
    } catch (e) {
      // لو فشل السيرفر والكاش موجود، نكمل بالكاش
      if (_config == null) {
        _error = 'فشل تحميل Config: $e';
      } else {
        debugPrint('⚠️ Config: استخدام الكاش (تعذّر الاتصال): $e');
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateConfig(Map<String, dynamic> newConfig) async {
    try {
      await SupabaseService()
          .client
          .from(DbTables.appConfig)
          .update({'value': newConfig}).eq('key', ConfigKeys.main);
      _config = ConfigModel.fromJson(newConfig);
      _fromCache = false;
      await LocalCacheService().saveConfig(newConfig);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ updateConfig error: $e');
      return false;
    }
  }

  void listenToConfigChanges() {
    SupabaseService()
        .client
        .from(DbTables.appConfig)
        .stream(primaryKey: ['key']).listen((data) {
      for (var row in data) {
        if (row['key'] == ConfigKeys.main && row['value'] != null) {
          final map = Map<String, dynamic>.from(row['value'] as Map);
          _config = ConfigModel.fromJson(map);
          _fromCache = false;
          LocalCacheService().saveConfig(map);
          notifyListeners();
        }
      }
    });
  }
}
