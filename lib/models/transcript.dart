import 'package:cloud_firestore/cloud_firestore.dart';

class TranscriptSegment {
  final double start;
  final double end;
  final String text;

  const TranscriptSegment({
    required this.start,
    required this.end,
    required this.text,
  });

  Map<String, dynamic> toMap() => {
        'start': start,
        'end': end,
        'text': text,
      };

  factory TranscriptSegment.fromMap(Map<String, dynamic> map) {
    return TranscriptSegment(
      start: (map['start'] as num?)?.toDouble() ?? 0.0,
      end: (map['end'] as num?)?.toDouble() ?? 0.0,
      text: map['text'] as String? ?? '',
    );
  }
}

class TranscriptionModel {
  final String transcriptionId;
  final String userId;
  final String title;
  final String transcript;
  final String language;
  final int duration; // in seconds
  final String? audioUrl;
  final String? audioLocalPath;
  final String? provider;
  final String? detectedLanguage;
  final int? segmentCount;
  final int? droppedSegmentCount;
  final List<TranscriptSegment>? segments;
  final DateTime createdAt;

  TranscriptionModel({
    required this.transcriptionId,
    required this.userId,
    required this.title,
    required this.transcript,
    required this.language,
    required this.duration,
    this.audioUrl,
    this.audioLocalPath,
    this.provider,
    this.detectedLanguage,
    this.segmentCount,
    this.droppedSegmentCount,
    this.segments,
    required this.createdAt,
  });

  // Convert model to Map for writing to Firestore (omits nulls)
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'transcriptionId': transcriptionId,
      'userId': userId,
      'title': title,
      'transcript': transcript,
      'language': language,
      'duration': duration,
      'createdAt': Timestamp.fromDate(createdAt),
    };

    if (audioUrl != null) {
      map['audioUrl'] = audioUrl;
    }
    if (audioLocalPath != null) {
      map['audioLocalPath'] = audioLocalPath;
    }
    if (provider != null) {
      map['provider'] = provider;
    }
    if (detectedLanguage != null) {
      map['detectedLanguage'] = detectedLanguage;
    }
    if (segmentCount != null) {
      map['segmentCount'] = segmentCount;
    }
    if (droppedSegmentCount != null) {
      map['droppedSegmentCount'] = droppedSegmentCount;
    }
    if (segments != null && segments!.isNotEmpty) {
      map['segments'] = segments!.map((s) => s.toMap()).toList();
    }

    return map;
  }

  // Create model from Firestore Map
  factory TranscriptionModel.fromMap(Map<String, dynamic> map) {
    List<TranscriptSegment>? parsedSegments;
    if (map['segments'] is List) {
      parsedSegments = (map['segments'] as List)
          .whereType<Map<String, dynamic>>()
          .map((s) => TranscriptSegment.fromMap(s))
          .toList();
    }

    return TranscriptionModel(
      transcriptionId: map['transcriptionId'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      transcript: map['transcript'] ?? '',
      language: map['language'] ?? 'Bilingual',
      duration: map['duration'] ?? 0,
      audioUrl: map['audioUrl'],
      audioLocalPath: map['audioLocalPath'],
      provider: map['provider'],
      detectedLanguage: map['detectedLanguage'],
      segmentCount:
          (map['segmentCount'] as num?)?.toInt() ?? parsedSegments?.length,
      droppedSegmentCount: (map['droppedSegmentCount'] as num?)?.toInt(),
      segments: parsedSegments,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Create model from DocumentSnapshot
  factory TranscriptionModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    List<TranscriptSegment>? parsedSegments;
    if (data['segments'] is List) {
      parsedSegments = (data['segments'] as List)
          .whereType<Map<String, dynamic>>()
          .map((s) => TranscriptSegment.fromMap(s))
          .toList();
    }

    return TranscriptionModel(
      transcriptionId: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      transcript: data['transcript'] ?? '',
      language: data['language'] ?? 'Bilingual',
      duration: data['duration'] ?? 0,
      audioUrl: data['audioUrl'],
      audioLocalPath: data['audioLocalPath'],
      provider: data['provider'],
      detectedLanguage: data['detectedLanguage'],
      segmentCount:
          (data['segmentCount'] as num?)?.toInt() ?? parsedSegments?.length,
      droppedSegmentCount: (data['droppedSegmentCount'] as num?)?.toInt(),
      segments: parsedSegments,
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
    String? audioLocalPath,
    String? provider,
    String? detectedLanguage,
    int? segmentCount,
    int? droppedSegmentCount,
    List<TranscriptSegment>? segments,
  }) {
    return TranscriptionModel(
      transcriptionId: transcriptionId,
      userId: userId,
      title: title ?? this.title,
      transcript: transcript ?? this.transcript,
      language: language ?? this.language,
      duration: duration ?? this.duration,
      audioUrl: audioUrl ?? this.audioUrl,
      audioLocalPath: audioLocalPath ?? this.audioLocalPath,
      provider: provider ?? this.provider,
      detectedLanguage: detectedLanguage ?? this.detectedLanguage,
      segmentCount: segmentCount ?? this.segmentCount,
      droppedSegmentCount: droppedSegmentCount ?? this.droppedSegmentCount,
      segments: segments ?? this.segments,
      createdAt: createdAt,
    );
  }
}
