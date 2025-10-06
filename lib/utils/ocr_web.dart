import 'dart:typed_data';

// Web fallback: no native OCR implementation included here. Returns empty string.
Future<String> extractTextWeb({String? filePath, Uint8List? bytes}) async {
  // Ideally implement Tesseract.js interop here. For now, return empty and rely on analyzer heuristics.
  return '';
}
