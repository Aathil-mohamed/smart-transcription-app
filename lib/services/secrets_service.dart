import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';

class SecretsService {
  final AppConfig _config;
  final FlutterSecureStorage _secureStorage;

  SecretsService(
    this._config, {
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Migrates legacy SharedPreferences API key entry into secure storage on first launch.
  Future<void> migrateLegacyPreferences(SharedPreferences prefs) async {
    final legacyKey = prefs.getString(_config.preferences.keyLegacyCustomApiKey);
    if (legacyKey != null && legacyKey.trim().isNotEmpty) {
      // Store in secure storage
      await setGroqApiKey(legacyKey.trim());
      // Delete old plaintext entry
      await prefs.remove(_config.preferences.keyLegacyCustomApiKey);
    }
  }

  /// Retrieve the Groq API Key:
  /// 1. Reads user-entered key from FlutterSecureStorage
  /// 2. Falls back to compile-time --dart-define-from-file=env/secrets.json
  Future<String?> getGroqApiKey() async {
    return _resolveKey(
      secureStorageKey: _config.secrets.secureStorageKeyGroqApiKey,
      dartDefineKey: _config.secrets.dartDefineKeyGroqApiKey,
    );
  }

  /// Store or clear user-entered Groq API Key in secure storage
  Future<void> setGroqApiKey(String? apiKey) async {
    await _writeKey(
      secureStorageKey: _config.secrets.secureStorageKeyGroqApiKey,
      value: apiKey,
    );
  }

  /// Retrieve the Gemini API Key:
  /// 1. Reads user-entered key from FlutterSecureStorage
  /// 2. Falls back to compile-time --dart-define-from-file=env/secrets.json
  Future<String?> getGeminiApiKey() async {
    return _resolveKey(
      secureStorageKey: _config.secrets.secureStorageKeyGeminiApiKey,
      dartDefineKey: _config.secrets.dartDefineKeyGeminiApiKey,
    );
  }

  /// Store or clear user-entered Gemini API Key in secure storage
  Future<void> setGeminiApiKey(String? apiKey) async {
    await _writeKey(
      secureStorageKey: _config.secrets.secureStorageKeyGeminiApiKey,
      value: apiKey,
    );
  }

  /// Retrieve the Google Translate API Key:
  /// 1. Reads user-entered key from FlutterSecureStorage
  /// 2. Falls back to compile-time --dart-define-from-file=env/secrets.json
  Future<String?> getGoogleTranslateApiKey() async {
    return _resolveKey(
      secureStorageKey: _config.secrets.secureStorageKeyGoogleTranslateApiKey,
      dartDefineKey: _config.secrets.dartDefineKeyGoogleTranslateApiKey,
    );
  }

  /// Store or clear user-entered Google Translate API Key in secure storage
  Future<void> setGoogleTranslateApiKey(String? apiKey) async {
    await _writeKey(
      secureStorageKey: _config.secrets.secureStorageKeyGoogleTranslateApiKey,
      value: apiKey,
    );
  }

  /// Helper to resolve a key from secure storage first, then --dart-define, otherwise null.
  Future<String?> _resolveKey({
    required String secureStorageKey,
    required String dartDefineKey,
  }) async {
    try {
      final userKey = await _secureStorage.read(key: secureStorageKey);
      if (userKey != null && userKey.trim().isNotEmpty) {
        return userKey.trim();
      }
    } catch (_) {
      // Secure storage unavailable or errored; proceed to fallback
    }

    final envKey = String.fromEnvironment(dartDefineKey);
    if (envKey.trim().isNotEmpty) {
      return envKey.trim();
    }

    return null;
  }

  Future<void> _writeKey({
    required String secureStorageKey,
    required String? value,
  }) async {
    if (value == null || value.trim().isEmpty) {
      await _secureStorage.delete(key: secureStorageKey);
    } else {
      await _secureStorage.write(
        key: secureStorageKey,
        value: value.trim(),
      );
    }
  }

  /// Verifies if a usable Groq API key is configured (non-empty).
  Future<bool> hasValidApiKey() async {
    final key = await getGroqApiKey();
    return key != null && key.isNotEmpty;
  }
}

final secretsServiceProvider = Provider<SecretsService>((ref) {
  final config = ref.watch(appConfigProvider);
  return SecretsService(config);
});
