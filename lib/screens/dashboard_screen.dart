import 'package:flutter/material.dart';
import '../models/game_result.dart';
import '../services/auth_service.dart';
import '../services/game_data_service.dart';
import '../widgets/common/app_scaffold.dart';
import '../widgets/progress_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _gameDataService = GameDataService();
  Map<GameType, List<GameResult>> _resultsByGame = {};
  Map<GameType, Map<String, dynamic>> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final patient = AuthService().currentPatient;
    if (patient == null) return;

    final results = await _gameDataService.getProgressData(patient.id);
    final stats = await _gameDataService.getSummaryStats(patient.id);

    setState(() {
      _resultsByGame = results;
      _stats = stats;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Your Progress',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                children: [
                  // Overall stats cards
                  _buildStatsOverview(),
                  const Divider(height: 32),
                  // Per-game charts
                  for (final gameType in GameType.values)
                    if (_resultsByGame.containsKey(gameType))
                      ProgressChart(
                        results: _resultsByGame[gameType]!,
                        title: '${gameType.displayName} Score Over Time',
                      ),
                  if (_resultsByGame.isEmpty) _buildEmptyState(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsOverview() {
    final totalSessions = _stats.values.fold<int>(
      0,
      (sum, s) => sum + (s['sessionsPlayed'] as int),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Summary',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard(
                'Total Sessions',
                totalSessions.toString(),
                Icons.fitness_center,
                Colors.blue,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Games Played',
                '${_stats.length}/3',
                Icons.games,
                Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No progress data yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete game sessions to track your improvement over time',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
