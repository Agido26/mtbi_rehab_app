enum GameType {
  cupShuffle('Cup Shuffle', 'Train visual attention and memory'),
  visualScanning('Visual Scanning', 'Improve visual scanning speed'),
  spatialMemory('Spatial Memory', 'Enhance working memory');

  final String displayName;
  final String description;

  const GameType(this.displayName, this.description);
}

class GameResult {
  final String id;
  final String patientId;
  final GameType gameType;
  final int score;
  final int totalAttempts;
  final int correctAttempts;
  final int durationSeconds;
  final DateTime playedAt;
  final Map<String, dynamic>? metadata;

  GameResult({
    required this.id,
    required this.patientId,
    required this.gameType,
    required this.score,
    required this.totalAttempts,
    required this.correctAttempts,
    required this.durationSeconds,
    required this.playedAt,
    this.metadata,
  });

  double get accuracy =>
      totalAttempts > 0 ? correctAttempts / totalAttempts : 0;

  factory GameResult.fromJson(Map<String, dynamic> json) {
    return GameResult(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      gameType: GameType.values.firstWhere(
        (e) => e.name == json['gameType'],
      ),
      score: json['score'] as int,
      totalAttempts: json['totalAttempts'] as int,
      correctAttempts: json['correctAttempts'] as int,
      durationSeconds: json['durationSeconds'] as int,
      playedAt: DateTime.parse(json['playedAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'gameType': gameType.name,
      'score': score,
      'totalAttempts': totalAttempts,
      'correctAttempts': correctAttempts,
      'durationSeconds': durationSeconds,
      'playedAt': playedAt.toIso8601String(),
      'metadata': metadata,
    };
  }
}
