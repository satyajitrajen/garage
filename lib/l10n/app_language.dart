import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings_mr.dart';

/// App UI language. English is the source text; Marathi is looked up from
/// [marathiStrings] and falls back to English for anything untranslated.
///
/// The current code is static so [tr] works anywhere, including const-free
/// widget code without a BuildContext. Changing it notifies [instance]; the
/// app root rebuilds its MaterialApp under a new key so every screen picks
/// up the new language.
class AppLanguage extends ChangeNotifier {
  AppLanguage._();
  static final AppLanguage instance = AppLanguage._();

  static const _prefsKey = 'app_language';
  static const supported = {'en': 'English', 'mr': 'मराठी'};

  static String _code = 'en';
  static String get code => _code;

  /// Reads the saved choice; call once before runApp.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && supported.containsKey(saved)) _code = saved;
    } catch (_) {
      // Preferences unavailable (tests, first boot): stay on English.
    }
  }

  Future<void> set(String code) async {
    if (!supported.containsKey(code) || code == _code) return;
    _code = code;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, code);
    } catch (_) {}
  }
}

/// Translates an English UI string into the current language.
String tr(String english) =>
    AppLanguage.code == 'mr' ? (marathiStrings[english] ?? english) : english;
