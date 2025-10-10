import 'package:tflite_flutter/tflite_flutter.dart';

/// Minimal, safe TFLite helper.
class TFLiteHelper {
  Interpreter? _interpreter;

  Future<void> loadModel(String assetPath) async {
    try {
      _interpreter ??= await Interpreter.fromAsset(assetPath);
    } catch (e) {
      rethrow;
    }
  }

  bool get isLoaded => _interpreter != null;

  void run(List<Object> input, Map<int, Object> output) {
    if (_interpreter == null) throw Exception('Interpreter not loaded');
    _interpreter!.runForMultipleInputs([input], output);
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
  }
}
