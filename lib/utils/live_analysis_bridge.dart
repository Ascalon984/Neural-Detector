import 'dart:async';

class LiveAnalysis {
  final DateTime time;
  final double aiPercent;

  LiveAnalysis(this.time, this.aiPercent);
}

/// Simple in-memory bridge for recent live analyses from the Text Editor.
/// HomeScreen can subscribe to [stream] or call [recent] to aggregate.
class LiveAnalysisBridge {
  static final LiveAnalysisBridge _instance = LiveAnalysisBridge._internal();
  factory LiveAnalysisBridge() => _instance;
  LiveAnalysisBridge._internal();

  final _controller = StreamController<LiveAnalysis>.broadcast();
  final List<LiveAnalysis> _recent = [];

  Stream<LiveAnalysis> get stream => _controller.stream;

  /// Pushes a new analysis result (call from TextEditor after analysis).
  void push(double aiPercent) {
    final entry = LiveAnalysis(DateTime.now(), aiPercent);
    _recent.insert(0, entry);
    // keep bounded history
    if (_recent.length > 1000) _recent.removeLast();
    // debug print to help trace runtime event flow
    try {
      // ignore: avoid_print
      print('[LiveAnalysisBridge] push: aiPercent=${aiPercent.toStringAsFixed(2)} time=${entry.time.toIso8601String()}');
    } catch (_) {}
    _controller.add(entry);
  }

  /// Unmodifiable snapshot of recent live analyses (newest first)
  List<LiveAnalysis> get recent => List.unmodifiable(_recent);

  void dispose() {
    _controller.close();
  }
}
