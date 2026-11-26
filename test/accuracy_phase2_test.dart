import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_transcription_app/core/config/app_config.dart';
import 'package:smart_transcription_app/core/errors/service_error.dart';
import 'package:smart_transcription_app/services/transcription/network_helper.dart';
import 'package:smart_transcription_app/services/transcription/quality_filter.dart';

class FakeHttpClient extends http.BaseClient {
  int callCount = 0;
  final List<http.StreamedResponse> responses;

  FakeHttpClient(this.responses);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
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
}
