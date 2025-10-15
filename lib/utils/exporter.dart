import 'dart:io' show File, Platform;
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:isolate';
import 'settings_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

// Conditional import: use the web implementation when dart:html is available,
// otherwise fall back to a non-web stub that does nothing.
import 'exporter_stub.dart' if (dart.library.html) 'exporter_web.dart' as web_export;

class Exporter {
  // Export progress callback
  static ProgressCallback? _progressCallback;
  
  // Export status stream for UI updates
  static final _exportStatusController = StreamController<ExportStatus>.broadcast();
  static Stream<ExportStatus> get exportStatusStream => _exportStatusController.stream;
  
  // Export options for customization
  static ExportOptions _defaultOptions = const ExportOptions();
  
  // Set progress callback for monitoring export progress
  static void setProgressCallback(ProgressCallback callback) {
    _progressCallback = callback;
  }
  
  // Set default export options
  static void setDefaultOptions(ExportOptions options) {
    _defaultOptions = options;
  }

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

  // Generate CSV content from history entries with memory optimization
  static Future<String> generateCsv(List<Map<String, dynamic>> rows, {ExportOptions? options}) async {
    final opts = options ?? _defaultOptions;
    
    // Validate input
    if (rows.isEmpty) {
      throw ArgumentError('Cannot export empty dataset');
    }
    
    // Use Isolate for large datasets to prevent UI freezing
    if (rows.length > 1000 && !kIsWeb) {
      return await _generateCsvInIsolate(rows, opts);
    }
    
    // Process in main thread for smaller datasets
    return _generateCsvDirectly(rows, opts);
  }
  
  // Direct CSV generation for smaller datasets
  static String _generateCsvDirectly(List<Map<String, dynamic>> rows, ExportOptions options) {
    final csvRows = <List<dynamic>>[];
    
    // Add headers if enabled
    if (options.includeHeaders) {
      csvRows.add(headers(langCode: options.languageCode));
    }

    final df = DateFormat(options.dateFormat);

    for (var i = 0; i < rows.length; i++) {
      // Update progress
      _progressCallback?.call((i + 1) / rows.length);
      _exportStatusController.add(ExportStatus(
        progress: (i + 1) / rows.length,
        status: ExportStatusType.processing,
        message: 'Processing row ${i + 1} of ${rows.length}',
      ));
      
      final r = rows[i];
      final date = r['date'] is DateTime ? df.format(r['date']) : r['date']?.toString() ?? '';
      final sizeKb = r['sizeBytes'] != null ? (r['sizeBytes'] / 1024).toStringAsFixed(0) : '';
      final aiPct = r['aiScore'] != null ? (r['aiScore'] * 100).toStringAsFixed(options.decimalPlaces) : '';
      final humanPct = (r['aiScore'] != null) ? (100 - (r['aiScore'] * 100)).toStringAsFixed(options.decimalPlaces) : '';
      
      // Filter columns based on options
      final row = <dynamic>[];
      if (options.columnsToInclude.isEmpty || options.columnsToInclude.contains('no')) {
        row.add(i + 1);
      }
      if (options.columnsToInclude.isEmpty || options.columnsToInclude.contains('filename')) {
        row.add(r['filename'] ?? '');
      }
      if (options.columnsToInclude.isEmpty || options.columnsToInclude.contains('date')) {
        row.add(date);
      }
      if (options.columnsToInclude.isEmpty || options.columnsToInclude.contains('size')) {
        row.add(sizeKb);
      }
      if (options.columnsToInclude.isEmpty || options.columnsToInclude.contains('ai')) {
        row.add(aiPct);
      }
      if (options.columnsToInclude.isEmpty || options.columnsToInclude.contains('human')) {
        row.add(humanPct);
      }
      if (options.columnsToInclude.isEmpty || options.columnsToInclude.contains('backend')) {
        row.add(r['backend'] ?? '');
      }
      if (options.columnsToInclude.isEmpty || options.columnsToInclude.contains('language')) {
        row.add(r['language'] ?? '');
      }
      if (options.columnsToInclude.isEmpty || options.columnsToInclude.contains('notes')) {
        row.add(r['notes'] ?? '');
      }
      
      csvRows.add(row);
    }

    return const ListToCsvConverter().convert(csvRows);
  }
  
  // Generate CSV in Isolate for large datasets
  static Future<String> _generateCsvInIsolate(List<Map<String, dynamic>> rows, ExportOptions options) async {
    final receivePort = ReceivePort();
    await Isolate.spawn(_csvGeneratorIsolate, receivePort.sendPort);
    
    final sendPort = await receivePort.first as SendPort;
    final answerPort = ReceivePort();
    sendPort.send({
      'rows': rows,
      'options': options,
      'replyTo': answerPort.sendPort,
    });
    
    final result = await answerPort.first;
    return result as String;
  }
  
  // Isolate entry point for CSV generation
  static void _csvGeneratorIsolate(SendPort sendPort) {
    final port = ReceivePort();
    sendPort.send(port.sendPort);
    
    port.listen((message) async {
      if (message is Map && message.containsKey('rows')) {
        final rows = message['rows'] as List<Map<String, dynamic>>;
        final options = message['options'] as ExportOptions;
        final replyTo = message['replyTo'] as SendPort;
        
        try {
          final csv = _generateCsvDirectly(rows, options);
          replyTo.send(csv);
        } catch (e) {
          replyTo.send('Error: $e');
        }
      }
    });
  }

  // Write an XLSX file using excel package with memory optimization
  static Future<List<int>> generateXlsxBytes(List<Map<String, dynamic>> rows, {ExportOptions? options}) async {
    final opts = options ?? _defaultOptions;
    
    // Validate input
    if (rows.isEmpty) {
      throw ArgumentError('Cannot export empty dataset');
    }
    
    // Use Isolate for large datasets to prevent UI freezing
    if (rows.length > 500 && !kIsWeb) {
      return await _generateXlsxInIsolate(rows, opts);
    }
    
    // Process in main thread for smaller datasets
    return _generateXlsxDirectly(rows, opts);
  }
  
  // Direct XLSX generation for smaller datasets
  static Future<List<int>> _generateXlsxDirectly(List<Map<String, dynamic>> rows, ExportOptions options) async {
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];
    
    // Add headers if enabled
    if (options.includeHeaders) {
      final headerRow = headers(langCode: options.languageCode);
      for (int i = 0; i < headerRow.length; i++) {
        final cell = sheet.cell(CellIndex.indexByString('${String.fromCharCode(65 + i)}1'));
        cell.value = headerRow[i];
      }
    }

    final df = DateFormat(options.dateFormat);

    for (var i = 0; i < rows.length; i++) {
      // Update progress
      _progressCallback?.call((i + 1) / rows.length);
      _exportStatusController.add(ExportStatus(
        progress: (i + 1) / rows.length,
        status: ExportStatusType.processing,
        message: 'Processing row ${i + 1} of ${rows.length}',
      ));
      
      final r = rows[i];
      final date = r['date'] is DateTime ? df.format(r['date']) : r['date']?.toString() ?? '';
      final sizeKb = r['sizeBytes'] != null ? (r['sizeBytes'] / 1024).toStringAsFixed(0) : '';
      final aiPct = r['aiScore'] != null ? (r['aiScore'] * 100).toStringAsFixed(options.decimalPlaces) : '';
      final humanPct = (r['aiScore'] != null) ? (100 - (r['aiScore'] * 100)).toStringAsFixed(options.decimalPlaces) : '';
      
      final rowIndex = i + (options.includeHeaders ? 2 : 1);
      int colIndex = 0;
      
      // Add columns based on options
      if (options.columnsToInclude.isEmpty || options.columnsToInclude.contains('no')) {
        sheet.cell(CellIndex.indexByString('${String.fromCharCode(65 + colIndex++)}$rowIndex'))
            .value = i + 1;
      }
      if (options.columnsToInclude.isEmpty || options.columnsToInclude.contains('filename')) {
        sheet.cell(CellIndex.indexByString('${String.fromCharCode(65 + colIndex++)}$rowIndex'))
            .value = r['filename'] ?? '';
      }
      if (options.columnsToInclude.isEmpty || options.columnsToInclude.contains('date')) {
        sheet.cell(CellIndex.indexByString('${String.fromCharCode(65 + colIndex++)}$rowIndex'))
            .value = date;
      }
      if (options.columnsToInclude.isEmpty || options.columnsToInclude.contains('size')) {
        sheet.cell(CellIndex.indexByString('${String.fromCharCode(65 + colIndex++)}$rowIndex'))
            .value = sizeKb;
      }
      if (options.columnsToInclude.isEmpty || options.columnsToInclude.contains('ai')) {
        sheet.cell(CellIndex.indexByString('${String.fromCharCode(65 + colIndex++)}$rowIndex'))
            .value = aiPct;
      }
      if (options.columnsToInclude.isEmpty || options.columnsToInclude.contains('human')) {
        sheet.cell(CellIndex.indexByString('${String.fromCharCode(65 + colIndex++)}$rowIndex'))
            .value = humanPct;
      }
      if (options.columnsToInclude.isEmpty || options.columnsToInclude.contains('backend')) {
        sheet.cell(CellIndex.indexByString('${String.fromCharCode(65 + colIndex++)}$rowIndex'))
            .value = r['backend'] ?? '';
      }
      if (options.columnsToInclude.isEmpty || options.columnsToInclude.contains('language')) {
        sheet.cell(CellIndex.indexByString('${String.fromCharCode(65 + colIndex++)}$rowIndex'))
            .value = r['language'] ?? '';
      }
      if (options.columnsToInclude.isEmpty || options.columnsToInclude.contains('notes')) {
        sheet.cell(CellIndex.indexByString('${String.fromCharCode(65 + colIndex++)}$rowIndex'))
            .value = r['notes'] ?? '';
      }
    }

    final bytes = excel.encode();
    return bytes ?? <int>[];
  }
  
  // Generate XLSX in Isolate for large datasets
  static Future<List<int>> _generateXlsxInIsolate(List<Map<String, dynamic>> rows, ExportOptions options) async {
    final receivePort = ReceivePort();
    await Isolate.spawn(_xlsxGeneratorIsolate, receivePort.sendPort);
    
    final sendPort = await receivePort.first as SendPort;
    final answerPort = ReceivePort();
    sendPort.send({
      'rows': rows,
      'options': options,
      'replyTo': answerPort.sendPort,
    });
    
    final result = await answerPort.first;
    return result is List<int> ? result : <int>[];
  }
  
  // Isolate entry point for XLSX generation
  static void _xlsxGeneratorIsolate(SendPort sendPort) {
    final port = ReceivePort();
    sendPort.send(port.sendPort);
    
    port.listen((message) async {
      if (message is Map && message.containsKey('rows')) {
        final rows = message['rows'] as List<Map<String, dynamic>>;
        final options = message['options'] as ExportOptions;
        final replyTo = message['replyTo'] as SendPort;
        
        try {
          final bytes = await _generateXlsxDirectly(rows, options);
          replyTo.send(bytes);
        } catch (e) {
          replyTo.send(<int>[]);
        }
      }
    });
  }

  // Main export function with mobile optimizations
  static Future<ExportResult> exportToFolder(
    List<Map<String, dynamic>> rows, 
    {String? suggestedName, 
    ExportOptions? options}
  ) async {
    final opts = options ?? _defaultOptions;
    final baseName = suggestedName ?? 'scan_history_${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      // Update status
      _exportStatusController.add(const ExportStatus(
        progress: 0.0,
        status: ExportStatusType.initializing,
        message: 'Preparing export...',
      ));
      
      // Validate input
      if (rows.isEmpty) {
        throw ArgumentError('Cannot export empty dataset');
      }
      
      // Web: browsers cannot write to arbitrary local folders. Instead trigger a download
      if (kIsWeb) {
        return await _exportForWeb(rows, baseName, opts);
      }
      
      // Mobile: Handle permissions and platform-specific paths
      if (Platform.isAndroid) {
        return await _exportForAndroid(rows, baseName, opts);
      } else if (Platform.isIOS) {
        return await _exportForIOS(rows, baseName, opts);
      } else {
        // Fallback for other platforms
        return await _exportForOtherPlatforms(rows, baseName, opts);
      }
    } catch (e) {
      debugPrint('Export error: $e');
      _exportStatusController.add(ExportStatus(
        progress: 0.0,
        status: ExportStatusType.error,
        message: 'Export failed: ${e.toString()}',
      ));
      
      return ExportResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  // Export for web platform
  static Future<ExportResult> _exportForWeb(
    List<Map<String, dynamic>> rows, 
    String baseName, 
    ExportOptions options
  ) async {
    try {
      _exportStatusController.add(const ExportStatus(
        progress: 0.2,
        status: ExportStatusType.processing,
        message: 'Generating CSV...',
      ));
      
      final csvContent = await generateCsv(rows, options: options);
      final csvBytes = Uint8List.fromList(csvContent.codeUnits);
      await web_export.saveBytesAsFile(csvBytes, '$baseName.csv');
      
      _exportStatusController.add(const ExportStatus(
        progress: 0.6,
        status: ExportStatusType.processing,
        message: 'Generating XLSX...',
      ));
      
      final xlsxBytes = await generateXlsxBytes(rows, options: options);
      if (xlsxBytes.isNotEmpty) {
        await web_export.saveBytesAsFile(Uint8List.fromList(xlsxBytes), '$baseName.xlsx');
      }
      
      _exportStatusController.add(const ExportStatus(
        progress: 1.0,
        status: ExportStatusType.completed,
        message: 'Export completed successfully',
      ));
      
      return ExportResult(
        success: true,
        filePath: baseName, // Web doesn't have a real file path
        files: [
          ExportedFile(name: '$baseName.csv', bytes: csvBytes),
          ExportedFile(name: '$baseName.xlsx', bytes: Uint8List.fromList(xlsxBytes)),
        ],
      );
    } catch (e) {
      debugPrint('Web export error: $e');
      return ExportResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  // Export for Android platform
  static Future<ExportResult> _exportForAndroid(
    List<Map<String, dynamic>> rows, 
    String baseName, 
    ExportOptions options
  ) async {
    try {
      // Check and request storage permissions
      _exportStatusController.add(const ExportStatus(
        progress: 0.1,
        status: ExportStatusType.requestingPermissions,
        message: 'Checking storage permissions...',
      ));
      
      final hasPermission = await _checkStoragePermission();
      if (!hasPermission) {
        return const ExportResult(
          success: false,
          errorMessage: 'Storage permission denied',
        );
      }
      
      // Try to save to Downloads folder first
      _exportStatusController.add(const ExportStatus(
        progress: 0.2,
        status: ExportStatusType.processing,
        message: 'Preparing files for export...',
      ));
      
      final csvContent = await generateCsv(rows, options: options);
      final xlsxBytes = await generateXlsxBytes(rows, options: options);
      
      // Use MethodChannel to save to Downloads
      _exportStatusController.add(const ExportStatus(
        progress: 0.4,
        status: ExportStatusType.saving,
        message: 'Saving to Downloads folder...',
      ));
      
      final csvBytes = Uint8List.fromList(csvContent.codeUnits);
      final csvResult = await _saveToDownloads('$baseName.csv', csvBytes);
      
      _exportStatusController.add(const ExportStatus(
        progress: 0.7,
        status: ExportStatusType.saving,
        message: 'Saving XLSX file...',
      ));
      
      final xlsxUint8 = Uint8List.fromList(xlsxBytes);
      final xlsxResult = await _saveToDownloads('$baseName.xlsx', xlsxUint8);
      
      _exportStatusController.add(const ExportStatus(
        progress: 1.0,
        status: ExportStatusType.completed,
        message: 'Export completed successfully',
      ));
      
      return ExportResult(
        success: true,
        filePath: csvResult,
        files: [
          ExportedFile(name: '$baseName.csv', path: csvResult),
          ExportedFile(name: '$baseName.xlsx', path: xlsxResult),
        ],
      );
    } catch (e) {
      debugPrint('Android export error: $e');
      return ExportResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  // Export for iOS platform
  static Future<ExportResult> _exportForIOS(
    List<Map<String, dynamic>> rows, 
    String baseName, 
    ExportOptions options
  ) async {
    try {
      // iOS doesn't have a Downloads folder accessible to apps, so we use app's documents directory
      _exportStatusController.add(const ExportStatus(
        progress: 0.2,
        status: ExportStatusType.processing,
        message: 'Preparing files for export...',
      ));
      
      final csvContent = await generateCsv(rows, options: options);
      final xlsxBytes = await generateXlsxBytes(rows, options: options);
      
      // Get app's documents directory
      final directory = await getApplicationDocumentsDirectory();
      
      _exportStatusController.add(const ExportStatus(
        progress: 0.4,
        status: ExportStatusType.saving,
        message: 'Saving CSV file...',
      ));
      
      final csvPath = p.join(directory.path, '$baseName.csv');
      final csvFile = File(csvPath);
      await csvFile.writeAsString(csvContent, flush: true);
      
      _exportStatusController.add(const ExportStatus(
        progress: 0.7,
        status: ExportStatusType.saving,
        message: 'Saving XLSX file...',
      ));
      
      final xlsxPath = p.join(directory.path, '$baseName.xlsx');
      final xlsxFile = File(xlsxPath);
      await xlsxFile.writeAsBytes(xlsxBytes, flush: true);
      
      _exportStatusController.add(const ExportStatus(
        progress: 1.0,
        status: ExportStatusType.completed,
        message: 'Export completed successfully',
      ));
      
      return ExportResult(
        success: true,
        filePath: csvPath,
        files: [
          ExportedFile(name: '$baseName.csv', path: csvPath),
          ExportedFile(name: '$baseName.xlsx', path: xlsxPath),
        ],
      );
    } catch (e) {
      debugPrint('iOS export error: $e');
      return ExportResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  // Export for other platforms
  static Future<ExportResult> _exportForOtherPlatforms(
    List<Map<String, dynamic>> rows, 
    String baseName, 
    ExportOptions options
  ) async {
    try {
      // Let user pick a directory
      _exportStatusController.add(const ExportStatus(
        progress: 0.2,
        status: ExportStatusType.requestingInput,
        message: 'Please select a destination folder...',
      ));
      
      String? selectedDirectory;
      try {
        final result = await FilePicker.platform.getDirectoryPath();
        selectedDirectory = result;
      } catch (e) {
        selectedDirectory = null;
      }

      if (selectedDirectory == null) {
        return const ExportResult(
          success: false,
          errorMessage: 'No directory selected',
        );
      }
      
      _exportStatusController.add(const ExportStatus(
        progress: 0.4,
        status: ExportStatusType.processing,
        message: 'Preparing files for export...',
      ));
      
      final csvContent = await generateCsv(rows, options: options);
      final xlsxBytes = await generateXlsxBytes(rows, options: options);
      
      _exportStatusController.add(const ExportStatus(
        progress: 0.6,
        status: ExportStatusType.saving,
        message: 'Saving CSV file...',
      ));
      
      final csvPath = p.join(selectedDirectory, '$baseName.csv');
      final csvFile = File(csvPath);
      await csvFile.writeAsString(csvContent, flush: true);
      
      _exportStatusController.add(const ExportStatus(
        progress: 0.8,
        status: ExportStatusType.saving,
        message: 'Saving XLSX file...',
      ));
      
      if (xlsxBytes.isNotEmpty) {
        final xlsxPath = p.join(selectedDirectory, '$baseName.xlsx');
        final xlsxFile = File(xlsxPath);
        await xlsxFile.writeAsBytes(xlsxBytes, flush: true);
      }
      
      _exportStatusController.add(const ExportStatus(
        progress: 1.0,
        status: ExportStatusType.completed,
        message: 'Export completed successfully',
      ));
      
      return ExportResult(
        success: true,
        filePath: csvPath,
        files: [
          ExportedFile(name: '$baseName.csv', path: csvPath),
          if (xlsxBytes.isNotEmpty) ExportedFile(name: '$baseName.xlsx', path: p.join(selectedDirectory, '$baseName.xlsx')),
        ],
      );
    } catch (e) {
      debugPrint('Other platform export error: $e');
      return ExportResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  // Check and request storage permissions
  static Future<bool> _checkStoragePermission() async {
    if (Platform.isAndroid) {
      // For Android 10+ (API 29+), we need scoped storage
      if (Platform.version.contains('10') || 
          Platform.version.contains('11') || 
          Platform.version.contains('12') || 
          Platform.version.contains('13')) {
        // For Android 10+, we don't need storage permission for app-specific directories
        return true;
      } else {
        // For older Android versions, request storage permission
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } else if (Platform.isIOS) {
      // iOS doesn't need explicit storage permission for app documents
      return true;
    }
    
    return true;
  }
  
  // Save file to Downloads folder using MethodChannel
  static Future<String> _saveToDownloads(String filename, Uint8List bytes) async {
    const MethodChannel channel = MethodChannel('ai_text_checker/saveFileToDownloads');
    
    try {
      final result = await channel.invokeMethod('saveFile', {
        'filename': filename,
        'bytes': bytes,
      });
      return result as String;
    } catch (e) {
      debugPrint('Error saving to Downloads: $e');
      throw Exception('Failed to save file to Downloads: $e');
    }
  }
  
  // Share exported files
  static Future<void> shareFiles(List<ExportedFile> files) async {
    try {
      final tempFiles = <XFile>[];
      final tmpDir = await getTemporaryDirectory();

      for (final file in files) {
        if (file.path != null) {
          tempFiles.add(XFile(file.path!));
          continue;
        }

        if (file.bytes != null) {
          final f = File(p.join(tmpDir.path, file.name));
          await f.writeAsBytes(file.bytes!, flush: true);
          tempFiles.add(XFile(f.path));
          continue;
        }
      }

      if (tempFiles.isEmpty) throw Exception('No files to share');

      await Share.shareXFiles(
        tempFiles,
        text: 'Scan History Export',
        subject: 'AI Text Checker Export',
      );
    } catch (e) {
      debugPrint('Error sharing files: $e');
      throw Exception('Failed to share files: $e');
    }
  }
  
  // Clean up resources
  static void dispose() {
    _exportStatusController.close();
  }
}

// Export options class for customization
class ExportOptions {
  final bool includeHeaders;
  final String dateFormat;
  final int decimalPlaces;
  final String languageCode;
  final List<String> columnsToInclude;
  final Map<String, String> columnAliases;
  
  const ExportOptions({
    this.includeHeaders = true,
    this.dateFormat = 'yyyy-MM-dd HH:mm:ss',
    this.decimalPlaces = 2,
    this.languageCode = 'en',
    this.columnsToInclude = const [], // Empty means include all columns
    this.columnAliases = const {},
  });
}

// Export result class
class ExportResult {
  final bool success;
  final String? filePath;
  final String? errorMessage;
  final List<ExportedFile>? files;
  
  const ExportResult({
    required this.success,
    this.filePath,
    this.errorMessage,
    this.files,
  });
}

// Exported file class
class ExportedFile {
  final String name;
  final String? path;
  final Uint8List? bytes;

  const ExportedFile({
    required this.name,
    this.path,
    this.bytes,
  });
}

// Export status enum
enum ExportStatusType {
  initializing,
  requestingPermissions,
  requestingInput,
  processing,
  saving,
  completed,
  error,
}

// Export status class
class ExportStatus {
  final double progress;
  final ExportStatusType status;
  final String message;
  
  const ExportStatus({
    required this.progress,
    required this.status,
    required this.message,
  });
}

// Progress callback type
typedef ProgressCallback = void Function(double progress);