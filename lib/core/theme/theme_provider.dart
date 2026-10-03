import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Setiap preset punya warna untuk light theme dan dark theme
class ThemeColorPreset {
  final String label;
  final Color light;
  final Color dark;

  const ThemeColorPreset({
    required this.label,
    required this.light,
    required this.dark,
  });
}

const List<ThemeColorPreset> kThemeColorPresets = [
  ThemeColorPreset(
    label: "Biru",
    light: Color(0xFF5B9BD5), // kPrimary - default awal
    dark: Color(0xFFA7C6ED), // kPastelBlue - default awal
  ),
  ThemeColorPreset(
    label: "Oranye",
    light: Color(0xFFE8956E),
    dark: Color(0xFFFFCBA4),
  ),
  ThemeColorPreset(
    label: "Hijau",
    light: Color(0xFF6FAE8C),
    dark: Color(0xFFB8E0C8),
  ),
  ThemeColorPreset(
    label: "Ungu",
    light: Color(0xFFA98ACB),
    dark: Color(0xFFD7BCE8),
  ),
  ThemeColorPreset(
    label: "Pink",
    light: Color(0xFFE391AE),
    dark: Color(0xFFF8C8DC),
  ),
];

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  int _seedColorIndex = 0; // default index 0 = Biru

  ThemeMode get themeMode => _themeMode;
  int get seedColorIndex => _seedColorIndex;

  Color get seedColorLight => kThemeColorPresets[_seedColorIndex].light;
  Color get seedColorDark => kThemeColorPresets[_seedColorIndex].dark;

  ThemeProvider() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('themeMode') ?? 0;
    _themeMode = ThemeMode.values[themeIndex];

    final colorIndex = prefs.getInt('seedColorIndex') ?? 0;
    if (colorIndex >= 0 && colorIndex < kThemeColorPresets.length) {
      _seedColorIndex = colorIndex;
    }
    notifyListeners();
  }

  Future<void> changeTheme(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
  }

  Future<void> changeColor(int index) async {
    if (index < 0 || index >= kThemeColorPresets.length) return;
    _seedColorIndex = index;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('seedColorIndex', index);
  }
}
