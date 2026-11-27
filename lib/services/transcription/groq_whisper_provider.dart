import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
    String? forcedModel,
    String? customPrompt,
    bool withoutPrompt = false,
    bool autoDetectLanguage = false,
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
      forcedModel: forcedModel,
      customPrompt: customPrompt,
      withoutPrompt: withoutPrompt,
      autoDetectLanguage: autoDetectLanguage,
    );
  }

  Future<TranscriptionResult> _executeGroqRequest({
    required File audioFile,
    required LanguageConfig language,
    required String apiKey,
    required ProviderConfig providerConfig,
    List<String>? additionalVocabulary,
    required bool isRetry,
    String? forcedModel,
    String? customPrompt,
    bool withoutPrompt = false,
    bool autoDetectLanguage = false,
  }) async {
    final prompt = withoutPrompt
        ? null
        : (customPrompt ??
            language.buildPrompt(
              additionalVocabulary: additionalVocabulary,
              maxLength: _config.transcription.maxPromptLengthChars,
            ));

    final modelToUse = forcedModel ?? providerConfig.model;

    final uploadWatch = Stopwatch()..start();
    final streamedResponse = await _networkHelper.sendWithRetry(
      _client,
      () async {
        final request = http.MultipartRequest('POST', Uri.parse(providerConfig.baseUrl));
        request.headers['Authorization'] = 'Bearer $apiKey';
        request.files.add(await http.MultipartFile.fromPath('file', audioFile.path));
        request.fields['model'] = modelToUse;
        request.fields['temperature'] = providerConfig.temperature.toString();
        request.fields['response_format'] = providerConfig.responseFormat;
        request.fields['timestamp_granularities[]'] = providerConfig.timestampGranularities;
        if (prompt != null && prompt.isNotEmpty) {
          request.fields['prompt'] = prompt;
        }

        if (!autoDetectLanguage && language.whisperLanguage != null && language.whisperLanguage!.isNotEmpty) {
          request.fields['language'] = language.whisperLanguage!;
        }

        return request;
      },
    );

    debugPrint('[Timing] upload -> first response byte: ${uploadWatch.elapsedMilliseconds}ms');

    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200) {
      final isPromptError = responseBody.toLowerCase().contains('prompt');
      if (!withoutPrompt && isPromptError) {
        // Groq rejected request because of the prompt; retry once without prompt and log it
        debugPrint('WARNING: Groq rejected request due to prompt ($responseBody). Retrying once without prompt.');
        return _executeGroqRequest(
          audioFile: audioFile,
          language: language,
          apiKey: apiKey,
          providerConfig: providerConfig,
          additionalVocabulary: additionalVocabulary,
          isRetry: isRetry,
          forcedModel: forcedModel,
          customPrompt: null,
          withoutPrompt: true,
          autoDetectLanguage: autoDetectLanguage,
        );
      }

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
    final durationSec = (decoded['duration'] as num?)?.toDouble();

    // Task 3: If language was auto (whisperLanguage was null) and detected language
    // is not in allowed list, rerun once with retryLanguage.
    if (!isRetry &&
        !autoDetectLanguage &&
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
        colloquialPromptSampleSentence: language.colloquialPromptSampleSentence,
        whisperPrompt: language.whisperPrompt,
        allowedDetectedLanguages: language.allowedDetectedLanguages,
        retryLanguage: null,
        customVocabulary: language.customVocabulary,
        pipeline: language.pipeline,
      );

      return _executeGroqRequest(
        audioFile: audioFile,
        language: forcedLanguage,
        apiKey: apiKey,
        providerConfig: providerConfig,
        additionalVocabulary: additionalVocabulary,
        isRetry: true,
        forcedModel: forcedModel,
        customPrompt: customPrompt,
        withoutPrompt: withoutPrompt,
        autoDetectLanguage: autoDetectLanguage,
      );
    }

    // Task 4: Quality filter
    final rawSegments = decoded['segments'] as List<dynamic>? ?? const [];
    final filtered = _qualityFilter.filterSegments(rawSegments);

    final finalText = filtered.text.isNotEmpty ? filtered.text : rawText;
    if (finalText.trim().isEmpty) {
      throw const ServiceException(ServiceErrorCode.emptyResult);
    }

    // Requirement 1: Raw-response log (debug builds only, no secrets)
    if (kDebugMode) {
      debugPrint('====================================================');
      debugPrint('[RawResponseLog] GROQ RAW RESPONSE METRICS:');
      debugPrint('[RawResponseLog] Response language: $detectedLang');
      debugPrint('[RawResponseLog] Total segments returned: ${rawSegments.length}');
      for (final d in filtered.decisions) {
        debugPrint(
          '[RawResponseLog] Segment #${d.index} [${d.start.toStringAsFixed(2)}s - ${d.end.toStringAsFixed(2)}s]: '
          'avg_logprob=${d.avgLogprob.toStringAsFixed(2)}, no_speech_prob=${d.noSpeechProb.toStringAsFixed(2)}, '
          'compression_ratio=${d.compressionRatio.toStringAsFixed(2)} -> '
          '${d.kept ? "KEPT" : "DROPPED (${d.dropReason})"} | text: "${d.text}"',
        );
      }
      debugPrint('[RawResponseLog] Text length before filtering (raw response text): ${rawText.length} chars');
      debugPrint('[RawResponseLog] Text length after filtering & stitching: ${filtered.text.length} chars');
      debugPrint('[RawResponseLog] Surviving segments: ${filtered.segments.length} | Dropped: ${filtered.droppedCount}');
      debugPrint('====================================================');
    }

    return TranscriptionResult(
      text: finalText,
      segments: filtered.segments,
      provider: id,
      detectedLanguage: detectedLang,
      segmentCount: filtered.segments.length,
      droppedSegmentCount: filtered.droppedCount,
      duration: durationSec,
      rawTextLength: rawText.length,
      decisions: filtered.decisions,
    );
  }
}
