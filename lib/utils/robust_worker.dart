import 'dart:typed_data';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'ocr.dart';
import 'text_analyzer.dart';
import 'sensitivity.dart';

class _IsolateMessage {
  final String? filePath;
  final Uint8List? bytes;
  final int level;
  final SendPort sendPort;
  _IsolateMessage(this.filePath, this.bytes, this.level, this.sendPort);
}

/// Runs OCR + text analysis in an isolate and returns adjusted result
Future<Map<String, double>> runAnalysisIsolate({String? filePath, Uint8List? bytes, required int sensitivityLevel}) async {
  final p = ReceivePort();
  await Isolate.spawn<_IsolateMessage>(_isolateEntry, _IsolateMessage(filePath, bytes, sensitivityLevel, p.sendPort));
  final result = await p.first as Map<String, double>;
  p.close();
  return result;
}

void _isolateEntry(_IsolateMessage msg) async {
  try {
    String extracted = '';
    try {
      if (msg.filePath != null) {
        extracted = await OCR.extractText(filePath: msg.filePath);
      } else if (msg.bytes != null) {
        extracted = await OCR.extractText(bytes: msg.bytes);
      }
    } catch (_) {
      extracted = '';
    }

    // perform text analysis (uses routing inside TextAnalyzer)
    final toAnalyze = extracted.isNotEmpty ? extracted : 'image_capture_' + DateTime.now().millisecondsSinceEpoch.toString();
    Map<String, double> rawResult = {'ai_detection': 0.0, 'human_written': 100.0};
    try {
      rawResult = await TextAnalyzer.analyzeText(toAnalyze);
    } catch (_) {}

    // apply sensitivity (delegate to central function)
    Map<String, double> adjusted = rawResult;
    try {
      // Note: applySensitivityToResult reads SettingsManager internally; pass sensitivityLevel if needed
      adjusted = await applySensitivityToResult(rawResult);
    } catch (_) {}

    msg.sendPort.send(adjusted);
  } catch (e) {
    msg.sendPort.send({'ai_detection': 0.0, 'human_written': 100.0});
  }
}
