import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_design_tokens.dart';
import '../core/theme/motion_helpers.dart';
import '../models/transcript.dart';
import '../providers/auth_provider.dart';
import '../providers/history_provider.dart';
import '../providers/record_provider.dart';
import '../providers/upload_provider.dart';
import '../widgets/language_selector_sheet.dart';
import '../widgets/upload_live_transcription_sheet.dart';
import 'details_screen.dart';
import 'recorder_screen.dart';
import 'saved_list_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _eqCtrl;

  @override
  void initState() {
    super.initState();
    _eqCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _eqCtrl.dispose();
    super.dispose();
  }

  String _greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING';
    if (hour < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  String _formatTotalDuration(List<TranscriptionModel> list) {
    final totalSeconds = list.fold<int>(0, (sum, item) => sum + item.duration);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tintBg = isDark ? Palette.charcoalTint : Palette.paperTint;
    final config = ref.watch(appConfigProvider);
    final userDetails = ref.watch(userDetailsProvider);
    final transcriptionsAsync = ref.watch(rawTranscriptionsStreamProvider);
    final recordState = ref.watch(recordNotifierProvider);
    final uploadState = ref.watch(uploadNotifierProvider);

    final isUploading = uploadState.status == UploadStatus.picking ||
        uploadState.status == UploadStatus.transcribing ||
        uploadState.status == UploadStatus.streaming ||
        uploadState.status == UploadStatus.saving;

    final userName = userDetails.value?.name.isNotEmpty == true
        ? userDetails.value!.name.split(' ').first
        : 'User';

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: transcriptionsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Palette.coral),
              ),
              error: (err, _) => Center(
                child: Text('Error loading dashboard: $err'),
              ),
              data: (list) {
                final sessionCount = list.length.toString().padLeft(2, '0');
                final capturedDuration = _formatTotalDuration(list);
                final recentItems = list.take(5).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 115),
                  children: [
                    // Header Row: Greeting + Tactile Profile Avatar with Tune Icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _greetingText(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$userName 👋',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                        Tactile(
                          onTap: () => Navigator.push(
                            context,
                            SlideUpRoute(builder: (_) => const SettingsScreen()),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 17,
                                  backgroundColor: Palette.emerald,
                                  child: Text(
                                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.tune_rounded, size: 18),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Hardware "Tape Deck" Hero Card
                    Tactile(
                      onTap: () => Navigator.push(
                        context,
                        SlideUpRoute(builder: (_) => const RecorderScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: isDark ? Palette.emerald : Palette.ink,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: (isDark ? Palette.emerald : Palette.ink)
                                  .withValues(alpha: 0.24),
                              blurRadius: 28,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: const Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 3.5,
                                        backgroundColor: Palette.coral,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'STUDIO READY',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Animated mini equalizer
                                RepaintBoundary(
                                  child: AnimatedBuilder(
                                    animation: _eqCtrl,
                                    builder: (_, __) => Row(
                                      children: List.generate(5, (i) {
                                        final h = 6 +
                                            12 *
                                                (0.5 +
                                                    0.5 *
                                                        math.sin(
                                                          _eqCtrl.value * 2 * math.pi + i,
                                                        ));
                                        return Container(
                                          width: 3,
                                          height: h,
                                          margin: const EdgeInsets.only(left: 3),
                                          decoration: BoxDecoration(
                                            color: Palette.coral,
                                            borderRadius: BorderRadius.circular(9),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                _HeroMetric(
                                  label: 'SESSIONS',
                                  value: sessionCount,
                                ),
                                const SizedBox(width: 34),
                                _HeroMetric(
                                  label: 'CAPTURED',
                                  value: capturedDuration,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Tap to start bilingual recording',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_rounded,
                                      color: Palette.coral),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Horizontal Action Pill Strip
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _ActionPill(
                            icon: Icons.upload_file_rounded,
                            label: isUploading ? 'Transcribing...' : 'Upload Audio',
                            bg: tintBg,
                            onTap: isUploading
                                ? () {
                                    showUploadLiveTranscriptionModal(context);
                                  }
                                : () async {
                                    final chosenLang = await showLanguageSheet(
                                      context,
                                      config: config,
                                      currentCode: recordState.selectedLanguageCode,
                                      actionLabel: 'Select Audio File  →',
                                    );
                                    if (chosenLang != null && context.mounted) {
                                      final file = await ref
                                          .read(uploadNotifierProvider.notifier)
                                          .pickAudioFile();
                                      if (file != null && context.mounted) {
                                        showUploadLiveTranscriptionModal(context);
                                        ref
                                            .read(uploadNotifierProvider.notifier)
                                            .startTranscribingFile(file, chosenLang);
                                      }
                                    }
                                  },
                          ),
                          const SizedBox(width: 10),
                          _ActionPill(
                            icon: Icons.folder_copy_outlined,
                            label: 'All Files',
                            bg: tintBg,
                            onTap: () => Navigator.push(
                              context,
                              SlideUpRoute(builder: (_) => const SavedListScreen()),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _ActionPill(
                            icon: Icons.translate_rounded,
                            label: config
                                .findLanguage(recordState.selectedLanguageCode)
                                .displayName,
                            bg: tintBg,
                            onTap: () async {
                              final chosen = await showLanguageSheet(
                                context,
                                config: config,
                                currentCode: recordState.selectedLanguageCode,
                                actionLabel: 'Set Active Language  →',
                              );
                              if (chosen != null) {
                                ref
                                    .read(recordNotifierProvider.notifier)
                                    .setLanguage(chosen);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Timeline Journal Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Notes',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            SlideUpRoute(builder: (_) => const SavedListScreen()),
                          ),
                          child: Text(
                            'View all →',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Palette.coral : Palette.emerald,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Timeline Items
                    if (recentItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.graphic_eq_rounded,
                                size: 40,
                                color: Theme.of(context).hintColor.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'No recordings yet',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap the REC button below to start your first session.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).hintColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...recentItems.map((item) {
                        final formattedTime =
                            DateFormat('MMM d • h:mm a').format(item.createdAt).toUpperCase();
                        final durationStr =
                            '${(item.duration ~/ 60).toString().padLeft(2, '0')}:${(item.duration % 60).toString().padLeft(2, '0')}';
                        final langTag =
                            '${item.language.toUpperCase().substring(0, math.min(item.language.length, 2))} • $durationStr';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Tactile(
                            onTap: () => Navigator.push(
                              context,
                              SlideUpRoute(
                                builder: (_) => DetailsScreen(
                                  transcriptionId: item.transcriptionId,
                                ),
                              ),
                            ),
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
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          color: Theme.of(context).dividerColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).cardColor,
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(
                                          color: Theme.of(context).dividerColor,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                formattedTime,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.6,
                                                  color: Theme.of(context).hintColor,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: tintBg,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  langTag,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            item.title,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item.transcript.isEmpty
                                                ? 'No transcript text available'
                                                : item.transcript,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              height: 1.5,
                                              color: Theme.of(context).hintColor,
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
                      }),
                  ],
                );
              },
            ),
          ),

          // Floating Bottom Capsule Navigation Bar
          Positioned(
            left: 24,
            right: 24,
            bottom: 20,
            child: SafeArea(
              top: false,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    height: 68,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: (isDark ? Palette.charcoalCard : Palette.ink)
                          .withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.24),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.home_filled, color: Colors.white),
                        ),
                        Tactile(
                          onTap: () => Navigator.push(
                            context,
                            SlideUpRoute(builder: (_) => const RecorderScreen()),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 26,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Palette.coral,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.mic_rounded, color: Colors.white, size: 19),
                                SizedBox(width: 6),
                                Text(
                                  'REC',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.push(
                            context,
                            SlideUpRoute(builder: (_) => const SettingsScreen()),
                          ),
                          icon: const Icon(Icons.settings_outlined,
                              color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  const _HeroMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.60),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final VoidCallback onTap;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tactile(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}
