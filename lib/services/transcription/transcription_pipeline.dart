import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../../core/errors/service_error.dart';
import 'gemini_transcription_provider.dart';
import 'groq_whisper_provider.dart';
import 'transcription_provider.dart';
import '../secrets_service.dart';

class TranscriptionPipeline {
  final AppConfig _config;
  final Map<String, TranscriptionProvider> _providers;
  final http.Client _client;

  TranscriptionPipeline(
    this._config,
    this._providers, {
    http.Client? client,
  }) : _client = client ?? http.Client();

  factory TranscriptionPipeline.create(
    AppConfig config,
    SecretsService secretsService, {
    http.Client? client,
  }) {
    final sharedClient = client ?? http.Client();
    return TranscriptionPipeline(
      config,
      {
        'groq': GroqWhisperProvider(config, secretsService, client: sharedClient),
        'gemini': GeminiTranscriptionProvider(config, secretsService, client: sharedClient),
      },
      client: sharedClient,
    );
  }

  /// Opens the network connection early to the transcription host with HTTP keep-alive.
  Future<void> prewarmConnection() async {
    try {
      final groqConfig = _config.transcription.providers['groq'];
      if (groqConfig != null) {
        final uri = Uri.parse(groqConfig.baseUrl);
        final request = http.Request('HEAD', uri);
        request.headers['Connection'] = 'keep-alive';
        final response = await _client.send(request);
        await response.stream.drain<void>().catchError((_) {});
        debugPrint('[Timing] Network pre-warm: Socket cached for ${uri.host}');
      }
    } catch (_) {
      debugPrint('[Timing] Network pre-warm completed (socket initiated)');
    }
  }

  /// Tries the configured transcription providers in order.
  Future<TranscriptionResult> transcribe({
    required File audioFile,
    required LanguageConfig language,
    String? customApiKey,
    List<String>? additionalVocabulary,
  }) async {
    final pipelineOrder = _config.transcription.pipeline;
    ServiceException? lastException;

    for (final providerId in pipelineOrder) {
      final provider = _providers[providerId];
      if (provider == null) {
        debugPrint('Configured provider "$providerId" not registered. Skipping.');
        continue;
      }

      try {
        debugPrint('Attempting transcription via provider: $providerId');
        final result = await provider.transcribe(
          audioFile: audioFile,
          language: language,
          customApiKey: customApiKey,
          additionalVocabulary: additionalVocabulary,
        );
        debugPrint('Transcription succeeded via provider: $providerId');
        return result;
      } on ServiceException catch (e) {
        lastException = e;
        debugPrint('Provider "$providerId" failed with code ${e.code}. Continuing pipeline...');
      } catch (e) {
        lastException = ServiceException(ServiceErrorCode.unknown, e.toString());
        debugPrint('Provider "$providerId" failed with error $e. Continuing pipeline...');
      }
    }

    throw lastException ??
        const ServiceException(
          ServiceErrorCode.unknown,
          'All transcription providers in pipeline failed.',
        );
  }
}
