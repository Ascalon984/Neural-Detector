import 'dart:async';

import '../utils/history_manager.dart';
import '../models/scan_history.dart';

class SearchIndex {
  // Simple in-memory index built from HistoryManager
  static List<ScanHistory> _cache = [];
  static DateTime _lastLoad = DateTime.fromMillisecondsSinceEpoch(0);

  static Future<void> _ensureLoaded() async {
    if (_cache.isEmpty || DateTime.now().difference(_lastLoad).inSeconds > 5) {
      _cache = await HistoryManager.loadHistory();
      _lastLoad = DateTime.now();
    }
  }

  // Simple suggestions: prefix match on fileName and words in fileName
  // Respects source and minConfidence filters
  static Future<List<String>> searchSuggestions(String q, Map<String, dynamic> filters, {int limit = 6}) async {
    await _ensureLoaded();
    final term = q.trim().toLowerCase();
    if (term.isEmpty) return [];

    final source = (filters['source'] as String?) ?? 'all';
    final minConf = (filters['minConfidence'] as int?) ?? 50;

    final results = <MapEntry<String, int>>[]; // suggestion -> score

    for (final item in _cache) {
      if (source != 'all' && item.source != source) continue;
      final conf = item.aiDetection; // assume aiDetection is score-ish
      if (conf < minConf) continue;

      final name = item.fileName.toLowerCase();
      if (name.startsWith(term)) {
        results.add(MapEntry(item.fileName, 100));
        continue;
      }

      // words
      final words = name.split(RegExp(r'[^a-z0-9]+'));
      for (final w in words) {
        if (w.startsWith(term)) {
          results.add(MapEntry(item.fileName, 80));
          break;
        }
      }
    }

    // sort by score desc and dedupe by fileName
    results.sort((a, b) => b.value.compareTo(a.value));
    final seen = <String>{};
    final suggestions = <String>[];
    for (final e in results) {
      if (seen.contains(e.key)) continue;
      seen.add(e.key);
      suggestions.add(e.key);
      if (suggestions.length >= limit) break;
    }

    return suggestions;
  }

  // Full search: returns ScanHistory list filtered and optionally sorted
  static Future<List<ScanHistory>> fullSearch(String q, Map<String, dynamic> filters) async {
    await _ensureLoaded();
    final term = q.trim().toLowerCase();

    final source = (filters['source'] as String?) ?? 'all';
    final minConf = (filters['minConfidence'] as int?) ?? 50;
    final onlyAi = (filters['onlyAi'] as bool?) ?? false;
    final sort = (filters['sort'] as String?) ?? 'relevance';

    List<ScanHistory> candidates = [];

    for (final item in _cache) {
      if (source != 'all' && item.source != source) continue;
      if (item.aiDetection < minConf) continue;
      if (onlyAi && item.aiDetection < 50) continue; // heuristic

      if (term.isEmpty) {
        candidates.add(item);
      } else {
        final hay = (item.fileName + ' ' + item.date).toLowerCase();
        if (hay.contains(term)) candidates.add(item);
      }
    }

    // Sorting
    if (sort == 'newest') {
      candidates.sort((a, b) => b.date.compareTo(a.date));
    } else if (sort == 'confidence') {
      candidates.sort((a, b) => b.aiDetection.compareTo(a.aiDetection));
    } else {
      // basic relevance: contains earlier + aiDetection
      candidates.sort((a, b) {
        final aHas = (a.fileName + ' ' + a.date).toLowerCase().contains(term);
        final bHas = (b.fileName + ' ' + b.date).toLowerCase().contains(term);
        if (aHas && !bHas) return -1;
        if (!aHas && bHas) return 1;
        return b.aiDetection.compareTo(a.aiDetection);
      });
    }

    return candidates;
  }
}
