import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_design_tokens.dart';
import '../core/theme/motion_helpers.dart';
import '../l10n/app_localizations.dart';
import '../providers/record_provider.dart';
import '../widgets/waveform_painter.dart';

class RecorderScreen extends ConsumerStatefulWidget {
  const RecorderScreen({super.key});

  @override
  ConsumerState<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends ConsumerState<RecorderScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  String _formatTimer(int durationSecs) {
    final int minutes = durationSecs ~/ 60;
    final int seconds = durationSecs % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showExitWarning(BuildContext context, RecordNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Discard Recording?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Are you sure you want to exit? The current audio session will be discarded.',
        ),
        actions: [
          TextButton(
            child: const Text('CANCEL',
                style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('EXIT & DISCARD',
                style: TextStyle(
                    color: Palette.coral, fontWeight: FontWeight.w700)),
            onPressed: () async {
              await notifier.cancelRecording();
              if (context.mounted) {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final recordState = ref.watch(recordNotifierProvider);
    final recordNotifier = ref.read(recordNotifierProvider.notifier);

    final isRecording = recordState.status == RecordStatus.recording;
    final isFinalizing = recordState.status == RecordStatus.finalizing;
    final isRetry = recordState.status == RecordStatus.retryRequired;

    final clock = _formatTimer(recordState.durationSecs);

    // Dynamic wave amplitude reacting to real microphone decibels
    double waveAmplitude = 0.12;
    if (isRecording) {
      final normalized = ((recordState.currentDb + 60) / 60).clamp(0.0, 1.0);
      waveAmplitude = (0.45 + normalized * 0.50).clamp(0.2, 0.95);
    }

    final langs = [
      ('TA + EN', 'bilingual'),
      ('English', 'en-US'),
      ('தமிழ்', 'ta-IN'),
    ];

    String captionText = '';
    if (isFinalizing) {
      captionText = 'Refining & transcribing audio with Whisper AI...';
    } else if (isRecording) {
      captionText = recordState.liveText.isNotEmpty
          ? recordState.liveText
          : 'Listening... Speak naturally in Tamil or English.';
    } else {
      captionText =
          'Ready when you are.\nTap the record button below to begin speaking.';
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Minimal Header + Sliding Segmented Language Switcher
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Tactile(
                    onTap: () {
                      if (isRecording ||
                          recordState.status == RecordStatus.paused) {
                        _showExitWarning(context, recordNotifier);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ),

                  // Language Switcher (Disabled while active recording)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? Palette.charcoalTint : Palette.paperTint,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      children: List.generate(langs.length, (i) {
                        final active =
                            recordState.selectedLanguageCode == langs[i].$2;
                        return GestureDetector(
                          onTap: isRecording
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  recordNotifier.setLanguage(langs[i].$2);
                                },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  active ? Palette.emerald : Colors.transparent,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              langs[i].$1,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: active ? Colors.white : theme.hintColor,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),

            // Full-Bleed Large Caption Stage
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: Text(
                        captionText,
                        key: ValueKey(captionText),
                        style: TextStyle(
                          fontSize: 26,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: (recordState.status == RecordStatus.idle &&
                                  recordState.liveText.isEmpty)
                              ? theme.hintColor.withValues(alpha: 0.6)
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Retry Card if error occurred
            if (isRetry) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Palette.coral.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Palette.coral.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        AppLocalizations.of(context)?.retryTitle ??
                            'Transcription Incomplete',
                        style: const TextStyle(
                          color: Palette.coral,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppLocalizations.of(context)?.retryMessage ??
                            'Audio was safely saved to your device. Would you like to retry transcription?',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: theme.hintColor),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Tactile(
                            onTap: () => recordNotifier.cancelRecording(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(color: theme.dividerColor),
                              ),
                              child: Text(
                                AppLocalizations.of(context)?.discardButton ??
                                    'Discard',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Tactile(
                            onTap: () => recordNotifier.retryTranscription(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: Palette.coral,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                AppLocalizations.of(context)?.retryButton ??
                                    'Retry Now',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Flowing Ribbon Waveform
            SizedBox(
              height: 90,
              width: double.infinity,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _waveCtrl,
                  builder: (_, __) => CustomPaint(
                    painter: RibbonWavePainter(
                      phase: _waveCtrl.value * 2 * math.pi,
                      amplitude: waveAmplitude,
                      color: isRecording
                          ? Palette.coral
                          : Palette.emerald.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Hardware Control Deck
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              decoration: BoxDecoration(
                color: isDark ? Palette.charcoalCard : Palette.ink,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFinalizing
                            ? 'TRANSCRIBING'
                            : (isRecording ? 'RECORDING' : 'STANDBY'),
                        style: TextStyle(
                          color: isRecording
                              ? Palette.coral
                              : (isFinalizing ? Palette.amber : Colors.white54),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        clock,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),

                  // Circular / Squircle Record Button with tactile feedback
                  Tactile(
                    onTap: isFinalizing
                        ? null
                        : () async {
                            if (isRecording) {
                              HapticFeedback.heavyImpact();
                              await recordNotifier.stopRecording();
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            } else {
                              HapticFeedback.mediumImpact();
                              await recordNotifier.startRecording();
                            }
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: Palette.coral,
                        borderRadius:
                            BorderRadius.circular(isRecording ? 22 : 34),
                        boxShadow: [
                          BoxShadow(
                            color: Palette.coral.withValues(alpha: 0.42),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Center(
                        child: isFinalizing
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.8,
                                ),
                              )
                            : Icon(
                                isRecording
                                    ? Icons.stop_rounded
                                    : Icons.mic_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
