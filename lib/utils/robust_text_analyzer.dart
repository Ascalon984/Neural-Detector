import 'dart:async';
import 'dart:math' as math;
import 'text_analyzer_interface.dart';
import 'native_text_analyzer.dart';

/// Robust analyzer for high sensitivity: uses native analyzer if available and
/// applies additional checks to increase detection quality.
class RobustTextAnalyzer implements TextAnalyzerInterface {
  final NativeTextAnalyzer _native = NativeTextAnalyzer();

  @override
  Future<Map<String, double>> analyzeText(String text) async {
    if (text.isEmpty) return {'ai_detection': 0.0, 'human_written': 100.0};

    // Use native analyzer if supported, else run a moderate algorithm
    if (NativeTextAnalyzer.isSupported) {
      final base = await _native.analyzeText(text);
      // Post-process to sharpen AI detection a bit for high sensitivity
      double ai = base['ai_detection'] ?? 0.0;
      // Apply small boost based on repetitiveness and coherence
      final repBoost = _repetitivenessBoost(text);
      ai = (ai / 100.0 + repBoost).clamp(0.0, 1.0) * 100.0;
      return {
        'ai_detection': ai,
        'human_written': 100.0 - ai,
      };
    }

    // fallback: basic robust heuristics
    final words = text.split(RegExp(r'\s+'));
    final avgLen = words.fold<int>(0, (s, w) => s + w.length) / words.length;
    double aiScore = ((avgLen - 4) / 3).clamp(0.0, 1.0);
    aiScore = (aiScore * 0.6 + _repetitivenessBoost(text) * 0.4).clamp(0.0, 1.0);
    return {
      'ai_detection': aiScore * 100,
      'human_written': (1.0 - aiScore) * 100,
    };
  }

  double _repetitivenessBoost(String text) {
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    final counts = <String, int>{};
    for (var w in words) {
      counts[w] = (counts[w] ?? 0) + 1;
    }
    final max = counts.values.isEmpty ? 0 : counts.values.reduce(math.max);
    final boost = (max / (words.length + 1)).clamp(0.0, 1.0) * 0.25;
    return boost;
  }
}
