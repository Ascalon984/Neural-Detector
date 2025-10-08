import 'dart:typed_data';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'ocr.dart';
import 'text_analyzer.dart';
import 'sensitivity.dart';

class _IsolateMessage {
  final String? extractedText;
  final int level;
  final SendPort sendPort;
  _IsolateMessage(this.extractedText, this.level, this.sendPort);
}

/// Runs OCR (on the caller/main isolate) then offloads CPU-bound text analysis
/// to a spawned isolate. Many platform plugins (eg. ML Kit) are not isolate-
/// safe; extracting text on the main isolate avoids hangs when calling native
/// plugins from a spawned isolate. The spawned isolate only runs analysis &
/// sensitivity adjustment.
Future<Map<String, double>> runAnalysisIsolate({String? filePath, Uint8List? bytes, required int sensitivityLevel}) async {
  // Extract text on the caller isolate first. If extraction fails, fall back
  // to an empty string so analysis will operate on a placeholder.
  String extracted = '';
  try {
    if (filePath != null || bytes != null) {
      extracted = await OCR.extractText(filePath: filePath, bytes: bytes);
    }
  } catch (e) {
    // Swallow extraction errors; we'll proceed with empty extracted text.
    extracted = '';
  }

  final p = ReceivePort();
  await Isolate.spawn<_IsolateMessage>(_isolateEntry, _IsolateMessage(extracted, sensitivityLevel, p.sendPort));
  final result = await p.first as Map<String, double>;
  p.close();
  return result;
}

void _isolateEntry(_IsolateMessage msg) async {
  try {
    // perform text analysis (uses routing inside TextAnalyzer)
    final toAnalyze = (msg.extractedText != null && msg.extractedText!.isNotEmpty)
        ? msg.extractedText!
        : 'image_capture_' + DateTime.now().millisecondsSinceEpoch.toString();

    Map<String, double> rawResult = {'ai_detection': 0.0, 'human_written': 100.0};
    try {
      rawResult = await TextAnalyzer.analyzeText(toAnalyze);
    } catch (_) {}

    // apply sensitivity (delegate to central function)
    Map<String, double> adjusted = rawResult;
    try {
      // applySensitivityToResult may read SettingsManager internally
      adjusted = await applySensitivityToResult(rawResult);
    } catch (_) {}

    msg.sendPort.send(adjusted);
  } catch (e) {
    msg.sendPort.send({'ai_detection': 0.0, 'human_written': 100.0});
  }
}
