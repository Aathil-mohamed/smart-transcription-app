import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final double avgQuietDbfs;
  final double avgSpeakingDbfs;
  final double dynamicRangeDb;
  final double peakDbfs;
  final int totalBytes;

  const AcousticResult({
    required this.source,
    required this.avgQuietDbfs,
    required this.avgSpeakingDbfs,
    required this.dynamicRangeDb,
    required this.peakDbfs,
    required this.totalBytes,
  });
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

  bool _isRunning = false;
  int _secondsRemaining = 15;
  int _testTotalSeconds = 15;
  Timer? _countdownTimer;
  final Stopwatch _testWatch = Stopwatch();

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

  // 15s Acoustic Calibration Samples
  final List<double> _quietRmsSamples = [];
  final List<double> _speakingRmsSamples = [];
  final Map<AndroidAudioSource, AcousticResult> _sourceResults = {};

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
    _cleanup();
    _recorder.dispose();
    _logScrollController.dispose();
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
    _quietRmsSamples.clear();
    _speakingRmsSamples.clear();
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
    _addLog('SELECTED AUDIO SOURCE: ${_selectedSource.name.toUpperCase()}');
    _addLog('CONFIG: sampleRate=${config.audio.sampleRate}, channels=${config.audio.numChannels}, encoder=AudioEncoder.pcm16bits');
    _addLog('EFFECTS FLAGS: NS=${config.audio.noiseSuppress}, AEC=${config.audio.echoCancel}, AGC=${config.audio.autoGain}');
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
        autoGain: config.audio.autoGain,
        androidConfig: AndroidRecordConfig(
          audioSource: _selectedSource,
        ),
      );

      final pcmStream = await _recorder.startStream(recordConfig);
      _addLog('AudioRecorder.startStream active with audioSource=${_selectedSource.name}');

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

    if (_chunksReceived == 1 || _chunksReceived % 30 == 0) {
      final stage = _mode == SpikeMode.soloAcoustic15s
          ? ((_testTotalSeconds - _secondsRemaining) < 5 ? "[QUIET STAGE]" : "[SPEAKING STAGE]")
          : "";
      _addLog('PCM #$_chunksReceived $stage: ${data.lengthInBytes} B, RMS: ${dbfs.toStringAsFixed(1)} dBFS ${allZeros ? "(ALL ZEROS!)" : "(ACTIVE)"}');
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

  Future<void> _stopTest() async {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _testWatch.stop();

    _addLog('Stopping stream and recorder...');
    _cleanup();

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
        avgQuietDbfs: avgQuiet,
        avgSpeakingDbfs: avgSpeaking,
        dynamicRangeDb: dynamicRange,
        peakDbfs: _peakDbfs,
        totalBytes: _totalBytesReceived,
      );

      _sourceResults[_selectedSource] = result;
    }

    if (mounted) {
      setState(() {
        _isRunning = false;
        _sttStatus = 'Stopped';
      });
    }

    _addLog('====================================================');
    _addLog('TEST SUMMARY - SOURCE: ${_selectedSource.name.toUpperCase()}');
    _addLog('Total Duration: ${_testWatch.elapsedMilliseconds} ms | Total Bytes: $_totalBytesReceived B in $_chunksReceived chunks');
    _addLog('Active Non-Zero Chunks: $_nonZeroChunksCount | All-Zero Chunks: $_zeroChunksCount');
    _addLog('Peak Level: ${_peakDbfs.toStringAsFixed(1)} dBFS');

    if (_mode == SpikeMode.soloAcoustic15s) {
      _addLog('--- ACOUSTIC CALIBRATION RESULTS ---');
      _addLog('1. Noise Floor (Quiet 0-5s): ${avgQuiet.toStringAsFixed(1)} dBFS');
      _addLog('2. Voice Level (Speaking 5-15s): ${avgSpeaking.toStringAsFixed(1)} dBFS');
      _addLog('3. Dynamic Range (SNR Margin): +${dynamicRange.toStringAsFixed(1)} dB');
      _addLog('Clarity Assessment: ${_assessClarity(avgQuiet, avgSpeaking, dynamicRange)}');
    } else {
      _addLog('STT Recognized Text Count: $_sttResultCount');
      _addLog('STT First Word Latency: ${_firstTextTimestampMs != null ? "+${_firstTextTimestampMs}ms" : "None"}');
      _addLog('Hybrid Concurrency Verdict: ${_determineHybridVerdict()}');
    }
    _addLog('====================================================');
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
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('15s Solo Acoustic'),
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
                      label: const Text('30s Hybrid (PCM+STT)'),
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

            // Android Audio Source Selector Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'AudioSource:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.hintColor),
                  ),
                  const SizedBox(width: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      _buildSourceChip(AndroidAudioSource.defaultSource, 'DEFAULT'),
                      _buildSourceChip(AndroidAudioSource.mic, 'MIC'),
                      _buildSourceChip(AndroidAudioSource.voiceRecognition, 'VOICE_REC'),
                    ],
                  ),
                ],
              ),
            ),

            // Hardware Audio Effects Availability Strip
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? Palette.charcoalTint : Palette.paperTint,
                  borderRadius: BorderRadius.circular(16),
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
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
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
                            fontSize: 12,
                            color: isQuietStage ? Colors.amber[800] : Palette.emerald,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isRunning ? 'RUNNING (${_secondsRemaining}s remaining)' : 'TEST IDLE',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _isRunning ? Palette.emerald : theme.hintColor,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Peak: ${_peakDbfs.toStringAsFixed(1)} dBFS',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // VU Meter Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        children: [
                          Container(height: 16, color: theme.dividerColor.withValues(alpha: 0.3)),
                          AnimatedFractionallySizedBox(
                            duration: const Duration(milliseconds: 60),
                            widthFactor: normalizedVU,
                            child: Container(
                              height: 16,
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
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'RMS: ${_currentDbfs.toStringAsFixed(1)} dBFS',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        _buildAudioHealthBadge(),
                      ],
                    ),

                    // STT Status Section for Hybrid Mode
                    if (_mode == SpikeMode.hybridSimultaneous30s) ...[
                      const Divider(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'STT: $_sttStatus',
                            style: TextStyle(fontSize: 12, color: theme.hintColor),
                          ),
                          if (_firstTextTimestampMs != null)
                            Text(
                              '1st word: +${_firstTextTimestampMs}ms',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Palette.emerald,
                              ),
                            ),
                        ],
                      ),
                      if (_lastRecognizedText.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Text: "$_lastRecognizedText"',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],

                    // Results Comparison Strip if results recorded
                    if (_sourceResults.isNotEmpty) ...[
                      const Divider(height: 16),
                      const Text(
                        'Acoustic Calibration Comparison:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _sourceResults.entries.map((e) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: theme.dividerColor),
                            ),
                            child: Text(
                              '${e.key.name.toUpperCase()}: Noise ${e.value.avgQuietDbfs.toStringAsFixed(1)} dB | Voice ${e.value.avgSpeakingDbfs.toStringAsFixed(1)} dB (SNR +${e.value.dynamicRangeDb.toStringAsFixed(1)} dB)',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRunning ? Palette.coral : Palette.emerald,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isRunning ? _stopTest : _startTest,
                  icon: Icon(_isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded),
                  label: Text(
                    _isRunning
                        ? 'STOP TEST'
                        : 'START ${_mode == SpikeMode.soloAcoustic15s ? "15s ACOUSTIC TEST" : "30s HYBRID TEST"}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ),

            // Diagnostics Log Window Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Diagnostics Output:',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  Text(
                    '${_logEntries.length} events',
                    style: TextStyle(fontSize: 11, color: theme.hintColor),
                  ),
                ],
              ),
            ),

            // Diagnostics Log ListView
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14171A) : const Color(0xFFF2F4F8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: _logEntries.isEmpty
                    ? Center(
                        child: Text(
                          'Select audio source above and tap "START 15s ACOUSTIC TEST".\nTest each source (DEFAULT, MIC, VOICE_REC) to compare noise floor and voice clarity.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.hintColor, fontSize: 12),
                        ),
                      )
                    : ListView.builder(
                        controller: _logScrollController,
                        itemCount: _logEntries.length,
                        itemBuilder: (context, index) {
                          final text = _logEntries[index];
                          final isError = text.contains('ERROR') || text.contains('FAIL');
                          final isSuccess = text.contains('EXCELLENT') || text.contains('SUCCESS') || text.contains('RESULTS');
                          final isStage = text.contains('QUIET STAGE') || text.contains('SPEAKING STAGE');

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1.5),
                            child: Text(
                              text,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10.5,
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
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: active,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isUnknown
            ? Colors.grey.withValues(alpha: 0.15)
            : isAvail
                ? Palette.emerald.withValues(alpha: 0.15)
                : Palette.coral.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
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
          fontSize: 10,
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Palette.coral.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Palette.coral),
        ),
        child: const Text('MUTED / ZERO STREAM', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Palette.coral)),
      );
    }
    if (_currentDbfs > -45.0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Palette.emerald.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Palette.emerald),
        ),
        child: const Text('ACTIVE AUDIO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Palette.emerald)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.amber),
      ),
      child: const Text('AMBIENT SILENCE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.amber)),
    );
  }
}
