import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_transcription_app/core/config/app_config.dart';
import 'package:smart_transcription_app/core/errors/service_error.dart';
import 'package:smart_transcription_app/models/transcript.dart';
import 'package:smart_transcription_app/services/secrets_service.dart';
import 'package:smart_transcription_app/services/transcription/groq_whisper_provider.dart';
import 'package:smart_transcription_app/services/transcription/network_helper.dart';
import 'package:smart_transcription_app/services/transcription/quality_filter.dart';

class FakeHttpClient extends http.BaseClient {
  int callCount = 0;
  final List<http.StreamedResponse> responses;
  final List<http.BaseRequest> capturedRequests = [];

  FakeHttpClient(this.responses);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    capturedRequests.add(request);
    final response = responses[callCount];
    callCount++;
    return response;
  }
}

void main() {
  group('Phase 2 - Task 1 & 3: Prompt Building and Truncation', () {
    const lang = LanguageConfig(
      id: 'bilingual',
      code: 'bilingual',
      storedName: 'Bilingual',
      name: 'Bilingual',
      uiLabel: 'Bilingual',
      displayName: 'Bilingual',
      speechLocale: 'ta-IN',
      sttLocale: 'ta-IN',
      whisperLanguage: 'ta',
      promptKey: 'bilingual_prompt',
      promptSampleSentence: 'வணக்கம், today we discuss the project update.',
      whisperPrompt: 'வணக்கம், today we discuss the project update.',
      allowedDetectedLanguages: ['ta', 'en'],
      retryLanguage: 'ta',
      customVocabulary: ['Flutter', 'Whisper'],
    );

    test('builds prompt with sample sentence and vocabulary', () {
      final prompt = lang.buildPrompt();
      expect(prompt, contains('வணக்கம், today we discuss the project update.'));
      expect(prompt, contains('Flutter'));
      expect(prompt, contains('Whisper'));
    });

    test('truncates keeping the END of text when exceeding max length', () {
      final prompt = lang.buildPrompt(
        additionalVocabulary: ['VeryLongDomainTerm1', 'VeryLongDomainTerm2'],
        maxLength: 25,
      );
      expect(prompt.length, equals(25));
      expect(prompt.endsWith('.'), isTrue);
    });

    test('combines static and user vocabulary, deduplicates, and places user words last', () {
      final prompt = lang.buildPrompt(
        additionalVocabulary: ['Whisper', 'UserWord1', 'UserWord2'],
        maxLength: 200,
      );
      // 'Whisper' was in both static and additional -> deduplicated
      expect(prompt, contains('Flutter'));
      expect(prompt, contains('Whisper'));
      expect(prompt, contains('UserWord1'));
      expect(prompt, contains('UserWord2'));
      // Count occurrences of Whisper
      final matches = RegExp(r'\bWhisper\b').allMatches(prompt);
      expect(matches.length, equals(1));
      // User words must appear at the very end
      expect(prompt.endsWith('UserWord1, UserWord2.'), isTrue);
    });

    test('truncation preserves user words at the end when prompt exceeds max length', () {
      final prompt = lang.buildPrompt(
        additionalVocabulary: ['ImportantUserWord'],
        maxLength: 25,
      );
      expect(prompt.length, equals(25));
      expect(prompt.endsWith('ImportantUserWord.'), isTrue);
    });
  });

  group('Phase 2 - Task 4: Quality Filter', () {
    const filterConfig = QualityFilterConfig(
      maxNoSpeechProb: 0.6,
      minAvgLogprob: -1.0,
      maxCompressionRatio: 2.4,
      dropConsecutiveDuplicates: true,
    );

    const filter = QualityFilter(filterConfig);

    test('drops hallucinated segments with high no_speech_prob and low avg_logprob', () {
      final rawSegments = [
        {
          'start': 0.0,
          'end': 2.0,
          'text': 'Legitimate speech.',
          'no_speech_prob': 0.1,
          'avg_logprob': -0.2,
          'compression_ratio': 1.1,
        },
        {
          'start': 2.0,
          'end': 4.0,
          'text': 'Thank you for watching.',
          'no_speech_prob': 0.85,
          'avg_logprob': -1.4,
          'compression_ratio': 1.0,
        },
      ];

      final result = filter.filterSegments(rawSegments);
      expect(result.segments.length, equals(1));
      expect(result.segments.first.text, equals('Legitimate speech.'));
      expect(result.text, equals('Legitimate speech.'));
    });

    test('drops repetitive hallucinations with high compression ratio', () {
      final rawSegments = [
        {
          'start': 0.0,
          'end': 3.0,
          'text': 'Good morning everyone.',
          'no_speech_prob': 0.05,
          'avg_logprob': -0.1,
          'compression_ratio': 1.2,
        },
        {
          'start': 3.0,
          'end': 6.0,
          'text': 'a a a a a a a a a a a a a a a',
          'no_speech_prob': 0.1,
          'avg_logprob': -0.5,
          'compression_ratio': 2.8,
        },
      ];

      final result = filter.filterSegments(rawSegments);
      expect(result.segments.length, equals(1));
      expect(result.segments.first.text, equals('Good morning everyone.'));
    });

    test('drops consecutive duplicate segments', () {
      final rawSegments = [
        {
          'start': 0.0,
          'end': 2.0,
          'text': 'Hello world',
          'no_speech_prob': 0.1,
          'avg_logprob': -0.2,
          'compression_ratio': 1.0,
        },
        {
          'start': 2.0,
          'end': 4.0,
          'text': 'hello world',
          'no_speech_prob': 0.1,
          'avg_logprob': -0.2,
          'compression_ratio': 1.0,
        },
        {
          'start': 4.0,
          'end': 6.0,
          'text': 'Welcome to the app',
          'no_speech_prob': 0.1,
          'avg_logprob': -0.2,
          'compression_ratio': 1.0,
        },
      ];

      final result = filter.filterSegments(rawSegments);
      expect(result.segments.length, equals(2));
      expect(result.segments[0].text, equals('Hello world'));
      expect(result.segments[1].text, equals('Welcome to the app'));
      expect(result.text, equals('Hello world Welcome to the app'));
    });

    test('reports correct rawCount and droppedCount metrics', () {
      final rawSegments = [
        {
          'start': 0.0,
          'end': 2.0,
          'text': 'Good speech.',
          'no_speech_prob': 0.1,
          'avg_logprob': -0.2,
          'compression_ratio': 1.1,
        },
        {
          'start': 2.0,
          'end': 4.0,
          'text': 'Silence noise.',
          'no_speech_prob': 0.9,
          'avg_logprob': -1.5,
          'compression_ratio': 1.0,
        },
      ];

      final result = filter.filterSegments(rawSegments);
      expect(result.rawCount, equals(2));
      expect(result.droppedCount, equals(1));
      expect(result.segments.length, equals(1));
    });
  });

  group('Phase 2 - Task 5: NetworkHelper, Retry & Error Mapping', () {
    const retryConfig = RetryConfig(
      maxRetries: 2,
      initialBackoffMs: 10,
      maxBackoffMs: 100,
      backoffMultiplier: 2.0,
      retryStatuses: [429, 500, 503],
      maxRetryAfterSeconds: 5,
    );

    test('retries on retryable status and succeeds', () async {
      final fakeResponses = [
        http.StreamedResponse(
          Stream.value(utf8.encode('Rate limited')),
          429,
          headers: {'retry-after': '1'},
        ),
        http.StreamedResponse(
          Stream.value(utf8.encode('{"text": "Success"}')),
          200,
        ),
      ];

      final fakeClient = FakeHttpClient(fakeResponses);
      final networkHelper = NetworkHelper(
        retryConfig,
        delayFn: (duration) async {}, // instantaneous in test
      );

      final response = await networkHelper.sendWithRetry(
        fakeClient,
        () async => http.Request('GET', Uri.parse('https://example.com')),
      );

      expect(response.statusCode, equals(200));
      expect(fakeClient.callCount, equals(2));
    });

    test('maps status codes to ServiceErrorCode accurately', () {
      expect(NetworkHelper.mapStatusCode(401), equals(ServiceErrorCode.invalidApiKey));
      expect(NetworkHelper.mapStatusCode(403), equals(ServiceErrorCode.invalidApiKey));
      expect(NetworkHelper.mapStatusCode(413), equals(ServiceErrorCode.fileTooLarge));
      expect(NetworkHelper.mapStatusCode(429), equals(ServiceErrorCode.rateLimited));
      expect(NetworkHelper.mapStatusCode(500), equals(ServiceErrorCode.server));
      expect(NetworkHelper.mapStatusCode(503), equals(ServiceErrorCode.server));
      expect(NetworkHelper.mapStatusCode(404), equals(ServiceErrorCode.unknown));
    });
  });

  group('Phase 2 - Task 6: Max Duration Calculation', () {
    test('calculates maximum recording duration correctly based on bitrate and safety ratio', () {
      const audioConfig = AudioConfig(
        sampleRate: 16000,
        numChannels: 1,
        encoder: 'aacLc',
        bitRate: 64000,
        noiseSuppress: true,
        echoCancel: true,
        autoGain: true,
        safetyRatio: 0.9,
        recordingsFolder: 'transcriptions',
        amplitudeIntervalMs: 100,
        secondsIntervalMs: 1000,
        minDb: -160,
        maxDb: 0,
        waveHistoryLimit: 45,
        fileNamePrefix: 'rec_',
        fileExtension: '.m4a',
      );

      // (26214400 * 0.9 * 8) / 64000 = 2949 seconds (~49.15 minutes)
      final maxSecs = audioConfig.calculateMaxDurationSeconds(26214400);
      expect(maxSecs, equals(2949));
    });
  });

  group('Follow-up - Groq Prompt Error Retry', () {
    test('retries once without prompt when Groq returns 400 mentioning prompt and succeeds', () async {
      final tempAudio = File('${Directory.systemTemp.path}/test_groq_audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
      tempAudio.writeAsStringSync('fake audio content');

      final fakeResponses = [
        http.StreamedResponse(
          Stream.value(utf8.encode('{"error": {"message": "Invalid prompt string", "type": "invalid_request_error"}}')),
          400,
        ),
        http.StreamedResponse(
          Stream.value(utf8.encode('{"text": "Successfully transcribed audio without prompt", "language": "en", "segments": []}')),
          200,
        ),
      ];

      final fakeClient = FakeHttpClient(fakeResponses);

      const testAppConfig = AppConfig(
        api: ApiConfig(
          groqWhisperUrl: 'https://api.groq.com',
          whisperModel: 'whisper-large-v3',
          temperature: 0.0,
          responseFormat: 'verbose_json',
          maxFileSizeBytes: 1000000,
          timeoutMinutes: 1,
          retries: 2,
          retryStatuses: [429, 500, 502],
        ),
        audio: AudioConfig(
          sampleRate: 16000,
          numChannels: 1,
          encoder: 'aacLc',
          bitRate: 64000,
          noiseSuppress: true,
          echoCancel: true,
          autoGain: true,
          recordingsFolder: 'r',
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
        transcription: TranscriptionConfig(
          pipeline: ['groq'],
          maxPromptLengthChars: 200,
          providers: {
            'groq': ProviderConfig(
              baseUrl: 'https://api.groq.com/openai/v1/audio/transcriptions',
              model: 'whisper-large-v3',
              temperature: 0.0,
              responseFormat: 'verbose_json',
              timestampGranularities: 'segment',
              timeoutSeconds: 300,
              maxUploadBytes: 26214400,
            ),
          },
          qualityFilter: QualityFilterConfig(
            maxNoSpeechProb: 0.6,
            minAvgLogprob: -1.0,
            maxCompressionRatio: 2.4,
            dropConsecutiveDuplicates: true,
          ),
          retry: RetryConfig(
            maxRetries: 2,
            initialBackoffMs: 10,
            maxBackoffMs: 100,
            backoffMultiplier: 2.0,
            retryStatuses: [429, 500],
            maxRetryAfterSeconds: 5,
          ),
        ),
        preferences: PreferencesConfig(
          keyThemeMode: 'theme_mode',
          keyUserLanguage: 'user_language',
          keyLivePreviewEnabled: 'live_preview_enabled',
          keyLegacyCustomApiKey: 'groq_api_key_custom',
        ),
        secrets: SecretsConfig(
          secureStorageKeyGroqApiKey: 'secure_groq_api_key',
          secureStorageKeyGeminiApiKey: 'secure_gemini_api_key',
          secureStorageKeyGoogleTranslateApiKey: 'secure_google_translate_api_key',
          dartDefineKeyGroqApiKey: 'GROQ_API_KEY',
          dartDefineKeyGeminiApiKey: 'GEMINI_API_KEY',
          dartDefineKeyGoogleTranslateApiKey: 'GOOGLE_TRANSLATE_API_KEY',
        ),
        export: ExportConfig(
          pdfFontUrl: '',
          defaultPdfFileName: 't.pdf',
          defaultTxtFileName: 't.txt',
          defaultDocFileName: 't.doc',
          pdfPageMargin: 24.0,
          pdfHeaderFontSize: 18.0,
          pdfBodyFontSize: 12.0,
          pdfMetadataFontSize: 10.0,
          pdfAccentColorHex: '#6C5CE7',
        ),
      );

      final secretsService = SecretsService(testAppConfig);
      final provider = GroqWhisperProvider(
        testAppConfig,
        secretsService,
        client: fakeClient,
      );

      const lang = LanguageConfig(
        id: 'en',
        code: 'en',
        storedName: 'English',
        name: 'English',
        uiLabel: 'English',
        displayName: 'English',
        speechLocale: 'en-US',
        sttLocale: 'en-US',
        whisperLanguage: 'en',
        promptKey: 'en_prompt',
        promptSampleSentence: 'Hello there.',
        whisperPrompt: 'Hello there.',
        allowedDetectedLanguages: ['en'],
        retryLanguage: null,
        customVocabulary: ['TestWord'],
      );

      try {
        final result = await provider.transcribe(
          audioFile: tempAudio,
          language: lang,
          customApiKey: 'dummy_api_key',
        );

        expect(result.text, equals('Successfully transcribed audio without prompt'));
        expect(fakeClient.callCount, equals(2));
        // First request should include prompt
        final firstReq = fakeClient.capturedRequests[0] as http.MultipartRequest;
        expect(firstReq.fields.containsKey('prompt'), isTrue);
        // Second request (retry) must NOT include prompt
        final secondReq = fakeClient.capturedRequests[1] as http.MultipartRequest;
        expect(secondReq.fields.containsKey('prompt'), isFalse);
      } finally {
        if (tempAudio.existsSync()) {
          tempAudio.deleteSync();
        }
      }
    });
  });

  group('Follow-up - TranscriptionModel Debug Fields', () {
    test('serializes and deserializes detectedLanguage, segmentCount, and droppedSegmentCount', () {
      final model = TranscriptionModel(
        transcriptionId: 'tx_123',
        userId: 'usr_456',
        title: 'Meeting Notes',
        transcript: 'Full transcript here.',
        language: 'Bilingual',
        duration: 120,
        provider: 'groq',
        detectedLanguage: 'ta',
        segmentCount: 8,
        droppedSegmentCount: 2,
        createdAt: DateTime.now(),
      );

      final map = model.toMap();
      expect(map['provider'], equals('groq'));
      expect(map['detectedLanguage'], equals('ta'));
      expect(map['segmentCount'], equals(8));
      expect(map['droppedSegmentCount'], equals(2));

      final restored = TranscriptionModel.fromMap(map);
      expect(restored.provider, equals('groq'));
      expect(restored.detectedLanguage, equals('ta'));
      expect(restored.segmentCount, equals(8));
      expect(restored.droppedSegmentCount, equals(2));
    });
  });
}
