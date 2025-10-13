import 'dart:io';
import 'dart:convert';
import 'package:archive/archive_io.dart';
import 'package:xml/xml.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Utility to extract plain text from common document formats.
/// Currently supports: .txt, .docx, .pdf
/// Returns null if extraction failed or unsupported.
class FileTextExtractor {
  /// Extract text from a local File.
  static Future<String?> extractText(File file) async {
    final path = file.path.toLowerCase();
    if (path.endsWith('.txt')) {
      try {
        return await file.readAsString();
      } catch (_) {
        return null;
      }
    }

    if (path.endsWith('.docx')) {
      try {
        // Read bytes and decode archive
        final bytes = await file.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        // find document.xml inside word/
        ArchiveFile? docEntry;
        for (final f in archive.files) {
          if (f.name.toLowerCase().endsWith('word/document.xml')) {
            docEntry = f;
            break;
          }
        }
        if (docEntry == null) return null;
        final docBytes = docEntry.content as List<int>;
        final xmlStr = utf8.decode(docBytes);
        final xmlDoc = XmlDocument.parse(xmlStr);
        final buffer = StringBuffer();
        // text nodes are in w:t
        final texts = xmlDoc.findAllElements('t');
        for (final node in texts) {
          buffer.write(node.text);
          buffer.write(' ');
        }
        return buffer.toString().trim();
      } catch (e, st) {
        // Diagnostic logging for native extraction failures
        try {
          // use stdout prints which will appear in flutter run logs
          // include stacktrace for deeper debugging
          // ignore: avoid_print
          print('FileTextExtractor: docx extraction error for ${file.path}: $e');
          // ignore: avoid_print
          print(st);
        } catch (_) {}
        return null;
      }
    }

    if (path.endsWith('.pdf')) {
      try {
        final bytes = await file.readAsBytes();
        final pdfDoc = PdfDocument(inputBytes: bytes);
        final buffer = StringBuffer();
        final extractor = PdfTextExtractor(pdfDoc);
        for (int i = 0; i < pdfDoc.pages.count; i++) {
          final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
          buffer.writeln(pageText);
        }
        pdfDoc.dispose();
        final t = buffer.toString().trim();
        return t.isEmpty ? null : t;
      } catch (e, st) {
        try {
          print('FileTextExtractor: pdf extraction error for ${file.path}: $e');
          print(st);
        } catch (_) {}
        return null;
      }
    }

    return null;
  }
}
