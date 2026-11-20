import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/history_provider.dart';
import '../providers/record_provider.dart';
import 'details_screen.dart';
import '../widgets/transcript_card.dart';

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
      appBar: AppBar(
        title: const Text('Saved Transcriptions'),
      ),
      body: Column(
        children: [
          // Premium Search Input Field
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search title or transcription text...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchFilterProvider.notifier).state = '';
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                ref.read(searchFilterProvider.notifier).state = value;
                setState(() {}); // refresh close icon status
              },
            ),
          ),

          // Transcriptions List View
          Expanded(
            child: transcriptionsAsync.when(
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? 'No saved transcriptions yet'
                              : 'No matches found',
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
              error: (err, stack) => Center(
                child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Confirm delete dialog
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
