import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';
import '../models/transcript.dart';
import '../services/speech_service.dart';
import '../services/whisper_service.dart';
import '../services/firestore_service.dart';
import '../services/secrets_service.dart';
import 'auth_provider.dart';

// Singletons for services
final speechServiceProvider = Provider<SpeechService>((ref) {
  final config = ref.watch(appConfigProvider);
  return SpeechService(config);
});

final whisperServiceProvider = Provider<WhisperService>((ref) {
  final config = ref.watch(appConfigProvider);
  final secrets = ref.watch(secretsServiceProvider);
  return WhisperService(config, secrets);
});

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  final config = ref.watch(appConfigProvider);
  return FirestoreService(config);
});

// State Model for recording
enum RecordStatus { idle, recording, paused, finalizing }

class RecordState {
  final RecordStatus status;
  final String liveText;
  final double currentDb;
  final List<double> waveHistory;
  final int durationSecs;
  final String selectedLanguageCode; // 'bilingual', 'ta-IN', 'en-US'
  final String? errorMessage;

  RecordState({
    required this.status,
    required this.liveText,
    required this.currentDb,
    required this.waveHistory,
    required this.durationSecs,
    required this.selectedLanguageCode,
    this.errorMessage,
  });

  factory RecordState.initial() {
    return RecordState(
      status: RecordStatus.idle,
      liveText: '',
      currentDb: -160.0,
      waveHistory: const [],
      durationSecs: 0,
      selectedLanguageCode: 'bilingual',
    );
  }

  RecordState copyWith({
    RecordStatus? status,
    String? liveText,
    double? currentDb,
    List<double>? waveHistory,
    int? durationSecs,
    String? selectedLanguageCode,
    String? errorMessage,
  }) {
    return RecordState(
      status: status ?? this.status,
      liveText: liveText ?? this.liveText,
      currentDb: currentDb ?? this.currentDb,
      waveHistory: waveHistory ?? this.waveHistory,
      durationSecs: durationSecs ?? this.durationSecs,
      selectedLanguageCode: selectedLanguageCode ?? this.selectedLanguageCode,
      errorMessage: errorMessage,
    );
  }
}

class RecordNotifier extends StateNotifier<RecordState> {
  final Ref _ref;
  final AudioRecorder _audioRecorder = AudioRecorder();
  
  Timer? _timer;
  Timer? _amplitudeTimer;
  String? _localAudioPath;
  
  String _previousText = '';
  String _currentSegment = '';

  RecordNotifier(this._ref) : super(RecordState.initial());

  // Cancel/discard recording without saving
  Future<void> cancelRecording() async {
    _stopTimers();
    try {
      await _audioRecorder.stop();
    } catch (e, st) {
      debugPrint('Audio recorder stop error in cancelRecording: $e\n$st');
    }
    try {
      await _ref.read(speechServiceProvider).cancelListening();
    } catch (e, st) {
      debugPrint('Speech service cancel error in cancelRecording: $e\n$st');
    }
    _previousText = '';
    _currentSegment = '';
    state = RecordState.initial();
    _localAudioPath = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amplitudeTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  // Change recording language
  void setLanguage(String code) {
    if (state.status == RecordStatus.idle) {
      state = state.copyWith(selectedLanguageCode: code);
    }
  }

  // Start Recording Session
  Future<void> startRecording() async {
    try {
      _previousText = '';
      _currentSegment = '';
      state = state.copyWith(errorMessage: null, liveText: 'Listening...');

      // 1. Check & Request Permissions
      final speechService = _ref.read(speechServiceProvider);
      final hasMicPermission = await _audioRecorder.hasPermission();
      
      if (!hasMicPermission) {
        state = state.copyWith(
          errorMessage: 'Microphone permission denied.',
          status: RecordStatus.idle,
        );
        return;
      }

      // 2. Initialize Native Speech Recognition
      final initialized = await speechService.initialize(
        onError: (SpeechRecognitionError err) {
          debugPrint('Speech Engine Error: ${err.errorMsg}');
          if (state.status == RecordStatus.recording) {
            _restartListening();
          }
        },
        onStatus: (String status) {
          debugPrint('Speech Status: $status');
          if ((status == 'notListening' || status == 'done') && state.status == RecordStatus.recording) {
            _restartListening();
          }
        },
      );

      if (!initialized) {
        state = state.copyWith(
          errorMessage: 'Failed to initialize speech recognition engine.',
          status: RecordStatus.idle,
        );
        return;
      }

      // 3. Prepare Audio File Path from config
      final config = _ref.read(appConfigProvider);
      final directory = await getTemporaryDirectory();
      final String filename = '${config.audio.fileNamePrefix}${DateTime.now().millisecondsSinceEpoch}${config.audio.fileExtension}';
      _localAudioPath = '${directory.path}/$filename';

      // 4. Start Audio Recorder with config
      await _audioRecorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: config.audio.sampleRate,
          numChannels: config.audio.numChannels,
          bitRate: config.audio.bitRate,
          autoGain: config.audio.autoGain,
          echoCancel: config.audio.echoCancel,
          noiseSuppress: config.audio.noiseSuppress,
        ),
        path: _localAudioPath!,
      );

      // 5. Start Native Speech recognition (instant live rendering)
      await speechService.startListening(
        localeId: state.selectedLanguageCode,
        onResult: (String text) {
          if (state.status == RecordStatus.recording) {
            _currentSegment = text;
            state = state.copyWith(
              liveText: _previousText.isEmpty 
                  ? _currentSegment 
                  : '$_previousText\n$_currentSegment',
            );
          }
        },
      );

      state = state.copyWith(
        status: RecordStatus.recording,
        liveText: 'Speak now...',
        waveHistory: [],
      );

      // 6. Start UI Amplitude tracker & seconds timer
      _startTimers();
    } catch (e) {
      state = state.copyWith(
        status: RecordStatus.idle,
        errorMessage: 'Failed to start recording: $e',
      );
    }
  }

  // Automatic restart loop helper
  void _restartListening() async {
    if (state.status != RecordStatus.recording) return;

    if (_currentSegment.trim().isNotEmpty) {
      if (_previousText.isNotEmpty) {
        _previousText = '$_previousText\n$_currentSegment';
      } else {
        _previousText = _currentSegment;
      }
      _currentSegment = '';
    }

    try {
      final config = _ref.read(appConfigProvider);
      final speechService = _ref.read(speechServiceProvider);
      await Future.delayed(Duration(milliseconds: config.speechToText.restartDelayMs));
      if (state.status != RecordStatus.recording) return;

      await speechService.startListening(
        localeId: state.selectedLanguageCode,
        onResult: (String text) {
          if (state.status == RecordStatus.recording) {
            _currentSegment = text;
            state = state.copyWith(
              liveText: _previousText.isEmpty 
                  ? _currentSegment 
                  : '$_previousText\n$_currentSegment',
            );
          }
        },
      );
    } catch (e) {
      debugPrint('Failed to restart speech recognition: $e');
    }
  }

  // Pause Recording Session
  Future<void> pauseRecording() async {
    if (state.status != RecordStatus.recording) return;

    try {
      _stopTimers();
      await _audioRecorder.pause();
      await _ref.read(speechServiceProvider).stopListening();

      if (_currentSegment.trim().isNotEmpty) {
        if (_previousText.isNotEmpty) {
          _previousText = '$_previousText\n$_currentSegment';
        } else {
          _previousText = _currentSegment;
        }
        _currentSegment = '';
      }

      state = state.copyWith(status: RecordStatus.paused);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to pause: $e');
    }
  }

  // Resume Recording Session
  Future<void> resumeRecording() async {
    if (state.status != RecordStatus.paused) return;

    try {
      await _audioRecorder.resume();
      await _ref.read(speechServiceProvider).startListening(
        localeId: state.selectedLanguageCode,
        onResult: (String text) {
          if (state.status == RecordStatus.recording) {
            _currentSegment = text;
            state = state.copyWith(
              liveText: _previousText.isEmpty 
                  ? _currentSegment 
                  : '$_previousText\n$_currentSegment',
            );
          }
        },
      );

      state = state.copyWith(status: RecordStatus.recording);
      _startTimers();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to resume: $e');
    }
  }

  // Stop & Finalize Recording (runs Whisper refine backend)
  Future<void> stopRecording() async {
    if (state.status != RecordStatus.recording && state.status != RecordStatus.paused) return;

    try {
      state = state.copyWith(status: RecordStatus.finalizing);
      _stopTimers();

      // 1. Stop all inputs
      final String? finalAudioPath = await _audioRecorder.stop();
      await _ref.read(speechServiceProvider).stopListening();

      if (_currentSegment.trim().isNotEmpty) {
        if (_previousText.isNotEmpty) {
          _previousText = '$_previousText\n$_currentSegment';
        } else {
          _previousText = _currentSegment;
        }
        _currentSegment = '';
      }

      // Preserve native text if we need to fall back
      final String nativeDraftText = _previousText;
      String finalTranscript = nativeDraftText;

      // 2. Bilingual Whisper Refinement
      if (finalAudioPath != null) {
        state = state.copyWith(liveText: 'Refining transcript using AI...');
        try {
          final whisperService = _ref.read(whisperServiceProvider);
          final refinedText = await whisperService.transcribeAudio(
            filePath: finalAudioPath,
            languageCode: state.selectedLanguageCode,
          );
          if (refinedText.isNotEmpty) {
            finalTranscript = refinedText;
          }
        } catch (e) {
          debugPrint('Whisper failed, falling back to on-device draft: $e');
          state = state.copyWith(errorMessage: 'AI Refinement skipped (using live draft): $e');
        }
      }

      // 3. Save transcript to Firestore
      final String? currentUserId = _ref.read(authNotifierProvider).value?.uid;
      if (currentUserId != null && finalTranscript.trim().isNotEmpty && finalTranscript != 'Speak now...' && finalTranscript != 'Listening...') {
        final docId = const Uuid().v4();
        final config = _ref.read(appConfigProvider);
        final langConfig = config.findLanguage(state.selectedLanguageCode);

        final transcription = TranscriptionModel(
          transcriptionId: docId,
          userId: currentUserId,
          title: 'Transcription - ${DateTime.now().toString().split('.')[0]}',
          transcript: finalTranscript,
          language: langConfig.displayName,
          duration: state.durationSecs,
          createdAt: DateTime.now(),
        );

        await _ref.read(firestoreServiceProvider).saveTranscription(transcription);
      }

      // Reset state to idle
      state = RecordState(
        status: RecordStatus.idle,
        liveText: '',
        currentDb: -160.0,
        waveHistory: const [],
        durationSecs: 0,
        selectedLanguageCode: state.selectedLanguageCode,
        errorMessage: state.errorMessage,
      );
      _localAudioPath = null;
    } catch (e) {
      state = state.copyWith(
        status: RecordStatus.idle,
        errorMessage: 'Failed to save recording: $e',
      );
    }
  }

  // Timer helpers using config
  void _startTimers() {
    final config = _ref.read(appConfigProvider);

    _timer = Timer.periodic(Duration(milliseconds: config.audio.secondsIntervalMs), (timer) {
      state = state.copyWith(durationSecs: state.durationSecs + 1);
    });

    _amplitudeTimer = Timer.periodic(Duration(milliseconds: config.audio.amplitudeIntervalMs), (timer) async {
      final amp = await _audioRecorder.getAmplitude();
      final minDb = config.audio.minDb;
      final maxDb = config.audio.maxDb;
      final range = maxDb - minDb;
      double normalized = range != 0 ? (amp.current - minDb) / range : 0.0;
      if (normalized < 0.0) normalized = 0.0;
      if (normalized > 1.0) normalized = 1.0;

      final history = List<double>.from(state.waveHistory)..add(normalized);
      if (history.length > config.audio.waveHistoryLimit) {
        history.removeAt(0);
      }

      state = state.copyWith(
        currentDb: amp.current,
        waveHistory: history,
      );
    });
  }

  void _stopTimers() {
    _timer?.cancel();
    _amplitudeTimer?.cancel();
  }
}

// Global provider for screen recording UI controllers
final recordNotifierProvider = StateNotifierProvider<RecordNotifier, RecordState>((ref) {
  return RecordNotifier(ref);
});
