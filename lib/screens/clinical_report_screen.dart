import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/game_result.dart';
import '../models/patient.dart';
import '../services/game_data_service.dart';
import '../services/metrics_analyzer.dart';
import '../widgets/charts/spatial_error_chart.dart';
import '../widgets/charts/trend_line_chart.dart';

class ClinicalReportScreen extends StatefulWidget {
  final Patient patient;
  const ClinicalReportScreen({super.key, required this.patient});

  @override
  State<ClinicalReportScreen> createState() => _ClinicalReportScreenState();
}

class _ClinicalReportScreenState extends State<ClinicalReportScreen>
    with SingleTickerProviderStateMixin {
  final _service = GameDataService();
  Map<GameType, List<GameResult>> _byGame = {};
  bool _loading = true;
  late final TabController _tabController;

  // حالة الفلترة وعرض المزيد
  int _limitSM = 6;
  int _limitCS = 6;
  String _csFilter = 'all'; // 'all', 'easy', 'medium', 'hard'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await _service.getProgressData(widget.patient.id);
    setState(() {
      _byGame = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Clinical Report')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final shapeMatch = _byGame[GameType.shapeMatch] ?? [];
    final cupShuffle = _byGame[GameType.cupShuffle] ?? [];

    final sm = shapeMatch.isNotEmpty
        ? MetricsAnalyzer.analyzeShapeMatch(shapeMatch)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinical Report'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              icon: const Icon(Icons.extension, size: 20),
              text: 'Shape Match${sm != null ? ' (${sm.sessionsCount})' : ''}',
            ),
            const Tab(
              icon: Icon(Icons.local_drink, size: 20),
              text: 'Cup Shuffle',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildPatientHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildShapeMatchTab(sm, shapeMatch),
                _buildCupShuffleTab(cupShuffle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================
  Widget _buildPatientHeader() {
    final sm = _byGame[GameType.shapeMatch];
    final cs = _byGame[GameType.cupShuffle];
    final smM = sm != null && sm.isNotEmpty
        ? MetricsAnalyzer.analyzeShapeMatch(sm)
        : null;
    final csM = cs != null && cs.isNotEmpty
        ? MetricsAnalyzer.analyzeCupShuffle(cs)
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.indigo.shade50,
      child: Row(
        children: [
          const Icon(Icons.person, color: Colors.indigo),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.patient.username,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'ID: ${widget.patient.id} • SM: ${smM?.sessionsCount ?? 0} • CS: ${csM?.sessionsCount ?? 0}',
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.indigo, size: 20),
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 1: SHAPE MATCH
  // ============================================================
  Widget _buildShapeMatchTab(ShapeMatchMetrics? sm, List<GameResult> raw) {
    if (sm == null) return _buildNoData('Shape Match');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('🧩 Working Memory & Pattern Recognition'),
        _buildInsightBox(_shapeMatchInsights(sm)),
        const SizedBox(height: 12),
        _buildQuickStatsRow([
          _buildStatChip('Avg Accuracy',
              '${(sm.avgAccuracy * 100).toStringAsFixed(0)}%', Colors.purple),
          _buildStatChip(
              'Improvement',
              '${sm.improvementPct >= 0 ? '+' : ''}${sm.improvementPct.toStringAsFixed(0)}%',
              sm.improvementPct >= 0 ? Colors.green : Colors.red),
          _buildStatChip(
              'Fatigue',
              sm.fatigueScore >= -0.05
                  ? 'Low'
                  : (sm.fatigueScore >= -0.15 ? 'Moderate' : 'High'),
              sm.fatigueScore >= -0.05
                  ? Colors.green
                  : (sm.fatigueScore >= -0.15 ? Colors.orange : Colors.red)),
        ]),
        const SizedBox(height: 16),
        TrendLineChart(
            points: sm.accuracyTrend,
            title: 'Accuracy Over Sessions',
            isPercent: true,
            color: Colors.purple,
            unitLabel: 'Pattern recognition + visual attention'),
        const SizedBox(height: 12),
        TrendLineChart(
            points: sm.avgTimeTrend,
            title: 'Avg Round Time (sec)',
            color: Colors.teal,
            unitLabel: 'Lower = faster cognitive processing'),
        const SizedBox(height: 12),
        TrendLineChart(
            points: sm.peeksTrend,
            title: 'Peeks Per Session',
            color: Colors.orange,
            unitLabel:
                'Working memory dependence — decreasing = stronger memory'),
        const SizedBox(height: 12),
        _buildRecentSessions('Recent Sessions — Shape Match', raw,
            limit: _limitSM, onShowMore: () => setState(() => _limitSM += 6)),
      ],
    );
  }

  // ============================================================
  // TAB 2: CUP SHUFFLE (مع الفلترة حسب الصعوبة)
  // ============================================================
  Widget _buildCupShuffleTab(List<GameResult> raw) {
    // 1. فلترة البيانات بناءً على الاختيار
    final filteredRaw = _csFilter == 'all'
        ? raw
        : raw
            .where((r) =>
                (r.metadata?['difficulty'] as String?)?.toLowerCase() ==
                _csFilter)
            .toList();

    // 2. حساب المقاييس للبيانات المفلترة فقط
    final cs = filteredRaw.isNotEmpty
        ? MetricsAnalyzer.analyzeCupShuffle(filteredRaw)
        : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('🎯 Visual Attention & Processing Speed'),
        _buildInsightBox(cs != null
            ? _cupShuffleInsights(cs)
            : ['No data available for this difficulty filter.']),
        const SizedBox(height: 12),

        // ✅ أزرار الفلترة للشارتات
        _buildDifficultyFilter(
            _csFilter, (val) => setState(() => _csFilter = val)),
        const SizedBox(height: 16),

        if (cs == null)
          _buildNoData('Selected Difficulty')
        else ...[
          _buildQuickStatsRow([
            _buildStatChip('Avg Accuracy',
                '${(cs.avgAccuracy * 100).toStringAsFixed(0)}%', Colors.blue),
            _buildStatChip('Avg RT',
                '${cs.avgResponseTime.toStringAsFixed(2)}s', Colors.green),
            _buildStatChip('ISV', cs.intraSessionVariability.toStringAsFixed(1),
                cs.intraSessionVariability > 20 ? Colors.orange : Colors.green),
          ]),
          const SizedBox(height: 16),
          TrendLineChart(
              points: cs.accuracyTrend,
              title: 'Accuracy Over Sessions ($_csFilter)',
              isPercent: true,
              color: Colors.blue),
          const SizedBox(height: 12),
          TrendLineChart(
              points: cs.responseTimeTrend,
              title: 'Response Time (sec) ($_csFilter)',
              color: Colors.green,
              unitLabel: 'Processing speed — lower = faster'),
          const SizedBox(height: 12),
          _buildISVCard(cs.intraSessionVariability),
          const SizedBox(height: 12),
          _buildFatigueCard(cs),
          const SizedBox(height: 12),
          TrendLineChart(
              points: cs.fatigueIndexTrend,
              title: 'Fatigue Index Trend ($_csFilter)',
              color: Colors.deepOrange,
              unitLabel:
                  'FI = avg RT (2nd half) ÷ avg RT (1st half) — >1.0 = within-session slowing'),
          const SizedBox(height: 12),
          SpatialErrorChart(errors: cs.spatialErrors),
          const SizedBox(height: 12),
          // ✅ قائمة الجلسات تعكس أيضاً الفلتر المختار
          _buildRecentSessions('Recent Sessions — Cup Shuffle', filteredRaw,
              limit: _limitCS, onShowMore: () => setState(() => _limitCS += 6)),
        ]
      ],
    );
  }

  // ============================================================
  // WIDGETS مشتركة
  // ============================================================
  Widget _buildDifficultyFilter(
      String selected, ValueChanged<String> onChanged) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ['all', 'easy', 'medium', 'hard'].map((d) {
          final isSelected = selected == d;
          final color = d == 'all'
              ? Colors.grey
              : (d == 'easy'
                  ? Colors.green
                  : (d == 'medium' ? Colors.orange : Colors.red));
          final label = d[0].toUpperCase() + d.substring(1);

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(label),
              selected: isSelected,
              selectedColor: color.withOpacity(0.15),
              checkmarkColor: color,
              labelStyle: TextStyle(
                color: isSelected ? color : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (_) => onChanged(d),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
    );
  }

  Widget _buildInsightBox(List<String> insights) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡 Clinical Insights',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ...insights.map((i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('• $i', style: const TextStyle(fontSize: 13)))),
        ],
      ),
    );
  }

  Widget _buildQuickStatsRow(List<Widget> chips) {
    return Row(children: [
      for (int i = 0; i < chips.length; i++) ...[
        Expanded(child: chips[i]),
        if (i < chips.length - 1) const SizedBox(width: 8)
      ]
    ]);
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildISVCard(double isv) {
    final level = isv > 30 ? 'High' : (isv > 15 ? 'Moderate' : 'Low');
    final color =
        isv > 30 ? Colors.red : (isv > 15 ? Colors.orange : Colors.green);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.bolt, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Intra-Session Variability (ISV)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                      '$level — ${isv.toStringAsFixed(1)} (marker of cognitive stability in mTBI)',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFatigueCard(CupShuffleMetrics cs) {
    final fi = cs.latestFatigueIndex;
    final level = fi <= 1.05 ? 'Low' : (fi <= 1.25 ? 'Moderate' : 'High');
    final color =
        fi <= 1.05 ? Colors.green : (fi <= 1.25 ? Colors.orange : Colors.red);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.battery_2_bar, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cognitive Fatigue (latest session)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                      '$level — FI ${fi.toStringAsFixed(2)} (avg ${cs.avgFatigueIndex.toStringAsFixed(2)})',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ الإصلاح الجذري للـ Overflow: استخدام Column بدلاً من نص واحد طويل
  Widget _buildRecentSessions(String title, List<GameResult> results,
      {required int limit, required VoidCallback onShowMore}) {
    final recent = List<GameResult>.from(results)
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    final shown = recent.take(limit).toList();
    final hasMore = recent.length > limit;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Recent Sessions",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text('${recent.length} total',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 8),
            if (shown.isEmpty)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('No sessions yet',
                      style: TextStyle(color: Colors.grey[500])))
            else
              ...shown.map((r) {
                final diff =
                    (r.metadata?['difficulty'] as String?)?.toLowerCase() ?? '';
                final diffLabel = diff == 'easy'
                    ? 'Easy'
                    : (diff == 'medium'
                        ? 'Medium'
                        : (diff == 'hard' ? 'Hard' : ''));

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading:
                      Icon(Icons.history, size: 18, color: Colors.grey[600]),
                  title: Text(
                    DateFormat('EEE, MMM d — HH:mm').format(r.playedAt),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  // ✅ هنا الحل: تقسيم النص إلى سطرين قصيرين مع ellipsis يمنع الـ Overflow تماماً
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Score: ${r.score} • Acc: ${(r.accuracy * 100).toStringAsFixed(0)}% • ${r.durationSeconds}s',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500),
                      ),
                      if (diffLabel.isNotEmpty)
                        Text(
                          'Difficulty: $diffLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                );
              }),
            if (hasMore)
              Center(
                child: TextButton.icon(
                  onPressed: onShowMore,
                  icon: const Icon(Icons.expand_more, size: 18),
                  label: Text('Show more (${recent.length - limit} older)'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<String> _shapeMatchInsights(ShapeMatchMetrics sm) {
    final insights = <String>[];
    if (sm.improvementPct > 10) {
      insights.add(
          'Strong improvement (+${sm.improvementPct.toStringAsFixed(0)}%) — working memory responding well.');
    } else if (sm.improvementPct < -5) {
      insights.add(
          'Accuracy declining — consider adjusting difficulty or session length.');
    } else {
      insights.add(
          'Stable performance — may need increased cognitive load for further gains.');
    }

    if (sm.fatigueScore < -0.15) {
      insights.add(
          '⚠️ Significant intra-session fatigue — recommend shorter sessions.');
    } else if (sm.fatigueScore < -0.05) {
      insights.add('Mild fatigue detected — monitor session duration.');
    } else {
      insights.add('Good endurance across sessions.');
    }

    final lastPeeks = sm.peeksTrend.isNotEmpty ? sm.peeksTrend.last.y : 0;
    if (lastPeeks > 0) {
      insights.add(
          'Still using $lastPeeks peek(s)/session — memory consolidation ongoing.');
    } else {
      insights.add('No peeks used — memory independent retrieval achieved.');
    }
    return insights;
  }

  List<String> _cupShuffleInsights(CupShuffleMetrics cs) {
    final insights = <String>[];
    if (cs.hasSpatialBias) {
      insights.add(
          '⚠️ Left-side error bias (${cs.spatialBiasRatio.toStringAsFixed(1)}x) — consider formal spatial attention assessment.');
    }

    if (cs.intraSessionVariability > 30) {
      insights.add(
          'High response variability — common in mTBI; suggests fluctuating cognitive stability.');
    } else if (cs.intraSessionVariability > 15) {
      insights.add('Moderate variability — monitor over next sessions.');
    } else {
      insights.add('Consistent response times — stable cognitive performance.');
    }

    if (cs.latestFatigueIndex > 1.25) {
      insights.add(
          '⚠️ High cognitive fatigue (FI ${cs.latestFatigueIndex.toStringAsFixed(2)}) — responses slow markedly within sessions.');
    } else if (cs.latestFatigueIndex > 1.05) {
      insights.add(
          'Mild within-session slowing (FI ${cs.latestFatigueIndex.toStringAsFixed(2)}) — monitor the fatigue trend.');
    } else {
      insights.add(
          'Stable response speed within sessions — no significant cognitive fatigue.');
    }
    return insights;
  }

  Widget _buildNoData(String gameName) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('No $gameName data yet',
                style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text('Data will appear after the patient completes sessions',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}
