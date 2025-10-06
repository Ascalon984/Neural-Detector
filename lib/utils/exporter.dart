import 'dart:io' show File, Platform;
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'settings_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional import: use the web implementation when dart:html is available,
// otherwise fall back to a non-web stub that does nothing.
import 'exporter_stub.dart' if (dart.library.html) 'exporter_web.dart' as web_export;
// ...existing code...

class Exporter {
  // Header as requested by the user. Localized labels applied here based on language.
  static List<String> headers({String? langCode}) {
    final code = langCode ?? SettingsManager.currentLanguage;
    if (code == 'id') {
      return [
        'No.',
        'Nama Berkas',
        'Tanggal',
        'Ukuran (KB)',
        'AI (%)',
        'Human (%)',
        'Backend',
        'Bahasa',
        'Catatan',
      ];
    }
    return [
      'No.',
      'Filename',
      'Date',
      'Size (KB)',
      'AI (%)',
      'Human (%)',
      'Backend',
      'Language',
      'Notes',
    ];
  }

  // Generate CSV content from history entries. historyEntries should be a list
  // of maps or objects convertible to the expected columns. We'll accept a
  // list of maps with keys matching: filename, date (DateTime), sizeBytes,
  // aiScore (0..1), backend, language, notes
  static String generateCsv(List<Map<String, dynamic>> rows) {
  final csvRows = <List<dynamic>>[];
  csvRows.add(headers(langCode: SettingsManager.currentLanguage));

    final df = DateFormat('yyyy-MM-dd HH:mm:ss');

    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final date = r['date'] is DateTime ? df.format(r['date']) : r['date']?.toString() ?? '';
      final sizeKb = r['sizeBytes'] != null ? (r['sizeBytes'] / 1024).toStringAsFixed(0) : '';
      final aiPct = r['aiScore'] != null ? (r['aiScore'] * 100).toStringAsFixed(2) : '';
      final humanPct = (r['aiScore'] != null) ? (100 - (r['aiScore'] * 100)).toStringAsFixed(2) : '';
      csvRows.add([
        i + 1,
        r['filename'] ?? '',
        date,
        sizeKb,
        aiPct,
        humanPct,
        r['backend'] ?? '',
        r['language'] ?? '',
        r['notes'] ?? '',
      ]);
    }

    return const ListToCsvConverter().convert(csvRows);
  }

  // Write an XLSX file using excel package
  static List<int> generateXlsxBytes(List<Map<String, dynamic>> rows) {
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];

  sheet.appendRow(headers(langCode: SettingsManager.currentLanguage));

    final df = DateFormat('yyyy-MM-dd HH:mm:ss');

    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final date = r['date'] is DateTime ? df.format(r['date']) : r['date']?.toString() ?? '';
      final sizeKb = r['sizeBytes'] != null ? (r['sizeBytes'] / 1024).toStringAsFixed(0) : '';
      final aiPct = r['aiScore'] != null ? (r['aiScore'] * 100).toStringAsFixed(2) : '';
      final humanPct = (r['aiScore'] != null) ? (100 - (r['aiScore'] * 100)).toStringAsFixed(2) : '';

      sheet.appendRow([
        i + 1,
        r['filename'] ?? '',
        date,
        sizeKb,
        aiPct,
        humanPct,
        r['backend'] ?? '',
        r['language'] ?? '',
        r['notes'] ?? '',
      ]);
    }

    final bytes = excel.encode();
    return bytes ?? <int>[];
  }

  // Prompt the user to select a destination folder and save both CSV and XLSX there.
  // Returns the path to the saved CSV file on success, or null on cancel/failure.
  static Future<String?> exportToFolder(List<Map<String, dynamic>> rows, {String? suggestedName}) async {
    // Web: browsers cannot write to arbitrary local folders. Instead trigger a
    // download for both CSV and XLSX.
    final baseName = suggestedName ?? 'scan_history_${DateTime.now().millisecondsSinceEpoch}';
    final csvContent = generateCsv(rows);
    final xlsxBytes = generateXlsxBytes(rows);

    if (kIsWeb) {
      // Trigger downloads in browser
      try {
        final csvBytes = Uint8List.fromList(csvContent.codeUnits);
        await web_export.saveBytesAsFile(csvBytes, '$baseName.csv');
        if (xlsxBytes.isNotEmpty) {
          await web_export.saveBytesAsFile(Uint8List.fromList(xlsxBytes), '$baseName.xlsx');
        }
        return baseName; // return base name as a 'path' indicator
      } catch (e) {
        return null;
      }
    }

    // Non-web: Let user pick a directory. file_picker supports directory picking on many platforms.
    String? selectedDirectory;
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      selectedDirectory = result;
    } catch (e) {
      selectedDirectory = null;
    }

    if (selectedDirectory == null) return null;

    final csvPath = p.join(selectedDirectory, '$baseName.csv');
    final csvFile = File(csvPath);
    await csvFile.writeAsString(csvContent, flush: true);

    if (xlsxBytes.isNotEmpty) {
      final xlsxPath = p.join(selectedDirectory, '$baseName.xlsx');
      final xlsxFile = File(xlsxPath);
      await xlsxFile.writeAsBytes(xlsxBytes, flush: true);
    }

    return csvPath;
  }

  static const MethodChannel _channel = MethodChannel('ai_text_checker/saveFileToDownloads');

  // Robust save that prefers platform channel on Android to write to Downloads.
  static Future<String?> saveToDownloadsFallback(List<Map<String, dynamic>> rows, {String? suggestedName}) async {
    final xlsxBytes = generateXlsxBytes(rows);
    final csvContent = generateCsv(rows);
    final baseName = suggestedName ?? 'scan_history_${DateTime.now().millisecondsSinceEpoch}';
    // If running on web, trigger downloads
    if (kIsWeb) {
      try {
        final csvBytes = Uint8List.fromList(csvContent.codeUnits);
        await web_export.saveBytesAsFile(csvBytes, '$baseName.csv');
        if (xlsxBytes.isNotEmpty) {
          await web_export.saveBytesAsFile(Uint8List.fromList(xlsxBytes), '$baseName.xlsx');
        }
        return baseName;
      } catch (_) {
        // fall through
      }
    }

    // Try Android platform channel first
    try {
      final isAndroid = Platform.isAndroid;
      if (isAndroid) {
        // Save CSV
        final csvBytes = Uint8List.fromList(csvContent.codeUnits);
        final csvResult = await _channel.invokeMethod('saveFile', {
          'filename': '$baseName.csv',
          'bytes': csvBytes,
        });
        // Save XLSX
        final xlsxUint8 = Uint8List.fromList(xlsxBytes);
        await _channel.invokeMethod('saveFile', {
          'filename': '$baseName.xlsx',
          'bytes': xlsxUint8,
        });
        return csvResult as String?;
      }
    } catch (e) {
      // platform channel failed, fallback to folder picker
    }

    // Fallback to folder picker approach
    return await exportToFolder(rows, suggestedName: suggestedName);
  }
}
