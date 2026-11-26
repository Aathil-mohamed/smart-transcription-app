import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_transcription_app/core/config/app_config.dart';
import 'package:smart_transcription_app/main.dart';

void main() {
  const testConfigJson = {
    'api': {
      'groqWhisperUrl': 'https://api.groq.com/openai/v1/audio/transcriptions',
      'whisperModel': 'whisper-large-v3',
      'temperature': 0.0,
      'responseFormat': 'verbose_json',
      'maxFileSizeBytes': 26214400,
      'timeoutMinutes': 5,
      'retries': 2,
      'retryStatuses': [429, 500, 502, 503, 504],
    },
    'audio': {
      'sampleRate': 16000,
      'numChannels': 1,
      'encoder': 'aacLc',
      'bitRate': 64000,
      'noiseSuppress': true,
      'echoCancel': true,
      'autoGain': true,
      'recordingsFolder': 'recordings',
      'amplitudeIntervalMs': 100,
      'secondsIntervalMs': 1000,
      'minDb': -160.0,
      'maxDb': 0.0,
      'waveHistoryLimit': 45,
      'fileNamePrefix': 'rec_',
      'fileExtension': '.m4a',
    },
    'speechToText': {
      'listenForHours': 1,
      'pauseForSeconds': 10,
      'listenMode': 'dictation',
      'restartDelayMs': 100,
    },
    'languages': [
      {
        'id': 'bilingual',
        'code': 'bilingual',
        'storedName': 'Bilingual (Tamil + English)',
        'name': 'Bilingual (Tamil + English)',
        'uiLabel': 'Bilingual',
        'displayName': 'Bilingual',
        'speechLocale': 'ta-IN',
        'sttLocale': 'ta-IN',
        'whisperLanguage': null,
        'promptKey': 'bilingual_prompt',
        'whisperPrompt': 'Transcribe accurately.',
      }
    ],
    'firestore': {
      'collectionUsers': 'users',
      'collectionTranscriptions': 'transcriptions',
      'collectionExports': 'exports',
      'pageSize': 20,
      'cachePersistenceEnabled': false,
      'cacheSizeBytesUnlimited': true,
    },
    'storage': {
      'exportsPathPattern': 'users/{userId}/exports/{transcriptionId}/{fileName}',
    },
    'preferences': {
      'keyThemeMode': 'theme_mode',
      'keyUserLanguage': 'user_language',
      'keyLegacyCustomApiKey': 'groq_api_key_custom',
    },
    'secrets': {
      'secureStorageKeyGroqApiKey': 'secure_groq_api_key',
      'secureStorageKeyGeminiApiKey': 'secure_gemini_api_key',
      'secureStorageKeyGoogleTranslateApiKey': 'secure_google_translate_api_key',
      'dartDefineKeyGroqApiKey': 'GROQ_API_KEY',
      'dartDefineKeyGeminiApiKey': 'GEMINI_API_KEY',
      'dartDefineKeyGoogleTranslateApiKey': 'GOOGLE_TRANSLATE_API_KEY',
    },
    'export': {
      'pdfFontUrl': 'https://example.com/font.ttf',
      'defaultPdfFileName': 'transcript.pdf',
      'defaultTxtFileName': 'transcript.txt',
      'defaultDocFileName': 'transcript.doc',
      'pdfPageMargin': 24.0,
      'pdfHeaderFontSize': 18.0,
      'pdfBodyFontSize': 12.0,
      'pdfMetadataFontSize': 10.0,
      'pdfAccentColorHex': '#6C5CE7',
    },
  };

  testWidgets('App shows splash screen', (WidgetTester tester) async {
    final testConfig = AppConfig.fromJson(testConfigJson);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(testConfig),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pump();
    expect(find.text('Smart Transcribe'), findsOneWidget);
    expect(find.text('Real-Time Speech Transcription'), findsOneWidget);
  });
}
