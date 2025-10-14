// Lightweight chart models used by HomeScreen for aggregation and rendering.
class ChartDataPoint {
  final DateTime timestamp;
  final double aiPercentage;
  final int scanCount;

  ChartDataPoint({
    required this.timestamp,
    required this.aiPercentage,
    required this.scanCount,
  });
}

class ChartStatistics {
  final List<ChartDataPoint> dataPoints;
  final double averageAiPercentage;
  final int totalScans;
  final String period;

  ChartStatistics({
    required this.dataPoints,
    required this.averageAiPercentage,
    required this.totalScans,
    required this.period,
  });

  factory ChartStatistics.empty(String period) {
    return ChartStatistics(
      dataPoints: <ChartDataPoint>[],
      averageAiPercentage: 0.0,
      totalScans: 0,
      period: period,
    );
  }
}
