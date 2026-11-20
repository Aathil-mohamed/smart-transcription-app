import 'package:cloud_firestore/cloud_firestore.dart';

class ExportModel {
  final String exportId;
  final String transcriptionId;
  final String userId;
  final String fileType; // 'pdf', 'docx', 'txt'
  final String fileUrl; // Firebase Storage URL
  final DateTime createdAt;

  ExportModel({
    required this.exportId,
    required this.transcriptionId,
    required this.userId,
    required this.fileType,
    required this.fileUrl,
    required this.createdAt,
  });

  // Convert to Map for Firestore writes
  Map<String, dynamic> toMap() {
    return {
      'exportId': exportId,
      'transcriptionId': transcriptionId,
      'userId': userId,
      'fileType': fileType,
      'fileUrl': fileUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create from Map
  factory ExportModel.fromMap(Map<String, dynamic> map) {
    return ExportModel(
      exportId: map['exportId'] ?? '',
      transcriptionId: map['transcriptionId'] ?? '',
      userId: map['userId'] ?? '',
      fileType: map['fileType'] ?? '',
      fileUrl: map['fileUrl'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Create from DocumentSnapshot
  factory ExportModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ExportModel(
      exportId: doc.id,
      transcriptionId: data['transcriptionId'] ?? '',
      userId: data['userId'] ?? '',
      fileType: data['fileType'] ?? '',
      fileUrl: data['fileUrl'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
