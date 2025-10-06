abstract class TextAnalyzerInterface {
  Future<Map<String, double>> analyzeText(String text);
}

class AnalysisResult {
  final double aiProbability;
  final double humanProbability;

  AnalysisResult({
    required this.aiProbability,
    required this.humanProbability,
  });

  Map<String, double> toJson() => {
    'ai_detection': aiProbability * 100,
    'human_written': humanProbability * 100,
  };
}