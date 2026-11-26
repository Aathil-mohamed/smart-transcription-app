import 'dart:io';
import '../core/config/app_config.dart';
import 'secrets_service.dart';
import 'transcription/transcription_pipeline.dart';

/// Legacy adapter for backward compatibility with existing callers.
///
/// Deprecated: Use [TranscriptionPipeline] directly.
@Deprecated('Use TranscriptionPipeline instead of WhisperService.')
class WhisperService {
  final AppConfig _config;
  final SecretsService _secretsService;
  final TranscriptionPipeline _pipeline;

  WhisperService(
    this._config,
    this._secretsService, {
    TranscriptionPipeline? pipeline,
  }) : _pipeline = pipeline ?? TranscriptionPipeline.create(_config, _secretsService);

  /// Transcribe audio file using the configured transcription pipeline.
  Future<String> transcribeAudio({
    required String filePath,
    required String languageCode,
    String? customApiKey,
  }) async {
    final language = _config.findLanguage(languageCode);
    final result = await _pipeline.transcribe(
      audioFile: File(filePath),
      language: language,
      customApiKey: customApiKey,
    );
    return result.text;
  }

  /// Verifies if a usable Groq API key is configured.
  Future<bool> hasValidApiKey([String? customApiKey]) async {
    if (customApiKey != null && customApiKey.trim().isNotEmpty) {
      return true;
    }
    return _secretsService.hasValidApiKey();
  }
}
