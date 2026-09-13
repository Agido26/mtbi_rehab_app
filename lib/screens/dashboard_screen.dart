import 'package:flutter/material.dart';
import '../models/game_result.dart';
import '../services/auth_service.dart';
import '../services/game_data_service.dart';
import '../screens/clinical_report_screen.dart';
import '../widgets/common/app_scaffold.dart';
import '../widgets/games/cup_shuffle_dashboard.dart';
import '../widgets/games/shape_match_dashboard.dart';
import '../widgets/progress_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final _gameDataService = GameDataService();
  Map<GameType, List<GameResult>> _resultsByGame = {};
  bool _isLoading = true;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final patient = AuthService().currentPatient;
    if (patient == null) return;

    final results = await _gameDataService.getProgressData(patient.id);
    setState(() {
      _resultsByGame = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Dashboard',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.indigo,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.indigo,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.emoji_events),
                        text: 'My Progress',
                      ),
                      Tab(
                        icon: Icon(Icons.medical_services),
                        text: 'Clinical Report',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPatientTab(),
                      const ClinicalReportScreen(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ============================================================
  // Patient Tab (My Progress) — تحفيزي، بدون مصطلحات طبية
  // ============================================================
  Widget _buildPatientTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 16),
          _buildStatsOverview(),
          const Divider(height: 32),
          if (_resultsByGame.containsKey(GameType.cupShuffle))
            CupShuffleDashboard(results: _resultsByGame[GameType.cupShuffle]!),
          const SizedBox(height: 24),
          if (_resultsByGame.containsKey(GameType.shapeMatch))
            ShapeMatchDashboard(results: _resultsByGame[GameType.shapeMatch]!),
          for (final gameType in GameType.values)
            if (gameType != GameType.cupShuffle &&
                gameType != GameType.shapeMatch &&
                _resultsByGame.containsKey(gameType))
              ProgressChart(
                results: _resultsByGame[gameType]!,
                title: '${gameType.displayName} Score Over Time',
              ),
          if (_resultsByGame.isEmpty) _buildEmptyState(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final patient = AuthService().currentPatient;
    final totalSessions =
        _resultsByGame.values.fold<int>(0, (sum, list) => sum + list.length);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade400, Colors.purple.shade400],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back, ${patient?.username ?? 'there'}! 👋',
            style: const TextStyle(
                fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            totalSessions == 0
                ? 'Start your first session to track your progress!'
                : 'You\'ve completed $totalSessions session${totalSessions == 1 ? '' : 's'}. Keep going!',
            style:
                TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStat('🏆', '${_resultsByGame.length}/3', 'Games'),
              const SizedBox(width: 16),
              _buildStat('📈', totalSessions.toString(), 'Sessions'),
              const SizedBox(width: 16),
              _buildStat('⭐', _totalScore().toString(), 'Points'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8)),
        ),
      ],
    );
  }

  int _totalScore() {
    int total = 0;
    for (final list in _resultsByGame.values) {
      for (final r in list) {
        total += r.score;
      }
    }
    return total;
  }

  Widget _buildStatsOverview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Stats',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ..._resultsByGame.entries.map((entry) {
                final game = entry.key;
                final results = entry.value;
                final totalScore = results.fold<int>(0, (s, r) => s + r.score);
                final avgAcc = results.isEmpty
                    ? 0.0
                    : results.map((r) => r.accuracy).reduce((a, b) => a + b) /
                        results.length;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: game == GameType.cupShuffle
                        ? Colors.blue[50]
                        : (game == GameType.shapeMatch
                            ? Colors.purple[50]
                            : Colors.orange[50]),
                    child: Icon(
                      game == GameType.cupShuffle
                          ? Icons.local_drink
                          : (game == GameType.shapeMatch
                              ? Icons.extension
                              : Icons.search),
                      color: game == GameType.cupShuffle
                          ? Colors.blue
                          : (game == GameType.shapeMatch
                              ? Colors.purple
                              : Colors.orange),
                    ),
                  ),
                  title: Text(game.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${results.length} sessions • ${(avgAcc * 100).toStringAsFixed(0)}% avg'),
                  trailing: Text(
                    '$totalScore pts',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }),
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
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete game sessions to track your improvement over time',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
