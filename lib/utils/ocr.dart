// Platform-neutral OCR API (conditional import) - shim
import 'dart:typed_data';

// The conditional import will resolve to the proper implementation file
import 'ocr_stub.dart'
    if (dart.library.io) 'ocr_mobile_impl.dart'
    if (dart.library.html) 'ocr_web_impl.dart' as impl;

class OCR {
  /// Extract text from an image file path (mobile) or image bytes (web).
  static Future<String> extractText({String? filePath, Uint8List? bytes}) async {
    return impl.extractText(filePath: filePath, bytes: bytes);
  }
}
