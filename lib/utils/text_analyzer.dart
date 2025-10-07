import 'text_analyzer_interface.dart';
import 'native_text_analyzer.dart';
import 'web_text_analyzer.dart';
import 'simple_text_analyzer.dart';
import 'robust_text_analyzer.dart';
import 'settings_manager.dart';
import 'sensitivity.dart';
import 'analysis_cache.dart';

class TextAnalyzer {
  static TextAnalyzerInterface? _instance;
  static final Map<String, TextAnalyzerInterface> _analyzerCache = {};
  static final AnalysisCache _resultCache = AnalysisCache(capacity: 300);
  
  static TextAnalyzerInterface get instance {
    _instance ??= _createAnalyzer();
    return _instance!;
  }
  
  static TextAnalyzerInterface _createAnalyzer() {
    // Try to use native analyzer first
    if (NativeTextAnalyzer.isSupported) {
      return NativeTextAnalyzer();
    }
    
    // Fall back to web implementation
    return WebTextAnalyzer();
  }
  
  static Future<Map<String, double>> analyzeText(String text) {
    // Decide backend based on detection sensitivity level and text characteristics
    return _routeAnalyze(text);
  }

  static Future<Map<String, double>> _routeAnalyze(String text) async {
    try {
      final level = await SettingsManager.getSensitivityLevel();
      final textLength = text.length;
      final textComplexity = _calculateTextComplexity(text);
      final cacheKey = '${text.hashCode}|lvl:$level';
      final cached = _resultCache.get(cacheKey);
      if (cached != null) return cached;
      // Determine the appropriate analyzer based on sensitivity and text characteristics
      TextAnalyzerInterface analyzer = _selectAnalyzer(level, textLength, textComplexity);

      // Perform the analysis
  final result = await analyzer.analyzeText(text);

  // Delegate sensitivity adjustment to central function in sensitivity.dart
  final adjusted = await applySensitivityToResult(result);
  // store adjusted result in cache
  _resultCache.set(cacheKey, adjusted);
  return adjusted;
    } catch (e) {
      // Fallback to default analyzer with basic error handling
      return _fallbackAnalysis(text);
    }
  }
  
  // Calculate text complexity based on various factors
  static double _calculateTextComplexity(String text) {
    if (text.isEmpty) return 0.0;
    
    // Basic complexity metrics
    final words = text.split(RegExp(r'\s+'));
    final avgWordLength = words.isEmpty ? 0 : words.map((w) => w.length).reduce((a, b) => a + b) / words.length;
    final uniqueWords = words.toSet().length;
    final wordDiversity = words.isEmpty ? 0 : uniqueWords / words.length;
    
  // Punctuation and structure complexity (safe counting without complex regex)
  const punctChars = <String>{'.', '!', '?', ';', ':', ',', '"', "'", '-'};
  final punctuationCount = text.runes
    .map((r) => String.fromCharCode(r))
    .where((ch) => punctChars.contains(ch))
    .length;
  final punctuationDensity = punctuationCount / text.length;
    
    // Sentence complexity
    final sentences = text.split(RegExp(r'[.!?]+')).where((s) => s.trim().isNotEmpty).length;
    final avgSentenceLength = sentences == 0 ? 0 : text.length / sentences;
    
    // Calculate normalized complexity score (0-1)
    final complexityScore = 
        (avgWordLength / 10.0) * 0.2 +           // Word length factor
        wordDiversity * 0.3 +                    // Vocabulary diversity
        punctuationDensity * 20.0 * 0.2 +        // Punctuation density
        (avgSentenceLength / 100.0) * 0.3;       // Sentence length factor
    
    return complexityScore.clamp(0.0, 1.0);
  }
  
  // Select the most appropriate analyzer based on multiple factors
  static TextAnalyzerInterface _selectAnalyzer(int sensitivityLevel, int textLength, double textComplexity) {
  // analyzer cache is a static final map; entries are created below when needed
    
    // Create a routing decision matrix
    final RoutingDecision decision = _makeRoutingDecision(sensitivityLevel, textLength, textComplexity);
    
    switch (decision) {
      case RoutingDecision.simple:
        return _analyzerCache['simple'] ??= SimpleTextAnalyzer();
      case RoutingDecision.standard:
        return instance;
      case RoutingDecision.robust:
        return _analyzerCache['robust'] ??= RobustTextAnalyzer();
      case RoutingDecision.hybrid:
        return _analyzerCache['hybrid'] ??= _createHybridAnalyzer();
    }
  }
  
  // Make intelligent routing decision based on multiple factors
  static RoutingDecision _makeRoutingDecision(int sensitivityLevel, int textLength, double textComplexity) {
    // Low sensitivity (1-3): Use simple analyzer for speed
    if (sensitivityLevel <= 3) {
      return RoutingDecision.simple;
    }
    
    // High sensitivity (8-10): Use robust analyzer for accuracy
    if (sensitivityLevel >= 8) {
      return RoutingDecision.robust;
    }
    
    // Medium sensitivity (4-7): Consider text characteristics
    if (sensitivityLevel >= 4 && sensitivityLevel <= 7) {
      // For medium sensitivity, consider text length and complexity
      if (textLength > 5000 || textComplexity > 0.7) {
        // Long or complex texts need robust analysis
        return RoutingDecision.robust;
      } else if (textLength < 500 && textComplexity < 0.3) {
        // Short, simple texts can use simple analyzer
        return RoutingDecision.simple;
      } else {
        // Medium texts use standard analyzer
        return RoutingDecision.standard;
      }
    }
    
    // Default to standard analyzer
    return RoutingDecision.standard;
  }
  
  // Create a hybrid analyzer that combines multiple approaches
  static TextAnalyzerInterface _createHybridAnalyzer() {
    return HybridTextAnalyzer();
  }
  
  // Removed inline sensitivity adjustment: delegated to sensitivity.applySensitivityToResult
  
  // Fallback analysis with error handling
  static Future<Map<String, double>> _fallbackAnalysis(String text) async {
    try {
      // Try with the default instance
      return await instance.analyzeText(text);
    } catch (e) {
      // Last resort: return a neutral result
      return {
        'ai_detection': 50.0,
        'human_written': 50.0,
      };
    }
  }
}

// Enum for routing decisions
enum RoutingDecision {
  simple,
  standard,
  robust,
  hybrid,
}

// Hybrid analyzer that combines multiple approaches
class HybridTextAnalyzer implements TextAnalyzerInterface {
  @override
  Future<Map<String, double>> analyzeText(String text) async {
    // For hybrid approach, we can combine results from multiple analyzers
    final simpleResult = await SimpleTextAnalyzer().analyzeText(text);
    final robustResult = await RobustTextAnalyzer().analyzeText(text);
    
    // Weight the results based on text characteristics
  final textComplexity = _calculateTextComplexity(text);
    
    // More weight to robust analyzer for complex texts
    final robustWeight = 0.3 + (textComplexity * 0.4);
    final simpleWeight = 1.0 - robustWeight;
    
    final aiScore = (simpleResult['ai_detection']! * simpleWeight) + 
                    (robustResult['ai_detection']! * robustWeight);
    final humanScore = (simpleResult['human_written']! * simpleWeight) + 
                      (robustResult['human_written']! * robustWeight);
    
    return {
      'ai_detection': aiScore.clamp(0.0, 100.0),
      'human_written': humanScore.clamp(0.0, 100.0),
    };
  }
  
  // Helper method to calculate text complexity
  double _calculateTextComplexity(String text) {
    if (text.isEmpty) return 0.0;
    
    final words = text.split(RegExp(r'\s+'));
    final avgWordLength = words.isEmpty ? 0 : words.map((w) => w.length).reduce((a, b) => a + b) / words.length;
    final uniqueWords = words.toSet().length;
    final wordDiversity = words.isEmpty ? 0 : uniqueWords / words.length;
    
    final complexityScore = (avgWordLength / 10.0) * 0.4 + wordDiversity * 0.6;
    return complexityScore.clamp(0.0, 1.0);
  }
}