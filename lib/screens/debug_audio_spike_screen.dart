import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_design_tokens.dart';
import '../providers/record_provider.dart';

enum SpikeMode {
  soloAcoustic15s, // 15s Solo Acoustic: 5s quiet + 10s speaking
  hybridSimultaneous30s, // 30s Hybrid: PCM + Native STT
}

class AcousticResult {
  final AndroidAudioSource source;
  final bool autoGain;
  final double avgQuietDbfs;
  final double avgSpeakingDbfs;
  final double dynamicRangeDb;
  final double peakDbfs;
  final int totalBytes;
  final int? firstNonZeroMs;

  const AcousticResult({
    required this.source,
    required this.autoGain,
    required this.avgQuietDbfs,
    required this.avgSpeakingDbfs,
    required this.dynamicRangeDb,
    required this.peakDbfs,
    required this.totalBytes,
    this.firstNonZeroMs,
  });
}

class WerResult {
  final double werPercent;
  final int refWordCount;
  final int hypWordCount;
  final int editDistance;

  const WerResult({
    required this.werPercent,
    required this.refWordCount,
    required this.hypWordCount,
    required this.editDistance,
  });
}

WerResult calculateSimpleWer(String reference, String hypothesis) {
  // Normalize whitespace and case only
  final refWords = reference
      .toLowerCase()
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final hypWords = hypothesis
      .toLowerCase()
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  final n = refWords.length;
  final m = hypWords.length;

  if (n == 0) {
    return WerResult(
      werPercent: m == 0 ? 0.0 : 100.0,
      refWordCount: 0,
      hypWordCount: m,
      editDistance: m,
    );
  }

  // Standard Levenshtein dynamic programming on word tokens
  final dp = List.generate(n + 1, (_) => List.filled(m + 1, 0));
  for (int i = 0; i <= n; i++) {
    dp[i][0] = i;
  }
  for (int j = 0; j <= m; j++) {
    dp[0][j] = j;
  }

  for (int i = 1; i <= n; i++) {
    for (int j = 1; j <= m; j++) {
      if (refWords[i - 1] == hypWords[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1];
      } else {
        final sub = dp[i - 1][j - 1] + 1;
        final ins = dp[i][j - 1] + 1;
        final del = dp[i - 1][j] + 1;
        dp[i][j] = math.min(sub, math.min(ins, del));
      }
    }
  }

  final distance = dp[n][m];
  final wer = (distance / n) * 100.0;
  return WerResult(
    werPercent: wer,
    refWordCount: n,
    hypWordCount: m,
    editDistance: distance,
  );
}

class DebugAudioSpikeScreen extends ConsumerStatefulWidget {
  const DebugAudioSpikeScreen({super.key});

  @override
  ConsumerState<DebugAudioSpikeScreen> createState() => _DebugAudioSpikeScreenState();
}

class _DebugAudioSpikeScreenState extends ConsumerState<DebugAudioSpikeScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _streamSub;

  SpikeMode _mode = SpikeMode.soloAcoustic15s;
  AndroidAudioSource _selectedSource = AndroidAudioSource.defaultSource;
  bool _autoGainEnabled = true;

  bool _isRunning = false;
  int _secondsRemaining = 15;
  int _testTotalSeconds = 15;
  Timer? _countdownTimer;
  final Stopwatch _testWatch = Stopwatch();
  bool _summaryPrinted = false;

  // Hardware Effects
  bool? _noiseSuppressorAvailable;
  bool? _acousticEchoCancelerAvailable;
  bool? _automaticGainControlAvailable;

  // Real-time Metrics
  double _currentDbfs = -160.0;
  double _peakDbfs = -160.0;
  int _totalBytesReceived = 0;
  int _chunksReceived = 0;
  int _zeroChunksCount = 0;
  int _nonZeroChunksCount = 0;
  int? _firstNonZeroChunkMs;
  int _chunksWhileSttListening = 0;
  int _chunksInLast10s = 0;

  // 15s Acoustic Calibration Samples
  final List<double> _quietRmsSamples = [];
  final List<double> _speakingRmsSamples = [];
  final Map<String, AcousticResult> _sourceResults = {};

  // PCM Capture & WAV Export
  final BytesBuilder _pcmCaptureBuffer = BytesBuilder(copy: false);
  File? _lastCapturedWavFile;
  AndroidAudioSource? _lastCapturedSource;
  bool _lastCapturedAgc = true;
  int? _lastCapturedDurationMs;

  // Transcription Pipeline & WER
  final TextEditingController _referenceTextController = TextEditingController();
  LanguageConfig? _selectedTranscriptionLanguage;
  bool _isTranscribing = false;
  String? _lastTranscriptionResult;
  String? _lastTranscriptionProvider;
  int? _lastTranscriptionElapsedMs;
  String? _transcriptionError;
  WerResult? _werResult;

  // Speech to text metrics (for Hybrid mode)
  String _sttStatus = 'Idle';
  String _lastRecognizedText = '';
  int? _firstTextTimestampMs;
  int _sttResultCount = 0;

  // Diagnostics log
  final List<String> _logEntries = [];
  final ScrollController _logScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkHardwareEffects();
  }

  @override
  void dispose() {
    if (_isRunning && !_summaryPrinted) {
      _printTestSummary(earlyStopReason: 'Screen exited / disposed');
    }
    _cleanup();
    _recorder.dispose();
    _logScrollController.dispose();
    _referenceTextController.dispose();
    super.dispose();
  }

  Future<void> _checkHardwareEffects() async {
    try {
      const channel = MethodChannel('com.smarttranscribe/diagnostics');
      final result = await channel.invokeMethod<Map>('getAudioEffectsStatus');
      if (result != null && mounted) {
        setState(() {
          _noiseSuppressorAvailable = result['noiseSuppressorAvailable'] as bool?;
          _acousticEchoCancelerAvailable = result['acousticEchoCancelerAvailable'] as bool?;
          _automaticGainControlAvailable = result['automaticGainControlAvailable'] as bool?;
        });
        _addLog('DEVICE HARDWARE AUDIO EFFECTS:');
        _addLog(' - Noise Suppressor (NS): ${_noiseSuppressorAvailable == true ? "AVAILABLE" : "UNAVAILABLE"}');
        _addLog(' - Acoustic Echo Canceler (AEC): ${_acousticEchoCancelerAvailable == true ? "AVAILABLE" : "UNAVAILABLE"}');
        _addLog(' - Auto Gain Control (AGC): ${_automaticGainControlAvailable == true ? "AVAILABLE" : "UNAVAILABLE"}');
      }
    } catch (e) {
      _addLog('Hardware audio effects query note: $e');
    }
  }

  void _addLog(String message) {
    final elapsed = _testWatch.isRunning ? '+${_testWatch.elapsedMilliseconds}ms' : 'INIT';
    final entry = '[$elapsed] $message';
    debugPrint('[Spike] $entry');
    if (mounted) {
      setState(() {
        _logEntries.add(entry);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logScrollController.hasClients) {
          _logScrollController.animateTo(
            _logScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _startTest() async {
    if (_isRunning) return;

    _cleanup();
    _logEntries.clear();
    _currentDbfs = -160.0;
    _peakDbfs = -160.0;
    _totalBytesReceived = 0;
    _chunksReceived = 0;
    _zeroChunksCount = 0;
    _nonZeroChunksCount = 0;
    _firstNonZeroChunkMs = null;
    _chunksWhileSttListening = 0;
    _chunksInLast10s = 0;
    _quietRmsSamples.clear();
    _speakingRmsSamples.clear();
    _pcmCaptureBuffer.clear();
    _summaryPrinted = false;

    _sttStatus = 'Starting...';
    _lastRecognizedText = '';
    _firstTextTimestampMs = null;
    _sttResultCount = 0;

    _testTotalSeconds = _mode == SpikeMode.soloAcoustic15s ? 15 : 30;
    _secondsRemaining = _testTotalSeconds;

    setState(() {
      _isRunning = true;
    });

    _testWatch.reset();
    _testWatch.start();

    final config = ref.read(appConfigProvider);
    _addLog('====================================================');
    _addLog('STARTING TEST: ${_mode == SpikeMode.soloAcoustic15s ? "15s ACOUSTIC EVALUATION (Solo)" : "30s HYBRID (PCM + Native STT)"}');
    _addLog('SELECTED AUDIO SOURCE: ${_selectedSource.name.toUpperCase()} (AGC: ${_autoGainEnabled ? "ON" : "OFF"})');
    _addLog('CONFIG: sampleRate=${config.audio.sampleRate}, channels=${config.audio.numChannels}, encoder=AudioEncoder.pcm16bits');
    _addLog('EFFECTS FLAGS: NS=${config.audio.noiseSuppress}, AEC=${config.audio.echoCancel}, AGC=$_autoGainEnabled');
    if (_noiseSuppressorAvailable != null) {
      _addLog('HARDWARE STATUS: NS=$_noiseSuppressorAvailable, AEC=$_acousticEchoCancelerAvailable, AGC=$_automaticGainControlAvailable');
    }
    _addLog('====================================================');

    try {
      // 1. Permission Check
      final hasPermission = await _recorder.hasPermission();
      _addLog('Microphone Permission: ${hasPermission ? "GRANTED" : "DENIED"}');
      if (!hasPermission) {
        _addLog('ERROR: Microphone permission was denied.');
        _stopTest();
        return;
      }

      // 2. Start PCM Stream with exact AndroidRecordConfig
      final recordConfig = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: config.audio.sampleRate,
        numChannels: config.audio.numChannels,
        noiseSuppress: config.audio.noiseSuppress,
        echoCancel: config.audio.echoCancel,
        autoGain: _autoGainEnabled,
        androidConfig: AndroidRecordConfig(
          audioSource: _selectedSource,
        ),
      );

      final pcmStream = await _recorder.startStream(recordConfig);
      _addLog('AudioRecorder.startStream active with audioSource=${_selectedSource.name}, autoGain=$_autoGainEnabled');

      _streamSub = pcmStream.listen(
        (data) => _processPcmChunk(data),
        onError: (err, st) => _addLog('PCM STREAM ERROR: $err'),
        onDone: () => _addLog('PCM Stream closed by system.'),
        cancelOnError: false,
      );

      // 3. Start Native STT if in Hybrid Mode
      if (_mode == SpikeMode.hybridSimultaneous30s) {
        _addLog('Initializing native SpeechToText...');
        final livePreview = ref.read(livePreviewServiceProvider);
        final lang = config.findLanguage('bilingual');

        final initialized = await livePreview.initialize(
          onTextUpdated: (text) {
            _sttResultCount++;
            if (_firstTextTimestampMs == null && text.trim().isNotEmpty) {
              _firstTextTimestampMs = _testWatch.elapsedMilliseconds;
              _addLog('FIRST STT WORD RECEIVED at +${_firstTextTimestampMs}ms');
            }
            if (mounted) setState(() => _lastRecognizedText = text);
            _addLog('STT Recognized: "${text.length > 40 ? "${text.substring(0, 40)}..." : text}"');
          },
          onUnavailable: (reason) {
            _addLog('STT Unavailable: $reason');
            if (mounted) setState(() => _sttStatus = 'Unavailable: $reason');
          },
        );

        if (initialized) {
          await livePreview.startListening(language: lang);
          if (mounted) setState(() => _sttStatus = 'Listening');
          _addLog('STT actively listening with locale=${lang.speechLocale}');
        } else {
          if (mounted) setState(() => _sttStatus = 'Init Failed');
        }
      } else {
        if (mounted) setState(() => _sttStatus = 'Off (Solo Mode)');
      }

      // 4. Countdown Timer
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_secondsRemaining <= 1) {
          _addLog('Duration complete. Finalizing results...');
          _stopTest();
        } else {
          setState(() {
            _secondsRemaining--;
          });
        }
      });
    } catch (e, st) {
      _addLog('TEST EXCEPTION: $e\n$st');
      _stopTest();
    }
  }

  void _processPcmChunk(Uint8List data) {
    _chunksReceived++;
    _totalBytesReceived += data.lengthInBytes;
    _pcmCaptureBuffer.add(data);

    if (data.isEmpty) return;

    bool allZeros = true;
    for (int i = 0; i < data.lengthInBytes; i++) {
      if (data[i] != 0) {
        allZeros = false;
        break;
      }
    }

    if (allZeros) {
      _zeroChunksCount++;
    } else {
      _nonZeroChunksCount++;
      if (_firstNonZeroChunkMs == null) {
        _firstNonZeroChunkMs = _testWatch.elapsedMilliseconds;
        _addLog('FIRST NON-ZERO PCM CHUNK at +${_firstNonZeroChunkMs}ms (source: ${_selectedSource.name.toUpperCase()})');
      }
    }

    // Count chunks while STT was actively listening
    if (_mode == SpikeMode.hybridSimultaneous30s && _sttStatus == 'Listening') {
      _chunksWhileSttListening++;
    }

    // Count chunks in the last 10s of the test
    if (_secondsRemaining <= 10) {
      _chunksInLast10s++;
    }

    // Compute RMS (in dBFS)
    final byteData = ByteData.sublistView(data);
    final sampleCount = data.lengthInBytes ~/ 2;
    double sumSquares = 0.0;

    for (int i = 0; i < sampleCount; i++) {
      final sample = byteData.getInt16(i * 2, Endian.little);
      sumSquares += sample * sample;
    }

    final double rms = sampleCount > 0 ? math.sqrt(sumSquares / sampleCount) : 0.0;
    final double dbfs = rms > 0 ? (20 * math.log(rms / 32768.0) / math.ln10).clamp(-160.0, 0.0) : -160.0;

    // Track stages for 15s Solo Acoustic Test
    if (_mode == SpikeMode.soloAcoustic15s) {
      final elapsedSecs = _testTotalSeconds - _secondsRemaining;
      if (elapsedSecs < 5) {
        _quietRmsSamples.add(dbfs);
      } else {
        _speakingRmsSamples.add(dbfs);
      }
    }

    // Logging frequency:
    // - Always log chunk #1
    // - 30s hybrid test: every 10th chunk for the whole run
    // - 15s solo acoustic test: every 30th chunk
    final bool shouldLogChunk = _chunksReceived == 1 ||
        (_mode == SpikeMode.hybridSimultaneous30s && _chunksReceived % 10 == 0) ||
        (_mode == SpikeMode.soloAcoustic15s && _chunksReceived % 30 == 0);

    if (shouldLogChunk) {
      final stage = _mode == SpikeMode.soloAcoustic15s
          ? ((_testTotalSeconds - _secondsRemaining) < 5 ? " [QUIET STAGE]" : " [SPEAKING STAGE]")
          : "";
      _addLog('PCM #$_chunksReceived$stage: ${data.lengthInBytes} B, RMS: ${dbfs.toStringAsFixed(1)} dBFS ${allZeros ? "(ALL ZEROS!)" : "(ACTIVE)"}');
    }

    if (mounted) {
      setState(() {
        _currentDbfs = dbfs;
        if (dbfs > _peakDbfs) {
          _peakDbfs = dbfs;
        }
      });
    }
  }

  void _printTestSummary({String? earlyStopReason}) {
    if (_summaryPrinted) return;
    _summaryPrinted = true;

    // Calculate Acoustic Summary
    double avgQuiet = -160.0;
    double avgSpeaking = -160.0;
    double dynamicRange = 0.0;

    if (_mode == SpikeMode.soloAcoustic15s && _quietRmsSamples.isNotEmpty && _speakingRmsSamples.isNotEmpty) {
      avgQuiet = _quietRmsSamples.reduce((a, b) => a + b) / _quietRmsSamples.length;
      avgSpeaking = _speakingRmsSamples.reduce((a, b) => a + b) / _speakingRmsSamples.length;
      dynamicRange = (avgSpeaking - avgQuiet).clamp(0.0, 160.0);

      final result = AcousticResult(
        source: _selectedSource,
        autoGain: _autoGainEnabled,
        avgQuietDbfs: avgQuiet,
        avgSpeakingDbfs: avgSpeaking,
        dynamicRangeDb: dynamicRange,
        peakDbfs: _peakDbfs,
        totalBytes: _totalBytesReceived,
        firstNonZeroMs: _firstNonZeroChunkMs,
      );

      final key = "${_selectedSource.name}_agc_${_autoGainEnabled ? 'on' : 'off'}";
      _sourceResults[key] = result;
    }

    _addLog('====================================================');
    _addLog('TEST SUMMARY - SOURCE: ${_selectedSource.name.toUpperCase()} (AGC: ${_autoGainEnabled ? "ON" : "OFF"})${earlyStopReason != null ? " [$earlyStopReason]" : ""}');
    _addLog('Total Duration: ${_testWatch.elapsedMilliseconds} ms | Total Bytes: $_totalBytesReceived B in $_chunksReceived chunks');
    _addLog('Active Non-Zero Chunks: $_nonZeroChunksCount | All-Zero Chunks: $_zeroChunksCount');
    _addLog('Time to first non-zero chunk: ${_firstNonZeroChunkMs != null ? "+${_firstNonZeroChunkMs}ms" : "NEVER (stream was entirely silent zeros)"}');
    _addLog('Peak Level: ${_peakDbfs.toStringAsFixed(1)} dBFS');

    if (_mode == SpikeMode.soloAcoustic15s) {
      _addLog('--- ACOUSTIC CALIBRATION RESULTS ---');
      _addLog('1. Noise Floor (Quiet 0-5s): ${avgQuiet.toStringAsFixed(1)} dBFS');
      _addLog('2. Voice Level (Speaking 5-15s): ${avgSpeaking.toStringAsFixed(1)} dBFS');
      _addLog('3. Dynamic Range (SNR Margin): +${dynamicRange.toStringAsFixed(1)} dB');
      _addLog('Clarity Assessment: ${_assessClarity(avgQuiet, avgSpeaking, dynamicRange)}');
    } else {
      _addLog('PCM chunks received while STT was listening: $_chunksWhileSttListening');
      _addLog('PCM chunks in the last 10 s of the test: $_chunksInLast10s');
      _addLog('STT Recognized Text Count: $_sttResultCount');
      _addLog('STT First Word Latency: ${_firstTextTimestampMs != null ? "+${_firstTextTimestampMs}ms" : "None"}');
      _addLog('Hybrid Concurrency Verdict: ${_determineHybridVerdict()}');
    }
    _addLog('====================================================');
  }

  Future<void> _stopTest({String? earlyStopReason}) async {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _testWatch.stop();

    _addLog('Stopping stream and recorder...${earlyStopReason != null ? " ($earlyStopReason)" : ""}');
    _cleanup();

    _printTestSummary(earlyStopReason: earlyStopReason);

    // Save captured PCM as valid WAV file for transcription testing
    if (_mode == SpikeMode.soloAcoustic15s && _pcmCaptureBuffer.isNotEmpty) {
      try {
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final wavPath = '${tempDir.path}/spike_test_${_selectedSource.name}_agc_${_autoGainEnabled ? "on" : "off"}_$timestamp.wav';
        final pcmBytes = _pcmCaptureBuffer.toBytes();
        final config = ref.read(appConfigProvider);
        final header = _buildWavHeader(pcmBytes.length, config.audio.sampleRate, config.audio.numChannels);

        final wavBytes = Uint8List(header.length + pcmBytes.length);
        wavBytes.setRange(0, header.length, header);
        wavBytes.setRange(header.length, wavBytes.length, pcmBytes);

        final wavFile = File(wavPath);
        await wavFile.writeAsBytes(wavBytes, flush: true);

        if (mounted) {
          setState(() {
            _lastCapturedWavFile = wavFile;
            _lastCapturedSource = _selectedSource;
            _lastCapturedAgc = _autoGainEnabled;
            _lastCapturedDurationMs = _testWatch.elapsedMilliseconds;
          });
        }
        _addLog('WAV file saved: ${wavFile.path} (${wavBytes.length} bytes, ${_testWatch.elapsedMilliseconds}ms audio)');
      } catch (e) {
        _addLog('ERROR saving WAV file: $e');
      }
    }

    if (mounted) {
      setState(() {
        _isRunning = false;
        _sttStatus = 'Stopped';
      });
    }
  }

  Uint8List _buildWavHeader(int pcmByteLength, int sampleRate, int numChannels) {
    final byteData = ByteData(44);
    final byteRate = sampleRate * numChannels * 2;
    final blockAlign = numChannels * 2;

    // RIFF header
    byteData.setUint8(0, 0x52); // 'R'
    byteData.setUint8(1, 0x49); // 'I'
    byteData.setUint8(2, 0x46); // 'F'
    byteData.setUint8(3, 0x46); // 'F'
    byteData.setUint32(4, 36 + pcmByteLength, Endian.little);
    byteData.setUint8(8, 0x57);  // 'W'
    byteData.setUint8(9, 0x41);  // 'A'
    byteData.setUint8(10, 0x56); // 'V'
    byteData.setUint8(11, 0x45); // 'E'

    // "fmt " chunk
    byteData.setUint8(12, 0x66); // 'f'
    byteData.setUint8(13, 0x6d); // 'm'
    byteData.setUint8(14, 0x74); // 't'
    byteData.setUint8(15, 0x20); // ' '
    byteData.setUint32(16, 16, Endian.little); // 16 bytes for PCM format chunk
    byteData.setUint16(20, 1, Endian.little);  // AudioFormat (1 = PCM)
    byteData.setUint16(22, numChannels, Endian.little);
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, byteRate, Endian.little);
    byteData.setUint16(32, blockAlign, Endian.little);
    byteData.setUint16(34, 16, Endian.little); // 16 bits per sample

    // "data" chunk
    byteData.setUint8(36, 0x64); // 'd'
    byteData.setUint8(37, 0x61); // 'a'
    byteData.setUint8(38, 0x74); // 't'
    byteData.setUint8(39, 0x61); // 'a'
    byteData.setUint32(40, pcmByteLength, Endian.little);

    return byteData.buffer.asUint8List();
  }

  Future<void> _transcribeCapturedTest() async {
    if (_lastCapturedWavFile == null || !await _lastCapturedWavFile!.exists()) {
      _addLog('ERROR: No captured WAV file found to transcribe.');
      return;
    }

    setState(() {
      _isTranscribing = true;
      _transcriptionError = null;
    });

    final sourceName = _lastCapturedSource?.name.toUpperCase() ?? 'SOURCE';
    final agcStr = _lastCapturedAgc ? "ON" : "OFF";
    _addLog('----------------------------------------------------');
    _addLog('TRANSCRIBING TEST WAV ($sourceName, AGC $agcStr)...');
    _addLog('File: ${_lastCapturedWavFile!.path} (${_lastCapturedWavFile!.lengthSync()} bytes)');
    final sw = Stopwatch()..start();

    try {
      final config = ref.read(appConfigProvider);
      final pipeline = ref.read(transcriptionPipelineProvider);
      final lang = _selectedTranscriptionLanguage ?? config.findLanguage('bilingual');
      final groqConfig = config.transcription.providers['groq'];
      final targetModel = groqConfig?.model ?? 'whisper-large-v3';

      _addLog('Initiating pipeline transcribe (provider: ${config.transcription.pipeline.first}, model: $targetModel, lang: ${lang.id})...');

      final result = await pipeline.transcribe(
        audioFile: _lastCapturedWavFile!,
        language: lang,
      );
      sw.stop();

      if (mounted) {
        setState(() {
          _lastTranscriptionResult = result.text;
          _lastTranscriptionProvider = result.provider;
          _lastTranscriptionElapsedMs = sw.elapsedMilliseconds;
        });
      }

      _addLog('TRANSCRIPTION COMPLETED in ${sw.elapsedMilliseconds}ms');
      _addLog('Provider: ${result.provider}');
      _addLog('Transcript: "${result.text}"');

      _updateWer(logToOutput: true);
    } catch (e) {
      sw.stop();
      if (mounted) {
        setState(() {
          _transcriptionError = e.toString();
        });
      }
      _addLog('TRANSCRIPTION FAILED after ${sw.elapsedMilliseconds}ms: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
        });
      }
    }
  }

  void _updateWer({bool logToOutput = false}) {
    final refText = _referenceTextController.text.trim();
    final hypText = _lastTranscriptionResult?.trim() ?? '';

    if (refText.isNotEmpty && hypText.isNotEmpty) {
      final res = calculateSimpleWer(refText, hypText);
      if (mounted) {
        setState(() {
          _werResult = res;
        });
      }
      if (logToOutput) {
        _addLog('Word Error Rate (WER): ${res.werPercent.toStringAsFixed(1)}% (Rough measure - normalized whitespace and case only | Ref: ${res.refWordCount} words, Hyp: ${res.hypWordCount} words, Distance: ${res.editDistance})');
      }
    } else {
      if (mounted) {
        setState(() {
          _werResult = null;
        });
      }
    }
  }

  String _assessClarity(double quiet, double speaking, double snr) {
    if (_nonZeroChunksCount == 0) return 'FAILED: Silent stream.';
    if (snr > 20.0) return 'EXCELLENT: Strong signal clarity with low noise floor (+${snr.toStringAsFixed(1)} dB SNR).';
    if (snr > 10.0) return 'GOOD: Usable speech dynamic range (+${snr.toStringAsFixed(1)} dB SNR).';
    return 'MARGINAL/POOR: Low contrast between voice and background noise (+${snr.toStringAsFixed(1)} dB SNR).';
  }

  String _determineHybridVerdict() {
    if (_totalBytesReceived == 0) return 'FAILURE: No PCM bytes received.';
    if (_nonZeroChunksCount == 0) return 'FAILURE: PCM stream was completely muted/zeros.';
    if (_sttResultCount == 0) return 'WARNING: PCM audio active, but SpeechToText returned 0 words.';
    return 'SUCCESS: Both PCM stream and SpeechToText captured speech concurrently!';
  }

  void _cleanup() {
    _streamSub?.cancel();
    _streamSub = null;
    try {
      _recorder.stop();
    } catch (_) {}
    try {
      ref.read(livePreviewServiceProvider).stopListening();
    } catch (_) {}
  }

  void _copyLogToClipboard() {
    final fullLog = _logEntries.join('\n');
    Clipboard.setData(ClipboardData(text: fullLog));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diagnostics log copied to clipboard!'),
        backgroundColor: Palette.emerald,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final normalizedVU = ((_currentDbfs + 80) / 80).clamp(0.0, 1.0);
    final elapsedSecs = _testTotalSeconds - _secondsRemaining;
    final isQuietStage = _isRunning && _mode == SpikeMode.soloAcoustic15s && elapsedSecs < 5;
    final isSpeakingStage = _isRunning && _mode == SpikeMode.soloAcoustic15s && elapsedSecs >= 5;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Audio Source & Effects Spike',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy Diagnostics Log',
            onPressed: _logEntries.isNotEmpty ? _copyLogToClipboard : null,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Mode Selector
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('15s Solo Acoustic', style: TextStyle(fontSize: 12)),
                      selected: _mode == SpikeMode.soloAcoustic15s,
                      onSelected: _isRunning
                          ? null
                          : (sel) {
                              if (sel) setState(() => _mode = SpikeMode.soloAcoustic15s);
                            },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('30s Hybrid (PCM+STT)', style: TextStyle(fontSize: 12)),
                      selected: _mode == SpikeMode.hybridSimultaneous30s,
                      onSelected: _isRunning
                          ? null
                          : (sel) {
                              if (sel) setState(() => _mode = SpikeMode.hybridSimultaneous30s);
                            },
                    ),
                  ),
                ],
              ),
            ),

            // Android Audio Source Selector Chips & AGC Toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              child: Row(
                children: [
                  Text(
                    'Source:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: theme.hintColor),
                  ),
                  const SizedBox(width: 6),
                  _buildSourceChip(AndroidAudioSource.defaultSource, 'DEFAULT'),
                  const SizedBox(width: 4),
                  _buildSourceChip(AndroidAudioSource.mic, 'MIC'),
                  const SizedBox(width: 4),
                  _buildSourceChip(AndroidAudioSource.voiceRecognition, 'VOICE_REC'),
                  const Spacer(),
                  FilterChip(
                    label: Text(
                      'AGC: ${_autoGainEnabled ? "ON" : "OFF"}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _autoGainEnabled ? Palette.emerald : theme.hintColor,
                      ),
                    ),
                    selected: _autoGainEnabled,
                    visualDensity: VisualDensity.compact,
                    onSelected: _isRunning
                        ? null
                        : (val) {
                            setState(() => _autoGainEnabled = val);
                          },
                  ),
                ],
              ),
            ),

            // Hardware Audio Effects Availability Strip
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 1, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildEffectBadge('NS', _noiseSuppressorAvailable),
                  _buildEffectBadge('AEC', _acousticEchoCancelerAvailable),
                  _buildEffectBadge('AGC', _automaticGainControlAvailable),
                ],
              ),
            ),

            // Real-time Status Card & Stage Prompt
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Palette.charcoalTint : Palette.paperTint,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isQuietStage
                        ? Colors.amber
                        : isSpeakingStage
                            ? Palette.emerald
                            : theme.dividerColor,
                    width: (isQuietStage || isSpeakingStage) ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stage Prompt Banner
                    if (_isRunning && _mode == SpikeMode.soloAcoustic15s) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isQuietStage
                              ? Colors.amber.withValues(alpha: 0.18)
                              : Palette.emerald.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isQuietStage
                              ? '🤫 STAGE 1: STAY QUIET (${5 - elapsedSecs}s) - Measuring Noise Floor...'
                              : '🗣️ STAGE 2: SPEAK NOW (${_secondsRemaining}s) - Measuring Voice Level...',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: isQuietStage ? Colors.amber[800] : Palette.emerald,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isRunning ? 'RUNNING (${_secondsRemaining}s remaining)' : 'TEST IDLE',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _isRunning ? Palette.emerald : theme.hintColor,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          'Peak: ${_peakDbfs.toStringAsFixed(1)} dBFS',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // VU Meter Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Stack(
                        children: [
                          Container(height: 14, color: theme.dividerColor.withValues(alpha: 0.3)),
                          AnimatedFractionallySizedBox(
                            duration: const Duration(milliseconds: 60),
                            widthFactor: normalizedVU,
                            child: Container(
                              height: 14,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Palette.emerald,
                                    normalizedVU > 0.75 ? Palette.coral : Palette.emerald,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'RMS: ${_currentDbfs.toStringAsFixed(1)} dBFS',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        _buildAudioHealthBadge(),
                      ],
                    ),

                    // STT Status Section for Hybrid Mode
                    if (_mode == SpikeMode.hybridSimultaneous30s) ...[
                      const Divider(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'STT: $_sttStatus',
                            style: TextStyle(fontSize: 11, color: theme.hintColor),
                          ),
                          if (_firstTextTimestampMs != null)
                            Text(
                              '1st word: +${_firstTextTimestampMs}ms',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Palette.emerald,
                              ),
                            ),
                        ],
                      ),
                      if (_lastRecognizedText.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Text: "$_lastRecognizedText"',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],

                    // Results Comparison Strip across all tested sources & AGC settings
                    if (_sourceResults.isNotEmpty) ...[
                      const Divider(height: 12),
                      const Text(
                        'Acoustic Calibration Comparison:',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _sourceResults.entries.map((e) {
                          final res = e.value;
                          final nonZeroStr = res.firstNonZeroMs != null ? "+${res.firstNonZeroMs}ms" : "none";
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: theme.dividerColor),
                            ),
                            child: Text(
                              '${res.source.name.toUpperCase()} [AGC ${res.autoGain ? "ON" : "OFF"}]: 1st $nonZeroStr | Noise ${res.avgQuietDbfs.toStringAsFixed(1)} | Voice ${res.avgSpeakingDbfs.toStringAsFixed(1)} (SNR +${res.dynamicRangeDb.toStringAsFixed(1)} dB)',
                              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Start / Stop Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              child: SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRunning ? Palette.coral : Palette.emerald,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isRunning ? _stopTest : _startTest,
                  icon: Icon(_isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 20),
                  label: Text(
                    _isRunning
                        ? 'STOP TEST'
                        : 'START ${_mode == SpikeMode.soloAcoustic15s ? "15s ACOUSTIC TEST" : "30s HYBRID TEST"}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ),

            // Solo Acoustic 15s Controls: Reference Text, Transcribe WAV Button & WER
            if (_mode == SpikeMode.soloAcoustic15s) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Palette.charcoalTint : Palette.paperTint,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Reference Text Input Field
                      TextField(
                        controller: _referenceTextController,
                        enabled: !_isRunning && !_isTranscribing,
                        style: const TextStyle(fontSize: 11),
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Reference text (type what you read aloud)',
                          hintText: 'e.g. வணக்கம், testing microphone clarity...',
                          hintStyle: TextStyle(fontSize: 10.5, color: theme.hintColor),
                          labelStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          suffixIcon: _referenceTextController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 14),
                                  onPressed: () {
                                    _referenceTextController.clear();
                                    _updateWer(logToOutput: false);
                                  },
                                )
                              : null,
                        ),
                        onChanged: (_) => _updateWer(logToOutput: false),
                      ),

                      // Captured WAV Transcription Action
                      if (_lastCapturedWavFile != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Captured: ${_lastCapturedSource?.name.toUpperCase()} [AGC ${_lastCapturedAgc ? "ON" : "OFF"}] (${(_lastCapturedDurationMs ?? 0) ~/ 1000}s audio)',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Palette.emerald,
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: (_isRunning || _isTranscribing) ? null : _transcribeCapturedTest,
                              icon: _isTranscribing
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.record_voice_over_rounded, size: 14),
                              label: Text(
                                _isTranscribing ? 'Transcribing...' : 'Transcribe this test',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Transcription Result Display
                      if (_lastTranscriptionResult != null) ...[
                        const SizedBox(height: 5),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF14171A) : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Provider: ${_lastTranscriptionProvider ?? "groq"}',
                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Palette.emerald),
                                  ),
                                  Text(
                                    'Elapsed: ${_lastTranscriptionElapsedMs ?? 0}ms',
                                    style: TextStyle(fontSize: 9.5, color: theme.hintColor),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Result: "$_lastTranscriptionResult"',
                                style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Transcription Error Display
                      if (_transcriptionError != null) ...[
                        const SizedBox(height: 5),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Palette.coral.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Palette.coral.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'Transcription error: $_transcriptionError',
                            style: const TextStyle(fontSize: 10, color: Palette.coral, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],

                      // Simple Word Error Rate (WER) Display
                      if (_werResult != null) ...[
                        const SizedBox(height: 5),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Palette.emerald.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Palette.emerald.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Word Error Rate (WER): ${_werResult!.werPercent.toStringAsFixed(1)}%',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Palette.emerald),
                              ),
                              Text(
                                'Rough measure - normalized whitespace and case only (Ref: ${_werResult!.refWordCount} words, Hyp: ${_werResult!.hypWordCount} words, Distance: ${_werResult!.editDistance})',
                                style: TextStyle(fontSize: 9, color: theme.hintColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            // Diagnostics Log Window Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Diagnostics Output:',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                  Text(
                    '${_logEntries.length} events',
                    style: TextStyle(fontSize: 10.5, color: theme.hintColor),
                  ),
                ],
              ),
            ),

            // Diagnostics Log ListView
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14171A) : const Color(0xFFF2F4F8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: _logEntries.isEmpty
                    ? Center(
                        child: Text(
                          'Select audio source above and tap "START 15s ACOUSTIC TEST".\nTest each source (DEFAULT, MIC, VOICE_REC) with AGC ON/OFF to compare clarity & WER.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.hintColor, fontSize: 11),
                        ),
                      )
                    : ListView.builder(
                        controller: _logScrollController,
                        itemCount: _logEntries.length,
                        itemBuilder: (context, index) {
                          final text = _logEntries[index];
                          final isError = text.contains('ERROR') || text.contains('FAIL');
                          final isSuccess = text.contains('EXCELLENT') || text.contains('SUCCESS') || text.contains('RESULTS') || text.contains('COMPLETED');
                          final isStage = text.contains('QUIET STAGE') || text.contains('SPEAKING STAGE');

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1.0),
                            child: Text(
                              text,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                height: 1.25,
                                color: isError
                                    ? Palette.coral
                                    : isSuccess
                                        ? Palette.emerald
                                        : isStage
                                            ? Colors.amber[800]
                                            : null,
                                fontWeight: (isError || isSuccess || isStage) ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceChip(AndroidAudioSource source, String label) {
    final active = _selectedSource == source;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      selected: active,
      visualDensity: VisualDensity.compact,
      onSelected: _isRunning
          ? null
          : (sel) {
              if (sel) setState(() => _selectedSource = source);
            },
    );
  }

  Widget _buildEffectBadge(String name, bool? available) {
    final isAvail = available == true;
    final isUnknown = available == null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isUnknown
            ? Colors.grey.withValues(alpha: 0.15)
            : isAvail
                ? Palette.emerald.withValues(alpha: 0.15)
                : Palette.coral.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isUnknown
              ? Colors.grey
              : isAvail
                  ? Palette.emerald
                  : Palette.coral,
        ),
      ),
      child: Text(
        '$name: ${isUnknown ? "Detecting..." : isAvail ? "Supported" : "Unsupported"}',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: isUnknown
              ? Colors.grey
              : isAvail
                  ? Palette.emerald
                  : Palette.coral,
        ),
      ),
    );
  }

  Widget _buildAudioHealthBadge() {
    if (!_isRunning) return const SizedBox.shrink();

    if (_zeroChunksCount > 5 && _nonZeroChunksCount == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: Palette.coral.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Palette.coral),
        ),
        child: const Text('MUTED / ZERO STREAM', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: Palette.coral)),
      );
    }
    if (_currentDbfs > -45.0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: Palette.emerald.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Palette.emerald),
        ),
        child: const Text('ACTIVE AUDIO', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: Palette.emerald)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.amber),
      ),
      child: const Text('AMBIENT SILENCE', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: Colors.amber)),
    );
  }
}
