import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../services/metrics_analyzer.dart';

class TrendLineChart extends StatelessWidget {
  final List<TrendPoint> points;
  final String title;
  final String unitLabel;
  final Color color;
  final bool isPercent; // لو true، الـ Y من 0 لـ 1 ويظهر %

  const TrendLineChart({
    super.key,
    required this.points,
    required this.title,
    this.unitLabel = '',
    this.color = Colors.blue,
    this.isPercent = false,
  });

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              Center(
                child: Text(
                  'Need at least 2 sessions to show trend',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (final p in points) {
      spots.add(FlSpot(p.x, isPercent ? p.y * 100 : p.y));
    }

    double minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    double maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }
    final padding = (maxY - minY) * 0.15;
    minY -= padding;
    maxY += padding;
    if (isPercent) {
      minY = 0;
      if (maxY < 100) maxY = 100;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  gridData:
                      const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            isPercent
                                ? '${value.toInt()}%'
                                : value.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            points[idx].label,
                            style: const TextStyle(fontSize: 10),
                          );
                        },
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
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, _, __, ___) =>
                            FlDotCirclePainter(radius: 4, color: color),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (unitLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  unitLabel,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
