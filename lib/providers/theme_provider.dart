import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';
import '../services/secrets_service.dart';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  final Ref _ref;

  ThemeNotifier(this._ref) : super(ThemeMode.dark) {
    _loadTheme();
  }

  // Load persisted theme and run migration
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final config = _ref.read(appConfigProvider);

    // Migrate old SharedPreferences key into secure storage on first launch
    await _ref.read(secretsServiceProvider).migrateLegacyPreferences(prefs);

    final isDark = prefs.getBool(config.preferences.keyThemeMode) ?? true;
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  // Toggle Theme between Light & Dark
  Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final config = _ref.read(appConfigProvider);
    if (state == ThemeMode.dark) {
      state = ThemeMode.light;
      await prefs.setBool(config.preferences.keyThemeMode, false);
    } else {
      state = ThemeMode.dark;
      await prefs.setBool(config.preferences.keyThemeMode, true);
    }
  }

  // Set specific ThemeMode
  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final config = _ref.read(appConfigProvider);
    state = mode;
    await prefs.setBool(config.preferences.keyThemeMode, mode == ThemeMode.dark);
  }

  // Custom API key backward-compatible delegates
  Future<void> setCustomApiKey(String key) async {
    await _ref.read(secretsServiceProvider).setGroqApiKey(key);
  }

  Future<String> getCustomApiKey() async {
    return (await _ref.read(secretsServiceProvider).getGroqApiKey()) ?? '';
  }
}

// Global theme notifier provider
final themeNotifierProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier(ref);
});
