import '../models/game_result.dart';
import 'storage_service.dart';

class GameDataService {
  final StorageService _storage = StorageService();

  Future<void> saveResult(GameResult result) async {
    await _storage.saveGameResult(result);
  }

  Future<List<GameResult>> getPatientHistory(String patientId) async {
    return await _storage.getResultsForPatient(patientId);
  }

  Future<Map<GameType, List<GameResult>>> getProgressData(
    String patientId,
  ) async {
    return await _storage.getAllResultsByGame(patientId);
  }

  Future<Map<GameType, Map<String, dynamic>>> getSummaryStats(
    String patientId,
  ) async {
    final byGame = await getProgressData(patientId);
    final stats = <GameType, Map<String, dynamic>>{};

    for (final entry in byGame.entries) {
      final results = entry.value;
      if (results.isEmpty) continue;

      final totalScore = results.fold<int>(0, (sum, r) => sum + r.score);
      final totalCorrect =
          results.fold<int>(0, (sum, r) => sum + r.correctAttempts);
      final totalAttempts =
          results.fold<int>(0, (sum, r) => sum + r.totalAttempts);
      final avgDuration =
          results.fold<int>(0, (sum, r) => sum + r.durationSeconds) /
              results.length;

      stats[entry.key] = {
        'sessionsPlayed': results.length,
        'averageScore': totalScore / results.length,
        'totalCorrect': totalCorrect,
        'totalAttempts': totalAttempts,
        'accuracy': totalAttempts > 0 ? totalCorrect / totalAttempts : 0.0,
        'averageDurationSeconds': avgDuration,
        'lastPlayed': results.first.playedAt,
        'bestScore':
            results.map((r) => r.score).reduce((a, b) => a > b ? a : b),
      };
    }

    return stats;
  }
}
