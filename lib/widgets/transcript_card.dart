import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_design_tokens.dart';
import '../core/theme/motion_helpers.dart';
import '../models/transcript.dart';

class TranscriptCard extends StatelessWidget {
  final TranscriptionModel transcription;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const TranscriptCard({
    super.key,
    required this.transcription,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tintBg = isDark ? Palette.charcoalTint : Palette.paperTint;

    final formattedTime =
        DateFormat('MMM d • h:mm a').format(transcription.createdAt).toUpperCase();
    final durationStr =
        '${(transcription.duration ~/ 60).toString().padLeft(2, '0')}:${(transcription.duration % 60).toString().padLeft(2, '0')}';
    final langTag =
        '${transcription.language.toUpperCase().substring(0, math.min(transcription.language.length, 2))} • $durationStr';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Tactile(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Timeline Marker
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Palette.coral,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      color: theme.dividerColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Main Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formattedTime,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: theme.hintColor,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: tintBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  langTag,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 19,
                                  color: theme.hintColor.withValues(alpha: 0.6),
                                ),
                                onPressed: onDelete,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        transcription.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        transcription.transcript.isEmpty
                            ? 'No transcript text available'
                            : transcription.transcript,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: theme.hintColor,
                        ),
                      ),
                    ],
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
