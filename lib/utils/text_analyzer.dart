import 'text_analyzer_interface.dart';
import 'native_text_analyzer.dart';
import 'web_text_analyzer.dart';
import 'simple_text_analyzer.dart';
import 'robust_text_analyzer.dart';
import 'settings_manager.dart';

class TextAnalyzer {
  static TextAnalyzerInterface? _instance;
  
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
    // Decide backend based on detection sensitivity level
    return _routeAnalyze(text);
  }

  static Future<Map<String, double>> _routeAnalyze(String text) async {
    try {
      final level = await SettingsManager.getSensitivityLevel();
      if (level <= 5) {
        // sensitivity <= 50% -> use simple fast analyzer
        return SimpleTextAnalyzer().analyzeText(text);
      }
      if (level >= 8) {
        // sensitivity >= 80% -> use robust analyzer
        return RobustTextAnalyzer().analyzeText(text);
      }
      // default: use the platform instance
      return instance.analyzeText(text);
    } catch (e) {
      return instance.analyzeText(text);
    }
  }
}