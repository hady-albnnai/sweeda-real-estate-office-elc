import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_theme.dart';

class ThemeProvider with ChangeNotifier {
  static const String _storageKey = 'app_theme_mode';

  bool _isDarkMode = false;
  bool _loaded = false;

  ThemeProvider() {
    _load();
  }

  bool get isDarkMode => _isDarkMode;
  bool get isLoaded => _loaded;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getString(_storageKey) == 'dark';
    AppTheme.setDarkMode(_isDarkMode);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value && _loaded) return;
    _isDarkMode = value;
    AppTheme.setDarkMode(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, value ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> toggle() => setDarkMode(!_isDarkMode);
}
