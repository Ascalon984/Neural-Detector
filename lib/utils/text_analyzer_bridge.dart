import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'dart:io';
import 'wordpiece_tokenizer.dart';
import 'package:flutter/services.dart' show rootBundle;

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
// FFI for tokenized input: analyzeTokenIds(int32* ids_ptr, int32* mask_ptr, int32 len)
typedef AnalyzeTokenIdsNative = AnalysisResult Function(ffi.Pointer<ffi.Int32> ids, ffi.Pointer<ffi.Int32> mask, ffi.Int32 len);
typedef AnalyzeTokenIdsDart = AnalysisResult Function(ffi.Pointer<ffi.Int32> ids, ffi.Pointer<ffi.Int32> mask, int len);

class TextAnalyzer {
  static late final ffi.DynamicLibrary _lib;
  static late final AnalyzeTextDart _analyzeText;
  static AnalyzeTokenIdsDart? _analyzeTokenIds;

  static void initialize() {
    final libraryPath = Platform.isWindows
        ? 'text_analyzer.dll'
        : Platform.isMacOS
            ? 'libtext_analyzer.dylib'
            : 'libtext_analyzer.so';
    
    _lib = ffi.DynamicLibrary.open(libraryPath);
    _analyzeText = _lib
        .lookupFunction<AnalyzeTextNative, AnalyzeTextDart>('analyzeText');
    // optional: tokenized path
    try {
      _analyzeTokenIds = _lib.lookupFunction<AnalyzeTokenIdsNative, AnalyzeTokenIdsDart>('analyzeTokenIds');
    } catch (_) {
      // not available
      _analyzeTokenIds = null;
    }
  }

  static Future<Map<String, double>> analyzeText(String text) async {
    final textPointer = text.toNativeUtf8();
    try {
      // If tokenized native path is available, prefer it (tokenize in Dart then call native)
      if (_analyzeTokenIds != null) {
        try {
          // load vocab from assets/models/tokenizer/vocab.txt if present
          WordpieceTokenizer? tokenizer;
          try {
            final vocabStr = await rootBundle.loadString('assets/models/tokenizer/vocab.txt');
            // create temp vocab file
            final tmp = Directory.systemTemp.createTempSync('vocab');
            final path = '${tmp.path}/vocab.txt';
            File(path).writeAsStringSync(vocabStr);
            tokenizer = await WordpieceTokenizer.fromVocabFile(path);
          } catch (_) {
            tokenizer = null;
          }
          if (tokenizer != null) {
            final ids = tokenizer.tokenizeToIds(text);
            final mask = tokenizer.attentionMaskFromIds(ids);

            final idsPtr = calloc<ffi.Int32>(ids.length);
            final maskPtr = calloc<ffi.Int32>(mask.length);
            for (var i = 0; i < ids.length; i++) idsPtr.elementAt(i).value = ids[i];
            for (var i = 0; i < mask.length; i++) maskPtr.elementAt(i).value = mask[i];
            try {
              final result = _analyzeTokenIds!(idsPtr, maskPtr, ids.length);
              calloc.free(idsPtr);
              calloc.free(maskPtr);
              return {
                'ai_detection': result.aiProbability * 100,
                'human_written': result.humanProbability * 100,
              };
            } catch (_) {
              calloc.free(idsPtr);
              calloc.free(maskPtr);
            }
          }
        } catch (_) {}
      }
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