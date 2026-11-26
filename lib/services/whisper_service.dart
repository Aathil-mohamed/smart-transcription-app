import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import '../core/errors/service_error.dart';
import 'secrets_service.dart';

class WhisperService {
  final AppConfig _config;
  final SecretsService _secretsService;
  final http.Client _client;

  WhisperService(
    this._config,
    this._secretsService, {
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Transcribe recorded audio file to text using Whisper API on Groq Cloud.
  ///
  /// Returns the transcribed text string.
  /// Throws [ServiceException] with typed [ServiceErrorCode] on failure.
  Future<String> transcribeAudio({
    required String filePath,
    required String languageCode, // 'bilingual', 'ta-IN', 'en-US'
    String? customApiKey,        // Optional override from caller/settings
  }) async {
    final File audioFile = File(filePath);
    if (!await audioFile.exists()) {
      throw const ServiceException(ServiceErrorCode.fileMissing);
    }

    // Check file size before uploading
    final int fileSizeBytes = await audioFile.length();
    if (fileSizeBytes > _config.api.maxFileSizeBytes) {
      throw const ServiceException(ServiceErrorCode.fileTooLarge);
    }

    // Resolve API Key: custom key supplied, or secure storage / dart-define fallback
    String? apiKey = customApiKey?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      apiKey = await _secretsService.getGroqApiKey();
    }

    if (apiKey == null || apiKey.isEmpty) {
      throw const ServiceException(ServiceErrorCode.noApiKey);
    }

    final languageConfig = _config.findLanguage(languageCode);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(_config.api.groqWhisperUrl),
      );
      request.headers['Authorization'] = 'Bearer $apiKey';

      request.files.add(
        await http.MultipartFile.fromPath('file', filePath),
      );

      request.fields['model'] = _config.api.whisperModel;
      request.fields['temperature'] = _config.api.temperature.toString();
      request.fields['response_format'] = _config.api.responseFormat;
      request.fields['prompt'] = languageConfig.whisperPrompt;

      if (languageConfig.whisperLanguage != null) {
        request.fields['language'] = languageConfig.whisperLanguage!;
      }

      final http.StreamedResponse streamedResponse = await _client
          .send(request)
          .timeout(
        Duration(minutes: _config.api.timeoutMinutes),
        onTimeout: () {
          throw const ServiceException(ServiceErrorCode.timeout);
        },
      );

      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final dynamic decodedData = json.decode(responseBody);
        if (decodedData is Map<String, dynamic>) {
          final String text = (decodedData['text'] as String?)?.trim() ?? '';
          if (text.isEmpty) {
            throw const ServiceException(ServiceErrorCode.emptyResult);
          }
          return text;
        }
        throw const ServiceException(ServiceErrorCode.emptyResult);
      } else if (streamedResponse.statusCode == 401) {
        throw const ServiceException(ServiceErrorCode.invalidApiKey);
      } else if (streamedResponse.statusCode == 413) {
        throw const ServiceException(ServiceErrorCode.fileTooLarge);
      } else if (streamedResponse.statusCode == 429) {
        throw const ServiceException(ServiceErrorCode.rateLimited);
      } else if (streamedResponse.statusCode >= 500) {
        throw ServiceException(
          ServiceErrorCode.server,
          'HTTP ${streamedResponse.statusCode}: $responseBody',
        );
      } else {
        throw ServiceException(
          ServiceErrorCode.unknown,
          'HTTP ${streamedResponse.statusCode}: $responseBody',
        );
      }
    } on ServiceException {
      rethrow;
    } on SocketException catch (e) {
      throw ServiceException(ServiceErrorCode.network, e.message);
    } on http.ClientException catch (e) {
      throw ServiceException(ServiceErrorCode.network, e.message);
    } on TimeoutException {
      throw const ServiceException(ServiceErrorCode.timeout);
    } catch (e) {
      throw ServiceException(ServiceErrorCode.unknown, e.toString());
    }
  }

  /// Verifies if a usable API key is configured.
  Future<bool> hasValidApiKey([String? customApiKey]) async {
    if (customApiKey != null && customApiKey.trim().isNotEmpty) {
      return true;
    }
    return _secretsService.hasValidApiKey();
  }
}
