import 'dart:collection';

/// Simple in-memory LRU-style cache for analysis results.
class AnalysisCache {
  final int capacity;
  final LinkedHashMap<String, Map<String, double>> _cache = LinkedHashMap();

  AnalysisCache({this.capacity = 200});

  Map<String, double>? get(String key) {
    final v = _cache.remove(key);
    if (v != null) _cache[key] = v; // move to end (most recently used)
    return v;
  }

  void set(String key, Map<String, double> value) {
    if (_cache.length >= capacity) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  void clear() => _cache.clear();
}
