import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';
import '../core/errors/service_error.dart';
import '../models/transcript.dart';
import '../providers/auth_provider.dart';
import '../providers/record_provider.dart';
import '../services/secrets_service.dart';

enum UploadStatus { idle, picking, transcribing, saving, success, error }

class UploadState {
  final UploadStatus status;
  final String progressText;
  final String? errorMessage;
  final String? transcriptionId;

  UploadState({
    required this.status,
    required this.progressText,
    this.errorMessage,
    this.transcriptionId,
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
  }) {
    return UploadState(
      status: status ?? this.status,
      progressText: progressText ?? this.progressText,
      errorMessage: errorMessage,
      transcriptionId: transcriptionId ?? this.transcriptionId,
    );
  }
}

class UploadNotifier extends StateNotifier<UploadState> {
  final Ref _ref;

  UploadNotifier(this._ref) : super(UploadState.initial());

  Future<void> pickAndTranscribeAudio(String languageCode) async {
    state = state.copyWith(
      status: UploadStatus.picking,
      progressText: 'Checking API key...',
      errorMessage: null,
      transcriptionId: null,
    );

    String? tempUploadPath;

    try {
      // 0. Check that a valid Groq API key is configured
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
        return;
      }

      // 1. Pick audio file
      state = state.copyWith(progressText: 'Opening file picker...');
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      if (result == null || result.files.isEmpty) {
        state = UploadState.initial();
        return;
      }

      final PlatformFile file = result.files.first;
      final String? path = file.path;

      if (path == null) {
        state = state.copyWith(
          status: UploadStatus.error,
          errorMessage: 'Could not access the selected file.',
        );
        return;
      }

      String uploadPath = path;

      // Handle common extension issues if any
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

      // 2. Begin transcription using WhisperService
      state = state.copyWith(
        status: UploadStatus.transcribing,
        progressText: 'Uploading and transcribing using AI...',
      );

      final whisperService = _ref.read(whisperServiceProvider);

      final transcribedText = await whisperService.transcribeAudio(
        filePath: uploadPath,
        languageCode: languageCode,
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

      if (transcribedText.trim().isEmpty) {
        state = state.copyWith(
          status: UploadStatus.error,
          errorMessage: 'No speech could be detected or transcribed in the audio file.',
        );
        return;
      }

      // 3. Save transcript to Firestore
      state = state.copyWith(
        status: UploadStatus.saving,
        progressText: 'Saving transcription to database...',
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
      final config = _ref.read(appConfigProvider);
      final langConfig = config.findLanguage(languageCode);

      final transcription = TranscriptionModel(
        transcriptionId: docId,
        userId: currentUserId,
        title: 'Uploaded Audio - ${file.name}',
        transcript: transcribedText,
        language: langConfig.displayName,
        duration: 0,
        createdAt: DateTime.now(),
      );

      await _ref.read(firestoreServiceProvider).saveTranscription(transcription);

      state = state.copyWith(
        status: UploadStatus.success,
        progressText: 'Success!',
        transcriptionId: docId,
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

  void reset() {
    state = UploadState.initial();
  }
}

final uploadNotifierProvider = StateNotifierProvider<UploadNotifier, UploadState>((ref) {
  return UploadNotifier(ref);
});
