import 'dart:io';
import '../../core/config/app_config.dart';
import '../../models/transcript.dart';

class TranscriptionResult {
  final String text;
  final List<TranscriptSegment> segments;
  final String provider;
  final String? detectedLanguage;
  final int segmentCount;
  final int droppedSegmentCount;

  const TranscriptionResult({
    required this.text,
    required this.segments,
    required this.provider,
    this.detectedLanguage,
    this.segmentCount = 0,
    this.droppedSegmentCount = 0,
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
