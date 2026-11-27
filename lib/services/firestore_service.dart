import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transcript.dart';
import '../core/config/app_config.dart';
import '../core/errors/service_error.dart';

class FirestoreService {
  final AppConfig _config;
  final FirebaseFirestore _firestore;

  FirestoreService(this._config, [FirebaseFirestore? firestore])
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // 1. Create - Save a new transcription document
  Future<void> saveTranscription(TranscriptionModel transcription) async {
    try {
      await _firestore
          .collection(_config.firestore.collectionTranscriptions)
          .doc(transcription.transcriptionId)
          .set(transcription.toMap());
    } catch (e) {
      throw DataException('saveTranscription', e);
    }
  }

  // 2. Read - Get a real-time stream of transcriptions for the current user
  Stream<List<TranscriptionModel>> getUserTranscriptionsStream(String userId) {
    return _firestore
        .collection(_config.firestore.collectionTranscriptions)
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
  Future<TranscriptionModel?> getTranscriptionById(
      String transcriptionId) async {
    try {
      final doc = await _firestore
          .collection(_config.firestore.collectionTranscriptions)
          .doc(transcriptionId)
          .get();
      if (doc.exists) {
        return TranscriptionModel.fromDocument(doc);
      }
      return null;
    } catch (e) {
      throw DataException('getTranscriptionById', e);
    }
  }

  // 4. Update - Edit an existing transcript or details (e.g. title, text, language)
  Future<void> updateTranscription(TranscriptionModel transcription) async {
    try {
      await _firestore
          .collection(_config.firestore.collectionTranscriptions)
          .doc(transcription.transcriptionId)
          .update(transcription.toMap());
    } catch (e) {
      throw DataException('updateTranscription', e);
    }
  }

  // 5. Delete - Remove a transcription document and clean up local audio file
  Future<void> deleteTranscription(String transcriptionId) async {
    try {
      final doc = await getTranscriptionById(transcriptionId);
      if (doc?.audioLocalPath != null) {
        try {
          final file = File(doc!.audioLocalPath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint(
              'Failed to delete local audio file for $transcriptionId: $e');
        }
      }

      await _firestore
          .collection(_config.firestore.collectionTranscriptions)
          .doc(transcriptionId)
          .delete();
    } catch (e) {
      throw DataException('deleteTranscription', e);
    }
  }
}
