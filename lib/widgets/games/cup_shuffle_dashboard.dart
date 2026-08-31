import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/game_result.dart';
import '../../models/cup_shuffle_metrics.dart';

// ============================================================
// MAIN DASHBOARD (Tabs بدون سكرول متداخل)
// ============================================================
class CupShuffleDashboard extends StatefulWidget {
  final List<GameResult> results;
  const CupShuffleDashboard({super.key, required this.results});

  @override
  State<CupShuffleDashboard> createState() => _CupShuffleDashboardState();
}

class _CupShuffleDashboardState extends State<CupShuffleDashboard>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.results.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text('Cup Shuffle',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        TabBar(
          controller: _controller,
          labelColor: Colors.teal,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.teal,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Patient'),
            Tab(icon: Icon(Icons.medical_services), text: 'Clinician'),
          ],
        ),
        const SizedBox(height: 8),
        // ✅ المحتوى بينزل مباشرة مع سكرول الشاشة الرئيسي
        _controller.index == 0
            ? _PatientTab(results: widget.results)
            : _ClinicianTab(results: widget.results),
      ],
    );
  }
}

// ============================================================
// 👤 PATIENT TAB
// ============================================================
class _PatientTab extends StatefulWidget {
  final List<GameResult> results;
  const _PatientTab({required this.results});

  @override
  State<_PatientTab> createState() => _PatientTabState();
}

class _PatientTabState extends State<_PatientTab> {
  String _mode = 'all';

  List<double> _filteredAccuracies() {
    final filtered = _mode == 'all'
        ? widget.results
        : widget.results
            .where((r) => CupShuffleMetrics.fromResult(r).difficulty == _mode)
            .toList();
    return filtered.reversed
        .map((r) => CupShuffleMetrics.fromResult(r).accuracy)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final latest = CupShuffleMetrics.fromResult(widget.results.first);
    final accuracies = _filteredAccuracies();
    final bestScore =
        widget.results.map((r) => r.score).reduce((a, b) => a > b ? a : b);
    final stars = (latest.accuracy * 5).round().clamp(0, 5);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStarsCard(stars, latest),
          const SizedBox(height: 16),
          Row(
            children: ['all', 'easy', 'medium', 'hard'].map((m) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    label: Text(
                      m == 'all' ? 'All' : m[0].toUpperCase() + m.substring(1),
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: _mode == m,
                    onSelected: (_) => setState(() => _mode = m),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          accuracies.isEmpty
              ? const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No sessions for this mode yet'),
                  ),
                )
              : _buildAccuracyChart(accuracies),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.emoji_events,
            color: Colors.amber,
            title: 'Best Score',
            value: '$bestScore',
          ),
          const SizedBox(height: 16),
          _buildMotivationCard(latest, accuracies),
        ],
      ),
    );
  }

  Widget _buildStarsCard(int stars, CupShuffleMetrics latest) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Last Session: ${latest.difficulty.toUpperCase()}',
                style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => Icon(
                  i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: i < stars ? Colors.amber : Colors.grey[300],
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('${(latest.accuracy * 100).round()}% Accuracy',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildAccuracyChart(List<double> accuracies) {
    final last10 = accuracies.length > 10
        ? accuracies.sublist(accuracies.length - 10)
        : accuracies;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Accuracy Trend ($_mode)',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 1,
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: 0.25,
                    getDrawingHorizontalLine: (v) =>
                        FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        getTitlesWidget: (v, _) => Text('${(v * 100).round()}%',
                            style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) => Text('${v.round() + 1}',
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
                      spots: last10
                          .asMap()
                          .entries
                          .map((e) => FlSpot(e.key.toDouble(), e.value))
                          .toList(),
                      isCurved: true,
                      color: Colors.teal,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                          show: true, color: Colors.teal.withOpacity(0.15)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        trailing: Text(value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildMotivationCard(
      CupShuffleMetrics latest, List<double> accuracies) {
    String message;
    IconData icon;
    Color color;
    if (accuracies.length >= 2 &&
        accuracies.last > accuracies[accuracies.length - 2]) {
      message = "You're improving! Keep going! 🎉";
      icon = Icons.trending_up;
      color = Colors.green;
    } else if (latest.showsFatigue) {
      message = "Great effort today! Take a break 😊";
      icon = Icons.self_improvement;
      color = Colors.orange;
    } else if (latest.accuracy >= 0.8) {
      message = "Excellent performance! ⭐";
      icon = Icons.star;
      color = Colors.amber;
    } else {
      message = "Practice makes progress! 💪";
      icon = Icons.fitness_center;
      color = Colors.blue;
    }
    return Card(
      elevation: 2,
      color: color.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(message,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}

// ============================================================
// 👨‍️ CLINICIAN TAB
// ============================================================
class _ClinicianTab extends StatelessWidget {
  final List<GameResult> results;
  const _ClinicianTab({required this.results});

  @override
  Widget build(BuildContext context) {
    final metricsList =
        results.reversed.map((r) => CupShuffleMetrics.fromResult(r)).toList();
    final latest = metricsList.last;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildResponseTimeChart(metricsList),
          const SizedBox(height: 16),
          _buildFatigueCard(latest),
          const SizedBox(height: 16),
          _buildFatigueTrendChart(metricsList), // ✅ الجديد: FI كـ trend
          const SizedBox(height: 16),
          _buildErrorPatternChart(metricsList),
          const SizedBox(height: 16),
          _buildSessionsList(results),
        ],
      ),
    );
  }

  Widget _buildResponseTimeChart(List<CupShuffleMetrics> metricsList) {
    final last10 = metricsList.length > 10
        ? metricsList.sublist(metricsList.length - 10)
        : metricsList;
    final spots = last10
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.averageResponseTime))
        .toList();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Avg Response Time (s)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  gridData: FlGridData(
                    show: true,
                    getDrawingHorizontalLine: (v) =>
                        FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        getTitlesWidget: (v, _) => Text(
                            '${v.toStringAsFixed(1)}s',
                            style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) => Text('${v.round() + 1}',
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
                      spots: spots,
                      isCurved: true,
                      color: Colors.deepPurple,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFatigueCard(CupShuffleMetrics latest) {
    if (!latest.hasFatigueData) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const ListTile(
          leading: Icon(Icons.help_outline, color: Colors.grey),
          title: Text('Cognitive Fatigue'),
          subtitle: Text('N/A — need at least 4 rounds'),
        ),
      );
    }

    final fi = latest.fatigueIndex;
    final Color color;
    final String label;
    final IconData icon;

    if (fi <= 1.0) {
      color = Colors.green;
      label = 'Consistent';
      icon = Icons.check_circle;
    } else if (fi <= 1.2) {
      color = Colors.orange;
      label = 'Mild Fatigue';
      icon = Icons.warning_amber;
    } else {
      color = Colors.red;
      label = 'Significant Fatigue';
      icon = Icons.error;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cognitive Fatigue (Latest)',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Text(
              fi.toStringAsFixed(2),
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ الجديد: Fatigue Index عبر الجلسات
  Widget _buildFatigueTrendChart(List<CupShuffleMetrics> metricsList) {
    final valid = metricsList.where((m) => m.hasFatigueData).toList();
    if (valid.length < 2) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Not enough fatigue data yet'),
        ),
      );
    }
    final last10 = valid.length > 10 ? valid.sublist(valid.length - 10) : valid;

    final spots = last10
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.fatigueIndex))
        .toList();

    final maxFI =
        last10.map((m) => m.fatigueIndex).reduce((a, b) => a > b ? a : b);
    final maxY = (maxFI + 0.3).clamp(1.5, 3.0);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Fatigue Index Trend',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: LineChart(
                LineChartData(
                  minY: 0.5,
                  maxY: maxY,
                  extraLinesData: ExtraLinesData(horizontalLines: [
                    HorizontalLine(
                      y: 1.2,
                      color: Colors.red.withOpacity(0.6),
                      strokeWidth: 1,
                      dashArray: [6, 4],
                    ),
                  ]),
                  gridData: FlGridData(
                    show: true,
                    getDrawingHorizontalLine: (v) =>
                        FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        getTitlesWidget: (v, _) => Text(v.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) => Text('${v.round() + 1}',
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
                      spots: spots,
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Red dashed line = fatigue threshold (1.2)',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorPatternChart(List<CupShuffleMetrics> metricsList) {
    final allErrors = metricsList.expand((m) => m.errorPositions).toList();
    if (allErrors.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const ListTile(
          leading: Icon(Icons.check_circle, color: Colors.green),
          title: Text('No errors recorded'),
          subtitle: Text('Perfect spatial attention!'),
        ),
      );
    }

    final counts = {'left': 0, 'center': 0, 'right': 0};
    for (final e in allErrors) {
      if (counts.containsKey(e)) counts[e] = counts[e]! + 1;
    }
    final maxCount = counts.values.reduce((a, b) => a > b ? a : b).toDouble();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Error Pattern (Spatial)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: BarChart(
                BarChartData(
                  maxY: maxCount + 1,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          switch (v.toInt()) {
                            case 0:
                              return const Text('Left');
                            case 1:
                              return const Text('Center');
                            case 2:
                              return const Text('Right');
                            default:
                              return const Text('');
                          }
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    _buildBar(0, counts['left']!.toDouble(), Colors.blue),
                    _buildBar(1, counts['center']!.toDouble(), Colors.orange),
                    _buildBar(2, counts['right']!.toDouble(), Colors.red),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _buildBar(int x, double y, Color color) {
    return BarChartGroupData(x: x, barRods: [
      BarChartRodData(
        toY: y,
        color: color,
        width: 30,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
      ),
    ]);
  }

  // ✅ صفوف بسيطة بدل DataTable (بدون مشاكل قياس)
  Widget _buildSessionsList(List<GameResult> results) {
    final last10 = results.length > 10 ? results.sublist(0, 10) : results;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recent Sessions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...last10.map((r) {
              final m = CupShuffleMetrics.fromResult(r);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${r.playedAt.day}/${r.playedAt.month}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: m.difficulty == 'hard'
                                ? Colors.red.withOpacity(0.15)
                                : m.difficulty == 'medium'
                                    ? Colors.orange.withOpacity(0.15)
                                    : Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(m.difficulty.toUpperCase(),
                              style: const TextStyle(fontSize: 10)),
                        ),
                        Text('Score: ${r.score}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Acc: ${(m.accuracy * 100).round()}%'),
                        Text(
                            'RT: ${m.averageResponseTime.toStringAsFixed(1)}s'),
                        Text(
                            m.hasFatigueData
                                ? 'FI: ${m.fatigueIndex.toStringAsFixed(2)}'
                                : 'FI: —',
                            style: TextStyle(
                                color: !m.hasFatigueData
                                    ? Colors.grey
                                    : m.showsFatigue
                                        ? Colors.red
                                        : Colors.green)),
                      ],
                    ),
                    const Divider(height: 12),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
