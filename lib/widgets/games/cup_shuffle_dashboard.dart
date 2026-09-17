import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/game_result.dart';

/// ============================================================
/// Cup Shuffle Dashboard (Patient view only)
/// عرض تقدم اللاعب — بدون محتوى إكلينيكي (الطبيب عنده صفحة منفصلة)
/// ============================================================
class CupShuffleDashboard extends StatelessWidget {
  final List<GameResult> results;
  const CupShuffleDashboard({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();

    final sorted = List<GameResult>.from(results)
      ..sort((a, b) => a.playedAt.compareTo(b.playedAt));

    final totalScore = results.fold<int>(0, (s, r) => s + r.score);
    final avgAccuracy = results.isEmpty
        ? 0.0
        : results.map((r) => r.accuracy).reduce((a, b) => a + b) /
            results.length;
    final bestScore =
        results.map((r) => r.score).reduce((a, b) => a > b ? a : b);

    // Accuracy spots
    final accSpots = <FlSpot>[];
    for (int i = 0; i < sorted.length; i++) {
      accSpots.add(FlSpot(i.toDouble(), sorted[i].accuracy * 100));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_drink, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 6),
                    Text('Cup Shuffle',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700])),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text('${sorted.length} sessions',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          // Stats row
          Row(
            children: [
              _buildMiniCard('Total Score', totalScore.toString(),
                  Icons.emoji_events, Colors.blue),
              const SizedBox(width: 8),
              _buildMiniCard(
                  'Avg Accuracy',
                  '${(avgAccuracy * 100).toStringAsFixed(0)}%',
                  Icons.check_circle_outline,
                  Colors.green),
              const SizedBox(width: 8),
              _buildMiniCard(
                  'Best Score', bestScore.toString(), Icons.star, Colors.amber),
            ],
          ),
          const SizedBox(height: 16),
          // Accuracy chart
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Accuracy Over Sessions',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: accSpots.length < 2
                        ? Center(
                            child: Text(
                                'Play at least 2 sessions to see the trend',
                                style: TextStyle(color: Colors.grey[500])))
                        : LineChart(
                            LineChartData(
                              minY: 0,
                              maxY: 100,
                              gridData: const FlGridData(
                                  show: true, drawVerticalLine: false),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 32,
                                    getTitlesWidget: (v, _) => Text(
                                        '${v.toInt()}%',
                                        style: const TextStyle(fontSize: 10)),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 24,
                                    getTitlesWidget: (v, _) => Text(
                                        'S${v.toInt() + 1}',
                                        style: const TextStyle(fontSize: 10)),
                                  ),
                                ),
                                topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: accSpots,
                                  isCurved: true,
                                  color: Colors.blue,
                                  barWidth: 3,
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter: (s, _, __, ___) =>
                                        FlDotCirclePainter(
                                            radius: 4, color: Colors.blue),
                                  ),
                                  belowBarData: BarAreaData(
                                      show: true,
                                      color: Colors.blue.withOpacity(0.1)),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Last 3 sessions summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recent Sessions',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...sorted.reversed.take(3).map((r) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(Icons.history,
                            size: 18, color: Colors.grey[600]),
                        title: Text(
                          DateFormat('EEE, MMM d').format(r.playedAt),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Score ${r.score} • Acc ${(r.accuracy * 100).toStringAsFixed(0)}% • ${r.durationSeconds}s',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
