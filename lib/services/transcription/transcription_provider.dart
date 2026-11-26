import 'dart:io';
import '../../core/config/app_config.dart';
import '../../models/transcript.dart';

class TranscriptionResult {
  final String text;
  final List<TranscriptSegment> segments;
  final String provider;
  final String? detectedLanguage;

  const TranscriptionResult({
    required this.text,
    required this.segments,
    required this.provider,
    this.detectedLanguage,
  });
}

abstract class TranscriptionProvider {
  String get id;

  Future<TranscriptionResult> transcribe({
    required File audioFile,
    required LanguageConfig language,
    String? customApiKey,
    List<String>? additionalVocabulary,
  });
}
