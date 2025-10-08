import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// Reuse a single TextRecognizer instance to avoid repeated costly initialization.
final TextRecognizer _sharedTextRecognizer = TextRecognizer();

Future<String> extractText({String? filePath, Uint8List? bytes}) async {
  // Prefer using filePath on mobile (we get it from camera XFile)
  if (filePath == null) {
    // No path available; we cannot reliably create InputImage.fromBytes without metadata here.
    return '';
  }

  final inputImage = InputImage.fromFilePath(filePath);
  try {
    final result = await _sharedTextRecognizer.processImage(inputImage);
    return result.text;
  } catch (_) {
    return '';
  }
}

/// Dispose the shared recognizer when the app exits (optional).
Future<void> disposeSharedRecognizer() async {
  try {
    _sharedTextRecognizer.close();
  } catch (_) {}
}
