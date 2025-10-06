import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'text_analyzer_interface.dart';

class MemoryConfig {
  // Konfigurasi untuk device 3GB RAM
  static const int MAX_TEXT_LENGTH = 10000; // Maksimum karakter yang diproses dalam satu waktu
  static const int CHUNK_SIZE = 500; // Ukuran chunk yang optimal untuk 3GB RAM
  static const int MAX_CACHE_ITEMS = 20; // Batasi cache untuk menghemat RAM
  static const int MAX_THREADS = 2; // Optimal untuk 3GB RAM
}

class LowMemoryCache<K, V> {
  final int maxSize;
  final Map<K, V> _cache = {};
  final Queue<K> _accessOrder = Queue();

  LowMemoryCache({this.maxSize = MemoryConfig.MAX_CACHE_ITEMS});

  V? get(K key) {
    final value = _cache[key];
    if (value != null) {
      _accessOrder.remove(key);
      _accessOrder.addLast(key);
    }
    return value;
  }

  void put(K key, V value) {
    if (_cache.length >= maxSize) {
      final oldest = _accessOrder.removeFirst();
      _cache.remove(oldest);
    }
    _cache[key] = value;
    _accessOrder.addLast(key);
  }

  void clear() {
    _cache.clear();
    _accessOrder.clear();
  }
}

class OptimizedNativeAnalyzer implements TextAnalyzerInterface {
  static final OptimizedNativeAnalyzer _instance = OptimizedNativeAnalyzer._internal();
  factory OptimizedNativeAnalyzer() => _instance;

  final LowMemoryCache<String, AnalysisResult> _cache = LowMemoryCache();
  bool _isInitialized = false;
  
  OptimizedNativeAnalyzer._internal();

  @override
  Future<Map<String, double>> analyzeText(String text) async {
    if (!_isInitialized) {
      await _initialize();
    }

    try {
      final result = await _analyzeWithMemoryOptimization(text);
      return {
        'ai_detection': result.aiProbability * 100,
        'human_written': result.humanProbability * 100,
      };
    } catch (e) {
      print('Analysis error: $e');
      rethrow;
    }
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    
    try {
      // Inisialisasi dengan pengaturan memori minimal
      await compute(_initializeInIsolate, null);
      _isInitialized = true;
    } catch (e) {
      print('Initialization error: $e');
      rethrow;
    }
  }

  static Future<void> _initializeInIsolate(_) async {
    // Inisialisasi di isolate terpisah untuk menghindari memory spike
  }

  Future<AnalysisResult> _analyzeWithMemoryOptimization(String text) async {
    // Check cache first
    final cached = _cache.get(text);
    if (cached != null) return cached;

    // Jika teks terlalu panjang, proses dalam chunks
    if (text.length > MemoryConfig.MAX_TEXT_LENGTH) {
      return await _processLongText(text);
    }

    // Untuk teks pendek, proses langsung
    return await _processShortText(text);
  }

  Future<AnalysisResult> _processLongText(String text) async {
    final chunks = _splitIntoChunks(text);
    double totalAiScore = 0.0;
    int processedChunks = 0;

    // Proses setiap chunk dalam isolate terpisah
    for (final chunk in chunks) {
      final result = await compute(_analyzeChunk, chunk);
      totalAiScore += result.aiProbability;
      processedChunks++;

      // Bersihkan memori setiap beberapa chunk
      if (processedChunks % 5 == 0) {
        await _cleanupMemory();
      }
    }

    final avgAiScore = totalAiScore / chunks.length;
    final result = AnalysisResult(
      aiProbability: avgAiScore,
      humanProbability: 1.0 - avgAiScore,
    );

    // Cache hanya untuk teks yang tidak terlalu panjang
    if (text.length <= MemoryConfig.MAX_TEXT_LENGTH * 2) {
      _cache.put(text, result);
    }

    return result;
  }

  Future<AnalysisResult> _processShortText(String text) async {
    final result = await compute(_analyzeChunk, text);
    _cache.put(text, result);
    return result;
  }

  static AnalysisResult _analyzeChunk(String chunk) {
    // Analisis dalam isolate terpisah untuk efisiensi memori
    double aiScore = 0.0;
    
    // Implementasi analisis yang memory-efficient
    aiScore += _analyzeTextPatterns(chunk) * 0.4;
    aiScore += _analyzeLanguageStructure(chunk) * 0.3;
    aiScore += _analyzeStatisticalPatterns(chunk) * 0.3;

    return AnalysisResult(
      aiProbability: aiScore.clamp(0.0, 1.0),
      humanProbability: (1.0 - aiScore).clamp(0.0, 1.0),
    );
  }

  List<String> _splitIntoChunks(String text) {
    final chunks = <String>[];
    for (var i = 0; i < text.length; i += MemoryConfig.CHUNK_SIZE) {
      final end = (i + MemoryConfig.CHUNK_SIZE < text.length) 
          ? i + MemoryConfig.CHUNK_SIZE 
          : text.length;
      chunks.add(text.substring(i, end));
    }
    return chunks;
  }

  Future<void> _cleanupMemory() async {
    // Bersihkan cache jika memori mulai penuh
    if (_cache._cache.length > MemoryConfig.MAX_CACHE_ITEMS / 2) {
      _cache.clear();
    }
    // Tunggu GC selesai
    await Future.delayed(const Duration(milliseconds: 100));
  }

  static double _analyzeTextPatterns(String text) {
    // Implementasi ringan untuk analisis pola teks
    final words = text.split(RegExp(r'\s+'));
    if (words.isEmpty) return 0.0;

    final wordFreq = <String, int>{};
    for (final word in words) {
      wordFreq[word] = (wordFreq[word] ?? 0) + 1;
    }

    // Hitung repetisi kata
    final repetitionScore = wordFreq.values
        .where((freq) => freq > 1)
        .length / wordFreq.length;

    return repetitionScore.clamp(0.0, 1.0);
  }

  static double _analyzeLanguageStructure(String text) {
    // Analisis struktur bahasa yang memory-efficient
    final sentences = text.split(RegExp(r'[.!?]+\s*'));
    if (sentences.isEmpty) return 0.0;

    var structureScore = 0.0;
    var prevLength = 0;
    var consistentStructure = 0;

    for (final sentence in sentences) {
      final length = sentence.split(RegExp(r'\s+')).length;
      if (prevLength > 0 && (length - prevLength).abs() <= 2) {
        consistentStructure++;
      }
      prevLength = length;
    }

    structureScore = consistentStructure / (sentences.length - 1);
    return structureScore.clamp(0.0, 1.0);
  }

  static double _analyzeStatisticalPatterns(String text) {
    // Analisis statistik yang ringan
    final words = text.split(RegExp(r'\s+'));
    if (words.length < 2) return 0.0;

    var transitionScore = 0.0;
    for (var i = 0; i < words.length - 1; i++) {
      if (_isCommonTransition(words[i], words[i + 1])) {
        transitionScore += 1.0;
      }
    }

    return (transitionScore / (words.length - 1)).clamp(0.0, 1.0);
  }

  static bool _isCommonTransition(String word1, String word2) {
    // Daftar transisi kata yang sering digunakan AI
    final commonTransitions = {
      'namun': true,
      'sehingga': true,
      'oleh': true,
      'karena': true,
      'dengan': true,
    };

    return commonTransitions[word2.toLowerCase()] ?? false;
  }
}