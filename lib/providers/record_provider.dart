import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';
import '../models/transcript.dart';
import '../services/firestore_service.dart';
import '../services/live_preview_service.dart';
import '../services/secrets_service.dart';
import '../services/settings_repository.dart';
import '../services/speech_service.dart';
import '../services/transcription/transcription_pipeline.dart';
import '../services/transcription/transcription_provider.dart';
import '../services/whisper_service.dart';
import 'auth_provider.dart';

import 'package:http/http.dart' as http;

final sharedHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(() => client.close());
  return client;
});

final transcriptionPipelineProvider = Provider<TranscriptionPipeline>((ref) {
  final config = ref.watch(appConfigProvider);
  final secrets = ref.watch(secretsServiceProvider);
  final client = ref.watch(sharedHttpClientProvider);
  return TranscriptionPipeline.create(config, secrets, client: client);
});

final speechServiceProvider = Provider<SpeechService>((ref) {
  final config = ref.watch(appConfigProvider);
  return SpeechService(config);
});

final livePreviewServiceProvider = Provider<LivePreviewService>((ref) {
  final config = ref.watch(appConfigProvider);
  return LivePreviewService(config);
});

final whisperServiceProvider = Provider<WhisperService>((ref) {
  final config = ref.watch(appConfigProvider);
  final secrets = ref.watch(secretsServiceProvider);
  final pipeline = ref.watch(transcriptionPipelineProvider);
  return WhisperService(config, secrets, pipeline: pipeline);
});

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  final config = ref.watch(appConfigProvider);
  return FirestoreService(config);
});

enum RecordStatus { idle, recording, paused, finalizing, retryRequired }

class RecordState {
  final RecordStatus status;
  final String liveText;
  final double currentDb;
  final List<double> waveHistory;
  final int durationSecs;
  final int maxDurationSecs;
  final String selectedLanguageCode;
  final String? errorMessage;
  final String? failedAudioPath;
  final bool canRetry;

  RecordState({
    required this.status,
    required this.liveText,
    required this.currentDb,
    required this.waveHistory,
    required this.durationSecs,
    required this.maxDurationSecs,
    required this.selectedLanguageCode,
    this.errorMessage,
    this.failedAudioPath,
    this.canRetry = false,
  });

  factory RecordState.initial([int maxDurationSecs = 3600]) {
    return RecordState(
      status: RecordStatus.idle,
      liveText: '',
      currentDb: -160.0,
      waveHistory: const [],
      durationSecs: 0,
      maxDurationSecs: maxDurationSecs,
      selectedLanguageCode: 'bilingual',
      failedAudioPath: null,
      canRetry: false,
    );
  }

  RecordState copyWith({
    RecordStatus? status,
    String? liveText,
    double? currentDb,
    List<double>? waveHistory,
    int? durationSecs,
    int? maxDurationSecs,
    String? selectedLanguageCode,
    String? errorMessage,
    String? failedAudioPath,
    bool? canRetry,
  }) {
    return RecordState(
      status: status ?? this.status,
      liveText: liveText ?? this.liveText,
      currentDb: currentDb ?? this.currentDb,
      waveHistory: waveHistory ?? this.waveHistory,
      durationSecs: durationSecs ?? this.durationSecs,
      maxDurationSecs: maxDurationSecs ?? this.maxDurationSecs,
      selectedLanguageCode: selectedLanguageCode ?? this.selectedLanguageCode,
      errorMessage: errorMessage,
      failedAudioPath: failedAudioPath ?? this.failedAudioPath,
      canRetry: canRetry ?? this.canRetry,
    );
  }
}

class RecordNotifier extends StateNotifier<RecordState> {
  final Ref _ref;
  final AudioRecorder _audioRecorder = AudioRecorder();

  Timer? _timer;
  Timer? _amplitudeTimer;
  String? _localAudioPath;
  bool? _isMicPermissionGranted;
  bool _isWarmingUp = false;
  bool _isWarmedUp = false;

  RecordNotifier(this._ref) : super(RecordState.initial());

  @override
  void dispose() {
    _stopTimers();
    _audioRecorder.dispose();
    super.dispose();
  }

  /// Pre-warms microphone permissions and the native speech recognizer on screen open.
  Future<void> warmUp() async {
    if (_isWarmingUp || _isWarmedUp) return;
    _isWarmingUp = true;
    try {
      _isMicPermissionGranted = await _audioRecorder.hasPermission();

      final isLivePreviewEnabled = _ref.read(settingsRepositoryProvider).isLivePreviewEnabled;
      if (isLivePreviewEnabled) {
        final livePreview = _ref.read(livePreviewServiceProvider);
        await livePreview.initialize(
          onUnavailable: (reason) {
            debugPrint('Live preview unavailable: $reason');
          },
        );
      }
      _isWarmedUp = true;
      debugPrint('[Timing] Warm-up complete: mic permission cached, speech engine initialized');
    } catch (e) {
      debugPrint('Warm up error: $e');
    } finally {
      _isWarmingUp = false;
    }
  }

  void setLanguage(String code) {
    if (state.status == RecordStatus.idle || state.status == RecordStatus.retryRequired) {
      state = state.copyWith(selectedLanguageCode: code);
    }
  }

  // Cancel and discard recording
  Future<void> cancelRecording() async {
    _stopTimers();
    try {
      await _audioRecorder.stop();
    } catch (e, st) {
      debugPrint('Audio recorder stop error in cancelRecording: $e\n$st');
    }

    try {
      await _ref.read(livePreviewServiceProvider).cancelListening();
    } catch (e, st) {
      debugPrint('Live preview cancel error in cancelRecording: $e\n$st');
    }

    // Clean up local audio file if present
    final pathToDelete = _localAudioPath ?? state.failedAudioPath;
    if (pathToDelete != null) {
      try {
        final file = File(pathToDelete);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Failed to delete cancelled recording file: $e');
      }
    }

    _localAudioPath = null;
    final config = _ref.read(appConfigProvider);
    state = RecordState.initial(config.audio.calculateMaxDurationSeconds(config.api.maxFileSizeBytes));
  }

  // Start Recording Session
  Future<void> startRecording() async {
    final tapWatch = Stopwatch()..start();
    bool firstAmplitudeLogged = false;
    bool firstLiveTextLogged = false;

    final config = _ref.read(appConfigProvider);
    final maxDuration = config.audio.calculateMaxDurationSeconds(config.api.maxFileSizeBytes);
    final isLivePreviewEnabled = _ref.read(settingsRepositoryProvider).isLivePreviewEnabled;

    // 1. Show recording UI immediately on tap
    state = state.copyWith(
      status: RecordStatus.recording,
      errorMessage: null,
      liveText: isLivePreviewEnabled ? 'Listening...' : 'Recording in progress...',
      waveHistory: const [],
      durationSecs: 0,
      maxDurationSecs: maxDuration,
      canRetry: false,
      failedAudioPath: null,
    );

    // 2. Early network connection pre-warm to transcription host
    unawaited(_ref.read(transcriptionPipelineProvider).prewarmConnection());

    try {
      // 3. Verify microphone permission (uses cached result if pre-warmed)
      final hasMicPermission = _isMicPermissionGranted ?? await _audioRecorder.hasPermission();
      _isMicPermissionGranted = hasMicPermission;
      if (!hasMicPermission) {
        state = state.copyWith(
          errorMessage: 'Microphone permission denied.',
          status: RecordStatus.idle,
        );
        return;
      }

      // 4. Prepare documents directory storage path
      final appDir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${appDir.path}/${config.audio.recordingsFolder}');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      final filename = '${config.audio.fileNamePrefix}${const Uuid().v4()}${config.audio.fileExtension}';
      _localAudioPath = '${recordingsDir.path}/$filename';

      // 5. Start audio recorder FIRST
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

      debugPrint('[Timing] tap -> recorder started: ${tapWatch.elapsedMilliseconds}ms');

      // 6. Start timers with first amplitude measurement
      _startTimers(
        onFirstAmplitude: () {
          if (!firstAmplitudeLogged) {
            firstAmplitudeLogged = true;
            debugPrint('[Timing] tap -> first amplitude event: ${tapWatch.elapsedMilliseconds}ms');
          }
        },
      );

      // 7. Start preview AFTER recorder starts
      if (isLivePreviewEnabled) {
        final livePreview = _ref.read(livePreviewServiceProvider);
        final langConfig = config.findLanguage(state.selectedLanguageCode);

        if (!livePreview.isAvailable) {
          await livePreview.initialize(
            onUnavailable: (reason) {
              debugPrint('Live preview unavailable: $reason');
            },
          );
        }

        await livePreview.startListening(
          language: langConfig,
          onTextUpdated: (text) {
            if (state.status == RecordStatus.recording) {
              if (text.trim().isNotEmpty && !firstLiveTextLogged) {
                firstLiveTextLogged = true;
                debugPrint('[Timing] tap -> first live text: ${tapWatch.elapsedMilliseconds}ms');
              }
              state = state.copyWith(liveText: text);
            }
          },
        );

        debugPrint('[Timing] tap -> speech engine ready: ${tapWatch.elapsedMilliseconds}ms');
      }
    } catch (e) {
      _stopTimers();
      state = state.copyWith(
        status: RecordStatus.idle,
        errorMessage: 'Failed to start recording: $e',
      );
    }
  }

  // Pause Recording
  Future<void> pauseRecording() async {
    if (state.status != RecordStatus.recording) return;

    try {
      _stopTimers();
      await _audioRecorder.pause();
      await _ref.read(livePreviewServiceProvider).pauseListening();
      state = state.copyWith(status: RecordStatus.paused);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to pause: $e');
    }
  }

  // Resume Recording
  Future<void> resumeRecording() async {
    if (state.status != RecordStatus.paused) return;

    try {
      await _audioRecorder.resume();
      final config = _ref.read(appConfigProvider);
      final langConfig = config.findLanguage(state.selectedLanguageCode);
      await _ref.read(livePreviewServiceProvider).resumeListening(language: langConfig);

      state = state.copyWith(status: RecordStatus.recording);
      _startTimers();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to resume: $e');
    }
  }

  // Stop & Finalize Recording
  Future<bool> stopRecording() async {
    if (state.status != RecordStatus.recording && state.status != RecordStatus.paused) {
      return false;
    }

    final stopWatch = Stopwatch()..start();

    try {
      state = state.copyWith(status: RecordStatus.finalizing);
      _stopTimers();

      final String? finalAudioPath = await _audioRecorder.stop();
      final livePreview = _ref.read(livePreviewServiceProvider);
      await livePreview.stopListening();
      final String onDeviceDraft = livePreview.draftText;

      if (finalAudioPath == null) {
        state = state.copyWith(
          status: RecordStatus.idle,
          errorMessage: 'Audio recording file was not created.',
        );
        return false;
      }

      final config = _ref.read(appConfigProvider);
      final langConfig = config.findLanguage(state.selectedLanguageCode);
      final pipeline = _ref.read(transcriptionPipelineProvider);

      state = state.copyWith(liveText: 'Refining transcript using AI...');

      final userVocab = _ref.read(settingsRepositoryProvider).customVocabulary;
      TranscriptionResult? pipelineResult;
      try {
        debugPrint('[Timing] stop -> upload started: ${stopWatch.elapsedMilliseconds}ms');
        pipelineResult = await pipeline.transcribe(
          audioFile: File(finalAudioPath),
          language: langConfig,
          additionalVocabulary: userVocab,
        );
      } catch (e) {
        debugPrint('Pipeline transcription failed: $e');
      }

      String finalTranscript = '';
      List<TranscriptSegment>? segments;
      String? providerName;

      if (pipelineResult != null && pipelineResult.text.trim().isNotEmpty) {
        finalTranscript = pipelineResult.text;
        segments = pipelineResult.segments;
        providerName = pipelineResult.provider;
      } else if (onDeviceDraft.trim().isNotEmpty) {
        // Fall back to live draft
        finalTranscript = onDeviceDraft;
        providerName = 'on_device_fallback';
        debugPrint('Using on-device speech draft as fallback');
      } else {
        // Both pipeline and draft failed -> NEVER LOSE AUDIO
        state = state.copyWith(
          status: RecordStatus.retryRequired,
          failedAudioPath: finalAudioPath,
          canRetry: true,
          errorMessage: 'Transcription could not be completed. Your audio has been saved safely.',
        );
        return false;
      }

      // Save transcription to Firestore
      final currentUserId = _ref.read(authNotifierProvider).value?.uid;
      if (currentUserId != null && finalTranscript.trim().isNotEmpty) {
        final docId = const Uuid().v4();

        final transcription = TranscriptionModel(
          transcriptionId: docId,
          userId: currentUserId,
          title: 'Transcription - ${DateTime.now().toString().split('.')[0]}',
          transcript: finalTranscript,
          language: langConfig.storedName,
          duration: state.durationSecs,
          audioLocalPath: finalAudioPath,
          provider: providerName,
          detectedLanguage: pipelineResult?.detectedLanguage,
          segmentCount: pipelineResult?.segmentCount ?? segments?.length ?? 0,
          droppedSegmentCount: pipelineResult?.droppedSegmentCount ?? 0,
          segments: segments,
          createdAt: DateTime.now(),
        );

        final saveWatch = Stopwatch()..start();
        await _ref.read(firestoreServiceProvider).saveTranscription(transcription);
        debugPrint('[Timing] response -> saved: ${saveWatch.elapsedMilliseconds}ms');
      }

      state = RecordState.initial(config.audio.calculateMaxDurationSeconds(config.api.maxFileSizeBytes));
      _localAudioPath = null;
      return true;
    } catch (e) {
      state = state.copyWith(
        status: RecordStatus.retryRequired,
        failedAudioPath: _localAudioPath,
        canRetry: true,
        errorMessage: 'Failed to finalize transcription: $e',
      );
      return false;
    }
  }

  // Retry failed transcription
  Future<bool> retryTranscription() async {
    final audioPath = state.failedAudioPath;
    if (audioPath == null) return false;

    state = state.copyWith(
      status: RecordStatus.finalizing,
      liveText: 'Retrying transcription...',
      errorMessage: null,
    );

    try {
      final config = _ref.read(appConfigProvider);
      final langConfig = config.findLanguage(state.selectedLanguageCode);
      final pipeline = _ref.read(transcriptionPipelineProvider);

      final userVocab = _ref.read(settingsRepositoryProvider).customVocabulary;
      final result = await pipeline.transcribe(
        audioFile: File(audioPath),
        language: langConfig,
        additionalVocabulary: userVocab,
      );

      final currentUserId = _ref.read(authNotifierProvider).value?.uid;
      if (currentUserId != null && result.text.trim().isNotEmpty) {
        final docId = const Uuid().v4();

        final transcription = TranscriptionModel(
          transcriptionId: docId,
          userId: currentUserId,
          title: 'Transcription - ${DateTime.now().toString().split('.')[0]}',
          transcript: result.text,
          language: langConfig.storedName,
          duration: state.durationSecs,
          audioLocalPath: audioPath,
          provider: result.provider,
          detectedLanguage: result.detectedLanguage,
          segmentCount: result.segmentCount,
          droppedSegmentCount: result.droppedSegmentCount,
          segments: result.segments,
          createdAt: DateTime.now(),
        );

        await _ref.read(firestoreServiceProvider).saveTranscription(transcription);
      }

      state = RecordState.initial(config.audio.calculateMaxDurationSeconds(config.api.maxFileSizeBytes));
      _localAudioPath = null;
      return true;
    } catch (e) {
      state = state.copyWith(
        status: RecordStatus.retryRequired,
        canRetry: true,
        errorMessage: 'Retry failed: $e',
      );
      return false;
    }
  }

  void _startTimers({VoidCallback? onFirstAmplitude}) {
    final config = _ref.read(appConfigProvider);

    _timer = Timer.periodic(Duration(milliseconds: config.audio.secondsIntervalMs), (timer) {
      final nextSecs = state.durationSecs + 1;
      // Auto-stop at maximum derived duration
      if (nextSecs >= state.maxDurationSecs) {
        stopRecording();
        return;
      }
      state = state.copyWith(durationSecs: nextSecs);
    });

    _amplitudeTimer = Timer.periodic(Duration(milliseconds: config.audio.amplitudeIntervalMs), (timer) async {
      final amp = await _audioRecorder.getAmplitude();
      onFirstAmplitude?.call();
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

final recordNotifierProvider = StateNotifierProvider<RecordNotifier, RecordState>((ref) {
  return RecordNotifier(ref);
});
