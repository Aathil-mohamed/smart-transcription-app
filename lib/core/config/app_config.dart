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
      retries: (json['retries'] as num?)?.toInt() ?? 3,
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
  final String timestampGranularities;
  final int timeoutSeconds;
  final int maxUploadBytes;

  const ProviderConfig({
    required this.baseUrl,
    required this.model,
    required this.temperature,
    this.responseFormat = 'verbose_json',
    this.timestampGranularities = 'segment',
    required this.timeoutSeconds,
    required this.maxUploadBytes,
  });

  factory ProviderConfig.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, [
      'baseUrl',
      'model',
      'temperature',
      'timeoutSeconds',
      'maxUploadBytes',
    ], 'ProviderConfig');

    return ProviderConfig(
      baseUrl: json['baseUrl'] as String,
      model: json['model'] as String,
      temperature: (json['temperature'] as num).toDouble(),
      responseFormat: json['responseFormat'] as String? ?? 'verbose_json',
      timestampGranularities: json['timestampGranularities'] as String? ?? 'segment',
      timeoutSeconds: (json['timeoutSeconds'] as num).toInt(),
      maxUploadBytes: (json['maxUploadBytes'] as num).toInt(),
    );
  }
}

class QualityFilterConfig {
  final double maxNoSpeechProb;
  final double minAvgLogprob;
  final double maxCompressionRatio;
  final bool dropConsecutiveDuplicates;

  const QualityFilterConfig({
    required this.maxNoSpeechProb,
    required this.minAvgLogprob,
    required this.maxCompressionRatio,
    required this.dropConsecutiveDuplicates,
  });

  factory QualityFilterConfig.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, [
      'maxNoSpeechProb',
      'minAvgLogprob',
      'maxCompressionRatio',
      'dropConsecutiveDuplicates',
    ], 'QualityFilterConfig');

    return QualityFilterConfig(
      maxNoSpeechProb: (json['maxNoSpeechProb'] as num).toDouble(),
      minAvgLogprob: (json['minAvgLogprob'] as num).toDouble(),
      maxCompressionRatio: (json['maxCompressionRatio'] as num).toDouble(),
      dropConsecutiveDuplicates: json['dropConsecutiveDuplicates'] as bool,
    );
  }
}

class RetryConfig {
  final int maxRetries;
  final int initialBackoffMs;
  final int maxBackoffMs;
  final double backoffMultiplier;
  final List<int> retryStatuses;
  final int maxRetryAfterSeconds;

  const RetryConfig({
    required this.maxRetries,
    required this.initialBackoffMs,
    required this.maxBackoffMs,
    required this.backoffMultiplier,
    required this.retryStatuses,
    required this.maxRetryAfterSeconds,
  });

  factory RetryConfig.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, [
      'maxRetries',
      'initialBackoffMs',
      'maxBackoffMs',
      'backoffMultiplier',
      'retryStatuses',
      'maxRetryAfterSeconds',
    ], 'RetryConfig');

    return RetryConfig(
      maxRetries: (json['maxRetries'] as num).toInt(),
      initialBackoffMs: (json['initialBackoffMs'] as num).toInt(),
      maxBackoffMs: (json['maxBackoffMs'] as num).toInt(),
      backoffMultiplier: (json['backoffMultiplier'] as num).toDouble(),
      retryStatuses: (json['retryStatuses'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
      maxRetryAfterSeconds: (json['maxRetryAfterSeconds'] as num).toInt(),
    );
  }
}

class TranscriptionConfig {
  final List<String> pipeline;
  final int maxPromptLengthChars;
  final Map<String, ProviderConfig> providers;
  final QualityFilterConfig qualityFilter;
  final RetryConfig retry;

  const TranscriptionConfig({
    required this.pipeline,
    required this.maxPromptLengthChars,
    required this.providers,
    required this.qualityFilter,
    required this.retry,
  });

  factory TranscriptionConfig.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, [
      'pipeline',
      'maxPromptLengthChars',
      'providers',
      'qualityFilter',
      'retry',
    ], 'TranscriptionConfig');

    final rawProviders = json['providers'] as Map<String, dynamic>;
    final parsedProviders = <String, ProviderConfig>{};
    for (final entry in rawProviders.entries) {
      parsedProviders[entry.key] =
          ProviderConfig.fromJson(entry.value as Map<String, dynamic>);
    }

    return TranscriptionConfig(
      pipeline: (json['pipeline'] as List<dynamic>).map((e) => e as String).toList(),
      maxPromptLengthChars: (json['maxPromptLengthChars'] as num).toInt(),
      providers: parsedProviders,
      qualityFilter: QualityFilterConfig.fromJson(
        json['qualityFilter'] as Map<String, dynamic>,
      ),
      retry: RetryConfig.fromJson(json['retry'] as Map<String, dynamic>),
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
  final double safetyRatio;
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
    this.safetyRatio = 0.9,
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
      safetyRatio: (json['safetyRatio'] as num?)?.toDouble() ?? 0.9,
      recordingsFolder: json['recordingsFolder'] as String? ?? 'transcriptions',
      amplitudeIntervalMs: (json['amplitudeIntervalMs'] as num).toInt(),
      secondsIntervalMs: (json['secondsIntervalMs'] as num).toInt(),
      minDb: (json['minDb'] as num).toDouble(),
      maxDb: (json['maxDb'] as num).toDouble(),
      waveHistoryLimit: (json['waveHistoryLimit'] as num).toInt(),
      fileNamePrefix: json['fileNamePrefix'] as String,
      fileExtension: json['fileExtension'] as String,
    );
  }

  /// Derives maximum safe recording duration in seconds based on max upload bytes and bitrate.
  int calculateMaxDurationSeconds(int maxUploadBytes) {
    if (bitRate <= 0) return 3600;
    return ((maxUploadBytes * safetyRatio * 8) / bitRate).floor();
  }
}

class SpeechToTextConfig {
  final int listenForHours;
  final int pauseForSeconds;
  final String listenMode;
  final int restartDelayMs;
  final int maxRestarts;
  final bool enabledByDefault;

  const SpeechToTextConfig({
    required this.listenForHours,
    required this.pauseForSeconds,
    required this.listenMode,
    required this.restartDelayMs,
    this.maxRestarts = 3,
    this.enabledByDefault = true,
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
      maxRestarts: (json['maxRestarts'] as num?)?.toInt() ?? 3,
      enabledByDefault: json['enabledByDefault'] as bool? ?? true,
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
  final String promptSampleSentence;
  final String whisperPrompt;
  final List<String> allowedDetectedLanguages;
  final String? retryLanguage;
  final List<String> customVocabulary;

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
    required this.promptSampleSentence,
    required this.whisperPrompt,
    required this.allowedDetectedLanguages,
    required this.retryLanguage,
    required this.customVocabulary,
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
    final sample = json['promptSampleSentence'] as String? ?? (json['whisperPrompt'] as String);

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
      promptSampleSentence: sample,
      whisperPrompt: json['whisperPrompt'] as String,
      allowedDetectedLanguages: (json['allowedDetectedLanguages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [code.split('-').first],
      retryLanguage: json['retryLanguage'] as String?,
      customVocabulary: (json['customVocabulary'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  /// Builds prompt with sample sentence and vocabulary, truncating keeping the END of text.
  ///
  /// Combines static vocabulary from config with user words from SettingsRepository,
  /// deduplicating them and ensuring user words are placed strictly at the END of the prompt
  /// so left-truncation (which preserves the end) never drops the user's words.
  String buildPrompt({
    List<String>? additionalVocabulary,
    int maxLength = 200,
  }) {
    final userWords = (additionalVocabulary ?? const <String>[])
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toSet();

    final staticWords = customVocabulary
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty && !userWords.contains(w))
        .toList();

    final allVocab = [...staticWords, ...userWords];
    final vocabString = allVocab.isNotEmpty ? ' ${allVocab.join(', ')}.' : '';
    final combined = '$promptSampleSentence$vocabString'.trim();

    if (combined.length <= maxLength) {
      return combined;
    }
    // Truncate keeping the END of the text (preserving user words)
    return combined.substring(combined.length - maxLength);
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
  final String keyLivePreviewEnabled;
  final String keyCustomVocabulary;
  final String keyLegacyCustomApiKey;

  const PreferencesConfig({
    required this.keyThemeMode,
    required this.keyUserLanguage,
    required this.keyLivePreviewEnabled,
    this.keyCustomVocabulary = 'custom_vocabulary',
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
      keyLivePreviewEnabled: json['keyLivePreviewEnabled'] as String? ?? 'live_preview_enabled',
      keyCustomVocabulary: json['keyCustomVocabulary'] as String? ?? 'custom_vocabulary',
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
  final TranscriptionConfig transcription;
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
    required this.transcription,
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
      'transcription',
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
      transcription: TranscriptionConfig.fromJson(
        json['transcription'] as Map<String, dynamic>,
      ),
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

  LanguageConfig findLanguage(String codeOrId) {
    return languages.firstWhere(
      (lang) => lang.code == codeOrId || lang.id == codeOrId,
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
