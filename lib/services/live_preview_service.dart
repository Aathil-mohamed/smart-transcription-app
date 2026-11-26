import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../core/config/app_config.dart';

enum LivePreviewStatus {
  idle,
  listening,
  paused,
  unavailable,
}

class LivePreviewService {
  final AppConfig _config;
  final stt.SpeechToText _speech;

  bool _isAvailable = false;
  LivePreviewStatus _status = LivePreviewStatus.idle;
  int _restartCount = 0;
  bool _isRestarting = false;

  String _accumulatedText = '';
  String _currentSegment = '';

  Function(String text)? _onTextUpdated;
  Function(String reason)? _onUnavailable;
  LanguageConfig? _currentLanguage;

  LivePreviewService(
    this._config, {
    stt.SpeechToText? speech,
  }) : _speech = speech ?? stt.SpeechToText();

  LivePreviewStatus get status => _status;
  bool get isAvailable => _isAvailable;
  String get draftText {
    if (_accumulatedText.isEmpty) return _currentSegment.trim();
    if (_currentSegment.trim().isEmpty) return _accumulatedText.trim();
    return '$_accumulatedText\n${_currentSegment.trim()}'.trim();
  }

  Future<bool> initialize({
    Function(String text)? onTextUpdated,
    Function(String reason)? onUnavailable,
  }) async {
    _onTextUpdated = onTextUpdated;
    _onUnavailable = onUnavailable;

    try {
      _isAvailable = await _speech.initialize(
        onError: _handleError,
        onStatus: _handleStatus,
        debugLogging: false,
      );
      if (!_isAvailable) {
        _status = LivePreviewStatus.unavailable;
        _onUnavailable?.call('Speech recognition unavailable on this device');
      }
      return _isAvailable;
    } catch (e) {
      _isAvailable = false;
      _status = LivePreviewStatus.unavailable;
      _onUnavailable?.call('Failed to initialize speech engine: $e');
      return false;
    }
  }

  Future<void> startListening({required LanguageConfig language}) async {
    if (!_isAvailable) return;

    _currentLanguage = language;
    _restartCount = 0;
    _isRestarting = false;
    _accumulatedText = '';
    _currentSegment = '';
    _status = LivePreviewStatus.listening;

    await _listenInternal();
  }

  Future<void> _listenInternal() async {
    if (_status != LivePreviewStatus.listening || _currentLanguage == null) return;

    try {
      await _speech.listen(
        onResult: (result) {
          if (_status == LivePreviewStatus.listening) {
            _currentSegment = result.recognizedWords;
            _onTextUpdated?.call(draftText);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
          localeId: _currentLanguage!.speechLocale,
          listenFor: Duration(hours: _config.speechToText.listenForHours),
          pauseFor: Duration(seconds: _config.speechToText.pauseForSeconds),
        ),
      );
    } catch (e) {
      debugPrint('LivePreview listen error: $e');
    }
  }

  void _handleError(SpeechRecognitionError err) {
    debugPrint('LivePreview Engine Error: ${err.errorMsg} (permanent: ${err.permanent})');
    // Only permanent errors count as critical failures
    if (err.permanent) {
      _status = LivePreviewStatus.unavailable;
      _onUnavailable?.call(err.errorMsg);
      return;
    }

    _attemptRestart();
  }

  void _handleStatus(String status) {
    debugPrint('LivePreview Engine Status: $status');
    if ((status == 'notListening' || status == 'done') &&
        _status == LivePreviewStatus.listening) {
      _attemptRestart();
    }
  }

  void _attemptRestart() async {
    if (_status != LivePreviewStatus.listening || _isRestarting) return;
    _isRestarting = true;

    // Save previous segment into accumulated text
    if (_currentSegment.trim().isNotEmpty) {
      if (_accumulatedText.isNotEmpty) {
        _accumulatedText = '$_accumulatedText\n${_currentSegment.trim()}';
      } else {
        _accumulatedText = _currentSegment.trim();
      }
      _currentSegment = '';
    }

    _restartCount++;
    if (_restartCount > _config.speechToText.maxRestarts) {
      debugPrint('LivePreview reached max restarts (${_config.speechToText.maxRestarts}). Stopping preview.');
      _status = LivePreviewStatus.unavailable;
      _isRestarting = false;
      _onUnavailable?.call('Live preview stopped after reaching restart limit');
      return;
    }

    final delayMs = _config.speechToText.restartDelayMs * _restartCount;
    await Future.delayed(Duration(milliseconds: delayMs));

    if (_status == LivePreviewStatus.listening) {
      await _listenInternal();
    }
    _isRestarting = false;
  }

  Future<void> pauseListening() async {
    if (_status != LivePreviewStatus.listening) return;
    _status = LivePreviewStatus.paused;

    try {
      await _speech.stop();
    } catch (_) {}

    if (_currentSegment.trim().isNotEmpty) {
      if (_accumulatedText.isNotEmpty) {
        _accumulatedText = '$_accumulatedText\n${_currentSegment.trim()}';
      } else {
        _accumulatedText = _currentSegment.trim();
      }
      _currentSegment = '';
    }
  }

  Future<void> resumeListening({required LanguageConfig language}) async {
    if (_status != LivePreviewStatus.paused) return;
    _currentLanguage = language;
    _status = LivePreviewStatus.listening;
    await _listenInternal();
  }

  Future<void> stopListening() async {
    _status = LivePreviewStatus.idle;
    try {
      await _speech.stop();
    } catch (_) {}

    if (_currentSegment.trim().isNotEmpty) {
      if (_accumulatedText.isNotEmpty) {
        _accumulatedText = '$_accumulatedText\n${_currentSegment.trim()}';
      } else {
        _accumulatedText = _currentSegment.trim();
      }
      _currentSegment = '';
    }
  }

  Future<void> cancelListening() async {
    _status = LivePreviewStatus.idle;
    try {
      await _speech.cancel();
    } catch (_) {}
    _accumulatedText = '';
    _currentSegment = '';
    _restartCount = 0;
  }

  void reset() {
    _accumulatedText = '';
    _currentSegment = '';
    _restartCount = 0;
    _status = LivePreviewStatus.idle;
  }
}
