import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';

class WhisperService {
  /// Transcribe recorded audio file to text using Whisper API (Groq free tier).
  ///
  /// Returns the transcribed text string.
  /// Throws an [Exception] with a user-friendly message on failure.
  Future<String> transcribeAudio({
    required String filePath,
    required String languageCode, // 'bilingual', 'ta-IN', 'en-US'
    String? customApiKey,        // Allow user to supply their own key in Settings
  }) async {
    final File audioFile = File(filePath);
    if (!await audioFile.exists()) {
      throw Exception('Audio file not found at path: $filePath');
    }

    // Use user-supplied key, or fallback to the constant key in constants.dart
    final String apiKey = (customApiKey != null && customApiKey.isNotEmpty)
        ? customApiKey
        : AppConstants.groqApiKey;

    if (apiKey.startsWith('gsk_xxxxxx') || apiKey.isEmpty) {
      throw Exception(
        'No valid Groq API Key found.\n\n'
        'To fix this:\n'
        '1. Go to https://console.groq.com/keys\n'
        '2. Create a free API key\n'
        '3. Paste it in Settings → "Custom Groq API Key"\n'
        '4. Tap SAVE API KEY'
      );
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(AppConstants.groqWhisperUrl),
      );
      request.headers['Authorization'] = 'Bearer $apiKey';

      request.files.add(
        await http.MultipartFile.fromPath('file', filePath),
      );

      // Model: whisper-large-v3 — best accuracy for multilingual audio
      request.fields['model'] = 'whisper-large-v3';

      // Temperature 0 = most deterministic & accurate transcription
      request.fields['temperature'] = '0';

      // verbose_json returns richer data including the full text
      request.fields['response_format'] = 'verbose_json';

      // Guide the model based on the selected language for maximum accuracy
      if (languageCode == 'bilingual') {
        // Do NOT set 'language' — let Whisper auto-detect for mixed speech
        request.fields['prompt'] = 
          'Transcribe this audio accurately. '
          'The speaker uses mixed Tamil (தமிழ்) and English. '
          'Preserve the original words exactly as spoken. '
          'Use proper punctuation and formatting.';
      } else if (languageCode == 'ta-IN') {
        request.fields['language'] = 'ta';
        request.fields['prompt'] = 
          'இது ஒரு தமிழ் உரையாடல். '
          'அனைத்து வார்த்தைகளையும் துல்லியமாக எழுதவும்.';
      } else {
        request.fields['language'] = 'en';
        request.fields['prompt'] = 
          'Transcribe this English audio accurately with proper punctuation and formatting.';
      }

      // Send the request with a generous timeout for large files
      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw Exception('Transcription timed out. The audio file may be too long. Please try a shorter file.');
        },
      );

      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final decodedData = json.decode(responseBody);
        // verbose_json format returns 'text' at the top level
        final String text = decodedData['text'] ?? '';
        return text.trim();
      } else if (streamedResponse.statusCode == 401) {
        throw Exception(
          'Invalid API Key. Please check your Groq API Key in Settings.\n'
          'Get a free key at https://console.groq.com/keys'
        );
      } else if (streamedResponse.statusCode == 413) {
        throw Exception('Audio file is too large for the API. Maximum size is 25MB.');
      } else {
        final error = json.decode(responseBody);
        final String errorMsg = error['error']?['message'] ?? 'Unknown API error (${streamedResponse.statusCode})';
        throw Exception('Transcription failed: $errorMsg');
      }
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Whisper Transcription Error: $e');
    }
  }

  /// Check if a valid API key is configured.
  /// Returns true if a usable key exists, false otherwise.
  static Future<bool> hasValidApiKey(String? customApiKey) async {
    final String apiKey = (customApiKey != null && customApiKey.isNotEmpty)
        ? customApiKey
        : AppConstants.groqApiKey;
    return apiKey.isNotEmpty && !apiKey.startsWith('gsk_xxxxxx');
  }
}
