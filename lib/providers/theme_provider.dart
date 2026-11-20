import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.dark) {
    _loadTheme();
  }

  // Load persisted theme
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(AppConstants.keyThemeMode) ?? true; // Default to dark mode
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  // Toggle Theme between Light & Dark
  Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (state == ThemeMode.dark) {
      state = ThemeMode.light;
      await prefs.setBool(AppConstants.keyThemeMode, false);
    } else {
      state = ThemeMode.dark;
      await prefs.setBool(AppConstants.keyThemeMode, true);
    }
  }

  // Custom API key settings persistence helper
  Future<void> setCustomApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('groq_api_key_custom', key);
  }

  Future<String> getCustomApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('groq_api_key_custom') ?? '';
  }
}

// Global theme notifier provider
final themeNotifierProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});
