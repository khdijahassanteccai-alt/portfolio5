import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppColorPreset {
  final String name;
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color accent;

  const AppColorPreset({
    required this.name,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.accent,
  });
}

class ThemeService {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static const _prefsKey = 'theme_color_index';

  static const List<AppColorPreset> presets = [
    AppColorPreset(
      name: 'أزرق',
      primary: Color(0xFF1565C0),
      primaryDark: Color(0xFF0D47A1),
      primaryLight: Color(0xFF1E88E5),
      accent: Color(0xFF00ACC1),
    ),
    AppColorPreset(
      name: 'أخضر',
      primary: Color(0xFF2E7D32),
      primaryDark: Color(0xFF1B5E20),
      primaryLight: Color(0xFF43A047),
      accent: Color(0xFF00897B),
    ),
    AppColorPreset(
      name: 'بنفسجي',
      primary: Color(0xFF6A1B9A),
      primaryDark: Color(0xFF4A148C),
      primaryLight: Color(0xFF8E24AA),
      accent: Color(0xFF00ACC1),
    ),
    AppColorPreset(
      name: 'برتقالي',
      primary: Color(0xFFE65100),
      primaryDark: Color(0xFFBF360C),
      primaryLight: Color(0xFFF4511E),
      accent: Color(0xFFFF8F00),
    ),
    AppColorPreset(
      name: 'أحمر',
      primary: Color(0xFFC62828),
      primaryDark: Color(0xFF7F0000),
      primaryLight: Color(0xFFD32F2F),
      accent: Color(0xFFE91E63),
    ),
  ];

  final ValueNotifier<int> colorIndex = ValueNotifier<int>(0);

  AppColorPreset get current => presets[colorIndex.value];

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_prefsKey) ?? 0;
    colorIndex.value = saved.clamp(0, presets.length - 1);
  }

  Future<void> setColor(int index) async {
    if (index < 0 || index >= presets.length) return;
    colorIndex.value = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, index);
  }
}
