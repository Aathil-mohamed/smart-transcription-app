import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';

class SettingsRepository {
  final SharedPreferences _prefs;
  final AppConfig _config;

  SettingsRepository(this._prefs, this._config);

  bool get isLivePreviewEnabled {
    return _prefs.getBool(_config.preferences.keyLivePreviewEnabled) ??
        _config.speechToText.enabledByDefault;
  }

  Future<void> setLivePreviewEnabled(bool enabled) async {
    await _prefs.setBool(_config.preferences.keyLivePreviewEnabled, enabled);
  }

  List<String> get customVocabulary {
    return _prefs.getStringList(_config.preferences.keyCustomVocabulary) ?? const [];
  }

  Future<void> setCustomVocabulary(List<String> words) async {
    await _prefs.setStringList(_config.preferences.keyCustomVocabulary, words);
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in ProviderScope');
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final config = ref.watch(appConfigProvider);
  return SettingsRepository(prefs, config);
});
