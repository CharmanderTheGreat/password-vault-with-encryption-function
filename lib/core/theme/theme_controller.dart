import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'color_palette.dart';

/// Holds the current light/dark preference AND the selected color
/// palette, persisting both across app restarts. Entirely local — no
/// network involved.
class ThemeController extends ChangeNotifier {
  static const _modeKey = 'theme_mode';
  static const _paletteKey = 'theme_palette';

  ThemeMode _mode = ThemeMode.dark;
  AppPalette _palette = kAppPalettes.first;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;
  AppPalette get palette => _palette;

  ThemeController() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_modeKey);
    final savedPaletteId = prefs.getString(_paletteKey);

    if (savedMode == 'light') {
      _mode = ThemeMode.light;
    }
    if (savedPaletteId != null) {
      _palette = paletteById(savedPaletteId);
    }
    notifyListeners();
  }

  Future<void> toggle() async {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, _mode == ThemeMode.dark ? 'dark' : 'light');
  }

  Future<void> setDark(bool dark) async {
    _mode = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, dark ? 'dark' : 'light');
  }

  Future<void> setPalette(AppPalette newPalette) async {
    _palette = newPalette;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_paletteKey, newPalette.id);
  }
}
