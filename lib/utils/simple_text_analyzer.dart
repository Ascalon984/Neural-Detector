import 'dart:async';
import 'text_analyzer_interface.dart';

/// Fast, lightweight analyzer for low sensitivity mode.
class SimpleTextAnalyzer implements TextAnalyzerInterface {
  @override
  Future<Map<String, double>> analyzeText(String text) async {
    if (text.isEmpty) return {'ai_detection': 0.0, 'human_written': 100.0};
    // Very simple heuristics: length + punctuation density
    final words = text.split(RegExp(r'\s+'));
    final avgWordLen = words.fold<int>(0, (s, w) => s + w.length) / words.length;
    final punctuation = RegExp(r'[.,!?;:]');
    final punctCount = punctuation.allMatches(text).length;
    final punctDensity = punctCount / (words.length + 1);

    double aiScore = 0.0;
    aiScore += ((avgWordLen - 4) / 4).clamp(0.0, 1.0) * 0.6;
    aiScore += (punctDensity * 0.5).clamp(0.0, 1.0) * 0.4;
    aiScore = aiScore.clamp(0.0, 1.0);

    return {
      'ai_detection': aiScore * 100,
      'human_written': (1.0 - aiScore) * 100,
    };
  }
}
