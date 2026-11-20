import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/transcript.dart';
import '../core/constants/app_constants.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Constructor - Enable offline caching support
  FirestoreService() {
    // Apply settings asynchronously to avoid issues if Firebase isn't fully
    // initialized at the time this service is constructed (some platforms
    // initialize Firebase later). Any failure is logged but does not crash
    // the app; Firestore will use default settings instead.
    Future.microtask(() async {
      try {
        _firestore.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      } catch (e) {
        debugPrint('Firestore settings could not be applied: $e');
      }
    });
  }

  // 1. Create - Save a new transcription document
  Future<void> saveTranscription(TranscriptionModel transcription) async {
    try {
      await _firestore
          .collection(AppConstants.collectionTranscriptions)
          .doc(transcription.transcriptionId)
          .set(transcription.toMap());
    } catch (e) {
      throw Exception('Failed to save transcription: $e');
    }
  }

  // 2. Read - Get a real-time stream of transcriptions for the current user
  Stream<List<TranscriptionModel>> getUserTranscriptionsStream(String userId) {
    return _firestore
        .collection(AppConstants.collectionTranscriptions)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final transcriptions = snapshot.docs
          .map((doc) => TranscriptionModel.fromDocument(doc))
          .toList();

      // Sort locally by creation time to avoid requiring a composite index.
      transcriptions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return transcriptions;
    });
  }

  // 3. Read - Retrieve a single transcription by ID
  Future<TranscriptionModel?> getTranscriptionById(String transcriptionId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.collectionTranscriptions)
          .doc(transcriptionId)
          .get();
      if (doc.exists) {
        return TranscriptionModel.fromDocument(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get transcription details: $e');
    }
  }

  // 4. Update - Edit an existing transcript or details (e.g. title, text, language)
  Future<void> updateTranscription(TranscriptionModel transcription) async {
    try {
      await _firestore
          .collection(AppConstants.collectionTranscriptions)
          .doc(transcription.transcriptionId)
          .update(transcription.toMap());
    } catch (e) {
      throw Exception('Failed to update transcription: $e');
    }
  }

  // 5. Delete - Remove a transcription document
  Future<void> deleteTranscription(String transcriptionId) async {
    try {
      await _firestore
          .collection(AppConstants.collectionTranscriptions)
          .doc(transcriptionId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete transcription: $e');
    }
  }

  // 6. Search - Filter transcriptions by query (Local filter on streams is usually better,
  // but we can query Firestore directly for larger datasets. We will do local searching in Riverpod).
}
