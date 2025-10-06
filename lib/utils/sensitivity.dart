import 'dart:math' as math;
import 'settings_manager.dart';

double _sensitivityMultiplier(int level) {
  final l = level.clamp(1, 10);
  return 1.0 + (l - 5) / 20.0; // level 1 -> 0.8, level 10 -> 1.25
}

Future<Map<String, double>> applySensitivityToResult(Map<String, double> result) async {
  final level = await SettingsManager.getSensitivityLevel();
  final mult = _sensitivityMultiplier(level);

  final ai = (result['ai_detection'] ?? 0.0);
  double aiAdj = ai * mult;
  aiAdj = math.max(0.0, math.min(100.0, aiAdj));
  final humanAdj = math.max(0.0, math.min(100.0, 100.0 - aiAdj));

  return {
    'ai_detection': aiAdj,
    'human_written': humanAdj,
  };
}
