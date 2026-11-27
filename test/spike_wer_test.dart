import 'package:flutter_test/flutter_test.dart';
import 'package:smart_transcription_app/screens/debug_audio_spike_screen.dart';

void main() {
  group('calculateSimpleWer', () {
    test('returns 0.0% for identical text', () {
      const text = 'வணக்கம் today we test speech recognition';
      final result = calculateSimpleWer(text, text);
      expect(result.werPercent, 0.0);
      expect(result.editDistance, 0);
      expect(result.refWordCount, 6);
      expect(result.hypWordCount, 6);
    });

    test('normalizes whitespace and case only', () {
      const ref = '  வணக்கம்   TODAY we TEST speech  ';
      const hyp = 'வணக்கம் today WE test speech';
      final result = calculateSimpleWer(ref, hyp);
      expect(result.werPercent, 0.0);
      expect(result.editDistance, 0);
      expect(result.refWordCount, 5);
      expect(result.hypWordCount, 5);
    });

    test('calculates correct WER for substitution', () {
      const ref = 'one two three four five';
      const hyp = 'one two zero four five';
      final result = calculateSimpleWer(ref, hyp);
      expect(result.werPercent, closeTo(20.0, 0.01)); // 1 / 5 = 20%
      expect(result.editDistance, 1);
    });

    test('calculates correct WER for deletion', () {
      const ref = 'one two three four';
      const hyp = 'one two four';
      final result = calculateSimpleWer(ref, hyp);
      expect(result.werPercent, closeTo(25.0, 0.01)); // 1 / 4 = 25%
      expect(result.editDistance, 1);
    });

    test('calculates correct WER for insertion', () {
      const ref = 'one two';
      const hyp = 'one two three';
      final result = calculateSimpleWer(ref, hyp);
      expect(result.werPercent, closeTo(50.0, 0.01)); // 1 / 2 = 50%
      expect(result.editDistance, 1);
    });

    test('handles empty inputs properly', () {
      expect(calculateSimpleWer('', '').werPercent, 0.0);
      expect(calculateSimpleWer('hello world', '').werPercent, 100.0);
      expect(calculateSimpleWer('', 'hello world').werPercent, 100.0);
    });
  });
}
