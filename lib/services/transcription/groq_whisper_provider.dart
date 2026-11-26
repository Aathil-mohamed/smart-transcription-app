import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../../core/errors/service_error.dart';
import '../secrets_service.dart';
import 'network_helper.dart';
import 'quality_filter.dart';
import 'transcription_provider.dart';

class GroqWhisperProvider implements TranscriptionProvider {
  @override
  String get id => 'groq';

  final AppConfig _config;
  final SecretsService _secretsService;
  final NetworkHelper _networkHelper;
  final QualityFilter _qualityFilter;
  final http.Client _client;

  GroqWhisperProvider(
    this._config,
    this._secretsService, {
    NetworkHelper? networkHelper,
    QualityFilter? qualityFilter,
    http.Client? client,
  })  : _networkHelper = networkHelper ?? NetworkHelper(_config.transcription.retry),
        _qualityFilter = qualityFilter ?? QualityFilter(_config.transcription.qualityFilter),
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

    final providerConfig = _config.transcription.providers['groq'];
    if (providerConfig == null) {
      throw const ServiceException(
        ServiceErrorCode.unknown,
        'Groq provider configuration missing.',
      );
    }

    final fileSize = await audioFile.length();
    if (fileSize > providerConfig.maxUploadBytes) {
      throw const ServiceException(ServiceErrorCode.fileTooLarge);
    }

    String? apiKey = customApiKey?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      apiKey = await _secretsService.getGroqApiKey();
    }

    if (apiKey == null || apiKey.isEmpty) {
      throw const ServiceException(ServiceErrorCode.noApiKey);
    }

    return _executeGroqRequest(
      audioFile: audioFile,
      language: language,
      apiKey: apiKey,
      providerConfig: providerConfig,
      additionalVocabulary: additionalVocabulary,
      isRetry: false,
    );
  }

  Future<TranscriptionResult> _executeGroqRequest({
    required File audioFile,
    required LanguageConfig language,
    required String apiKey,
    required ProviderConfig providerConfig,
    List<String>? additionalVocabulary,
    required bool isRetry,
  }) async {
    final prompt = language.buildPrompt(
      additionalVocabulary: additionalVocabulary,
      maxLength: _config.transcription.maxPromptLengthChars,
    );

    final streamedResponse = await _networkHelper.sendWithRetry(
      _client,
      () async {
        final request = http.MultipartRequest('POST', Uri.parse(providerConfig.baseUrl));
        request.headers['Authorization'] = 'Bearer $apiKey';
        request.files.add(await http.MultipartFile.fromPath('file', audioFile.path));
        request.fields['model'] = providerConfig.model;
        request.fields['temperature'] = providerConfig.temperature.toString();
        request.fields['response_format'] = providerConfig.responseFormat;
        request.fields['timestamp_granularities[]'] = providerConfig.timestampGranularities;
        request.fields['prompt'] = prompt;

        if (language.whisperLanguage != null && language.whisperLanguage!.isNotEmpty) {
          request.fields['language'] = language.whisperLanguage!;
        }

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

    final detectedLang = decoded['language'] as String?;
    final rawText = (decoded['text'] as String?)?.trim() ?? '';

    // Task 3: If language was auto (whisperLanguage was null) and detected language
    // is not in allowed list, rerun once with retryLanguage.
    if (!isRetry &&
        language.whisperLanguage == null &&
        detectedLang != null &&
        !language.allowedDetectedLanguages.contains(detectedLang) &&
        language.retryLanguage != null) {
      final forcedLanguage = LanguageConfig(
        id: language.id,
        code: language.code,
        storedName: language.storedName,
        name: language.name,
        uiLabel: language.uiLabel,
        displayName: language.displayName,
        speechLocale: language.speechLocale,
        sttLocale: language.sttLocale,
        whisperLanguage: language.retryLanguage,
        promptKey: language.promptKey,
        promptSampleSentence: language.promptSampleSentence,
        whisperPrompt: language.whisperPrompt,
        allowedDetectedLanguages: language.allowedDetectedLanguages,
        retryLanguage: null,
        customVocabulary: language.customVocabulary,
      );

      return _executeGroqRequest(
        audioFile: audioFile,
        language: forcedLanguage,
        apiKey: apiKey,
        providerConfig: providerConfig,
        additionalVocabulary: additionalVocabulary,
        isRetry: true,
      );
    }

    // Task 4: Quality filter
    final rawSegments = decoded['segments'] as List<dynamic>? ?? const [];
    final filtered = _qualityFilter.filterSegments(rawSegments);

    final finalText = filtered.text.isNotEmpty ? filtered.text : rawText;
    if (finalText.trim().isEmpty) {
      throw const ServiceException(ServiceErrorCode.emptyResult);
    }

    return TranscriptionResult(
      text: finalText,
      segments: filtered.segments,
      provider: id,
      detectedLanguage: detectedLang,
    );
  }
}
