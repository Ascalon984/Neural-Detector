import 'dart:typed_data';
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img_lib;
import 'package:flutter/foundation.dart' show compute;

class OCRMobile {
  static Future<String> extractText({String? filePath, Uint8List? bytes}) async {
    String pathToProcess = filePath ?? '';

    try {
      if (bytes != null && bytes.isNotEmpty) {
        // preprocess bytes (resize) in isolate and save to temp file
        final processed = await compute<_ResizeParams, Uint8List?>(_resizeBytes, _ResizeParams(bytes, 1280));
        if (processed == null) return '';
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/ocr_input_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(processed);
        pathToProcess = file.path;
      }

      if (pathToProcess.isEmpty) return '';

      final inputImage = InputImage.fromFilePath(pathToProcess);
      final textRecognizer = TextRecognizer();
      try {
        final result = await textRecognizer.processImage(inputImage);
        return result.text;
      } finally {
        textRecognizer.close();
      }
    } catch (e) {
      return '';
    }
  }
}

// Provide a shim function used by conditional import
Future<String> extractText({String? filePath, Uint8List? bytes}) => OCRMobile.extractText(filePath: filePath, bytes: bytes);

class _ResizeParams {
  final Uint8List bytes;
  final int maxWidth;
  _ResizeParams(this.bytes, this.maxWidth);
}

// Runs in isolate
Future<Uint8List?> _resizeBytes(_ResizeParams params) async {
  try {
    final img = img_lib.decodeImage(params.bytes);
    if (img == null) return null;
    if (img.width <= params.maxWidth) {
      // encode as jpeg with moderate quality
      return Uint8List.fromList(img_lib.encodeJpg(img, quality: 85));
    }
    final resized = img_lib.copyResize(img, width: params.maxWidth);
    return Uint8List.fromList(img_lib.encodeJpg(resized, quality: 85));
  } catch (e) {
    return null;
  }
}
