import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/transcript.dart';
import '../providers/auth_provider.dart';
import '../providers/record_provider.dart'; // contains service providers
import '../services/whisper_service.dart';

enum UploadStatus { idle, picking, transcribing, saving, success, error }

class UploadState {
  final UploadStatus status;
  final String progressText;
  final String? errorMessage;
  final String? transcriptionId; // Returns the ID on success

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
      // 0. First, check that a valid Groq API key is configured
      final prefs = await SharedPreferences.getInstance();
      final customApiKey = prefs.getString('groq_api_key_custom');
      final bool hasKey = await WhisperService.hasValidApiKey(customApiKey);

      if (!hasKey) {
        state = state.copyWith(
          status: UploadStatus.error,
          errorMessage:
            'No Groq API Key configured!\n\n'
            'To enable accurate transcription:\n'
            '1. Go to https://console.groq.com/keys\n'
            '2. Create a FREE API key\n'
            '3. Open Settings (⚙️) in this app\n'
            '4. Paste the key under "Custom Groq API Key"\n'
            '5. Tap SAVE API KEY\n\n'
            'Then try uploading again.',
        );
        return;
      }

      // 1. Pick audio file (using FileType.audio to support all registered formats like AMR, Opus, etc.)
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
          errorMessage: 'Could not access file path. Please try another file.',
        );
        return;
      }

      // Check size limit: Groq supports up to 25MB
      final int sizeLimit = 25 * 1024 * 1024;
      if (file.size > sizeLimit) {
        state = state.copyWith(
          status: UploadStatus.error,
          errorMessage: 'File is too large. Maximum supported size is 25MB.',
        );
        return;
      }

      // Resolve file path for upload.
      // Groq Gateway natively allows: mp3, mp4, mpeg, mpga, m4a, ogg, wav, webm, flac, opus.
      // If the picked file is AMR, 3GP, CAF, etc., we copy it to a temp file with a '.wav' extension.
      // This bypasses the gateway file-type checks, and the underlying Whisper decoder (which uses FFmpeg)
      // auto-sniffs the file header and decodes it correctly!
      String uploadPath = path;
      final String ext = (file.extension ?? path.split('.').last).toLowerCase();
      final List<String> nativelySupported = [
        'mp3', 'wav', 'm4a', 'aac', 'ogg', 'opus', 'flac', 'webm', 'mp4', 'mpeg', 'mpga'
      ];

      if (!nativelySupported.contains(ext)) {
        try {
          final directory = await getTemporaryDirectory();
          final String tempFileName = 'compat_${DateTime.now().millisecondsSinceEpoch}.wav';
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
        customApiKey: customApiKey,
      );

      // Try to clean up temporary file
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

      // Resolve language name based on languageCode
      String langName = 'Bilingual';
      if (languageCode == 'ta-IN') langName = 'Tamil';
      if (languageCode == 'en-US') langName = 'English';

      final transcription = TranscriptionModel(
        transcriptionId: docId,
        userId: currentUserId,
        title: 'Uploaded Audio - ${file.name}',
        transcript: transcribedText,
        language: langName,
        duration: 0, // 0 signifies uploaded file duration unknown
        createdAt: DateTime.now(),
      );

      await _ref.read(firestoreServiceProvider).saveTranscription(transcription);

      state = state.copyWith(
        status: UploadStatus.success,
        progressText: 'Success!',
        transcriptionId: docId,
      );
    } catch (e) {
      // Clean up temp file on failure
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
        errorMessage: e.toString().replaceAll('Exception: ', ''),
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
