import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_transcription_app/core/config/app_config.dart';
import 'package:smart_transcription_app/core/utils/audio_duration_helper.dart';
import 'package:smart_transcription_app/models/transcript.dart';

void main() {
  group('AudioDurationHelper', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('audio_duration_test_');
    });

    tearDown(() async {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    test('parses synthesized MP4 mvhd duration correctly', () async {
      // Build an MP4 buffer containing an mvhd atom
      // timescale: 1000, duration: 27563 -> 27.563s (~28s)
      final builder = BytesBuilder();
      // ftyp atom
      builder.add([0x00, 0x00, 0x00, 0x14, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x02, 0x00, 0x69, 0x73, 0x6F, 0x6D]);

      // moov -> mvhd atom
      // size: 108 bytes, name: 'mvhd'
      final mvhdBytes = ByteData(108);
      mvhdBytes.setUint32(0, 108, Endian.big);
      mvhdBytes.setUint8(4, 0x6D); // 'm'
      mvhdBytes.setUint8(5, 0x76); // 'v'
      mvhdBytes.setUint8(6, 0x68); // 'h'
      mvhdBytes.setUint8(7, 0x64); // 'd'
      mvhdBytes.setUint8(8, 0);    // version 0
      // timescale at offset +16 from 'm' (byte 20)
      mvhdBytes.setUint32(20, 1000, Endian.big);
      // duration at offset +20 from 'm' (byte 24)
      mvhdBytes.setUint32(24, 27563, Endian.big);

      builder.add(mvhdBytes.buffer.asUint8List());

      final file = File('${tempDir.path}/test_synth.mp4');
      await file.writeAsBytes(builder.toBytes());

      final duration = await AudioDurationHelper.getDuration(audioFile: file);
      expect(duration, 28);
    });

    test('parses synthesized WAV header duration correctly', () async {
      // 44-byte WAV header:
      // sampleRate: 16000, channels: 1, byteRate: 32000, dataSize: 320000 -> 10.0s
      final byteData = ByteData(44);
      byteData.setUint8(0, 0x52); // 'R'
      byteData.setUint8(1, 0x49); // 'I'
      byteData.setUint8(2, 0x46); // 'F'
      byteData.setUint8(3, 0x46); // 'F'
      byteData.setUint32(4, 36 + 320000, Endian.little);
      byteData.setUint8(8, 0x57);  // 'W'
      byteData.setUint8(9, 0x41);  // 'A'
      byteData.setUint8(10, 0x56); // 'V'
      byteData.setUint8(11, 0x45); // 'E'
      byteData.setUint8(12, 0x66); // 'f'
      byteData.setUint8(13, 0x6d); // 'm'
      byteData.setUint8(14, 0x74); // 't'
      byteData.setUint8(15, 0x20); // ' '
      byteData.setUint32(16, 16, Endian.little);
      byteData.setUint16(20, 1, Endian.little); // PCM
      byteData.setUint16(22, 1, Endian.little); // mono
      byteData.setUint32(24, 16000, Endian.little);
      byteData.setUint32(28, 32000, Endian.little); // byteRate
      byteData.setUint16(32, 2, Endian.little); // blockAlign
      byteData.setUint16(34, 16, Endian.little); // 16 bits
      byteData.setUint8(36, 0x64); // 'd'
      byteData.setUint8(37, 0x61); // 'a'
      byteData.setUint8(38, 0x74); // 't'
      byteData.setUint8(39, 0x61); // 'a'
      byteData.setUint32(40, 320000, Endian.little); // dataSize

      final file = File('${tempDir.path}/test_synth.wav');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      final duration = await AudioDurationHelper.getDuration(audioFile: file);
      expect(duration, 10);
    });

    test('falls back to providerDuration when metadata unavailable', () async {
      final file = File('${tempDir.path}/empty.raw');
      await file.writeAsBytes([1, 2, 3, 4]);

      final duration = await AudioDurationHelper.getDuration(
        audioFile: file,
        providerDuration: 15.4,
      );
      expect(duration, 15);
    });

    test('falls back to segments.last.end when metadata and providerDuration unavailable', () async {
      final file = File('${tempDir.path}/empty.raw');
      await file.writeAsBytes([1, 2, 3, 4]);

      final duration = await AudioDurationHelper.getDuration(
        audioFile: file,
        segments: const [
          TranscriptSegment(start: 0.0, end: 4.2, text: 'Hello'),
          TranscriptSegment(start: 4.2, end: 27.6, text: 'World'),
        ],
      );
      expect(duration, 28);
    });

    test('returns 0 when no duration source is available', () async {
      final file = File('${tempDir.path}/empty.raw');
      await file.writeAsBytes([1, 2, 3, 4]);

      final duration = await AudioDurationHelper.getDuration(audioFile: file);
      expect(duration, 0);
    });
  });

  group('Per-language provider order config', () {
    test('falls back to global order when language.pipeline is not specified or empty', () {
      const globalOrder = ['groq', 'gemini'];
      const langConfig = LanguageConfig(
        id: 'en-US',
        code: 'en-US',
        storedName: 'English',
        name: 'English',
        uiLabel: 'English',
        displayName: 'English',
        speechLocale: 'en-US',
        sttLocale: 'en-US',
        whisperLanguage: 'en',
        promptKey: 'en_prompt',
        promptSampleSentence: 'Hello world',
        whisperPrompt: 'Hello world',
        allowedDetectedLanguages: ['en'],
        retryLanguage: null,
        customVocabulary: [],
        pipeline: null,
      );

      final order = (langConfig.pipeline != null && langConfig.pipeline!.isNotEmpty)
          ? langConfig.pipeline!
          : globalOrder;
      expect(order, ['groq', 'gemini']);
    });

    test('uses language.pipeline when explicitly configured', () {
      const globalOrder = ['groq', 'gemini'];
      const langConfig = LanguageConfig(
        id: 'ta-IN',
        code: 'ta-IN',
        storedName: 'Tamil',
        name: 'Tamil',
        uiLabel: 'Tamil',
        displayName: 'Tamil',
        speechLocale: 'ta-IN',
        sttLocale: 'ta-IN',
        whisperLanguage: 'ta',
        promptKey: 'ta_prompt',
        promptSampleSentence: 'வணக்கம்',
        whisperPrompt: 'வணக்கம்',
        allowedDetectedLanguages: ['ta'],
        retryLanguage: 'ta',
        customVocabulary: [],
        pipeline: ['gemini', 'groq'],
      );

      final order = (langConfig.pipeline != null && langConfig.pipeline!.isNotEmpty)
          ? langConfig.pipeline!
          : globalOrder;
      expect(order, ['gemini', 'groq']);
    });
  });
}
