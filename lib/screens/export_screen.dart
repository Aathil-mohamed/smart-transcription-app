import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transcript.dart';
import '../services/export_service.dart';

// Provider for ExportService
final exportServiceProvider = Provider<ExportService>((ref) => ExportService());

class ExportScreen extends ConsumerStatefulWidget {
  final TranscriptionModel transcription;

  const ExportScreen({
    super.key,
    required this.transcription,
  });

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _uploadToCloud = false;
  bool _isProcessing = false;
  String? _cloudUrl;

  // Process file generation and optional upload
  Future<void> _processExport(String format) async {
    setState(() => _isProcessing = true);
    final exporter = ref.read(exportServiceProvider);

    try {
      File generatedFile;
      
      // 1. Generate local file depending on format
      if (format == 'pdf') {
        generatedFile = await exporter.generatePdf(widget.transcription);
      } else if (format == 'docx') {
        generatedFile = await exporter.generateDocx(widget.transcription);
      } else {
        generatedFile = await exporter.generateTxt(widget.transcription);
      }

      String? shareUrl;

      // 2. Upload to Cloud Storage if requested
      if (_uploadToCloud) {
        final userId = widget.transcription.userId;
        shareUrl = await exporter.uploadExportToStorage(
          file: generatedFile,
          transcriptionId: widget.transcription.transcriptionId,
          userId: userId,
          fileType: format,
        );
        setState(() {
          _cloudUrl = shareUrl;
        });
      }

      // 3. Trigger Native Share Sheet
      final String shareSubject = 'Transcript: ${widget.transcription.title}';
      await exporter.shareFile(generatedFile, shareSubject);

      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_uploadToCloud 
                ? 'File generated and uploaded to Cloud successfully!' 
                : 'File generated and opened for sharing!'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export File'),
      ),
      body: SafeArea(
        child: _isProcessing
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _uploadToCloud 
                          ? 'Generating file and uploading to Cloud...' 
                          : 'Generating document...',
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Export: ${widget.transcription.title}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose a format to save or share your transcript.',
                      style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Format Options List
                    _buildFormatOption(
                      format: 'pdf',
                      title: 'Portable Document Format (PDF)',
                      subtitle: 'Best for reading, printing, and official reports',
                      icon: Icons.picture_as_pdf,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    _buildFormatOption(
                      format: 'docx',
                      title: 'Microsoft Word Document (DOC)',
                      subtitle: 'Best for advanced text editing in Word or Docs',
                      icon: Icons.description,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    _buildFormatOption(
                      format: 'txt',
                      title: 'Plain Text File (TXT)',
                      subtitle: 'Lightweight format, compatible with any device',
                      icon: Icons.text_snippet,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 32),

                    const Divider(),
                    const SizedBox(height: 16),

                    // Cloud backup checkbox
                    CheckboxListTile(
                      title: const Text('Upload to Firebase Cloud Storage'),
                      subtitle: const Text('Creates a secure online link to access or share this document from anywhere.'),
                      value: _uploadToCloud,
                      onChanged: (val) {
                        if (val != null) setState(() => _uploadToCloud = val);
                      },
                      secondary: Icon(Icons.cloud_upload_outlined, color: theme.colorScheme.primary),
                      contentPadding: EdgeInsets.zero,
                    ),

                    if (_cloudUrl != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          'Cloud URL:\n$_cloudUrl',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  // Build clickable item
  Widget _buildFormatOption({
    required String format,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _processExport(format),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
