import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/game_result.dart';
import '../../../services/metrics_analyzer.dart';
import '../charts/trend_line_chart.dart';

class ShapeMatchDashboard extends StatelessWidget {
  final List<GameResult> results;
  const ShapeMatchDashboard({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    final metrics = MetricsAnalyzer.analyzeShapeMatch(results);

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
                  color: Colors.purple[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.extension, size: 16, color: Colors.purple[700]),
                    const SizedBox(width: 6),
                    Text(
                      'Shape Match',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${metrics.sessionsCount} sessions',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const Spacer(),
              if (metrics.lastPlayed != null)
                Text(
                  'Last: ${DateFormat('MMM d').format(metrics.lastPlayed!)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Summary cards
          Row(
            children: [
              _buildMiniCard(
                'Avg Accuracy',
                '${(metrics.avgAccuracy * 100).toStringAsFixed(0)}%',
                Icons.check_circle_outline,
                metrics.avgAccuracy >= 0.7 ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              _buildMiniCard(
                'Improvement',
                '${metrics.improvementPct >= 0 ? '+' : ''}${metrics.improvementPct.toStringAsFixed(0)}%',
                metrics.improvementPct >= 0
                    ? Icons.trending_up
                    : Icons.trending_down,
                metrics.improvementPct >= 0 ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              _buildMiniCard(
                'Fatigue',
                metrics.fatigueScore >= -0.05
                    ? 'Low'
                    : (metrics.fatigueScore >= -0.15 ? 'Medium' : 'High'),
                Icons.battery_alert,
                metrics.fatigueScore >= -0.05
                    ? Colors.green
                    : (metrics.fatigueScore >= -0.15
                        ? Colors.orange
                        : Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Charts
          TrendLineChart(
            points: metrics.accuracyTrend,
            title: 'Accuracy Over Sessions',
            isPercent: true,
            color: Colors.purple,
            unitLabel: 'Higher is better',
          ),
          const SizedBox(height: 8),
          TrendLineChart(
            points: metrics.avgTimeTrend,
            title: 'Avg Round Time (seconds)',
            color: Colors.teal,
            unitLabel: 'Lower is better (faster processing)',
          ),
          const SizedBox(height: 8),
          TrendLineChart(
            points: metrics.peeksTrend,
            title: 'Peeks Used Per Session',
            color: Colors.orange,
            unitLabel: 'Memory dependence — lower over time = stronger memory',
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
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
