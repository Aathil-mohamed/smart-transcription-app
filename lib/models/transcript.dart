import 'package:cloud_firestore/cloud_firestore.dart';

class TranscriptionModel {
  final String transcriptionId;
  final String userId;
  final String title;
  final String transcript;
  final String language;
  final int duration; // in seconds
  final String? audioUrl;
  final DateTime createdAt;

  TranscriptionModel({
    required this.transcriptionId,
    required this.userId,
    required this.title,
    required this.transcript,
    required this.language,
    required this.duration,
    this.audioUrl,
    required this.createdAt,
  });

  // Convert model to Map for writing to Firestore
  Map<String, dynamic> toMap() {
    return {
      'transcriptionId': transcriptionId,
      'userId': userId,
      'title': title,
      'transcript': transcript,
      'language': language,
      'duration': duration,
      'audioUrl': audioUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create model from Firestore Map
  factory TranscriptionModel.fromMap(Map<String, dynamic> map) {
    return TranscriptionModel(
      transcriptionId: map['transcriptionId'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      transcript: map['transcript'] ?? '',
      language: map['language'] ?? 'Bilingual',
      duration: map['duration'] ?? 0,
      audioUrl: map['audioUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Create model from DocumentSnapshot
  factory TranscriptionModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TranscriptionModel(
      transcriptionId: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      transcript: data['transcript'] ?? '',
      language: data['language'] ?? 'Bilingual',
      duration: data['duration'] ?? 0,
      audioUrl: data['audioUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Create a copy of the model with modified values
  TranscriptionModel copyWith({
    String? title,
    String? transcript,
    String? language,
    int? duration,
    String? audioUrl,
  }) {
    return TranscriptionModel(
      transcriptionId: transcriptionId,
      userId: userId,
      title: title ?? this.title,
      transcript: transcript ?? this.transcript,
      language: language ?? this.language,
      duration: duration ?? this.duration,
      audioUrl: audioUrl ?? this.audioUrl,
      createdAt: createdAt,
    );
  }
}
