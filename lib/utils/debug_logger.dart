import 'dart:io';
import 'package:path_provider/path_provider.dart';

class DebugLogger {
  static Future<File> _logFile() async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/neural_detector_debug.log');
    if (!await f.exists()) await f.create();
    return f;
  }

  static Future<void> append(String s) async {
    try {
      final f = await _logFile();
      final now = DateTime.now().toIso8601String();
      await f.writeAsString('[$now] $s\n', mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  static Future<String?> readAll() async {
    try {
      final f = await _logFile();
      return await f.readAsString();
    } catch (e) {
      return null;
    }
  }
}
