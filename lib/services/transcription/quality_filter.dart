import '../../core/config/app_config.dart';
import '../../models/transcript.dart';

class QualityFilter {
  final QualityFilterConfig config;

  const QualityFilter(this.config);

  /// Filters raw verbose_json segments according to acoustic and statistical thresholds.
  ///
  /// Returns a record containing the cleaned transcript string, the surviving segments,
  /// the total raw segment count, and the count of segments dropped by the quality filter.
  ({String text, List<TranscriptSegment> segments, int rawCount, int droppedCount}) filterSegments(
    List<dynamic> rawSegments,
  ) {
    if (rawSegments.isEmpty) {
      return (text: '', segments: const <TranscriptSegment>[], rawCount: 0, droppedCount: 0);
    }

    int rawValidCount = 0;
    final survivingSegments = <TranscriptSegment>[];
    String? lastNormalizedText;

    for (final raw in rawSegments) {
      if (raw is! Map<String, dynamic>) continue;
      rawValidCount++;

      final text = (raw['text'] as String?)?.trim() ?? '';
      if (text.isEmpty) continue;

      final start = (raw['start'] as num?)?.toDouble() ?? 0.0;
      final end = (raw['end'] as num?)?.toDouble() ?? 0.0;
      final noSpeechProb = (raw['no_speech_prob'] as num?)?.toDouble() ?? 0.0;
      final avgLogprob = (raw['avg_logprob'] as num?)?.toDouble() ?? 0.0;
      final compressionRatio = (raw['compression_ratio'] as num?)?.toDouble() ?? 1.0;

      // 1. Drop segments with high no_speech_prob AND low avg_logprob (hallucinated text over silence)
      if (noSpeechProb > config.maxNoSpeechProb && avgLogprob < config.minAvgLogprob) {
        continue;
      }

      // 2. Drop segments with extreme compression ratio (repetitive hallucinations / looping)
      if (compressionRatio > config.maxCompressionRatio) {
        continue;
      }

      // 3. Drop consecutive duplicates
      final normalized = text.toLowerCase();
      if (config.dropConsecutiveDuplicates && normalized == lastNormalizedText) {
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
    }

    final combinedText = survivingSegments.map((s) => s.text).join(' ').trim();
    return (
      text: combinedText,
      segments: survivingSegments,
      rawCount: rawValidCount,
      droppedCount: rawValidCount - survivingSegments.length,
    );
  }
}
