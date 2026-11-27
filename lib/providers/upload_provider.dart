import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';
import '../core/errors/service_error.dart';
import '../core/utils/audio_duration_helper.dart';
import '../models/transcript.dart';
import '../providers/auth_provider.dart';
import '../providers/record_provider.dart';
import '../services/secrets_service.dart';

enum UploadStatus { idle, picking, transcribing, streaming, saving, success, error }

class UploadState {
  final UploadStatus status;
  final String progressText;
  final String? errorMessage;
  final String? transcriptionId;
  final String? fileName;
  final int? fileSize;
  final String? languageCode;
  final String? languageDisplayName;
  final String liveText;
  final List<TranscriptSegment> revealedSegments;
  final List<TranscriptSegment> allSegments;
  final int? durationSec;
  final String? provider;
  final String? detectedLanguage;

  UploadState({
    required this.status,
    required this.progressText,
    this.errorMessage,
    this.transcriptionId,
    this.fileName,
    this.fileSize,
    this.languageCode,
    this.languageDisplayName,
    this.liveText = '',
    this.revealedSegments = const [],
    this.allSegments = const [],
    this.durationSec,
    this.provider,
    this.detectedLanguage,
  });

  factory UploadState.initial() {
    return UploadState(
      status: UploadStatus.idle,
      progressText: '',
    );
  }

  UploadState copyWith({
    UploadStatus? status,
    String? progressText,
    String? errorMessage,
    String? transcriptionId,
    String? fileName,
    int? fileSize,
    String? languageCode,
    String? languageDisplayName,
    String? liveText,
    List<TranscriptSegment>? revealedSegments,
    List<TranscriptSegment>? allSegments,
    int? durationSec,
    String? provider,
    String? detectedLanguage,
  }) {
    return UploadState(
      status: status ?? this.status,
      progressText: progressText ?? this.progressText,
      errorMessage: errorMessage,
      transcriptionId: transcriptionId ?? this.transcriptionId,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      languageCode: languageCode ?? this.languageCode,
      languageDisplayName: languageDisplayName ?? this.languageDisplayName,
      liveText: liveText ?? this.liveText,
      revealedSegments: revealedSegments ?? this.revealedSegments,
      allSegments: allSegments ?? this.allSegments,
      durationSec: durationSec ?? this.durationSec,
      provider: provider ?? this.provider,
      detectedLanguage: detectedLanguage ?? this.detectedLanguage,
    );
  }
}

class UploadNotifier extends StateNotifier<UploadState> {
  final Ref _ref;

  UploadNotifier(this._ref) : super(UploadState.initial());

  /// Step 1: Check API key and pick an audio file.
  Future<PlatformFile?> pickAudioFile() async {
    state = state.copyWith(
      status: UploadStatus.picking,
      progressText: 'Checking API key...',
      errorMessage: null,
      transcriptionId: null,
    );

    // Check valid Groq API key
    final bool hasKey = await _ref.read(secretsServiceProvider).hasValidApiKey();
    if (!hasKey) {
      state = state.copyWith(
        status: UploadStatus.error,
        errorMessage:
            'No Groq API Key configured!\n\n'
            'To enable transcription:\n'
            '1. Open Settings in this app\n'
            '2. Enter your API key under "Enter Groq API Key"\n'
            '3. Tap SAVE API KEY\n\n'
            'Then try uploading again.',
      );
      return null;
    }

    state = state.copyWith(progressText: 'Opening file picker...');
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result == null || result.files.isEmpty) {
      state = UploadState.initial();
      return null;
    }

    return result.files.first;
  }

  /// Step 2: Transcribe the given file with live progressive streaming to state.
  Future<void> startTranscribingFile(PlatformFile file, String languageCode) async {
    final String? path = file.path;
    if (path == null) {
      state = state.copyWith(
        status: UploadStatus.error,
        errorMessage: 'Could not access the selected file.',
      );
      return;
    }

    final config = _ref.read(appConfigProvider);
    final langConfig = config.findLanguage(languageCode);

    state = state.copyWith(
      status: UploadStatus.transcribing,
      progressText: 'Uploading audio to AI model...',
      fileName: file.name,
      fileSize: file.size,
      languageCode: languageCode,
      languageDisplayName: langConfig.displayName,
      liveText: '',
      revealedSegments: const [],
      allSegments: const [],
      errorMessage: null,
    );

    String? tempUploadPath;

    try {
      String uploadPath = path;

      // Handle common extension issues if any (e.g. temporary copy)
      final String extension = file.extension?.toLowerCase() ?? '';
      if (['aac', 'amr', 'opus'].contains(extension)) {
        try {
          final directory = await getTemporaryDirectory();
          final String tempFileName = 'temp_compat_${DateTime.now().millisecondsSinceEpoch}.$extension';
          tempUploadPath = '${directory.path}/$tempFileName';
          final File originalFile = File(path);
          await originalFile.copy(tempUploadPath);
          uploadPath = tempUploadPath;
        } catch (e) {
          debugPrint('Failed to copy file for compatibility: $e');
        }
      }

      final pipeline = _ref.read(transcriptionPipelineProvider);
      final audioFile = File(uploadPath);

      state = state.copyWith(
        progressText: 'Transcribing speech with ${langConfig.displayName}...',
      );

      final txResult = await pipeline.transcribe(
        audioFile: audioFile,
        language: langConfig,
      );

      // Clean up temporary file
      if (tempUploadPath != null) {
        try {
          final tempFile = File(tempUploadPath);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (e) {
          debugPrint('Failed to delete temp compat file: $e');
        }
      }

      if (txResult.text.trim().isEmpty) {
        state = state.copyWith(
          status: UploadStatus.error,
          errorMessage: 'No speech could be detected or transcribed in the audio file.',
        );
        return;
      }

      // Step 2a: Progressive live reveal of segments
      if (txResult.segments.isNotEmpty) {
        state = state.copyWith(
          status: UploadStatus.streaming,
          progressText: 'Streaming live transcription...',
          allSegments: txResult.segments,
          provider: txResult.provider,
          detectedLanguage: txResult.detectedLanguage,
        );

        final buffer = StringBuffer();
        final revealed = <TranscriptSegment>[];

        for (int i = 0; i < txResult.segments.length; i++) {
          final seg = txResult.segments[i];
          revealed.add(seg);
          if (buffer.isNotEmpty) buffer.write(' ');
          buffer.write(seg.text.trim());

          state = state.copyWith(
            liveText: buffer.toString(),
            revealedSegments: List.unmodifiable(revealed),
          );

          // Paced streaming so user visually experiences live transcription reveal
          if (i < txResult.segments.length - 1) {
            await Future.delayed(const Duration(milliseconds: 130));
          }
        }
      } else {
        state = state.copyWith(
          status: UploadStatus.streaming,
          liveText: txResult.text,
          provider: txResult.provider,
          detectedLanguage: txResult.detectedLanguage,
        );
      }

      // Read real duration from audio file metadata or fallback
      final durationSec = await AudioDurationHelper.getDuration(
        audioFile: audioFile,
        segments: txResult.segments,
        providerDuration: txResult.duration,
      );

      // Step 3: Save transcript to Firestore
      state = state.copyWith(
        status: UploadStatus.saving,
        progressText: 'Saving note to database...',
        durationSec: durationSec,
      );

      final String? currentUserId = _ref.read(authNotifierProvider).value?.uid;
      if (currentUserId == null) {
        state = state.copyWith(
          status: UploadStatus.error,
          errorMessage: 'User is not logged in. Failed to save transcription.',
        );
        return;
      }

      final String docId = const Uuid().v4();

      final transcription = TranscriptionModel(
        transcriptionId: docId,
        userId: currentUserId,
        title: 'Uploaded Audio - ${file.name}',
        transcript: txResult.text,
        language: langConfig.displayName,
        duration: durationSec,
        provider: txResult.provider,
        detectedLanguage: txResult.detectedLanguage,
        segmentCount: txResult.segmentCount,
        droppedSegmentCount: txResult.droppedSegmentCount,
        segments: txResult.segments,
        createdAt: DateTime.now(),
      );

      if (kDebugMode) {
        debugPrint('[Upload] Text length saved to Firestore: ${transcription.transcript.length} chars (duration: ${durationSec}s, docId: $docId)');
      }

      await _ref.read(firestoreServiceProvider).saveTranscription(transcription);

      state = state.copyWith(
        status: UploadStatus.success,
        progressText: 'Transcription Complete!',
        transcriptionId: docId,
        durationSec: durationSec,
        liveText: txResult.text,
        allSegments: txResult.segments,
        revealedSegments: txResult.segments,
      );
    } on ServiceException catch (e) {
      if (tempUploadPath != null) {
        try {
          final tempFile = File(tempUploadPath);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      }
      state = state.copyWith(
        status: UploadStatus.error,
        errorMessage: 'Transcription failed: ${e.code.name}${e.technicalDetails != null ? ' (${e.technicalDetails})' : ''}',
      );
    } catch (e) {
      if (tempUploadPath != null) {
        try {
          final tempFile = File(tempUploadPath);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      }
      state = state.copyWith(
        status: UploadStatus.error,
        errorMessage: 'An unexpected error occurred during upload: $e',
      );
    }
  }

  /// Convenience wrapper that picks and transcribes in one call
  Future<void> pickAndTranscribeAudio(String languageCode) async {
    final file = await pickAudioFile();
    if (file != null) {
      await startTranscribingFile(file, languageCode);
    }
  }

  void reset() {
    state = UploadState.initial();
  }
}

final uploadNotifierProvider = StateNotifierProvider<UploadNotifier, UploadState>((ref) {
  return UploadNotifier(ref);
});
