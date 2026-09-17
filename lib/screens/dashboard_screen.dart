import 'package:flutter/material.dart';
import '../models/game_result.dart';
import '../services/auth_service.dart';
import '../services/game_data_service.dart';
import '../screens/clinical_report_screen.dart';
import '../widgets/common/app_scaffold.dart';

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
      title: 'Your Progress',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
                children: [
                  // ✅ Stats Overview - ثابت فوق (مش بيتغير)
                  _buildStatsOverview(),
                  // ✅ TabBar
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      controller: _tabController,
                      labelColor: Colors.indigo,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.indigo,
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.local_drink),
                          text: 'Cup Shuffle',
                        ),
                        Tab(
                          icon: Icon(Icons.extension),
                          text: 'Shape Match',
                        ),
                      ],
                    ),
                  ),
                  // ✅ Tab content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildCupShuffleTab(),
                        _buildShapeMatchTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // STATS OVERVIEW (ثابت - من كل الألعاب)
  // ============================================================
  Widget _buildStatsOverview() {
    final patient = AuthService().currentPatient;
    final allResults = _resultsByGame.values.expand((list) => list).toList();
    final totalScore = allResults.fold<int>(0, (sum, r) => sum + r.score);
    final totalSessions = allResults.length;

    // Best game
    GameType? bestGame;
    int bestScore = 0;
    for (final entry in _resultsByGame.entries) {
      final gameScore = entry.value.fold<int>(0, (sum, r) => sum + r.score);
      if (gameScore > bestScore) {
        bestScore = gameScore;
        bestGame = entry.key;
      }
    }

    // Streak (جلسات متتالية في أيام مختلفة)
    final streak = _calculateStreak(allResults);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade400, Colors.purple.shade400],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back, ${patient?.username ?? 'there'}! 👋',
            style: const TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatBox('🏆', '$totalScore', 'Total Score'),
              const SizedBox(width: 12),
              _buildStatBox('📈', '$totalSessions', 'Sessions'),
              const SizedBox(width: 12),
              _buildStatBox(
                '⭐',
                bestGame?.displayName.split(' ').first ?? '-',
                'Best Game',
              ),
              const SizedBox(width: 12),
              _buildStatBox('🔥', '$streak', 'Streak'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String emoji, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _calculateStreak(List<GameResult> results) {
    if (results.isEmpty) return 0;

    final dates = results
        .map((r) => DateTime(r.playedAt.year, r.playedAt.month, r.playedAt.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (dates.isEmpty) return 0;

    int streak = 1;
    for (int i = 0; i < dates.length - 1; i++) {
      final diff = dates[i].difference(dates[i + 1]).inDays;
      if (diff == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  // ============================================================
  // TAB 1: CUP SHUFFLE
  // ============================================================
  Widget _buildCupShuffleTab() {
    final results = _resultsByGame[GameType.cupShuffle] ?? [];

    if (results.isEmpty) {
      return _buildEmptyGame('Cup Shuffle', Icons.local_drink, Colors.blue);
    }

    final sorted = List<GameResult>.from(results)
      ..sort((a, b) => a.playedAt.compareTo(b.playedAt));

    // Last 5 sessions average
    final last5 = sorted.length > 5 ? sorted.sublist(sorted.length - 5) : sorted;
    final avgAcc = last5.isEmpty
        ? 0.0
        : last5.map((r) => r.accuracy).reduce((a, b) => a + b) / last5.length;

    // Best score
    final bestScore =
        results.map((r) => r.score).reduce((a, b) => a > b ? a : b);
    final bestResult = results.firstWhere((r) => r.score == bestScore);

    // Perfect rounds
    final perfectRounds = results.where((r) => r.accuracy == 1.0).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Progress Bar
        _buildProgressCard(
          title: 'Recent Performance',
          subtitle: 'Last ${last5.length} sessions',
          progress: avgAcc,
          color: Colors.blue,
        ),
        const SizedBox(height: 16),

        // Achievement
        if (perfectRounds > 0)
          _buildAchievementCard(
            emoji: '🎯',
            title: '$perfectRounds Perfect Rounds!',
            subtitle: 'You nailed it every time',
            color: Colors.green,
          ),

        const SizedBox(height: 12),

        // Best Performance
        _buildBestPerformanceCard(
          score: bestScore,
          accuracy: bestResult.accuracy,
          date: bestResult.playedAt,
        ),

        const SizedBox(height: 16),

        // Recent Sessions
        _buildRecentSessionsList(results),

        const SizedBox(height: 16),

        // Clinical Report Button
        _buildClinicianEntry(),
      ],
    );
  }

  // ============================================================
  // TAB 2: SHAPE MATCH
  // ============================================================
  Widget _buildShapeMatchTab() {
    final results = _resultsByGame[GameType.shapeMatch] ?? [];

    if (results.isEmpty) {
      return _buildEmptyGame('Shape Match', Icons.extension, Colors.purple);
    }

    final sorted = List<GameResult>.from(results)
      ..sort((a, b) => a.playedAt.compareTo(b.playedAt));

    // Last 5 sessions average
    final last5 = sorted.length > 5 ? sorted.sublist(sorted.length - 5) : sorted;
    final avgAcc = last5.isEmpty
        ? 0.0
        : last5.map((r) => r.accuracy).reduce((a, b) => a + b) / last5.length;

    // Best score
    final bestScore =
        results.map((r) => r.score).reduce((a, b) => a > b ? a : b);
    final bestResult = results.firstWhere((r) => r.score == bestScore);

    // Games completed
    final gamesCompleted = results.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Progress Bar
        _buildProgressCard(
          title: 'Recent Performance',
          subtitle: 'Last ${last5.length} sessions',
          progress: avgAcc,
          color: Colors.purple,
        ),
        const SizedBox(height: 16),

        // Achievement
        if (gamesCompleted >= 3)
          _buildAchievementCard(
            emoji: '🧩',
            title: '$gamesCompleted Games Completed!',
            subtitle: 'Keep building your memory',
            color: Colors.purple,
          ),

        const SizedBox(height: 12),

        // Best Performance
        _buildBestPerformanceCard(
          score: bestScore,
          accuracy: bestResult.accuracy,
          date: bestResult.playedAt,
        ),

        const SizedBox(height: 16),

        // Recent Sessions
        _buildRecentSessionsList(results),

        const SizedBox(height: 16),

        // Clinical Report Button
        _buildClinicianEntry(),
      ],
    );
  }

  // ============================================================
  // Shared Widgets
  // ============================================================
  Widget _buildProgressCard({
    required String title,
    required String subtitle,
    required double progress,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(subtitle,
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 24,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress * 100).toStringAsFixed(0)}% accuracy',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Icon(
                  progress > 0.7 ? Icons.trending_up : Icons.trending_flat,
                  color: progress > 0.7 ? Colors.green : Colors.orange,
                  size: 28,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementCard({
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 32)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBestPerformanceCard({
    required int score,
    required double accuracy,
    required DateTime date,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 24),
                SizedBox(width: 8),
                Text(
                  'Best Performance',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '$score',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    Text('Points',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '${(accuracy * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text('Accuracy',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Achieved on ${date.day}/${date.month}/${date.year}',
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSessionsList(List<GameResult> results) {
    final recent = List<GameResult>.from(results)
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    final shown = recent.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recent Sessions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...shown.map((r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: r.accuracy >= 0.7
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      r.accuracy >= 0.7
                          ? Icons.check_circle
                          : Icons.error_outline,
                      color: r.accuracy >= 0.7 ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Score ${r.score}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${(r.accuracy * 100).toStringAsFixed(0)}% • ${r.durationSeconds}s',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  trailing: Text(
                    '${r.playedAt.day}/${r.playedAt.month}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyGame(String gameName, IconData icon, Color color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 80, color: color.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'No $gameName sessions yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Start playing to track your progress!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClinicianEntry() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.medical_services, color: Colors.indigo),
        title: const Text('Clinical Report'),
        subtitle: const Text('For clinician review'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ClinicalReportScreen()),
        ),
      ),
    );
  }
}
