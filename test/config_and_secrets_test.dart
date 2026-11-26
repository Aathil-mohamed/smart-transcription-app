import 'package:flutter_test/flutter_test.dart';
import 'package:smart_transcription_app/core/config/app_config.dart';
import 'package:smart_transcription_app/core/errors/service_error.dart';
import 'package:smart_transcription_app/services/secrets_service.dart';

void main() {
  group('AppConfig', () {
    test('fails fast when required key is missing', () {
      expect(
        () => AppConfig.fromJson(const {}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('builds storage export path pattern correctly', () {
      const storageConfig = StorageConfig(
        exportsPathPattern: 'users/{userId}/exports/{transcriptionId}/{fileName}',
      );
      final path = storageConfig.buildExportPath(
        userId: 'user123',
        transcriptionId: 'tx456',
        fileName: 'export.pdf',
      );
      expect(path, equals('users/user123/exports/tx456/export.pdf'));
    });
  });

  group('ServiceErrorCode & Exceptions', () {
    test('ServiceException formats properly', () {
      const ex = ServiceException(ServiceErrorCode.noApiKey, 'Missing key');
      expect(ex.code, equals(ServiceErrorCode.noApiKey));
      expect(ex.toString(), contains('noApiKey'));
      expect(ex.toString(), contains('Missing key'));
    });

    test('DataException formats properly', () {
      const ex = DataException('saveTranscription', 'network_failure');
      expect(ex.operation, equals('saveTranscription'));
      expect(ex.toString(), contains('saveTranscription'));
      expect(ex.toString(), contains('network_failure'));
    });
  });

  group('SecretsService', () {
    test('hasValidApiKey returns false when no key is set', () async {
      const config = AppConfig(
        api: ApiConfig(
          groqWhisperUrl: 'https://api.groq.com',
          whisperModel: 'whisper-large-v3',
          temperature: 0.0,
          responseFormat: 'verbose_json',
          maxFileSizeBytes: 1000,
          timeoutMinutes: 1,
          retries: 2,
          retryStatuses: [429],
        ),
        audio: AudioConfig(
          sampleRate: 16000,
          numChannels: 1,
          encoder: 'aacLc',
          bitRate: 64000,
          noiseSuppress: true,
          echoCancel: true,
          autoGain: true,
          recordingsFolder: 'recordings',
          amplitudeIntervalMs: 100,
          secondsIntervalMs: 1000,
          minDb: -160,
          maxDb: 0,
          waveHistoryLimit: 45,
          fileNamePrefix: 'rec_',
          fileExtension: '.m4a',
        ),
        speechToText: SpeechToTextConfig(
          listenForHours: 1,
          pauseForSeconds: 10,
          listenMode: 'dictation',
          restartDelayMs: 100,
        ),
        languages: [],
        firestore: FirestoreConfig(
          collectionUsers: 'users',
          collectionTranscriptions: 'transcriptions',
          collectionExports: 'exports',
          pageSize: 20,
          cachePersistenceEnabled: false,
          cacheSizeBytesUnlimited: true,
        ),
        storage: StorageConfig(exportsPathPattern: '{userId}/{fileName}'),
        preferences: PreferencesConfig(
          keyThemeMode: 'theme_mode',
          keyUserLanguage: 'user_language',
          keyLegacyCustomApiKey: 'groq_api_key_custom',
        ),
        secrets: SecretsConfig(
          secureStorageKeyGroqApiKey: 'secure_groq_api_key',
          secureStorageKeyGeminiApiKey: 'secure_gemini_api_key',
          secureStorageKeyGoogleTranslateApiKey: 'secure_google_translate_api_key',
          dartDefineKeyGroqApiKey: 'NON_EXISTENT_GROQ_KEY',
          dartDefineKeyGeminiApiKey: 'NON_EXISTENT_GEMINI_KEY',
          dartDefineKeyGoogleTranslateApiKey: 'NON_EXISTENT_TRANSLATE_KEY',
        ),
        export: ExportConfig(
          pdfFontUrl: '',
          defaultPdfFileName: 't.pdf',
          defaultTxtFileName: 't.txt',
          defaultDocFileName: 't.doc',
          pdfPageMargin: 24,
          pdfHeaderFontSize: 18,
          pdfBodyFontSize: 12,
          pdfMetadataFontSize: 10,
          pdfAccentColorHex: '#000000',
        ),
      );

      final secretsService = SecretsService(config);
      final hasKey = await secretsService.hasValidApiKey();
      expect(hasKey, isFalse);
    });
  });
}
