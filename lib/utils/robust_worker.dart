import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'ocr.dart';
import 'text_analyzer.dart';
import 'sensitivity.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

// Preprocess image bytes in an isolate: auto-crop to content, resize, enhance contrast.
Uint8List preprocessImageBytesCompute(Uint8List bytes) {
  try {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    final width = image.width;
    final height = image.height;

    // Convert to grayscale for fast content detection
    final gray = img.grayscale(image);

    int minX = width, minY = height, maxX = 0, maxY = 0;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final p = gray.getPixel(x, y);
        final lum = img.getLuminance(p);
        if (lum < 240) { // not almost-white
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }

    // If no content detected, return original bytes
    if (minX > maxX || minY > maxY) return bytes;

    // Add small padding
    const pad = 8;
    minX = (minX - pad).clamp(0, width - 1);
    minY = (minY - pad).clamp(0, height - 1);
    maxX = (maxX + pad).clamp(0, width - 1);
    maxY = (maxY + pad).clamp(0, height - 1);

    final w = maxX - minX;
    final h = maxY - minY;
    if (w <= 0 || h <= 0) return bytes;

    final crop = img.copyCrop(image, x: minX, y: minY, width: w, height: h);

    // Resize to reasonable max dimension for OCR
    const maxDim = 1200;
    int newW = crop.width;
    int newH = crop.height;
    if (newW > maxDim || newH > maxDim) {
      if (newW > newH) {
        newH = (newH * maxDim / newW).round();
        newW = maxDim;
      } else {
        newW = (newW * maxDim / newH).round();
        newH = maxDim;
      }
    }
    final resized = img.copyResize(crop, width: newW, height: newH);

    // Light enhancement
    final enhanced = img.adjustColor(resized, contrast: 1.08, saturation: 1.0);

    final out = img.encodeJpg(enhanced, quality: 85);
    return Uint8List.fromList(out);
  } catch (e) {
    return bytes;
  }
}

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

/// Runs the analysis isolate given already-extracted text. This avoids
/// calling OCR twice when the caller already performed text extraction.
Future<Map<String, double>> runAnalysisWithText(String extractedText, int sensitivityLevel) async {
  final p = ReceivePort();
  await Isolate.spawn<_IsolateMessage>(_isolateEntry, _IsolateMessage(extractedText, sensitivityLevel, p.sendPort));
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
