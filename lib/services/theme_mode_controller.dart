import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the app-wide dark/light theme mode, persisted across restarts.
/// Same singleton + ChangeNotifier pattern as LocaleController.
class ThemeModeController extends ChangeNotifier {
  ThemeModeController._();
  static final ThemeModeController instance = ThemeModeController._();

  static const _prefsKey = 'theme_mode';

  bool _isDark = true;
  bool _loaded = false;

  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool(_prefsKey) ?? true;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setDark(bool value) async {
    if (value == _isDark) return;
    _isDark = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }

  void toggle() => setDark(!_isDark);
}
