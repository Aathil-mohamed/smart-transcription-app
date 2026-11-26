import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';
import '../core/config/app_config.dart';

class SpeechService {
  final AppConfig? _config;
  final stt.SpeechToText _speech;
  bool _isAvailable = false;

  SpeechService([this._config, stt.SpeechToText? speech])
      : _speech = speech ?? stt.SpeechToText();

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

    // Determine target locale ID from language config if available
    String finalLocale = localeId;
    if (_config != null) {
      final langConfig = _config.findLanguage(localeId);
      finalLocale = langConfig.sttLocale;
    } else if (localeId == 'bilingual') {
      finalLocale = 'ta-IN';
    }

    final listenForHours = _config?.speechToText.listenForHours ?? 1;
    final pauseForSeconds = _config?.speechToText.pauseForSeconds ?? 10;

    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords);
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
        localeId: finalLocale,
        listenFor: Duration(hours: listenForHours),
        pauseFor: Duration(seconds: pauseForSeconds),
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
