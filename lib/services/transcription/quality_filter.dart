import 'package:flutter/foundation.dart';
import '../../core/config/app_config.dart';
import '../../models/transcript.dart';

class SegmentDecision {
  final int index;
  final double start;
  final double end;
  final double avgLogprob;
  final double noSpeechProb;
  final double compressionRatio;
  final String text;
  final bool kept;
  final String? dropReason;

  const SegmentDecision({
    required this.index,
    required this.start,
    required this.end,
    required this.avgLogprob,
    required this.noSpeechProb,
    required this.compressionRatio,
    required this.text,
    required this.kept,
    this.dropReason,
  });
}

class QualityFilter {
  final QualityFilterConfig config;

  const QualityFilter(this.config);

  /// Filters raw verbose_json segments according to acoustic and statistical thresholds.
  ///
  /// Returns a record containing the cleaned transcript string, the surviving segments,
  /// the total raw segment count, the count of segments dropped by the quality filter,
  /// and detailed decision logs for diagnostics.
  ({
    String text,
    List<TranscriptSegment> segments,
    int rawCount,
    int droppedCount,
    List<SegmentDecision> decisions,
  }) filterSegments(
    List<dynamic> rawSegments,
  ) {
    if (rawSegments.isEmpty) {
      return (
        text: '',
        segments: const <TranscriptSegment>[],
        rawCount: 0,
        droppedCount: 0,
        decisions: const <SegmentDecision>[],
      );
    }

    int rawValidCount = 0;
    final survivingSegments = <TranscriptSegment>[];
    final decisions = <SegmentDecision>[];
    String? lastNormalizedText;

    for (final raw in rawSegments) {
      if (raw is! Map<String, dynamic>) continue;
      rawValidCount++;

      final text = (raw['text'] as String?)?.trim() ?? '';
      final start = (raw['start'] as num?)?.toDouble() ?? 0.0;
      final end = (raw['end'] as num?)?.toDouble() ?? 0.0;
      final noSpeechProb = (raw['no_speech_prob'] as num?)?.toDouble() ?? 0.0;
      final avgLogprob = (raw['avg_logprob'] as num?)?.toDouble() ?? 0.0;
      final compressionRatio = (raw['compression_ratio'] as num?)?.toDouble() ?? 1.0;

      if (text.isEmpty) {
        decisions.add(SegmentDecision(
          index: rawValidCount,
          start: start,
          end: end,
          avgLogprob: avgLogprob,
          noSpeechProb: noSpeechProb,
          compressionRatio: compressionRatio,
          text: '',
          kept: false,
          dropReason: 'empty text',
        ));
        continue;
      }

      // 1. Drop segments with high no_speech_prob AND low avg_logprob (hallucinated text over silence)
      if (noSpeechProb > config.maxNoSpeechProb && avgLogprob < config.minAvgLogprob) {
        final reason =
            'high no_speech_prob (${noSpeechProb.toStringAsFixed(2)} > ${config.maxNoSpeechProb}) and low avg_logprob (${avgLogprob.toStringAsFixed(2)} < ${config.minAvgLogprob})';
        decisions.add(SegmentDecision(
          index: rawValidCount,
          start: start,
          end: end,
          avgLogprob: avgLogprob,
          noSpeechProb: noSpeechProb,
          compressionRatio: compressionRatio,
          text: text,
          kept: false,
          dropReason: reason,
        ));
        continue;
      }

      // 2. Drop segments with extreme compression ratio (repetitive hallucinations / looping)
      if (compressionRatio > config.maxCompressionRatio) {
        final reason =
            'high compression_ratio (${compressionRatio.toStringAsFixed(2)} > ${config.maxCompressionRatio})';
        decisions.add(SegmentDecision(
          index: rawValidCount,
          start: start,
          end: end,
          avgLogprob: avgLogprob,
          noSpeechProb: noSpeechProb,
          compressionRatio: compressionRatio,
          text: text,
          kept: false,
          dropReason: reason,
        ));
        continue;
      }

      // 3. Drop consecutive duplicates
      final normalized = text.toLowerCase();
      if (config.dropConsecutiveDuplicates && normalized == lastNormalizedText) {
        decisions.add(SegmentDecision(
          index: rawValidCount,
          start: start,
          end: end,
          avgLogprob: avgLogprob,
          noSpeechProb: noSpeechProb,
          compressionRatio: compressionRatio,
          text: text,
          kept: false,
          dropReason: 'consecutive duplicate',
        ));
        continue;
      }

      lastNormalizedText = normalized;
      survivingSegments.add(
        TranscriptSegment(
          start: start,
          end: end,
          text: text,
        ),
      );
      decisions.add(SegmentDecision(
        index: rawValidCount,
        start: start,
        end: end,
        avgLogprob: avgLogprob,
        noSpeechProb: noSpeechProb,
        compressionRatio: compressionRatio,
        text: text,
        kept: true,
      ));
    }

    final combinedText = survivingSegments.map((s) => s.text).join(' ').trim();

    if (kDebugMode) {
      debugPrint('[QualityFilter] Processed $rawValidCount segments: ${survivingSegments.length} kept, ${rawValidCount - survivingSegments.length} dropped.');
      for (final d in decisions) {
        if (!d.kept) {
          debugPrint('[QualityFilter] Segment #${d.index} [${d.start.toStringAsFixed(2)}s - ${d.end.toStringAsFixed(2)}s]: DROPPED (${d.dropReason})');
        }
      }
    }

    return (
      text: combinedText,
      segments: survivingSegments,
      rawCount: rawValidCount,
      droppedCount: rawValidCount - survivingSegments.length,
      decisions: decisions,
    );
  }
}
