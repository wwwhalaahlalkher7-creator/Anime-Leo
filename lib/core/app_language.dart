import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App language. Arabic is the default; English can be selected from Settings.
class AppLanguage extends ChangeNotifier {
  static final AppLanguage instance = AppLanguage._();
  AppLanguage._();

  static const _key = 'app_language';
  String code = 'ar';

  bool get isArabic => code == 'ar';
  bool get isEnglish => code == 'en';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    code = prefs.getString(_key) == 'en' ? 'en' : 'ar';
    notifyListeners();
  }

  Future<void> setEnglish(bool enabled) async {
    code = enabled ? 'en' : 'ar';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
    notifyListeners();
  }

  String text(String arabic, String english) => isArabic ? arabic : english;
}
