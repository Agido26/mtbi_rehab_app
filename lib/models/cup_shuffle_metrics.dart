import 'game_result.dart';

/// Typed metrics for Cup Shuffle sessions.
/// Reads from GameResult.metadata — no DB schema changes.
class CupShuffleMetrics {
  final String difficulty;
  final int cupsCount;
  final int roundsCompleted;
  final int roundsTotal;
  final List<bool> roundResults;
  final List<double> responseTimes;
  final List<String> errorPositions;
  final double fatigueIndex;

  const CupShuffleMetrics({
    required this.difficulty,
    required this.cupsCount,
    required this.roundsCompleted,
    required this.roundsTotal,
    required this.roundResults,
    required this.responseTimes,
    required this.errorPositions,
    required this.fatigueIndex,
  });

  double get accuracy => roundResults.isEmpty
      ? 0
      : roundResults.where((r) => r).length / roundResults.length;

  double get averageResponseTime => responseTimes.isEmpty
      ? 0
      : responseTimes.reduce((a, b) => a + b) / responseTimes.length;

  bool get showsFatigue => fatigueIndex > 1.2;

  /// هل عندنا بيانات كافية للـ FI؟
  bool get hasFatigueData => fatigueIndex > 0;

  String get dominantErrorSide {
    if (errorPositions.isEmpty) return 'none';
    final counts = <String, int>{};
    for (final p in errorPositions) {
      counts[p] = (counts[p] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  factory CupShuffleMetrics.fromJson(Map<String, dynamic> json) {
    return CupShuffleMetrics(
      difficulty: (json['difficulty'] as String?) ?? 'unknown',
      cupsCount: (json['cupsCount'] as int?) ?? 3,
      roundsCompleted: (json['roundsCompleted'] as int?) ?? 0,
      roundsTotal: (json['roundsTotal'] as int?) ?? 0,
      roundResults: (json['roundResults'] as List<dynamic>?)
              ?.map((e) => e == true)
              .toList() ??
          [],
      responseTimes: (json['responseTimes'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      errorPositions: (json['errorPositions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      fatigueIndex: (json['fatigueIndex'] as num?)?.toDouble() ?? 1.0,
    );
  }

  factory CupShuffleMetrics.fromResult(GameResult result) =>
      CupShuffleMetrics.fromJson(result.metadata ?? {});
}
