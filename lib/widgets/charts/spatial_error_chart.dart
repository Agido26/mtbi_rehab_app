import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SpatialErrorChart extends StatelessWidget {
  final Map<String, int> errors; // {left, center, right}

  const SpatialErrorChart({super.key, required this.errors});

  @override
  Widget build(BuildContext context) {
    final left = errors['left'] ?? 0;
    final center = errors['center'] ?? 0;
    final right = errors['right'] ?? 0;
    final total = left + center + right;

    if (total == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Spatial Error Distribution',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'No errors recorded yet',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final biasHint = left > right * 2 && total >= 3
        ? '⚠️ Left-side bias detected — consider attention assessment'
        : 'No significant spatial bias';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Spatial Error Distribution',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Which cup position was tapped incorrectly',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: total.toDouble() * 1.2,
                  barGroups: [
                    _makeGroup(0, left, Colors.red),
                    _makeGroup(1, center, Colors.orange),
                    _makeGroup(2, right, Colors.green),
                  ],
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          const labels = ['Left', 'Center', 'Right'];
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              labels[value.toInt()],
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              biasHint,
              style: TextStyle(
                fontSize: 11,
                color: left > right * 2 && total >= 3
                    ? Colors.red[700]
                    : Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _makeGroup(int x, int y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y.toDouble(),
          color: color,
          width: 28,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }
}
