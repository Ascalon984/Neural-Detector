import 'dart:math' as math;
import 'dart:async';
import 'text_analyzer_interface.dart';

class WebTextAnalyzer implements TextAnalyzerInterface {
  static final WebTextAnalyzer _instance = WebTextAnalyzer._internal();
  factory WebTextAnalyzer() => _instance;

  final _random = math.Random();
  
  WebTextAnalyzer._internal();

  @override
  Future<Map<String, double>> analyzeText(String text) async {
    if (text.isEmpty) {
      return {'ai_detection': 0.0, 'human_written': 100.0};
    }

    final result = await _analyzeTextDetailed(text);
    return {
      'ai_detection': result.aiProbability * 100,
      'human_written': result.humanProbability * 100,
    };
  }

  Future<AnalysisResult> _analyzeTextDetailed(String text) async {
    double aiScore = 0.0;
    
    // Analisis kompleksitas teks (30%)
    aiScore += _analyzeTextComplexity(text) * 0.3;
    
    // Analisis pola bahasa Indonesia (40%)
    aiScore += await _analyzeIndonesianPatterns(text) * 0.4;
    
    // Analisis struktur kalimat (30%)
    aiScore += _analyzeSentenceStructure(text) * 0.3;
    
    // Tambahkan variasi kecil untuk hasil yang lebih natural
    aiScore *= (0.95 + _random.nextDouble() * 0.1);
    
    // Pastikan nilai antara 0 dan 1
    aiScore = aiScore.clamp(0.0, 1.0);
    
    return AnalysisResult(
      aiProbability: aiScore,
      humanProbability: 1.0 - aiScore,
    );
  }

  double _analyzeTextComplexity(String text) {
    final words = text.split(RegExp(r'\s+'));
    if (words.isEmpty) return 0.0;

    // Hitung rata-rata panjang kata
    final avgWordLength = words.fold<int>(0, (sum, word) => sum + word.length) / words.length;
    
    // Hitung keunikan kata (rasio kata unik)
    final uniqueWords = words.toSet().length / words.length;
    
    // Deteksi penggunaan kata formal yang berlebihan
    final formalWords = _countFormalIndonesianWords(words);
    
    return ((avgWordLength - 4) / 4 * 0.4 + // Panjang kata
            (1 - uniqueWords) * 0.3 + // Keunikan kata
            (formalWords / words.length) * 0.3 // Formalitas
           ).clamp(0.0, 1.0);
  }

  Future<double> _analyzeIndonesianPatterns(String text) async {
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    double patternScore = 0.0;

    // Cek pola kata hubung yang tidak natural
    patternScore += _analyzeConnectorWords(words) * 0.3;

    // Cek penggunaan imbuhan yang tidak wajar
    patternScore += _analyzeAffixPatterns(words) * 0.4;

    // Cek konsistensi penggunaan bahasa formal/informal
    patternScore += _analyzeLanguageConsistency(text) * 0.3;

    return patternScore.clamp(0.0, 1.0);
  }

  double _countFormalIndonesianWords(List<String> words) {
    final formalPatterns = {
      'berdasarkan', 'dikarenakan', 'sebagaimana', 'oleh karena itu',
      'selanjutnya', 'sehubungan', 'adapun', 'merupakan', 'tersebut'
    };
    
    int count = 0;
    for (final word in words) {
      if (formalPatterns.contains(word.toLowerCase())) {
        count++;
      }
    }
    
    return count.toDouble();
  }

  double _analyzeConnectorWords(List<String> words) {
    final commonConnectors = {
      'namun': 0,
      'akan tetapi': 0,
      'sehingga': 0,
      'oleh karena itu': 0,
      'dengan demikian': 0,
    };
    
    for (var i = 0; i < words.length; i++) {
      for (var connector in commonConnectors.keys) {
        if (words.skip(i).take(connector.split(' ').length)
            .join(' ') == connector) {
          commonConnectors[connector] = (commonConnectors[connector] ?? 0) + 1;
        }
      }
    }
    
    // Hitung rasio penggunaan kata penghubung
    final totalConnectors = commonConnectors.values.fold<int>(0, (a, b) => a + b);
    return (totalConnectors / words.length).clamp(0.0, 1.0);
  }

  double _analyzeAffixPatterns(List<String> words) {
    final commonAffixes = {
      'me': 0, 'di': 0, 'ber': 0, 'ter': 0, 'pe': 0, 'per': 0
    };
    
    for (final word in words) {
      for (final prefix in commonAffixes.keys) {
        if (word.startsWith(prefix)) {
          commonAffixes[prefix] = (commonAffixes[prefix] ?? 0) + 1;
        }
      }
    }
    
    // Hitung keseimbangan penggunaan imbuhan
    final affixCounts = commonAffixes.values.toList();
    if (affixCounts.isEmpty) return 0.0;
    
    final avgAffixUse = affixCounts.reduce((a, b) => a + b) / affixCounts.length;
    final variance = affixCounts
        .map((count) => math.pow(count - avgAffixUse, 2))
        .reduce((a, b) => a + b) / affixCounts.length;
    
    // Semakin seragam penggunaan imbuhan (variance rendah), semakin tinggi kemungkinan AI
    return (1.0 - (math.sqrt(variance) / avgAffixUse)).clamp(0.0, 1.0);
  }

  double _analyzeLanguageConsistency(String text) {
    final formalCount = RegExp(r'\b(tersebut|adapun|yakni|sebagaimana)\b')
        .allMatches(text.toLowerCase())
        .length;
        
    final informalCount = RegExp(r'\b(nih|dong|sih|deh|kan)\b')
        .allMatches(text.toLowerCase())
        .length;
    
    // Mixing formal dan informal adalah indikasi teks manusia
    final total = formalCount + informalCount;
    if (total == 0) return 0.5;
    
    // Semakin ekstrem ke salah satu sisi, semakin mungkin AI
    return (math.max(formalCount, informalCount) / total).clamp(0.0, 1.0);
  }

  double _analyzeSentenceStructure(String text) {
    final sentences = text.split(RegExp(r'[.!?]+\s*'));
    if (sentences.length < 2) return 0.0;
    
    final lengths = sentences.map((s) => s.split(RegExp(r'\s+')).length).toList();
    if (lengths.isEmpty) return 0.0;
    final avg = lengths.fold<int>(0, (a, b) => a + b) / lengths.length;
    
    // Hitung variance panjang kalimat
    final variance = lengths
        .map((l) => math.pow(l - avg, 2))
        .reduce((a, b) => a + b) / lengths.length;
    
    // Kalimat yang terlalu seragam panjangnya menunjukkan AI
    return (1.0 - (math.sqrt(variance) / avg)).clamp(0.0, 1.0);
  }
}