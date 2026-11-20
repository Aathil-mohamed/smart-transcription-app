import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;

  bool get isAvailable => _isAvailable;
  bool get isListening => _speech.isListening;

  // Initialize Native Speech Engine
  Future<bool> initialize({
    required Function(SpeechRecognitionError) onError,
    required Function(String) onStatus,
  }) async {
    try {
      _isAvailable = await _speech.initialize(
        onError: onError,
        onStatus: onStatus,
        debugLogging: false,
      );
      return _isAvailable;
    } catch (e) {
      _isAvailable = false;
      return false;
    }
  }

  // Start Listening to Microphone
  Future<void> startListening({
    required Function(String) onResult,
    required String localeId, // e.g. 'ta-IN' for Tamil, 'en-US' for English
  }) async {
    if (!_isAvailable) return;

    // Determine target locale ID.
    // If user selects 'Bilingual', we run under 'ta-IN' since Google/Apple
    // speech services under Indian Tamil locale support English code-switching.
    String finalLocale = localeId;
    if (localeId == 'bilingual') {
      finalLocale = 'ta-IN';
    }

    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords);
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,    // Show live words dynamically as user speaks
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
        localeId: finalLocale,
        listenFor: const Duration(hours: 1), // Listen long-term
        pauseFor: const Duration(seconds: 10), // Pause detection buffer
      ),
    );
  }

  // Stop Listening session
  Future<void> stopListening() async {
    await _speech.stop();
  }

  // Cancel Listening session immediately
  Future<void> cancelListening() async {
    await _speech.cancel();
  }
}
