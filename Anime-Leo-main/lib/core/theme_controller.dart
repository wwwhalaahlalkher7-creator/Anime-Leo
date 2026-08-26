import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App theme mode: light, dark, or follow the OS ("system" — added Phase 6,
/// see docs/SETTINGS_SIDEBAR_PLAN.md). Defaults to dark, matching the app's
/// existing dark-first identity.
class ThemeController extends ChangeNotifier {
  ThemeMode mode = ThemeMode.dark;

  static const _modeKey = 'theme_mode'; // 'system' | 'light' | 'dark'
  static const _legacyLightKey = 'light_mode'; // pre-Phase-6 bool-only key

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_modeKey);
    switch (stored) {
      case 'light':
        mode = ThemeMode.light;
      case 'dark':
        mode = ThemeMode.dark;
      case 'system':
        mode = ThemeMode.system;
      default:
        // No new-format value yet: migrate from the old light/dark-only bool.
        mode = (prefs.getBool(_legacyLightKey) ?? false) ? ThemeMode.light : ThemeMode.dark;
    }
    notifyListeners();
  }

  Future<void> setMode(ThemeMode value) async {
    mode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, switch (value) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
    notifyListeners();
  }

  /// Kept for the Home tab's existing quick-toggle switch, which only ever
  /// offers light vs dark.
  Future<void> setLightMode(bool enabled) => setMode(enabled ? ThemeMode.light : ThemeMode.dark);
}
