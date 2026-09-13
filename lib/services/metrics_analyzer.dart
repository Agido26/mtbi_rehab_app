import '../models/game_result.dart';

/// ============================================================
/// Metrics Analyzer
/// يستخرج المؤشرات الإكلينيكية من الـ GameResults
/// كل الـ logic التحليلي هنا — منفصل تماماً عن UI
/// ============================================================

class MetricsAnalyzer {
  /// تحليل عام لمريض (كل الألعاب)
  static PatientSummary analyzePatient(Map<GameType, List<GameResult>> byGame) {
    int totalSessions = 0;
    int gamesPlayed = 0;
    for (final list in byGame.values) {
      if (list.isNotEmpty) {
        totalSessions += list.length;
        gamesPlayed++;
      }
    }
    return PatientSummary(
      totalSessions: totalSessions,
      gamesPlayed: gamesPlayed,
    );
  }

  /// ============================================================
  /// SHAPE MATCH ANALYSIS
  /// ============================================================
  static ShapeMatchMetrics analyzeShapeMatch(List<GameResult> results) {
    if (results.isEmpty) return ShapeMatchMetrics.empty();

    // ترتيب من الأقدم للأحدث
    final sorted = List<GameResult>.from(results)
      ..sort((a, b) => a.playedAt.compareTo(b.playedAt));

    final accuracyTrend = <TrendPoint>[];
    final avgTimeTrend = <TrendPoint>[];
    final peeksTrend = <TrendPoint>[];
    final fatigueScores = <double>[];
    double totalAccuracySum = 0;
    int totalRounds = 0;

    for (int i = 0; i < sorted.length; i++) {
      final r = sorted[i];
      final meta = r.metadata ?? {};
      final roundAccs = (meta['roundAccuracies'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [];
      final roundTimes = (meta['roundTimes'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [];
      final peeks = (meta['peeksUsed'] as num?)?.toInt() ?? 0;

      // دقة الجلسة
      final sessionAcc = roundAccs.isEmpty
          ? 0.0
          : roundAccs.reduce((a, b) => a + b) / roundAccs.length;
      accuracyTrend
          .add(TrendPoint(x: i.toDouble(), y: sessionAcc, label: 'S${i + 1}'));
      totalAccuracySum += sessionAcc;
      totalRounds += roundAccs.length;

      // متوسط زمن الجولة
      final avgTime = roundTimes.isEmpty
          ? 0.0
          : roundTimes.reduce((a, b) => a + b) / roundTimes.length;
      avgTimeTrend
          .add(TrendPoint(x: i.toDouble(), y: avgTime, label: 'S${i + 1}'));

      // Peeks used
      peeksTrend.add(
          TrendPoint(x: i.toDouble(), y: peeks.toDouble(), label: 'S${i + 1}'));

      // 🧠 Fatigue score: دقة النصف الثاني vs الأول (سلبي = إرهاق)
      if (roundAccs.length >= 2) {
        final half = roundAccs.length ~/ 2;
        final firstHalf = roundAccs.sublist(0, half);
        final secondHalf = roundAccs.sublist(half);
        final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
        final secondAvg =
            secondHalf.reduce((a, b) => a + b) / secondHalf.length;
        fatigueScores.add(secondAvg - firstAvg); // سالب = تعب
      }
    }

    // 📈 التحسن: آخر 3 جلسات vs أول 3
    double improvement = 0;
    if (sorted.length >= 6) {
      final first3 = accuracyTrend.take(3).map((p) => p.y).toList();
      final last3 =
          accuracyTrend.skip(sorted.length - 3).map((p) => p.y).toList();
      final firstAvg = first3.reduce((a, b) => a + b) / first3.length;
      final lastAvg = last3.reduce((a, b) => a + b) / last3.length;
      improvement = lastAvg - firstAvg;
    } else if (sorted.length >= 2) {
      improvement = accuracyTrend.last.y - accuracyTrend.first.y;
    }

    final avgFatigue = fatigueScores.isEmpty
        ? 0.0
        : fatigueScores.reduce((a, b) => a + b) / fatigueScores.length;

    return ShapeMatchMetrics(
      sessionsCount: sorted.length,
      avgAccuracy: totalRounds == 0 ? 0 : totalAccuracySum / sorted.length,
      accuracyTrend: accuracyTrend,
      avgTimeTrend: avgTimeTrend,
      peeksTrend: peeksTrend,
      fatigueScore: avgFatigue,
      improvementPct: (improvement * 100).roundToDouble(),
      lastPlayed: sorted.last.playedAt,
    );
  }

  /// ============================================================
  /// CUP SHUFFLE ANALYSIS
  /// ============================================================
  static CupShuffleMetrics analyzeCupShuffle(List<GameResult> results) {
    if (results.isEmpty) return CupShuffleMetrics.empty();

    final sorted = List<GameResult>.from(results)
      ..sort((a, b) => a.playedAt.compareTo(b.playedAt));

    final accuracyTrend = <TrendPoint>[];
    final responseTimeTrend = <TrendPoint>[];
    final variabilityTrend = <TrendPoint>[];
    final spatialErrors = <String, int>{'left': 0, 'center': 0, 'right': 0};
    double totalRTSum = 0;
    int totalRTCount = 0;

    for (int i = 0; i < sorted.length; i++) {
      final r = sorted[i];
      final meta = r.metadata ?? {};

      // Accuracy
      accuracyTrend.add(TrendPoint(
        x: i.toDouble(),
        y: r.accuracy,
        label: 'S${i + 1}',
      ));

      // Response times
      final rts = (meta['responseTimes'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [];
      if (rts.isNotEmpty) {
        final avgRT = rts.reduce((a, b) => a + b) / rts.length;
        responseTimeTrend
            .add(TrendPoint(x: i.toDouble(), y: avgRT, label: 'S${i + 1}'));
        totalRTSum += avgRT;
        totalRTCount++;

        // تذبذب الاستجابة (std deviation) — marker mTBI معروف
        final variance = rts
                .map((rt) => (rt - avgRT) * (rt - avgRT))
                .reduce((a, b) => a + b) /
            rts.length;
        variabilityTrend.add(TrendPoint(
          x: i.toDouble(),
          y: variance > 0 ? variance * 100 : 0, // normalized
          label: 'S${i + 1}',
        ));
      }

      // Spatial errors
      final errors = (meta['errorPositions'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      for (final pos in errors) {
        if (pos == 'left')
          spatialErrors['left'] = (spatialErrors['left'] ?? 0) + 1;
        if (pos == 'center')
          spatialErrors['center'] = (spatialErrors['center'] ?? 0) + 1;
        if (pos == 'right')
          spatialErrors['right'] = (spatialErrors['right'] ?? 0) + 1;
      }
    }

    // Intra-Session Variability (ISV) — متوسط تذبذب كل الجلسات
    final avgISV = variabilityTrend.isEmpty
        ? 0.0
        : variabilityTrend.map((p) => p.y).reduce((a, b) => a + b) /
            variabilityTrend.length;

    // Spatial bias: لو يسار >> يمين بشكل واضح = potential neglect
    final leftErrors = spatialErrors['left'] ?? 0;
    final rightErrors = spatialErrors['right'] ?? 0;
    final spatialBias = rightErrors > 0
        ? (leftErrors / rightErrors)
        : (leftErrors > 0 ? 99.0 : 1.0);
    final hasSpatialBias = spatialBias > 2.0 && leftErrors + rightErrors >= 3;

    return CupShuffleMetrics(
      sessionsCount: sorted.length,
      avgAccuracy: sorted.isEmpty
          ? 0
          : sorted.map((r) => r.accuracy).reduce((a, b) => a + b) /
              sorted.length,
      accuracyTrend: accuracyTrend,
      responseTimeTrend: responseTimeTrend,
      avgResponseTime: totalRTCount == 0 ? 0 : totalRTSum / totalRTCount,
      intraSessionVariability: avgISV,
      spatialErrors: spatialErrors,
      hasSpatialBias: hasSpatialBias,
      spatialBiasRatio: spatialBias,
      lastPlayed: sorted.last.playedAt,
    );
  }
}

// ============================================================
// Data classes
// ============================================================

class TrendPoint {
  final double x;
  final double y;
  final String label;
  TrendPoint({required this.x, required this.y, required this.label});
}

class PatientSummary {
  final int totalSessions;
  final int gamesPlayed;
  PatientSummary({required this.totalSessions, required this.gamesPlayed});
}

class ShapeMatchMetrics {
  final int sessionsCount;
  final double avgAccuracy;
  final List<TrendPoint> accuracyTrend;
  final List<TrendPoint> avgTimeTrend;
  final List<TrendPoint> peeksTrend;
  final double fatigueScore; // سالب = إرهاق داخل الجلسة
  final double improvementPct; // % تحسن من البداية للنهاية
  final DateTime? lastPlayed;

  ShapeMatchMetrics({
    required this.sessionsCount,
    required this.avgAccuracy,
    required this.accuracyTrend,
    required this.avgTimeTrend,
    required this.peeksTrend,
    required this.fatigueScore,
    required this.improvementPct,
    this.lastPlayed,
  });

  factory ShapeMatchMetrics.empty() => ShapeMatchMetrics(
        sessionsCount: 0,
        avgAccuracy: 0,
        accuracyTrend: [],
        avgTimeTrend: [],
        peeksTrend: [],
        fatigueScore: 0,
        improvementPct: 0,
      );
}

class CupShuffleMetrics {
  final int sessionsCount;
  final double avgAccuracy;
  final List<TrendPoint> accuracyTrend;
  final List<TrendPoint> responseTimeTrend;
  final double avgResponseTime;
  final double intraSessionVariability;
  final Map<String, int> spatialErrors;
  final bool hasSpatialBias;
  final double spatialBiasRatio;
  final DateTime? lastPlayed;

  CupShuffleMetrics({
    required this.sessionsCount,
    required this.avgAccuracy,
    required this.accuracyTrend,
    required this.responseTimeTrend,
    required this.avgResponseTime,
    required this.intraSessionVariability,
    required this.spatialErrors,
    required this.hasSpatialBias,
    required this.spatialBiasRatio,
    this.lastPlayed,
  });

  factory CupShuffleMetrics.empty() => CupShuffleMetrics(
        sessionsCount: 0,
        avgAccuracy: 0,
        accuracyTrend: [],
        responseTimeTrend: [],
        avgResponseTime: 0,
        intraSessionVariability: 0,
        spatialErrors: {'left': 0, 'center': 0, 'right': 0},
        hasSpatialBias: false,
        spatialBiasRatio: 1.0,
      );
}
