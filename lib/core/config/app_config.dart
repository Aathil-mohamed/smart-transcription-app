import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiConfig {
  final String groqWhisperUrl;
  final String whisperModel;
  final double temperature;
  final String responseFormat;
  final int maxFileSizeBytes;
  final int timeoutMinutes;
  final int retries;
  final List<int> retryStatuses;

  const ApiConfig({
    required this.groqWhisperUrl,
    required this.whisperModel,
    required this.temperature,
    required this.responseFormat,
    required this.maxFileSizeBytes,
    required this.timeoutMinutes,
    required this.retries,
    required this.retryStatuses,
  });

  factory ApiConfig.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, [
      'groqWhisperUrl',
      'whisperModel',
      'temperature',
      'responseFormat',
      'maxFileSizeBytes',
      'timeoutMinutes',
    ], 'ApiConfig');

    return ApiConfig(
      groqWhisperUrl: json['groqWhisperUrl'] as String,
      whisperModel: json['whisperModel'] as String,
      temperature: (json['temperature'] as num).toDouble(),
      responseFormat: json['responseFormat'] as String,
      maxFileSizeBytes: (json['maxFileSizeBytes'] as num).toInt(),
      timeoutMinutes: (json['timeoutMinutes'] as num).toInt(),
      retries: (json['retries'] as num?)?.toInt() ?? 2,
      retryStatuses: (json['retryStatuses'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [429, 500, 502, 503, 504],
    );
  }
}

class ProviderConfig {
  final String baseUrl;
  final String model;
  final double temperature;
  final String responseFormat;
  final int timeoutSeconds;
  final int retries;
  final List<int> retryStatuses;
  final int maxUploadBytes;

  const ProviderConfig({
    required this.baseUrl,
    required this.model,
    required this.temperature,
    required this.responseFormat,
    required this.timeoutSeconds,
    required this.retries,
    required this.retryStatuses,
    required this.maxUploadBytes,
  });

  factory ProviderConfig.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, [
      'baseUrl',
      'model',
      'temperature',
      'responseFormat',
      'timeoutSeconds',
      'retries',
      'retryStatuses',
      'maxUploadBytes',
    ], 'ProviderConfig');

    return ProviderConfig(
      baseUrl: json['baseUrl'] as String,
      model: json['model'] as String,
      temperature: (json['temperature'] as num).toDouble(),
      responseFormat: json['responseFormat'] as String,
      timeoutSeconds: (json['timeoutSeconds'] as num).toInt(),
      retries: (json['retries'] as num).toInt(),
      retryStatuses: (json['retryStatuses'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
      maxUploadBytes: (json['maxUploadBytes'] as num).toInt(),
    );
  }
}

class TranscriptionConfig {
  final String defaultProvider;
  final Map<String, ProviderConfig> providers;

  const TranscriptionConfig({
    required this.defaultProvider,
    required this.providers,
  });

  factory TranscriptionConfig.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, ['defaultProvider', 'providers'], 'TranscriptionConfig');

    final rawProviders = json['providers'] as Map<String, dynamic>;
    final parsedProviders = <String, ProviderConfig>{};
    for (final entry in rawProviders.entries) {
      parsedProviders[entry.key] =
          ProviderConfig.fromJson(entry.value as Map<String, dynamic>);
    }

    return TranscriptionConfig(
      defaultProvider: json['defaultProvider'] as String,
      providers: parsedProviders,
    );
  }
}

class AudioConfig {
  final int sampleRate;
  final int numChannels;
  final String encoder;
  final int bitRate;
  final bool noiseSuppress;
  final bool echoCancel;
  final bool autoGain;
  final String recordingsFolder;
  final int amplitudeIntervalMs;
  final int secondsIntervalMs;
  final double minDb;
  final double maxDb;
  final int waveHistoryLimit;
  final String fileNamePrefix;
  final String fileExtension;

  const AudioConfig({
    required this.sampleRate,
    required this.numChannels,
    required this.encoder,
    required this.bitRate,
    required this.noiseSuppress,
    required this.echoCancel,
    required this.autoGain,
    required this.recordingsFolder,
    required this.amplitudeIntervalMs,
    required this.secondsIntervalMs,
    required this.minDb,
    required this.maxDb,
    required this.waveHistoryLimit,
    required this.fileNamePrefix,
    required this.fileExtension,
  });

  factory AudioConfig.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, [
      'sampleRate',
      'numChannels',
      'encoder',
      'amplitudeIntervalMs',
      'secondsIntervalMs',
      'minDb',
      'maxDb',
      'waveHistoryLimit',
      'fileNamePrefix',
      'fileExtension',
    ], 'AudioConfig');

    return AudioConfig(
      sampleRate: (json['sampleRate'] as num).toInt(),
      numChannels: (json['numChannels'] as num).toInt(),
      encoder: json['encoder'] as String,
      bitRate: (json['bitRate'] as num?)?.toInt() ?? 64000,
      noiseSuppress: json['noiseSuppress'] as bool? ?? true,
      echoCancel: json['echoCancel'] as bool? ?? true,
      autoGain: json['autoGain'] as bool? ?? true,
      recordingsFolder: json['recordingsFolder'] as String? ?? 'recordings',
      amplitudeIntervalMs: (json['amplitudeIntervalMs'] as num).toInt(),
      secondsIntervalMs: (json['secondsIntervalMs'] as num).toInt(),
      minDb: (json['minDb'] as num).toDouble(),
      maxDb: (json['maxDb'] as num).toDouble(),
      waveHistoryLimit: (json['waveHistoryLimit'] as num).toInt(),
      fileNamePrefix: json['fileNamePrefix'] as String,
      fileExtension: json['fileExtension'] as String,
    );
  }
}

class SpeechToTextConfig {
  final int listenForHours;
  final int pauseForSeconds;
  final String listenMode;
  final int restartDelayMs;

  const SpeechToTextConfig({
    required this.listenForHours,
    required this.pauseForSeconds,
    required this.listenMode,
    required this.restartDelayMs,
  });

  factory SpeechToTextConfig.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, [
      'listenForHours',
      'pauseForSeconds',
      'listenMode',
      'restartDelayMs',
    ], 'SpeechToTextConfig');

    return SpeechToTextConfig(
      listenForHours: (json['listenForHours'] as num).toInt(),
      pauseForSeconds: (json['pauseForSeconds'] as num).toInt(),
      listenMode: json['listenMode'] as String,
      restartDelayMs: (json['restartDelayMs'] as num).toInt(),
    );
  }
}

class LanguageConfig {
  final String id;
  final String code;
  final String storedName;
  final String name;
  final String uiLabel;
  final String displayName;
  final String speechLocale;
  final String sttLocale;
  final String? whisperLanguage;
  final String promptKey;
  final String whisperPrompt;

  const LanguageConfig({
    required this.id,
    required this.code,
    required this.storedName,
    required this.name,
    required this.uiLabel,
    required this.displayName,
    required this.speechLocale,
    required this.sttLocale,
    required this.whisperLanguage,
    required this.promptKey,
    required this.whisperPrompt,
  });

  factory LanguageConfig.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, [
      'code',
      'name',
      'displayName',
      'sttLocale',
      'whisperPrompt',
    ], 'LanguageConfig');

    final code = json['code'] as String;
    final name = json['name'] as String;
    final displayName = json['displayName'] as String;

    return LanguageConfig(
      id: json['id'] as String? ?? code,
      code: code,
      storedName: json['storedName'] as String? ?? name,
      name: name,
      uiLabel: json['uiLabel'] as String? ?? displayName,
      displayName: displayName,
      speechLocale: json['speechLocale'] as String? ?? (json['sttLocale'] as String),
      sttLocale: json['sttLocale'] as String,
      whisperLanguage: json['whisperLanguage'] as String?,
      promptKey: json['promptKey'] as String? ?? '${code}_prompt',
      whisperPrompt: json['whisperPrompt'] as String,
    );
  }
}

class FirestoreConfig {
  final String collectionUsers;
  final String collectionTranscriptions;
  final String collectionExports;
  final int pageSize;
  final bool cachePersistenceEnabled;
  final bool cacheSizeBytesUnlimited;

  const FirestoreConfig({
    required this.collectionUsers,
    required this.collectionTranscriptions,
    required this.collectionExports,
    required this.pageSize,
    required this.cachePersistenceEnabled,
    required this.cacheSizeBytesUnlimited,
  });

  factory FirestoreConfig.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, [
      'collectionUsers',
      'collectionTranscriptions',
      'collectionExports',
      'cachePersistenceEnabled',
      'cacheSizeBytesUnlimited',
    ], 'FirestoreConfig');

    return FirestoreConfig(
      collectionUsers: json['collectionUsers'] as String,
      collectionTranscriptions: json['collectionTranscriptions'] as String,
      collectionExports: json['collectionExports'] as String,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
      cachePersistenceEnabled: json['cachePersistenceEnabled'] as bool,
      cacheSizeBytesUnlimited: json['cacheSizeBytesUnlimited'] as bool,
    );
  }
}

class StorageConfig {
  final String exportsPathPattern;

  const StorageConfig({required this.exportsPathPattern});

  factory StorageConfig.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, ['exportsPathPattern'], 'StorageConfig');
    return StorageConfig(
      exportsPathPattern: json['exportsPathPattern'] as String,
    );
  }

  String buildExportPath({
    required String userId,
    required String transcriptionId,
    required String fileName,
  }) {
    return exportsPathPattern
        .replaceAll('{userId}', userId)
        .replaceAll('{transcriptionId}', transcriptionId)
        .replaceAll('{fileName}', fileName);
  }
}

class PreferencesConfig {
  final String keyThemeMode;
  final String keyUserLanguage;
  final String keyLegacyCustomApiKey;

  const PreferencesConfig({
    required this.keyThemeMode,
    required this.keyUserLanguage,
    required this.keyLegacyCustomApiKey,
  });

  factory PreferencesConfig.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, [
      'keyThemeMode',
      'keyUserLanguage',
      'keyLegacyCustomApiKey',
    ], 'PreferencesConfig');

    return PreferencesConfig(
      keyThemeMode: json['keyThemeMode'] as String,
      keyUserLanguage: json['keyUserLanguage'] as String,
      keyLegacyCustomApiKey: json['keyLegacyCustomApiKey'] as String,
    );
  }
}

class SecretsConfig {
  final String secureStorageKeyGroqApiKey;
  final String secureStorageKeyGeminiApiKey;
  final String secureStorageKeyGoogleTranslateApiKey;
  final String dartDefineKeyGroqApiKey;
  final String dartDefineKeyGeminiApiKey;
  final String dartDefineKeyGoogleTranslateApiKey;

  const SecretsConfig({
    required this.secureStorageKeyGroqApiKey,
    required this.secureStorageKeyGeminiApiKey,
    required this.secureStorageKeyGoogleTranslateApiKey,
    required this.dartDefineKeyGroqApiKey,
    required this.dartDefineKeyGeminiApiKey,
    required this.dartDefineKeyGoogleTranslateApiKey,
  });

  factory SecretsConfig.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, [
      'secureStorageKeyGroqApiKey',
      'dartDefineKeyGroqApiKey',
    ], 'SecretsConfig');

    return SecretsConfig(
      secureStorageKeyGroqApiKey: json['secureStorageKeyGroqApiKey'] as String,
      secureStorageKeyGeminiApiKey: json['secureStorageKeyGeminiApiKey'] as String? ?? 'secure_gemini_api_key',
      secureStorageKeyGoogleTranslateApiKey: json['secureStorageKeyGoogleTranslateApiKey'] as String? ?? 'secure_google_translate_api_key',
      dartDefineKeyGroqApiKey: json['dartDefineKeyGroqApiKey'] as String,
      dartDefineKeyGeminiApiKey: json['dartDefineKeyGeminiApiKey'] as String? ?? 'GEMINI_API_KEY',
      dartDefineKeyGoogleTranslateApiKey: json['dartDefineKeyGoogleTranslateApiKey'] as String? ?? 'GOOGLE_TRANSLATE_API_KEY',
    );
  }
}

class ExportConfig {
  final String pdfFontUrl;
  final String defaultPdfFileName;
  final String defaultTxtFileName;
  final String defaultDocFileName;
  final double pdfPageMargin;
  final double pdfHeaderFontSize;
  final double pdfBodyFontSize;
  final double pdfMetadataFontSize;
  final String pdfAccentColorHex;

  const ExportConfig({
    required this.pdfFontUrl,
    required this.defaultPdfFileName,
    required this.defaultTxtFileName,
    required this.defaultDocFileName,
    required this.pdfPageMargin,
    required this.pdfHeaderFontSize,
    required this.pdfBodyFontSize,
    required this.pdfMetadataFontSize,
    required this.pdfAccentColorHex,
  });

  factory ExportConfig.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, [
      'pdfFontUrl',
      'defaultPdfFileName',
      'defaultTxtFileName',
      'defaultDocFileName',
    ], 'ExportConfig');

    return ExportConfig(
      pdfFontUrl: json['pdfFontUrl'] as String,
      defaultPdfFileName: json['defaultPdfFileName'] as String,
      defaultTxtFileName: json['defaultTxtFileName'] as String,
      defaultDocFileName: json['defaultDocFileName'] as String,
      pdfPageMargin: (json['pdfPageMargin'] as num?)?.toDouble() ?? 24.0,
      pdfHeaderFontSize: (json['pdfHeaderFontSize'] as num?)?.toDouble() ?? 18.0,
      pdfBodyFontSize: (json['pdfBodyFontSize'] as num?)?.toDouble() ?? 12.0,
      pdfMetadataFontSize: (json['pdfMetadataFontSize'] as num?)?.toDouble() ?? 10.0,
      pdfAccentColorHex: json['pdfAccentColorHex'] as String? ?? '#6C5CE7',
    );
  }
}

class AppConfig {
  final ApiConfig api;
  final TranscriptionConfig? transcription;
  final AudioConfig audio;
  final SpeechToTextConfig speechToText;
  final List<LanguageConfig> languages;
  final FirestoreConfig firestore;
  final StorageConfig storage;
  final PreferencesConfig preferences;
  final SecretsConfig secrets;
  final ExportConfig export;

  const AppConfig({
    required this.api,
    this.transcription,
    required this.audio,
    required this.speechToText,
    required this.languages,
    required this.firestore,
    required this.storage,
    required this.preferences,
    required this.secrets,
    required this.export,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, [
      'api',
      'audio',
      'speechToText',
      'languages',
      'firestore',
      'storage',
      'preferences',
      'secrets',
      'export',
    ], 'AppConfig');

    return AppConfig(
      api: ApiConfig.fromJson(json['api'] as Map<String, dynamic>),
      transcription: json.containsKey('transcription')
          ? TranscriptionConfig.fromJson(json['transcription'] as Map<String, dynamic>)
          : null,
      audio: AudioConfig.fromJson(json['audio'] as Map<String, dynamic>),
      speechToText: SpeechToTextConfig.fromJson(json['speechToText'] as Map<String, dynamic>),
      languages: (json['languages'] as List<dynamic>)
          .map((e) => LanguageConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      firestore: FirestoreConfig.fromJson(json['firestore'] as Map<String, dynamic>),
      storage: StorageConfig.fromJson(json['storage'] as Map<String, dynamic>),
      preferences: PreferencesConfig.fromJson(json['preferences'] as Map<String, dynamic>),
      secrets: SecretsConfig.fromJson(json['secrets'] as Map<String, dynamic>),
      export: ExportConfig.fromJson(json['export'] as Map<String, dynamic>),
    );
  }

  static Future<AppConfig> loadFromAsset([
    String path = 'assets/config/app_config.json',
  ]) async {
    try {
      final jsonString = await rootBundle.loadString(path);
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      return AppConfig.fromJson(jsonMap);
    } catch (e, st) {
      throw StateError('CRITICAL: Failed to load application config from $path: $e\n$st');
    }
  }

  LanguageConfig findLanguage(String code) {
    return languages.firstWhere(
      (lang) => lang.code == code,
      orElse: () => languages.first,
    );
  }
}

void _requireKeys(Map<String, dynamic> json, List<String> keys, String section) {
  for (final key in keys) {
    if (!json.containsKey(key) || json[key] == null) {
      throw ArgumentError(
        'Missing required configuration key "$key" in config section "$section".',
      );
    }
  }
}

final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError('appConfigProvider must be initialized in ProviderScope overrides');
});
