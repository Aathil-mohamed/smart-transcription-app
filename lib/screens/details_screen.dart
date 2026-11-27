import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_design_tokens.dart';
import '../core/theme/motion_helpers.dart';
import '../models/transcript.dart';
import '../providers/record_provider.dart';
import 'export_screen.dart';

class DetailsScreen extends ConsumerStatefulWidget {
  final String transcriptionId;

  const DetailsScreen({
    super.key,
    required this.transcriptionId,
  });

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen> {
  final _titleController = TextEditingController();
  final _transcriptController = TextEditingController();

  bool _isEditing = false;
  bool _isLoading = true;
  TranscriptionModel? _transcription;

  // Audio simulation / scrubber state
  bool _playing = false;
  int _currentSec = 0;
  Timer? _playbackTimer;

  @override
  void initState() {
    super.initState();
    _loadTranscriptionDetails();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _titleController.dispose();
    _transcriptController.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    if (_transcription == null || _transcription!.duration <= 0) return;

    setState(() => _playing = !_playing);
    if (_playing) {
      _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          if (_currentSec < _transcription!.duration) {
            _currentSec++;
          } else {
            _playing = false;
            _currentSec = 0;
            timer.cancel();
          }
        });
      });
    } else {
      _playbackTimer?.cancel();
    }
  }

  Future<void> _loadTranscriptionDetails() async {
    try {
      final doc = await ref
          .read(firestoreServiceProvider)
          .getTranscriptionById(widget.transcriptionId);
      if (doc != null) {
        setState(() {
          _transcription = doc;
          _titleController.text = doc.title;
          _transcriptController.text = doc.transcript;
          _isLoading = false;
        });
      } else {
        _showErrorAndExit('File not found.');
      }
    } catch (e) {
      _showErrorAndExit('Failed to load transcription details: $e');
    }
  }

  void _showErrorAndExit(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Palette.coral),
    );
    Navigator.of(context).pop();
  }

  Future<void> _saveChanges() async {
    if (_titleController.text.trim().isEmpty ||
        _transcriptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fields cannot be empty.'),
          backgroundColor: Palette.amber,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updated = _transcription!.copyWith(
        title: _titleController.text.trim(),
        transcript: _transcriptController.text.trim(),
      );

      await ref.read(firestoreServiceProvider).updateTranscription(updated);

      if (mounted) {
        setState(() {
          _transcription = updated;
          _isEditing = false;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Changes saved successfully!'),
            backgroundColor: Palette.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save details: $e'),
            backgroundColor: Palette.coral,
          ),
        );
      }
    }
  }

  void _showDiagnostics(BuildContext context) {
    if (_transcription == null) return;
    final engine = _transcription!.provider ?? 'groq_whisper';
    final detectedLang =
        _transcription!.detectedLanguage ?? _transcription!.language;
    final segments = _transcription!.segmentCount ??
        _transcription!.segments?.length ??
        0;
    final dropped = _transcription!.droppedSegmentCount ?? 0;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Technical Diagnostics',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Engine: $engine\n'
                  'Detected Language: $detectedLang\n'
                  'Total Segments: $segments\n'
                  'Filtered Noise / Silence: $dropped segments dropped\n'
                  'Audio Status: ${_transcription!.audioLocalPath != null ? "Cached Locally" : (_transcription!.audioUrl != null ? "Cloud Storage" : "None")}',
                  style: TextStyle(
                    height: 1.6,
                    fontSize: 14,
                    color: Theme.of(context).hintColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: Palette.coral),
        ),
      );
    }

    final tx = _transcription!;
    final dateStr = DateFormat('MMM d, yyyy').format(tx.createdAt).toUpperCase();
    final langStr = tx.language.toUpperCase();
    final totalSec = tx.duration;
    final durationStr = '${totalSec ~/ 60}M ${totalSec % 60}S';
    final metadataLine = '$dateStr • $langStr • $durationStr';

    final progressVal =
        totalSec > 0 ? (_currentSec / totalSec).clamp(0.0, 1.0) : 0.0;
    final timeDisplay = '${_formatTime(_currentSec)} / ${_formatTime(totalSec)}';

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 110),
              children: [
                // Top Header: Back Pill + Action Icons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Tactile(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.arrow_back_rounded, size: 18),
                            SizedBox(width: 6),
                            Text('Back',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.info_outline_rounded),
                          onPressed: () => _showDiagnostics(context),
                        ),
                        IconButton(
                          icon: Icon(
                            _isEditing
                                ? Icons.check_rounded
                                : Icons.edit_outlined,
                            color: _isEditing ? Palette.emerald : null,
                          ),
                          onPressed: () {
                            if (_isEditing) {
                              _saveChanges();
                            } else {
                              setState(() => _isEditing = true);
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: tx.transcript),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied transcript to clipboard'),
                                backgroundColor: Palette.emerald,
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.ios_share_rounded),
                          onPressed: () {
                            if (_isEditing) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please save changes before exporting.'),
                                  backgroundColor: Palette.amber,
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                SlideUpRoute(
                                  builder: (_) =>
                                      ExportScreen(transcription: tx),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Metadata Pill Label
                Text(
                  metadataLine,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark ? Palette.coral : Palette.emerald,
                  ),
                ),
                const SizedBox(height: 8),

                // Title Section (Editable / Display)
                if (_isEditing)
                  TextFormField(
                    controller: _titleController,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Title',
                      filled: true,
                      fillColor: theme.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  )
                else
                  Text(
                    tx.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                const SizedBox(height: 22),

                // Selectable Transcript Text (Reader Mode)
                if (_isEditing)
                  TextFormField(
                    controller: _transcriptController,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    style: const TextStyle(fontSize: 18, height: 1.7),
                    decoration: InputDecoration(
                      labelText: 'Transcript Content',
                      filled: true,
                      fillColor: theme.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  )
                else
                  SelectableText(
                    tx.transcript.isEmpty
                        ? 'No transcription text recorded.'
                        : tx.transcript,
                    style: const TextStyle(fontSize: 18, height: 1.7),
                  ),
              ],
            ),
          ),

          // Sticky Bottom Mini Audio Player
          if (totalSec > 0)
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: SafeArea(
                top: false,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Palette.charcoalCard : Palette.ink,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Tactile(
                        onTap: _togglePlayback,
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: Palette.coral,
                          child: Icon(
                            _playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: progressVal,
                            minHeight: 5,
                            backgroundColor: Colors.white24,
                            color: Palette.coral,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        timeDisplay,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
