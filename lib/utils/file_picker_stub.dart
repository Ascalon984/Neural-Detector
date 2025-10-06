import 'dart:async';

Future<Map<String, dynamic>?> pickFileWeb({List<String>? accept}) async {
  // Not supported on non-web platforms; return null so caller falls back to FilePicker
  return null;
}
