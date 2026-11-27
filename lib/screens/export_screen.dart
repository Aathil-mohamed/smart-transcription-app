import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_design_tokens.dart';
import '../core/theme/motion_helpers.dart';
import '../models/transcript.dart';
import '../services/export_service.dart';

final exportServiceProvider = Provider<ExportService>((ref) {
  final config = ref.watch(appConfigProvider);
  return ExportService(config);
});

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

  Future<void> _processExport(String format) async {
    HapticFeedback.mediumImpact();
    setState(() => _isProcessing = true);
    final exporter = ref.read(exportServiceProvider);

    try {
      File generatedFile;

      if (format == 'pdf') {
        generatedFile = await exporter.generatePdf(widget.transcription);
      } else if (format == 'docx') {
        generatedFile = await exporter.generateDocx(widget.transcription);
      } else {
        generatedFile = await exporter.generateTxt(widget.transcription);
      }

      String? shareUrl;

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

      final String shareSubject = 'Transcript: ${widget.transcription.title}';
      await exporter.shareFile(generatedFile, shareSubject);

      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_uploadToCloud
                ? 'File generated and uploaded to Cloud successfully!'
                : 'File generated and opened for sharing!'),
            backgroundColor: Palette.emerald,
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Palette.coral,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: _isProcessing
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Palette.coral),
                    SizedBox(height: 16),
                    Text(
                      'Generating document...',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 32),
                children: [
                  // Back Pill Navigation
                  Row(
                    children: [
                      Tactile(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: const Icon(Icons.arrow_back_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'Export Document',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text(
                    widget.transcription.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose a format to save or share your transcript.',
                    style: TextStyle(fontSize: 13.5, color: theme.hintColor),
                  ),
                  const SizedBox(height: 24),

                  // PDF Format Option
                  _buildFormatTile(
                    title: 'Portable Document Format (PDF)',
                    subtitle: 'Best for reading, printing, and official reports',
                    icon: Icons.picture_as_pdf_rounded,
                    color: Palette.coral,
                    onTap: () => _processExport('pdf'),
                  ),
                  const SizedBox(height: 12),

                  // DOCX Format Option
                  _buildFormatTile(
                    title: 'Microsoft Word Document (DOCX)',
                    subtitle: 'Best for advanced text editing in Word or Docs',
                    icon: Icons.description_rounded,
                    color: Palette.emerald,
                    onTap: () => _processExport('docx'),
                  ),
                  const SizedBox(height: 12),

                  // TXT Format Option
                  _buildFormatTile(
                    title: 'Plain Text File (TXT)',
                    subtitle: 'Lightweight format, compatible with any device',
                    icon: Icons.text_snippet_rounded,
                    color: Palette.amber,
                    onTap: () => _processExport('txt'),
                  ),
                  const SizedBox(height: 24),

                  // Cloud Upload Switch
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.cloud_upload_outlined,
                                color: Palette.emerald, size: 24),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cloud Storage Backup',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'Generate secure online link',
                                  style: TextStyle(
                                      fontSize: 12, color: theme.hintColor),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch(
                          value: _uploadToCloud,
                          activeThumbColor: Palette.coral,
                          onChanged: (val) =>
                              setState(() => _uploadToCloud = val),
                        ),
                      ],
                    ),
                  ),

                  if (_cloudUrl != null) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Palette.emerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Palette.emerald.withValues(alpha: 0.3)),
                      ),
                      child: SelectableText(
                        'Cloud Access URL:\n$_cloudUrl',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Palette.emerald,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildFormatTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Tactile(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: theme.hintColor),
          ],
        ),
      ),
    );
  }
}
