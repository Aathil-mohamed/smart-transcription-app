import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_design_tokens.dart';
import '../core/theme/motion_helpers.dart';
import '../providers/history_provider.dart';
import '../providers/record_provider.dart';
import '../widgets/transcript_card.dart';
import 'details_screen.dart';

class SavedListScreen extends ConsumerStatefulWidget {
  const SavedListScreen({super.key});

  @override
  ConsumerState<SavedListScreen> createState() => _SavedListScreenState();
}

class _SavedListScreenState extends ConsumerState<SavedListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transcriptionsAsync = ref.watch(filteredTranscriptionsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header: Tactile Back Pill + Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
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
                    'All Recordings',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
              child: TextFormField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search title or transcription text...',
                  filled: true,
                  fillColor: theme.cardColor,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(searchFilterProvider.notifier).state = '';
                            setState(() {});
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  ref.read(searchFilterProvider.notifier).state = value;
                  setState(() {});
                },
              ),
            ),

            // Transcriptions List
            Expanded(
              child: transcriptionsAsync.when(
                data: (list) {
                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 54,
                            color: theme.hintColor.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchController.text.isEmpty
                                ? 'No saved recordings yet'
                                : 'No matching notes found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return TranscriptCard(
                        transcription: item,
                        onTap: () => Navigator.push(
                          context,
                          SlideUpRoute(
                            builder: (context) => DetailsScreen(
                              transcriptionId: item.transcriptionId,
                            ),
                          ),
                        ),
                        onDelete: () =>
                            _confirmDelete(context, ref, item.transcriptionId),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Palette.coral),
                ),
                error: (err, stack) => Center(
                  child: Text(
                    'Error: $err',
                    style: const TextStyle(color: Palette.coral),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Transcription?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Are you sure you want to permanently delete this transcription note?',
        ),
        actions: [
          TextButton(
            child: const Text('CANCEL',
                style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text('DELETE',
                style: TextStyle(
                    color: Palette.coral, fontWeight: FontWeight.w700)),
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
