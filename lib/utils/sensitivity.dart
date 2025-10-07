import 'settings_manager.dart';

// Map sensitivity level 1..10 to a target percent range 50..100
double _levelToTargetPercent(int level) {
  final l = level.clamp(1, 10);
  // linear mapping: 1 -> 50.0, 10 -> 100.0
  return 50.0 + (l - 1) * (50.0 / 9.0);
}

Future<Map<String, double>> applySensitivityToResult(Map<String, double> result) async {
  final level = await SettingsManager.getSensitivityLevel();
  final target = _levelToTargetPercent(level);

  final originalAi = (result['ai_detection'] ?? 0.0).clamp(0.0, 100.0);

  // weight from 0.1 (level 1) .. 1.0 (level 10)
  final weight = (level.clamp(1, 10)) / 10.0;

  // Move the raw score towards the target by the weight
  final adjustedAi = (originalAi + (target - originalAi) * weight).clamp(0.0, 100.0);
  final adjustedHuman = (100.0 - adjustedAi).clamp(0.0, 100.0);

  return {
    'ai_detection': adjustedAi,
    'human_written': adjustedHuman,
  };
}