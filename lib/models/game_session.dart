import 'game_result.dart';

/// Represents a single game play session.
/// Tracks timing, scores, and state during active gameplay.
class GameSession {
  final String id;
  final String patientId;
  final GameType gameType;
  final DateTime startedAt;
  DateTime? endedAt;

  int score = 0;
  int totalAttempts = 0;
  int correctAttempts = 0;
  int durationSeconds = 0;

  GameSession({
    required this.id,
    required this.patientId,
    required this.gameType,
    required this.startedAt,
  });

  void endSession() {
    endedAt = DateTime.now();
    durationSeconds = endedAt!.difference(startedAt).inSeconds;
  }

  GameResult toResult() {
    if (endedAt == null) endSession();
    return GameResult(
      id: id,
      patientId: patientId,
      gameType: gameType,
      score: score,
      totalAttempts: totalAttempts,
      correctAttempts: correctAttempts,
      durationSeconds: durationSeconds,
      playedAt: startedAt,
    );
  }
}
