import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../providers/record_provider.dart';
import '../widgets/waveform_painter.dart';

class RecorderScreen extends ConsumerWidget {
  const RecorderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final config = ref.watch(appConfigProvider);
    final recordState = ref.watch(recordNotifierProvider);
    final recordNotifier = ref.read(recordNotifierProvider.notifier);

    // Format duration e.g. 00:00
    final int minutes = recordState.durationSecs ~/ 60;
    final int seconds = recordState.durationSecs % 60;
    final String timerString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Recording'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Warn if currently recording
            if (recordState.status == RecordStatus.recording || recordState.status == RecordStatus.paused) {
              _showExitWarning(context, recordNotifier);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Language selection block (Only editable when idle)
              if (recordState.status == RecordStatus.idle) ...[
                Text(
                  'Select Transcription Language',
                  style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: recordState.selectedLanguageCode,
                      isExpanded: true,
                      dropdownColor: theme.colorScheme.surface,
                      items: config.languages.map((lang) {
                        return DropdownMenuItem<String>(
                          value: lang.code,
                          child: Text(lang.name, style: const TextStyle(fontSize: 15)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) recordNotifier.setLanguage(val);
                      },
                    ),
                  ),
                ),
              ] else ...[
                // Lock language display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.translate, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Language Locked: ${config.findLanguage(recordState.selectedLanguageCode).displayName}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Recording Status Warning / Error messages
              if (recordState.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.amber, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          recordState.errorMessage!,
                          style: const TextStyle(fontSize: 12, color: Colors.amberAccent, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Custom Sound Wave visualizer
              Expanded(
                flex: 2,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.04)),
                  ),
                  child: recordState.status == RecordStatus.recording
                      ? CustomPaint(
                          size: Size(size.width - 96, 120),
                          painter: WaveformPainter(
                            waveHistory: recordState.waveHistory,
                            primaryColor: theme.colorScheme.primary,
                            accentColor: theme.colorScheme.secondary,
                          ),
                        )
                      : Text(
                          recordState.status == RecordStatus.paused
                              ? 'Recording Paused'
                              : 'Waveform visualizer ready',
                          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Live Transcription Box
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.04)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Live Transcript',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          // Mini recording status indicator dot
                          if (recordState.status == RecordStatus.recording)
                            _buildRecordingDot(theme),
                        ],
                      ),
                      const Divider(height: 24),
                      Expanded(
                        child: SingleChildScrollView(
                          reverse: true, // Auto scrolls down as words appear
                          child: Text(
                            recordState.liveText,
                            style: const TextStyle(
                              fontSize: 17,
                              height: 1.5,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Timer Display
              Center(
                child: Text(
                  timerString,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Control panel buttons (Start/Pause/Resume/Stop)
              _buildControlPanel(context, recordState, recordNotifier, theme),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // Builder: control buttons
  Widget _buildControlPanel(
    BuildContext context,
    RecordState state,
    RecordNotifier notifier,
    ThemeData theme,
  ) {
    if (state.status == RecordStatus.finalizing) {
      return Center(
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'Refining & Finalizing transcript...',
              style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    if (state.status == RecordStatus.idle) {
      return Center(
        child: Column(
          children: [
            GestureDetector(
              onTap: () => notifier.startRecording(),
              child: Container(
                height: 90,
                width: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.mic, size: 40, color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'TAP MIC TO START',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Pause / Resume Button
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2), width: 1.5),
          ),
          child: FloatingActionButton(
            heroTag: 'pauseBtn',
            elevation: 0,
            backgroundColor: theme.colorScheme.surface,
            foregroundColor: theme.colorScheme.primary,
            onPressed: () {
              if (state.status == RecordStatus.recording) {
                notifier.pauseRecording();
              } else {
                notifier.resumeRecording();
              }
            },
            child: Icon(
              state.status == RecordStatus.recording ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 32),
        // Stop & Save Button
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withValues(alpha: 0.25),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton.large(
            heroTag: 'stopBtn',
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            elevation: 0,
            onPressed: () async {
              await notifier.stopRecording();
              if (context.mounted) {
                Navigator.of(context).pop(); // Go back to dashboard when saved
              }
            },
            child: const Icon(Icons.stop_rounded, size: 36),
          ),
        ),
      ],
    );
  }

  // Live pulsing red dot
  Widget _buildRecordingDot(ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'REC',
          style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ],
    );
  }

  // Warn users if they leave recording
  void _showExitWarning(BuildContext context, RecordNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Recording?'),
        content: const Text('Are you sure you want to exit? The current recording will be lost.'),
        actions: [
          TextButton(
            child: const Text('CANCEL'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('EXIT & DISCARD', style: TextStyle(color: Colors.redAccent)),
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
}
