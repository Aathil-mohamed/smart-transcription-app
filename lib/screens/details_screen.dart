import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_design_tokens.dart';
import '../l10n/app_localizations.dart';
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

  @override
  void initState() {
    super.initState();
    _loadTranscriptionDetails();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _transcriptController.dispose();
    super.dispose();
  }

  // Load latest details from Firestore
  Future<void> _loadTranscriptionDetails() async {
    try {
      final doc = await ref.read(firestoreServiceProvider).getTranscriptionById(widget.transcriptionId);
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
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
    Navigator.of(context).pop();
  }

  // Save changes to Firestore
  Future<void> _saveChanges() async {
    if (_titleController.text.trim().isEmpty || _transcriptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fields cannot be empty.'), backgroundColor: Colors.amber),
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
          const SnackBar(content: Text('Changes saved successfully!'), backgroundColor: Colors.teal),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save details: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final String formattedDate = DateFormat('yMMMd').add_jm().format(_transcription!.createdAt);
    final int minutes = _transcription!.duration ~/ 60;
    final int seconds = _transcription!.duration % 60;
    final String durationString = '${minutes}m ${seconds}s';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        actions: [
          // Edit / Save toggle buttons
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.check, color: Colors.tealAccent),
              onPressed: _saveChanges,
            )
          else
            IconButton(
              icon: const Icon(Icons.edit_note),
              onPressed: () => setState(() => _isEditing = true),
            ),
          
          // Export Button
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: () {
              if (_isEditing) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please save your changes before exporting.'), backgroundColor: Colors.amber),
                );
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ExportScreen(transcription: _transcription!),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Meta Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Created: $formattedDate',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                  Row(
                    children: [
                      Icon(Icons.translate, size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        _transcription!.language,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.timer_outlined, size: 14, color: theme.colorScheme.secondary),
                      const SizedBox(width: 4),
                      Text(
                        durationString,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              // Debug Details Line
              if (_transcription!.provider != null) ...[
                SizedBox(height: context.tokens.spaceSm),
                Text(
                  AppLocalizations.of(context)?.transcriptionDetails(
                        _transcription!.provider!,
                        _transcription!.detectedLanguage ?? _transcription!.language,
                        _transcription!.segmentCount ?? _transcription!.segments?.length ?? 0,
                        _transcription!.droppedSegmentCount ?? 0,
                      ) ??
                      'Engine: ${_transcription!.provider} • Detected: ${_transcription!.detectedLanguage ?? _transcription!.language} • Segments: ${_transcription!.segmentCount ?? _transcription!.segments?.length ?? 0} (dropped: ${_transcription!.droppedSegmentCount ?? 0})',
                  style: TextStyle(
                    fontSize: context.tokens.fontXs,
                    color: context.tokens.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Title editing block
              if (_isEditing)
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Transcription Title',
                    prefixIcon: Icon(Icons.title),
                  ),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                )
              else
                Text(
                  _transcription!.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                ),
              const SizedBox(height: 20),

              // Transcription text block
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _isEditing
                      ? TextFormField(
                          controller: _transcriptController,
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            alignLabelWithHint: true,
                            labelText: 'Transcript Content',
                            contentPadding: EdgeInsets.all(16),
                          ),
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        )
                      : SingleChildScrollView(
                          child: Text(
                            _transcription!.transcript,
                            style: const TextStyle(fontSize: 16, height: 1.6, letterSpacing: 0.2),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
