import 'dart:io';
import 'dart:typed_data';
import '../../models/transcript.dart';

class AudioDurationHelper {
  /// Reads audio duration in seconds from container metadata (MP4/M4A/WAV),
  /// falling back to the last segment's end time, or provider-reported duration.
  /// Returns 0 if unable to determine duration.
  static Future<int> getDuration({
    required File audioFile,
    List<TranscriptSegment>? segments,
    double? providerDuration,
  }) async {
    // 1. Try lightweight container metadata read
    final metadataSec = await parseMetadataDuration(audioFile);
    if (metadataSec != null && metadataSec > 0) {
      return metadataSec.round();
    }

    // 2. Fallback: provider top-level duration (e.g. from Groq verbose_json)
    if (providerDuration != null && providerDuration > 0) {
      return providerDuration.round();
    }

    // 3. Fallback: last segment end time
    if (segments != null && segments.isNotEmpty) {
      final lastEnd = segments.last.end;
      if (lastEnd > 0) {
        return lastEnd.round();
      }
    }

    // 4. Unknown
    return 0;
  }

  /// Parses duration in seconds from file header/metadata without external binaries.
  static Future<double?> parseMetadataDuration(File file) async {
    try {
      if (!await file.exists()) return null;
      final length = await file.length();
      if (length < 32) return null;

      final raf = await file.open(mode: FileMode.read);

      // 1. Check WAV header (starts with RIFF and WAVE)
      final headBytes = await raf.read(44);
      if (headBytes.length >= 44 &&
          headBytes[0] == 0x52 && headBytes[1] == 0x49 && headBytes[2] == 0x46 && headBytes[3] == 0x46 &&
          headBytes[8] == 0x57 && headBytes[9] == 0x41 && headBytes[10] == 0x56 && headBytes[11] == 0x45) {
        final byteData = ByteData.sublistView(headBytes);
        final byteRate = byteData.getUint32(28, Endian.little);
        final dataSize = byteData.getUint32(40, Endian.little);
        await raf.close();
        if (byteRate > 0) {
          final effectiveDataSize = dataSize > 0 ? dataSize : (length - 44);
          return effectiveDataSize / byteRate;
        }
        return null;
      }

      // 2. Check MP4 / M4A / AAC container for 'mvhd' atom
      // In MP4, moov atom can be at the beginning or at the end (after mdat).
      // Check first 64 KB
      await raf.setPosition(0);
      final headChunkSize = length < 65536 ? length : 65536;
      final headChunk = await raf.read(headChunkSize);
      final headMvhd = _parseMvhdFromBytes(headChunk);
      if (headMvhd != null) {
        await raf.close();
        return headMvhd;
      }

      // Check last 64 KB if file is larger than 64 KB
      if (length > 65536) {
        final tailChunkSize = length < 131072 ? (length - headChunkSize) : 65536;
        await raf.setPosition(length - tailChunkSize);
        final tailChunk = await raf.read(tailChunkSize);
        final tailMvhd = _parseMvhdFromBytes(tailChunk);
        if (tailMvhd != null) {
          await raf.close();
          return tailMvhd;
        }
      }

      await raf.close();
    } catch (_) {
      // Graceful fallback
    }
    return null;
  }

  /// Searches for 'mvhd' box within [chunk] and extracts duration in seconds.
  static double? _parseMvhdFromBytes(Uint8List chunk) {
    final idx = _indexOfBytes(chunk, const [0x6D, 0x76, 0x68, 0x64]); // 'mvhd'
    if (idx == -1) return null;

    final byteData = ByteData.sublistView(chunk);
    if (idx + 24 > chunk.length) return null;

    final version = chunk[idx + 4];
    if (version == 0) {
      // timescale at idx + 16 (4 bytes), duration at idx + 20 (4 bytes)
      final timescale = byteData.getUint32(idx + 16, Endian.big);
      final duration = byteData.getUint32(idx + 20, Endian.big);
      if (timescale > 0) {
        return duration / timescale;
      }
    } else if (version == 1 && idx + 32 <= chunk.length) {
      // timescale at idx + 20 (4 bytes), duration at idx + 24 (8 bytes)
      final timescale = byteData.getUint32(idx + 20, Endian.big);
      final durationHigh = byteData.getUint32(idx + 24, Endian.big);
      final durationLow = byteData.getUint32(idx + 28, Endian.big);
      final duration = (durationHigh * 4294967296) + durationLow;
      if (timescale > 0) {
        return duration / timescale;
      }
    }
    return null;
  }

  static int _indexOfBytes(Uint8List source, List<int> pattern) {
    if (pattern.isEmpty || source.length < pattern.length) return -1;
    for (int i = 0; i <= source.length - pattern.length; i++) {
      bool match = true;
      for (int j = 0; j < pattern.length; j++) {
        if (source[i + j] != pattern[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }
}
