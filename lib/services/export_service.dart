import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/transcript.dart';
import '../models/export.dart';
import '../core/config/app_config.dart';
import '../core/errors/service_error.dart';

class ExportService {
  final AppConfig _config;
  final FirebaseStorage _storage;
  final FirebaseFirestore _firestore;

  ExportService(
    this._config, {
    FirebaseStorage? storage,
    FirebaseFirestore? firestore,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  // 1. Generate Plain Text File (.txt)
  Future<File> generateTxt(TranscriptionModel transcription) async {
    final String cleanTitle = transcription.title.replaceAll(RegExp(r'[^\w\s\-]'), '_');
    final directory = await getTemporaryDirectory();
    final filePath = p.join(directory.path, '$cleanTitle.txt');
    final file = File(filePath);

    final String content = '''
TITLE: ${transcription.title}
DATE: ${transcription.createdAt.toString()}
LANGUAGE: ${transcription.language}
DURATION: ${transcription.duration} seconds

----------------------------------------
TRANSCRIPT:
----------------------------------------
${transcription.transcript}
''';

    return await file.writeAsString(content);
  }

  // 2. Generate PDF File (.pdf)
  Future<File> generatePdf(TranscriptionModel transcription) async {
    final pdf = pw.Document();
    final String cleanTitle = transcription.title.replaceAll(RegExp(r'[^\w\s\-]'), '_');
    final directory = await getTemporaryDirectory();
    final filePath = p.join(directory.path, '$cleanTitle.pdf');

    // Tamil Unicode Font Support:
    pw.Font? tamilFont;
    try {
      final fontUrl = _config.export.pdfFontUrl;
      final response = await http.get(Uri.parse(fontUrl));
      if (response.statusCode == 200) {
        tamilFont = pw.Font.ttf(ByteData.view(response.bodyBytes.buffer));
      }
    } catch (e) {
      debugPrint("Warning: Failed to load Tamil font, falling back: $e");
    }

    final pw.Font fallbackFont = pw.Font.helvetica();
    final pw.TextStyle textStyle = pw.TextStyle(
      font: tamilFont ?? fallbackFont,
      fontSize: 12,
      lineSpacing: 4,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Document Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Smart Transcription System', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.Text(transcription.createdAt.toString().split(' ')[0], style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Transcription Title
            pw.Text(
              transcription.title,
              style: pw.TextStyle(
                font: tamilFont ?? fallbackFont,
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.indigo800,
              ),
            ),
            pw.SizedBox(height: 10),

            // Metadata Row
            pw.Row(
              children: [
                pw.Text('Language: ${transcription.language}  |  ', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
                pw.Text('Duration: ${transcription.duration}s', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 20),

            // Body Content
            pw.Paragraph(
              text: transcription.transcript,
              style: textStyle,
            ),
          ];
        },
      ),
    );

    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // 3. Generate Word Document (.doc / .docx representation)
  Future<File> generateDocx(TranscriptionModel transcription) async {
    final String cleanTitle = transcription.title.replaceAll(RegExp(r'[^\w\s\-]'), '_');
    final directory = await getTemporaryDirectory();
    final filePath = p.join(directory.path, '$cleanTitle.doc');
    final file = File(filePath);

    // RTF Document Structure with Unicode support
    const rtfHeader = r'{\rtf1\ansi\deff0 {\fonttbl {\f0\fnil\fcharset0 Arial;}{\f1\fnil\fcharset0 Noto Sans Tamil;}}\viewkind4\uc1\pard\lang1033';
    final rtfTitle = '\\f0\\fs40\\b ${transcription.title}\\b0\\fs24\\par\\par';
    final rtfMeta = '\\f0\\fs20\\i Language: ${transcription.language} | Duration: ${transcription.duration}s\\i0\\fs24\\par\\par';
    
    final String bodyText = transcription.transcript;
    final StringBuffer rtfBody = StringBuffer();
    for (int i = 0; i < bodyText.length; i++) {
      int charCode = bodyText.codeUnitAt(i);
      if (charCode > 127) {
        rtfBody.write('\\u$charCode?');
      } else {
        rtfBody.write(bodyText[i]);
      }
    }

    final String rtfContent = '$rtfHeader$rtfTitle$rtfMeta\\f1 ${rtfBody.toString()}\\par}';

    return await file.writeAsString(rtfContent);
  }

  // 4. Upload exported file to Firebase Storage & Register in Firestore
  Future<String> uploadExportToStorage({
    required File file,
    required String transcriptionId,
    required String userId,
    required String fileType,
  }) async {
    try {
      final fileName = p.basename(file.path);
      final storagePath = _config.storage.buildExportPath(
        userId: userId,
        transcriptionId: transcriptionId,
        fileName: fileName,
      );
      
      // 1. Upload to Firebase Storage
      final ref = _storage.ref().child(storagePath);
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // 2. Log in Firestore Exports collection
      final exportId = _firestore.collection(_config.firestore.collectionExports).doc().id;
      final exportModel = ExportModel(
        exportId: exportId,
        transcriptionId: transcriptionId,
        userId: userId,
        fileType: fileType,
        fileUrl: downloadUrl,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(_config.firestore.collectionExports)
          .doc(exportId)
          .set(exportModel.toMap());

      return downloadUrl;
    } catch (e) {
      throw DataException('uploadExportToStorage', e);
    }
  }

  // 5. Trigger Native Share Sheet
  Future<void> shareFile(File file, String subject) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: subject,
        ),
      );
    } catch (e) {
      throw ServiceException(ServiceErrorCode.unknown, 'Failed to share file: $e');
    }
  }
}
