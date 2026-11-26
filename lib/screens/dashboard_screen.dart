import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../providers/auth_provider.dart';
import '../providers/history_provider.dart';
import '../providers/record_provider.dart';
import '../providers/upload_provider.dart';
import 'recorder_screen.dart';
import 'saved_list_screen.dart';
import 'details_screen.dart';
import 'settings_screen.dart';
import '../providers/theme_provider.dart';
import '../widgets/transcript_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userDetails = ref.watch(userDetailsProvider);
    final transcriptionsAsync = ref.watch(rawTranscriptionsStreamProvider);
    final uploadState = ref.watch(uploadNotifierProvider);
    final isLoading = uploadState.status == UploadStatus.picking ||
                      uploadState.status == UploadStatus.transcribing ||
                      uploadState.status == UploadStatus.saving;

    ref.listen<UploadState>(uploadNotifierProvider, (previous, next) {
      if (next.status == UploadStatus.success && next.transcriptionId != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DetailsScreen(transcriptionId: next.transcriptionId!),
          ),
        ).then((_) {
          ref.read(uploadNotifierProvider.notifier).reset();
        });
      } else if (next.status == UploadStatus.error && next.errorMessage != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.redAccent),
                SizedBox(width: 8),
                Text('Upload Error'),
              ],
            ),
            content: Text(next.errorMessage!),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                  ref.read(uploadNotifierProvider.notifier).reset();
                },
              ),
            ],
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async => ref.refresh(rawTranscriptionsStreamProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // User Welcoming Header
              userDetails.when(
                data: (user) => Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                      child: Text(
                        user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U',
                        style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${user?.name ?? "User"} 👋',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Ready to transcribe some speech?',
                          style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ],
                ),
                loading: () => const LinearProgressIndicator(),
                error: (err, stack) => const Text('Error loading user profile'),
              ),
               // API Key Warning Banner
               FutureBuilder<String>(
                 future: ref.read(themeNotifierProvider.notifier).getCustomApiKey(),
                 builder: (context, snapshot) {
                   if (snapshot.connectionState != ConnectionState.done) {
                     return const SizedBox.shrink();
                   }
                   final key = snapshot.data ?? '';
                   final isValid = key.isNotEmpty;
                   if (isValid) return const SizedBox.shrink();

                   return Container(
                     margin: const EdgeInsets.only(top: 24),
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(
                       gradient: LinearGradient(
                         colors: [
                           theme.brightness == Brightness.dark 
                               ? Colors.amber.withValues(alpha: 0.15) 
                               : Colors.amber.shade50,
                           theme.brightness == Brightness.dark 
                               ? Colors.orange.withValues(alpha: 0.1) 
                               : Colors.orange.shade50,
                         ],
                       ),
                       borderRadius: BorderRadius.circular(20),
                       border: Border.all(
                         color: Colors.amber.withValues(alpha: 0.3),
                         width: 1,
                       ),
                     ),
                     child: Row(
                       children: [
                         CircleAvatar(
                           backgroundColor: Colors.amber.withValues(alpha: 0.2),
                           child: const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                         ),
                         const SizedBox(width: 16),
                         Expanded(
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text(
                                 'Groq API Key Missing',
                                 style: TextStyle(
                                   fontWeight: FontWeight.bold,
                                   fontSize: 15,
                                   color: theme.brightness == Brightness.dark ? Colors.amber : Colors.orange.shade900,
                                 ),
                               ),
                               const SizedBox(height: 4),
                               Text(
                                 'Configure your Groq key in Settings to unlock exact Whisper AI transcription.',
                                 style: TextStyle(
                                   fontSize: 12,
                                   color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                 ),
                               ),
                             ],
                           ),
                         ),
                         const SizedBox(width: 8),
                         ElevatedButton(
                           style: ElevatedButton.styleFrom(
                             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                             backgroundColor: theme.colorScheme.primary,
                             foregroundColor: Colors.white,
                             elevation: 0,
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                           ),
                           onPressed: () => Navigator.of(context).push(
                             MaterialPageRoute(builder: (_) => const SettingsScreen()),
                           ),
                           child: const Text('SET KEY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                         ),
                       ],
                     ),
                   );
                 },
               ),
              const SizedBox(height: 28),

              // Statistics Block
              transcriptionsAsync.when(
                data: (list) {
                  // Compute stats
                  final totalCount = list.length;
                  int totalSecs = 0;
                  for (var item in list) {
                    totalSecs += item.duration;
                  }
                  final hours = totalSecs ~/ 3600;
                  final minutes = (totalSecs % 3600) ~/ 60;
                  final durationText = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m ${totalSecs % 60}s';

                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context: context,
                          title: 'Total Sessions',
                          value: totalCount.toString(),
                          icon: Icons.list_alt,
                          cardColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                          iconColor: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          context: context,
                          title: 'Transcribed',
                          value: durationText,
                          icon: Icons.mic_none,
                          cardColor: theme.colorScheme.secondary.withValues(alpha: 0.1),
                          iconColor: theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
                error: (err, stack) => Container(),
              ),
              const SizedBox(height: 28),

              // Quick Actions
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildQuickActionBtn(
                        context: context,
                        label: 'New Recording',
                        icon: Icons.add_circle,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const RecorderScreen()),
                        ),
                        color: theme.colorScheme.primary,
                      ),
                      _buildQuickActionBtn(
                        context: context,
                        label: 'Upload Audio',
                        icon: Icons.cloud_upload,
                        onPressed: () => _showLanguageSelectionDialog(context, ref),
                        color: theme.colorScheme.secondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildQuickActionBtn(
                    context: context,
                    label: 'All Files',
                    icon: Icons.folder_copy,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const SavedListScreen()),
                    ),
                    color: theme.colorScheme.primary,
                    isFullWidth: true,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Recent Transcriptions Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Transcriptions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const SavedListScreen()),
                    ),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Recent List
              transcriptionsAsync.when(
                data: (list) {
                  if (list.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(40),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(Icons.mic_off, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text(
                            'No transcriptions saved yet.',
                            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                          ),
                        ],
                      ),
                    );
                  }

                  // Take only the 3 most recent entries
                  final recentList = list.take(3).toList();
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentList.length,
                    itemBuilder: (context, index) {
                      final item = recentList[index];
                      return TranscriptCard(
                        transcription: item,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => DetailsScreen(transcriptionId: item.transcriptionId),
                          ),
                        ),
                        onDelete: () => _confirmDelete(context, ref, item.transcriptionId),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text('Error loading files: $err'),
              ),
            ],
          ),
        ),
      ),
          if (isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 20),
                          Text(
                            uploadState.progressText,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please do not close the app.',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const RecorderScreen()),
        ),
        icon: const Icon(Icons.mic),
        label: const Text('Start Recording'),
      ),
    );
  }

  // Stat Card Widget
  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color cardColor,
    required Color iconColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            iconColor.withValues(alpha: 0.15),
            iconColor.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: iconColor.withValues(alpha: 0.12), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              CircleAvatar(
                radius: 14,
                backgroundColor: iconColor.withValues(alpha: 0.1),
                child: Icon(icon, color: iconColor, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }

  // Quick Action Button
  Widget _buildQuickActionBtn({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    bool isFullWidth = false,
  }) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final width = isFullWidth ? (size.width - 40) : (size.width - 56) / 2;

    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.1),
            color.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: isFullWidth ? 18 : 24, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          side: BorderSide(color: color.withValues(alpha: 0.15), width: 1.5),
          backgroundColor: Colors.transparent,
        ),
        onPressed: onPressed,
        child: isFullWidth
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.2),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(icon, size: 28, color: color),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.2),
                  ),
                ],
              ),
      ),
    );
  }

  // Language Selection Dialog
  Future<void> _showLanguageSelectionDialog(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    String selectedLang = 'bilingual'; // default

    final action = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Audio Language'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Choose the language model for transcription:',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedLang,
                        isExpanded: true,
                        dropdownColor: theme.colorScheme.surface,
                        items: ref.watch(appConfigProvider).languages.map((lang) {
                          return DropdownMenuItem<String>(
                            value: lang.code,
                            child: Text(lang.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => selectedLang = val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('CANCEL'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: const Text('SELECT FILE'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        );
      },
    );

    if (action == true) {
      // Trigger picking and transcribing with selected language
      await ref.read(uploadNotifierProvider.notifier).pickAndTranscribeAudio(selectedLang);
    }
  }

  // Delete confirmation
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transcription'),
        content: const Text('Are you sure you want to permanently delete this transcription?'),
        actions: [
          TextButton(
            child: const Text('CANCEL'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(firestoreServiceProvider).deleteTranscription(id);
    }
  }
}
