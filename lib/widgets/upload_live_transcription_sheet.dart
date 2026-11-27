import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_design_tokens.dart';
import '../core/theme/motion_helpers.dart';
import '../l10n/app_localizations.dart';
import '../providers/upload_provider.dart';
import '../screens/details_screen.dart';

/// Shows the bottom modal sheet for live upload transcription.
Future<void> showUploadLiveTranscriptionModal(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const UploadLiveTranscriptionSheet(),
  );
}

class UploadLiveTranscriptionSheet extends ConsumerStatefulWidget {
  const UploadLiveTranscriptionSheet({super.key});

  @override
  ConsumerState<UploadLiveTranscriptionSheet> createState() =>
      _UploadLiveTranscriptionSheetState();
}

class _UploadLiveTranscriptionSheetState
    extends ConsumerState<UploadLiveTranscriptionSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final ScrollController _scrollController = ScrollController();
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatTime(double sec) {
    final totalSec = sec.toInt();
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(uploadNotifierProvider);
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sheetBg = isDark ? Palette.charcoalCard : Palette.paperCard;
    final boxBg = isDark ? Palette.charcoalTint : Palette.paperTint;
    final textPrimary = isDark ? Colors.white : Palette.ink;
    final textMuted = isDark ? Colors.white60 : Colors.black54;

    final isBusy = uploadState.status == UploadStatus.transcribing ||
        uploadState.status == UploadStatus.streaming ||
        uploadState.status == UploadStatus.saving;
    final isSuccess = uploadState.status == UploadStatus.success;
    final isError = uploadState.status == UploadStatus.error;

    // Auto-scroll when new text or segments arrive
    ref.listen<UploadState>(uploadNotifierProvider, (previous, next) {
      if (next.revealedSegments.length != previous?.revealedSegments.length ||
          next.liveText.length != previous?.liveText.length) {
        _scrollToBottom();
      }
    });

    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.85,
        minHeight: screenHeight * 0.50,
      ),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 32,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSuccess
                          ? Palette.emerald.withValues(alpha: 0.15)
                          : isError
                              ? Palette.coral.withValues(alpha: 0.15)
                              : Palette.coral.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isSuccess
                          ? Icons.check_circle_rounded
                          : isError
                              ? Icons.error_outline_rounded
                              : Icons.graphic_eq_rounded,
                      color: isSuccess
                          ? Palette.emerald
                          : isError
                              ? Palette.coral
                              : Palette.coral,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.uploadLiveTitle ?? 'Live Audio Transcription',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          uploadState.progressText.isNotEmpty
                              ? uploadState.progressText
                              : (l10n?.uploadTranscribing ?? 'Transcribing speech live...'),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: isError
                                ? Palette.coral
                                : isSuccess
                                    ? Palette.emerald
                                    : textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Audio File Meta Strip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: boxBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.audio_file_rounded,
                      size: 20,
                      color: Palette.coral,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        uploadState.fileName ?? 'Audio Recording',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    if (uploadState.fileSize != null) ...[
                      Text(
                        _formatFileSize(uploadState.fileSize),
                        style: TextStyle(fontSize: 11.5, color: textMuted),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (uploadState.durationSec != null && uploadState.durationSec! > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Palette.emerald.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _formatDuration(uploadState.durationSec),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Palette.emerald,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (uploadState.languageDisplayName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          uploadState.languageDisplayName!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Pulsing Studio Equalizer Visualizer (Visible while active)
              if (isBusy) ...[
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return SizedBox(
                      height: 28,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(18, (index) {
                          final phase = (index / 18) * 2 * math.pi;
                          final wave = math.sin(_animController.value * 2 * math.pi + phase);
                          final heightFactor = (wave + 1) / 2; // 0.0 .. 1.0
                          final barHeight = 6.0 + (heightFactor * 20.0);

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2.2),
                            width: 3.5,
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: Palette.coral.withValues(
                                alpha: 0.35 + (heightFactor * 0.65),
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
              ],

              // Live Transcription View Area
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: boxBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isBusy
                          ? Palette.coral.withValues(alpha: 0.35)
                          : isSuccess
                              ? Palette.emerald.withValues(alpha: 0.35)
                              : Theme.of(context).dividerColor,
                    ),
                  ),
                  child: isError
                      ? Center(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  size: 40,
                                  color: Palette.coral,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l10n?.uploadFailed ?? 'Transcription Failed',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Palette.coral,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  uploadState.errorMessage ??
                                      (l10n?.errorUnknown ?? 'An unexpected error occurred.'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textMuted,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : uploadState.revealedSegments.isEmpty &&
                              uploadState.liveText.trim().isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isDark ? Palette.coral : Palette.emerald,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    l10n?.uploadConnecting ?? 'Connecting to AI model...',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      color: textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Scrollbar(
                              controller: _scrollController,
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (uploadState.revealedSegments.isNotEmpty) ...[
                                      ...uploadState.revealedSegments.map((seg) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                margin: const EdgeInsets.only(top: 2),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .dividerColor
                                                      .withValues(alpha: 0.35),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '${_formatTime(seg.start)} - ${_formatTime(seg.end)}',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: textMuted,
                                                    fontFeatures: const [
                                                      FontFeature.tabularFigures()
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: SelectableText(
                                                  seg.text.trim(),
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    height: 1.5,
                                                    fontWeight: FontWeight.w500,
                                                    color: textPrimary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ] else ...[
                                      SelectableText(
                                        uploadState.liveText,
                                        style: TextStyle(
                                          fontSize: 15,
                                          height: 1.5,
                                          fontWeight: FontWeight.w500,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ],
                                    if (isBusy)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                color: Palette.coral,
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              l10n?.uploadTranscribing ?? 'Transcribing speech live...',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontStyle: FontStyle.italic,
                                                color: Palette.coral,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                ),
              ),
              const SizedBox(height: 16),

              // Bottom Actions
              if (isSuccess && uploadState.transcriptionId != null) ...[
                Row(
                  children: [
                    // Copy button
                    Tactile(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: uploadState.liveText),
                        );
                        setState(() => _copied = true);
                        Future.delayed(const Duration(seconds: 2), () {
                          if (mounted) setState(() => _copied = false);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n?.textCopied ?? 'Transcript copied to clipboard'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: boxBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _copied
                                  ? Icons.check_rounded
                                  : Icons.copy_rounded,
                              size: 18,
                              color: _copied ? Palette.emerald : textPrimary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n?.copyText ?? 'Copy Text',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _copied ? Palette.emerald : textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // View Note Primary Button
                    Expanded(
                      child: Tactile(
                        onTap: () {
                          final docId = uploadState.transcriptionId!;
                          Navigator.of(context).pop(); // dismiss modal
                          Navigator.of(context).push(
                            SlideUpRoute(
                              builder: (_) =>
                                  DetailsScreen(transcriptionId: docId),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isDark ? Palette.emerald : Palette.ink,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: (isDark ? Palette.emerald : Palette.ink)
                                    .withValues(alpha: 0.3),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                l10n?.viewNote ?? 'View Note',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (isError) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          ref.read(uploadNotifierProvider.notifier).reset();
                          Navigator.of(context).pop();
                        },
                        child: Text(l10n?.done ?? 'Done'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // In progress or waiting
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Hide and continue in background',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
