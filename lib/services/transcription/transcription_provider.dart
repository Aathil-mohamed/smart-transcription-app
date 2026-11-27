import 'dart:io';
import '../../core/config/app_config.dart';
import '../../models/transcript.dart';
import 'quality_filter.dart';

class TranscriptionResult {
  final String text;
  final List<TranscriptSegment> segments;
  final String provider;
  final String? detectedLanguage;
  final int segmentCount;
  final int droppedSegmentCount;
  final double? duration;
  final int? rawTextLength;
  final List<SegmentDecision>? decisions;

  const TranscriptionResult({
    required this.text,
    required this.segments,
    required this.provider,
    this.detectedLanguage,
    this.segmentCount = 0,
    this.droppedSegmentCount = 0,
    this.duration,
    this.rawTextLength,
    this.decisions,
  });
}

abstract class TranscriptionProvider {
  String get id;

  Future<TranscriptionResult> transcribe({
    required File audioFile,
    required LanguageConfig language,
    String? customApiKey,
    List<String>? additionalVocabulary,
    String? forcedModel,
    String? customPrompt,
    bool withoutPrompt = false,
    bool autoDetectLanguage = false,
  });
}
