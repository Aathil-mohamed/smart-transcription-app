import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../../core/errors/service_error.dart';
import '../secrets_service.dart';
import 'network_helper.dart';
import 'transcription_provider.dart';

class GeminiTranscriptionProvider implements TranscriptionProvider {
  @override
  String get id => 'gemini';

  final AppConfig _config;
  final SecretsService _secretsService;
  final NetworkHelper _networkHelper;
  final http.Client _client;

  GeminiTranscriptionProvider(
    this._config,
    this._secretsService, {
    NetworkHelper? networkHelper,
    http.Client? client,
  })  : _networkHelper = networkHelper ?? NetworkHelper(_config.transcription.retry),
        _client = client ?? http.Client();

  @override
  Future<TranscriptionResult> transcribe({
    required File audioFile,
    required LanguageConfig language,
    String? customApiKey,
    List<String>? additionalVocabulary,
  }) async {
    if (!await audioFile.exists()) {
      throw const ServiceException(ServiceErrorCode.fileMissing);
    }

    final providerConfig = _config.transcription.providers['gemini'];
    if (providerConfig == null) {
      throw const ServiceException(
        ServiceErrorCode.unknown,
        'Gemini provider configuration missing.',
      );
    }

    final fileSize = await audioFile.length();
    if (fileSize > providerConfig.maxUploadBytes) {
      throw const ServiceException(ServiceErrorCode.fileTooLarge);
    }

    String? apiKey = customApiKey?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      apiKey = await _secretsService.getGeminiApiKey();
    }

    if (apiKey == null || apiKey.isEmpty) {
      throw const ServiceException(ServiceErrorCode.noApiKey);
    }

    final audioBytes = await audioFile.readAsBytes();
    final base64Audio = base64Encode(audioBytes);

    final url = Uri.parse(
      '${providerConfig.baseUrl}/${providerConfig.model}:generateContent?key=$apiKey',
    );

    final requestBody = json.encode({
      'contents': [
        {
          'parts': [
            {
              'text':
                  'Transcribe this audio accurately. Target language: ${language.displayName}. Output strictly the transcription text without commentary, timestamps, or quotes.',
            },
            {
              'inline_data': {
                'mime_type': 'audio/mp4',
                'data': base64Audio,
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': providerConfig.temperature,
      },
    });

    final streamedResponse = await _networkHelper.sendWithRetry(
      _client,
      () async {
        final request = http.Request('POST', url);
        request.headers['Content-Type'] = 'application/json';
        request.body = requestBody;
        return request;
      },
    );

    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200) {
      final errorCode = NetworkHelper.mapStatusCode(streamedResponse.statusCode);
      throw ServiceException(
        errorCode,
        'HTTP ${streamedResponse.statusCode}: $responseBody',
      );
    }

    final dynamic decoded = json.decode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw const ServiceException(ServiceErrorCode.emptyResult);
    }

    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw const ServiceException(ServiceErrorCode.emptyResult);
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    final transcribedText = (parts?.first?['text'] as String?)?.trim() ?? '';

    if (transcribedText.isEmpty) {
      throw const ServiceException(ServiceErrorCode.emptyResult);
    }

    return TranscriptionResult(
      text: transcribedText,
      segments: const [],
      provider: id,
      detectedLanguage: language.whisperLanguage,
      segmentCount: 0,
      droppedSegmentCount: 0,
    );
  }
}
