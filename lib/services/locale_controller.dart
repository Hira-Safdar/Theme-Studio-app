// lib/services/locale_controller.dart
//
// Real (working) language switching -- previously the Settings language
// picker only updated its own local state, nothing else in the app
// actually changed. This controller is the single source of truth for
// "which language is active", persisted across restarts, and every
// screen that shows translated text listens to it (via the ListenableBuilder
// wrapping MaterialApp in main.dart, which rebuilds the whole tree on change).
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends ChangeNotifier {
  LocaleController._();
  static final LocaleController instance = LocaleController._();

  static const _prefsKey = 'language_code';

  String languageCode = 'en';
  bool _loaded = false;

  /// App start par ek dafa call hota hai (main.dart) -- pehle se saved
  /// language load karta hai. Jab tak load na ho, English hi dikhta hai
  /// (koi flash/flicker nahi hota kyunke ye synchronous UI se pehle chalta hai).
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    languageCode = prefs.getString(_prefsKey) ?? 'en';
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    if (code == languageCode) return;
    languageCode = code;
    notifyListeners(); // UI turant badalta hai, save background mein hota hai
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, code);
  }
}