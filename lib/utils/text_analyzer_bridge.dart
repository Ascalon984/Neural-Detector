import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'dart:io' show Platform;

// FFI structure for the analysis result
base class AnalysisResult extends ffi.Struct {
  @ffi.Double()
  external double aiProbability;
  
  @ffi.Double()
  external double humanProbability;
}

// FFI bindings for the C++ functions
typedef AnalyzeTextNative = AnalysisResult Function(ffi.Pointer<Utf8> text);
typedef AnalyzeTextDart = AnalysisResult Function(ffi.Pointer<Utf8> text);

class TextAnalyzer {
  static late final ffi.DynamicLibrary _lib;
  static late final AnalyzeTextDart _analyzeText;

  static void initialize() {
    final libraryPath = Platform.isWindows
        ? 'text_analyzer.dll'
        : Platform.isMacOS
            ? 'libtext_analyzer.dylib'
            : 'libtext_analyzer.so';
    
    _lib = ffi.DynamicLibrary.open(libraryPath);
    _analyzeText = _lib
        .lookupFunction<AnalyzeTextNative, AnalyzeTextDart>('analyzeText');
  }

  static Future<Map<String, double>> analyzeText(String text) async {
    final textPointer = text.toNativeUtf8();
    try {
      final result = _analyzeText(textPointer);
      return {
        'ai_detection': result.aiProbability * 100,
        'human_written': result.humanProbability * 100,
      };
    } finally {
      calloc.free(textPointer);
    }
  }
}