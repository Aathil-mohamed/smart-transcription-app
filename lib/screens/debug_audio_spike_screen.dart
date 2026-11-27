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
  hybridSimultaneous, // PCM stream + native STT
  pcmSolo, // PCM stream only (STT off)
}

class DebugAudioSpikeScreen extends ConsumerStatefulWidget {
  const DebugAudioSpikeScreen({super.key});

  @override
  ConsumerState<DebugAudioSpikeScreen> createState() => _DebugAudioSpikeScreenState();
}

class _DebugAudioSpikeScreenState extends ConsumerState<DebugAudioSpikeScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _streamSub;

  SpikeMode _mode = SpikeMode.hybridSimultaneous;
  bool _isRunning = false;
  int _secondsRemaining = 30;
  Timer? _countdownTimer;
  final Stopwatch _testWatch = Stopwatch();

  // Metrics
  double _currentDbfs = -160.0;
  double _peakDbfs = -160.0;
  int _totalBytesReceived = 0;
  int _chunksReceived = 0;
  int _zeroChunksCount = 0;
  int _nonZeroChunksCount = 0;

  // Speech to text metrics
  String _sttStatus = 'Idle';
  String _lastRecognizedText = '';
  int? _firstTextTimestampMs;
  int _sttResultCount = 0;

  // Log events
  final List<String> _logEntries = [];
  final ScrollController _logScrollController = ScrollController();

  @override
  void dispose() {
    _cleanup();
    _recorder.dispose();
    _logScrollController.dispose();
    super.dispose();
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
    _sttStatus = 'Starting...';
    _lastRecognizedText = '';
    _firstTextTimestampMs = null;
    _sttResultCount = 0;
    _secondsRemaining = 30;

    setState(() {
      _isRunning = true;
    });

    _testWatch.reset();
    _testWatch.start();

    final config = ref.read(appConfigProvider);
    _addLog('--- STARTING 30s TEST (Mode: ${_mode == SpikeMode.hybridSimultaneous ? "HYBRID (PCM + STT)" : "SOLO (PCM Only)"}) ---');

    try {
      // 1. Check microphone permission
      final hasPermission = await _recorder.hasPermission();
      _addLog('Microphone permission check: ${hasPermission ? "GRANTED" : "DENIED"}');
      if (!hasPermission) {
        _addLog('ERROR: Microphone permission was denied.');
        _stopTest();
        return;
      }

      // 2. Start PCM Stream with exact config parameters
      _addLog('Starting AudioRecorder.startStream: sampleRate=${config.audio.sampleRate}, channels=${config.audio.numChannels}, encoder=AudioEncoder.pcm16bits, NS=${config.audio.noiseSuppress}, AEC=${config.audio.echoCancel}, AGC=${config.audio.autoGain}');

      final recordConfig = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: config.audio.sampleRate,
        numChannels: config.audio.numChannels,
        noiseSuppress: config.audio.noiseSuppress,
        echoCancel: config.audio.echoCancel,
        autoGain: config.audio.autoGain,
      );

      final pcmStream = await _recorder.startStream(recordConfig);
      _addLog('PCM stream handle created successfully.');

      _streamSub = pcmStream.listen(
        (data) {
          _processPcmChunk(data);
        },
        onError: (err, st) {
          _addLog('PCM STREAM ERROR: $err');
        },
        onDone: () {
          _addLog('PCM Stream closed by system.');
        },
        cancelOnError: false,
      );

      // 3. Start Native Speech Recognizer if in Hybrid Mode
      if (_mode == SpikeMode.hybridSimultaneous) {
        _addLog('Starting native SpeechToText preview...');
        final livePreview = ref.read(livePreviewServiceProvider);
        final lang = config.findLanguage('bilingual');

        final initialized = await livePreview.initialize(
          onTextUpdated: (text) {
            _sttResultCount++;
            if (_firstTextTimestampMs == null && text.trim().isNotEmpty) {
              _firstTextTimestampMs = _testWatch.elapsedMilliseconds;
              _addLog('FIRST STT TEXT RECEIVED at +${_firstTextTimestampMs}ms');
            }
            if (mounted) {
              setState(() {
                _lastRecognizedText = text;
              });
            }
            _addLog('STT Recognized: "${text.length > 40 ? "${text.substring(0, 40)}..." : text}"');
          },
          onUnavailable: (reason) {
            _addLog('STT Unavailable callback: $reason');
            if (mounted) setState(() => _sttStatus = 'Unavailable: $reason');
          },
        );

        _addLog('STT engine initialize result: $initialized');
        if (initialized) {
          await livePreview.startListening(language: lang);
          if (mounted) setState(() => _sttStatus = 'Listening');
          _addLog('STT engine actively listening with locale=${lang.speechLocale}');
        } else {
          if (mounted) setState(() => _sttStatus = 'Init Failed');
        }
      } else {
        if (mounted) setState(() => _sttStatus = 'Disabled for Solo Test');
      }

      // 4. Start 30s countdown timer
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_secondsRemaining <= 1) {
          _addLog('30-second duration completed. Auto-stopping test.');
          _stopTest();
        } else {
          setState(() {
            _secondsRemaining--;
          });
        }
      });
    } catch (e, st) {
      _addLog('TEST START FAILED WITH EXCEPTION: $e\n$st');
      _stopTest();
    }
  }

  void _processPcmChunk(Uint8List data) {
    _chunksReceived++;
    _totalBytesReceived += data.lengthInBytes;

    if (data.isEmpty) return;

    // Check if the entire chunk is dead zeros
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

    // Compute RMS in dBFS (16-bit little endian signed integer)
    final byteData = ByteData.sublistView(data);
    final sampleCount = data.lengthInBytes ~/ 2;
    double sumSquares = 0.0;

    for (int i = 0; i < sampleCount; i++) {
      final sample = byteData.getInt16(i * 2, Endian.little);
      sumSquares += sample * sample;
    }

    final double rms = sampleCount > 0 ? math.sqrt(sumSquares / sampleCount) : 0.0;
    final double dbfs = rms > 0 ? (20 * math.log(rms / 32768.0) / math.ln10).clamp(-160.0, 0.0) : -160.0;

    if (_chunksReceived == 1 || _chunksReceived % 25 == 0) {
      _addLog('PCM Chunk #$_chunksReceived: ${data.lengthInBytes} B, RMS: ${dbfs.toStringAsFixed(1)} dBFS ${allZeros ? "(ALL ZEROS)" : "(ACTIVE)"}');
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

    _addLog('Stopping test...');
    _cleanup();

    if (mounted) {
      setState(() {
        _isRunning = false;
        _sttStatus = 'Stopped';
      });
    }

    _addLog('--- TEST SUMMARY ---');
    _addLog('Total Duration: ${_testWatch.elapsedMilliseconds} ms');
    _addLog('Total PCM Bytes: $_totalBytesReceived bytes in $_chunksReceived chunks');
    _addLog('Non-zero active chunks: $_nonZeroChunksCount | All-zero silent chunks: $_zeroChunksCount');
    _addLog('Peak RMS Level: ${_peakDbfs.toStringAsFixed(1)} dBFS');
    _addLog('STT Text Result Count: $_sttResultCount');
    _addLog('STT First Text Timestamp: ${_firstTextTimestampMs != null ? "+${_firstTextTimestampMs}ms" : "None"}');
    _addLog('Verdict: ${_determineVerdict()}');
    _addLog('--- END OF TEST ---');
  }

  String _determineVerdict() {
    if (_totalBytesReceived == 0) {
      return 'FAILURE: No PCM bytes received from AudioRecorder.';
    }
    if (_nonZeroChunksCount == 0 && _zeroChunksCount > 0) {
      return 'FAILURE: PCM stream delivered ONLY zeros. Audio server or microphone was muted/blocked.';
    }
    if (_mode == SpikeMode.hybridSimultaneous) {
      if (_sttResultCount == 0) {
        return 'WARNING: PCM received real audio, but SpeechToText returned 0 words. Mic might be locked by PCM or speech engine timed out.';
      }
      return 'SUCCESS: Both PCM stream (real audio) and SpeechToText (recognized words) ran concurrently!';
    } else {
      return 'SUCCESS: PCM stream ran in solo mode with active non-zero audio!';
    }
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

    // Amplitude bar normalized 0.0 to 1.0 (from -80 dBFS to 0 dBFS)
    final normalizedVU = ((_currentDbfs + 80) / 80).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Audio & STT Spike Test',
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Hybrid (PCM + STT)'),
                      selected: _mode == SpikeMode.hybridSimultaneous,
                      onSelected: _isRunning
                          ? null
                          : (sel) {
                              if (sel) setState(() => _mode = SpikeMode.hybridSimultaneous);
                            },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Solo (PCM Only)'),
                      selected: _mode == SpikeMode.pcmSolo,
                      onSelected: _isRunning
                          ? null
                          : (sel) {
                              if (sel) setState(() => _mode = SpikeMode.pcmSolo);
                            },
                    ),
                  ),
                ],
              ),
            ),

            // Real-time Status Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Palette.charcoalTint : Palette.paperTint,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isRunning ? 'RUNNING TEST (${_secondsRemaining}s remaining)' : 'TEST IDLE',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _isRunning ? Palette.emerald : theme.hintColor,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Peak: ${_peakDbfs.toStringAsFixed(1)} dBFS',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // VU Meter Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        children: [
                          Container(
                            height: 18,
                            color: theme.dividerColor.withValues(alpha: 0.3),
                          ),
                          AnimatedFractionallySizedBox(
                            duration: const Duration(milliseconds: 60),
                            widthFactor: normalizedVU,
                            child: Container(
                              height: 18,
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
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        _buildAudioHealthBadge(),
                      ],
                    ),
                    const Divider(height: 18),

                    // STT Status Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'STT Status: $_sttStatus',
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
                      const SizedBox(height: 6),
                      Text(
                        'Text: "$_lastRecognizedText"',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                        ),
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
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRunning ? Palette.coral : Palette.emerald,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isRunning ? _stopTest : _startTest,
                  icon: Icon(_isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded),
                  label: Text(
                    _isRunning ? 'STOP TEST' : 'START 30s TEST',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ),

            // Diagnostics Log Window
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Real-Time Diagnostics Log:',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  Text(
                    '${_logEntries.length} events',
                    style: TextStyle(fontSize: 11, color: theme.hintColor),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14171A) : const Color(0xFFF2F4F8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: _logEntries.isEmpty
                    ? Center(
                        child: Text(
                          'Tap "START 30s TEST" above.\nSpeak continuously in Tamil or English to observe live RMS and STT feedback.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.hintColor, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        controller: _logScrollController,
                        itemCount: _logEntries.length,
                        itemBuilder: (context, index) {
                          final text = _logEntries[index];
                          final isError = text.contains('ERROR') || text.contains('FAIL');
                          final isSuccess = text.contains('SUCCESS') || text.contains('FIRST STT');
                          final isChunk = text.contains('PCM Chunk');

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              text,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                height: 1.3,
                                color: isError
                                    ? Palette.coral
                                    : isSuccess
                                        ? Palette.emerald
                                        : isChunk
                                            ? (isDark ? Colors.cyanAccent : Colors.teal)
                                            : null,
                                fontWeight: (isError || isSuccess) ? FontWeight.w700 : FontWeight.w400,
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

  Widget _buildAudioHealthBadge() {
    if (!_isRunning) {
      return const SizedBox.shrink();
    }
    if (_zeroChunksCount > 5 && _nonZeroChunksCount == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Palette.coral.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Palette.coral),
        ),
        child: const Text(
          'MUTED / ZERO STREAM',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Palette.coral),
        ),
      );
    }
    if (_currentDbfs > -45.0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Palette.emerald.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Palette.emerald),
        ),
        child: const Text(
          'REAL AUDIO DETECTED',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Palette.emerald),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.amber),
      ),
      child: const Text(
        'AMBIENT SILENCE',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.amber),
      ),
    );
  }
}
