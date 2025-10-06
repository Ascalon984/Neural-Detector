import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

Future<String> extractText({String? filePath, Uint8List? bytes}) async {
  // Prefer using filePath on mobile (we get it from camera XFile)
  if (filePath == null) {
    // No path available; we cannot reliably create InputImage.fromBytes without metadata here.
    return '';
  }

  final inputImage = InputImage.fromFilePath(filePath);
  final textRecognizer = TextRecognizer();
  try {
    final result = await textRecognizer.processImage(inputImage);
    return result.text;
  } finally {
    textRecognizer.close();
  }
}
