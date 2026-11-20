import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transcript.dart';
import 'auth_provider.dart';
import 'record_provider.dart';

// Search keyword state provider
final searchFilterProvider = StateProvider<String>((ref) => '');

// Base raw stream of transcriptions from firestore
final rawTranscriptionsStreamProvider = StreamProvider<List<TranscriptionModel>>((ref) {
  final authState = ref.watch(authStateProvider).value;
  if (authState != null) {
    return ref.watch(firestoreServiceProvider).getUserTranscriptionsStream(authState.uid);
  }
  return const Stream.empty();
});

// Search-filtered list provider
final filteredTranscriptionsProvider = Provider<AsyncValue<List<TranscriptionModel>>>((ref) {
  final streamValue = ref.watch(rawTranscriptionsStreamProvider);
  final searchQuery = ref.watch(searchFilterProvider).trim().toLowerCase();

  return streamValue.when(
    data: (transcripts) {
      if (searchQuery.isEmpty) {
        return AsyncValue.data(transcripts);
      }
      // Filter list locally based on title or transcript text matching query
      final filtered = transcripts.where((item) {
        final titleMatch = item.title.toLowerCase().contains(searchQuery);
        final textMatch = item.transcript.toLowerCase().contains(searchQuery);
        return titleMatch || textMatch;
      }).toList();
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});
