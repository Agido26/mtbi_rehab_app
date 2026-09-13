import 'package:flutter/material.dart';

import '../models/game_result.dart';
import '../services/auth_service.dart';
import '../services/game_data_service.dart';
import '../services/metrics_analyzer.dart';
import '../widgets/charts/spatial_error_chart.dart';
import '../widgets/charts/trend_line_chart.dart';

class ClinicalReportScreen extends StatefulWidget {
  const ClinicalReportScreen({super.key});

  @override
  State<ClinicalReportScreen> createState() => _ClinicalReportScreenState();
}

class _ClinicalReportScreenState extends State<ClinicalReportScreen> {
  final _service = GameDataService();
  Map<GameType, List<GameResult>> _byGame = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final patient = AuthService().currentPatient;
    if (patient == null) return;
    final data = await _service.getProgressData(patient.id);
    setState(() {
      _byGame = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final shapeMatch = _byGame[GameType.shapeMatch] ?? [];
    final cupShuffle = _byGame[GameType.cupShuffle] ?? [];
    final visualScan = _byGame[GameType.visualScanning] ?? [];

    final sm = shapeMatch.isNotEmpty
        ? MetricsAnalyzer.analyzeShapeMatch(shapeMatch)
        : null;
    final cs = cupShuffle.isNotEmpty
        ? MetricsAnalyzer.analyzeCupShuffle(cupShuffle)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinical Report'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPatientHeader(),
          const SizedBox(height: 16),
          _buildClinicalSummary(sm, cs),
          const SizedBox(height: 20),
          if (sm != null) ...[
            _buildSectionTitle('🧩 Shape Match — Working Memory'),
            _buildInsightBox(_shapeMatchInsights(sm)),
            const SizedBox(height: 8),
            TrendLineChart(
              points: sm.accuracyTrend,
              title: 'Accuracy Trend',
              isPercent: true,
              color: Colors.purple,
            ),
            const SizedBox(height: 8),
            TrendLineChart(
              points: sm.avgTimeTrend,
              title: 'Avg Round Time (sec)',
              color: Colors.teal,
            ),
            const SizedBox(height: 8),
            TrendLineChart(
              points: sm.peeksTrend,
              title: 'Peeks Per Session',
              color: Colors.orange,
            ),
            const SizedBox(height: 24),
          ],
          if (cs != null) ...[
            _buildSectionTitle('🎯 Cup Shuffle — Visual Attention'),
            _buildInsightBox(_cupShuffleInsights(cs)),
            const SizedBox(height: 8),
            TrendLineChart(
              points: cs.accuracyTrend,
              title: 'Accuracy Trend',
              isPercent: true,
              color: Colors.blue,
            ),
            const SizedBox(height: 8),
            TrendLineChart(
              points: cs.responseTimeTrend,
              title: 'Response Time (sec)',
              color: Colors.green,
            ),
            const SizedBox(height: 8),
            SpatialErrorChart(errors: cs.spatialErrors),
            const SizedBox(height: 8),
            _buildISVCard(cs.intraSessionVariability),
            const SizedBox(height: 24),
          ],
          if (sm == null && cs == null) _buildNoData(),
        ],
      ),
    );
  }

  Widget _buildPatientHeader() {
    final patient = AuthService().currentPatient;
    return Card(
      color: Colors.indigo.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  patient?.username ?? 'Patient',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'ID: ${patient?.id ?? '-'}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClinicalSummary(ShapeMatchMetrics? sm, CupShuffleMetrics? cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Clinical Overview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildRow(
                'Shape Match Sessions', sm?.sessionsCount.toString() ?? '0'),
            _buildRow(
                'Cup Shuffle Sessions', cs?.sessionsCount.toString() ?? '0'),
            if (sm != null)
              _buildRow(
                'Shape Match Improvement',
                '${sm.improvementPct >= 0 ? '+' : ''}${sm.improvementPct.toStringAsFixed(0)}%',
                color: sm.improvementPct >= 0 ? Colors.green : Colors.red,
              ),
            if (cs != null)
              _buildRow(
                'Spatial Bias',
                cs.hasSpatialBias ? '⚠️ Detected' : 'None',
                color: cs.hasSpatialBias ? Colors.red : Colors.green,
              ),
            if (cs != null)
              _buildRow(
                'Response Variability (ISV)',
                cs.intraSessionVariability.toStringAsFixed(1),
                color: cs.intraSessionVariability > 20
                    ? Colors.orange
                    : Colors.green,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.indigo,
        ),
      ),
    );
  }

  Widget _buildInsightBox(List<String> insights) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💡 Clinical Insights',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          ...insights.map((i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• $i', style: const TextStyle(fontSize: 13)),
              )),
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
                  const Text(
                    'Intra-Session Variability (ISV)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$level — ${isv.toStringAsFixed(1)} (marker of cognitive stability in mTBI)',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ],
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
          'Strong improvement (+${sm.improvementPct.toStringAsFixed(0)}%) — working memory responding well to training.');
    } else if (sm.improvementPct < -5) {
      insights.add(
          'Accuracy declining — consider adjusting difficulty or session length.');
    } else {
      insights.add(
          'Stable performance — may need increased cognitive load for further gains.');
    }
    if (sm.fatigueScore < -0.15) {
      insights.add(
          '⚠️ Significant intra-session fatigue — recommend shorter sessions or more breaks.');
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
    if (cs.avgResponseTime > 3.0) {
      insights.add(
          'Slower average response (${cs.avgResponseTime.toStringAsFixed(1)}s) — processing speed focus recommended.');
    } else if (cs.avgResponseTime < 1.5) {
      insights.add(
          'Fast responses (${cs.avgResponseTime.toStringAsFixed(1)}s) with ${cs.avgAccuracy >= 0.7 ? 'good accuracy' : 'lower accuracy — may be sacrificing accuracy for speed'}.');
    }
    return insights;
  }

  Widget _buildNoData() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No clinical data yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              'Data will appear after the patient completes game sessions',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
