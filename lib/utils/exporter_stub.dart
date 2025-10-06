import 'dart:typed_data';

/// Stub implementation used on non-web platforms. The web implementation
/// triggers a browser download; on non-web we return null to indicate no web
/// download was performed. This prevents importing `dart:html` on Android/iOS.
Future<String?> saveBytesAsFile(Uint8List bytes, String filename) async {
  // Not supported on non-web platforms; caller should use dart:io path instead.
  return null;
}
