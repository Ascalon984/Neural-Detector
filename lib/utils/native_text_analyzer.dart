import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'text_analyzer_interface.dart';

class NativeTextAnalyzer implements TextAnalyzerInterface {
  static final NativeTextAnalyzer _instance = NativeTextAnalyzer._internal();
  factory NativeTextAnalyzer() => _instance;
  
  static bool get isSupported {
    try {
      return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    } catch (_) {
      return false; // Return false if running on web
    }
  }
  
  bool _isInitialized = false;
  final _random = math.Random();

  NativeTextAnalyzer._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize any required resources
      _isInitialized = true;
    } catch (e) {
      print('Failed to initialize native analyzer: $e');
    }
  }

  @override
  Future<Map<String, double>> analyzeText(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (text.isEmpty) {
      return {'ai_detection': 0.0, 'human_written': 100.0};
    }

    final result = await _performAnalysis(text);
    return {
      'ai_detection': result.aiProbability * 100,
      'human_written': result.humanProbability * 100,
    };
  }

  Future<AnalysisResult> _performAnalysis(String text) async {
    // Actual text analysis implementation
    double aiScore = 0.0;
    
    // Check text complexity
    aiScore += _analyzeTextComplexity(text) * 0.3;
    
    // Check word patterns
    aiScore += _analyzeWordPatterns(text) * 0.3;
    
    // Check sentence structure
    aiScore += _analyzeSentenceStructure(text) * 0.4;
    
    // Add small random variation to make it more realistic
    aiScore *= (0.95 + _random.nextDouble() * 0.1);
    
    // Ensure the score is between 0 and 1
    aiScore = aiScore.clamp(0.0, 1.0);
    
    return AnalysisResult(
      aiProbability: aiScore,
      humanProbability: 1.0 - aiScore,
    );
  }

  double _analyzeTextComplexity(String text) {
    final words = text.split(RegExp(r'\s+'));
    final avgWordLength = words.fold<int>(0, (sum, word) => sum + word.length) / words.length;
    
    // Longer average word length often indicates AI-generated text
    return ((avgWordLength - 4) / 3).clamp(0.0, 1.0);
  }

  double _analyzeWordPatterns(String text) {
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    final transitions = <String, Map<String, int>>{};
    
    // Analyze word transitions
    for (var i = 0; i < words.length - 1; i++) {
      transitions.putIfAbsent(words[i], () => {});
      transitions[words[i]]![words[i + 1]] = 
        (transitions[words[i]]![words[i + 1]] ?? 0) + 1;
    }
    
    // Calculate predictability score
    double predictabilityScore = 0;
    for (var word in transitions.keys) {
      final totalTransitions = transitions[word]!.values.reduce((a, b) => a + b);
      final maxTransition = transitions[word]!.values.reduce(math.max);
      predictabilityScore += maxTransition / totalTransitions;
    }
    
    return (predictabilityScore / transitions.length).clamp(0.0, 1.0);
  }

  double _analyzeSentenceStructure(String text) {
    final sentences = text.split(RegExp(r'[.!?]+\s*'));
    if (sentences.isEmpty) return 0.0;
    
    final lengths = sentences.map((s) => s.split(RegExp(r'\s+')).length).toList();
    final avg = lengths.reduce((a, b) => a + b) / lengths.length;
    
    // Calculate variance in sentence length
    final variance = lengths
        .map((l) => math.pow(l - avg, 2))
        .reduce((a, b) => a + b) / lengths.length;
    
    // More uniform sentence lengths (lower variance) suggest AI generation
    return (1.0 - (math.sqrt(variance) / avg)).clamp(0.0, 1.0);
  }
}