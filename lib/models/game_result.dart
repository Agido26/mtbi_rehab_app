enum GameType {
  cupShuffle('Cup Shuffle', 'Train visual attention and memory'),
  visualScanning('Visual Scanning', 'Improve visual scanning speed'),
  shapeMatch(
    'Shape Match',
    'Pattern recognition and visual attention',
  ); // ADD THIS

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

  // Add this method to GameResult class:

  GameResult copyWith({
    String? id,
    String? patientId,
    GameType? gameType,
    int? score,
    int? totalAttempts,
    int? correctAttempts,
    int? durationSeconds,
    DateTime? playedAt,
    Map<String, dynamic>? metadata,
  }) {
    return GameResult(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      gameType: gameType ?? this.gameType,
      score: score ?? this.score,
      totalAttempts: totalAttempts ?? this.totalAttempts,
      correctAttempts: correctAttempts ?? this.correctAttempts,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      playedAt: playedAt ?? this.playedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  double get accuracy =>
      totalAttempts > 0 ? correctAttempts / totalAttempts : 0;

  factory GameResult.fromJson(Map<String, dynamic> json) {
    return GameResult(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      gameType: GameType.values.firstWhere((e) => e.name == json['gameType']),
      score: json['score'] as int,
      totalAttempts: json['totalAttempts'] as int,
      correctAttempts: json['correctAttempts'] as int,
      durationSeconds: json['durationSeconds'] as int,
      playedAt: DateTime.parse(json['playedAt'] as String),
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
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
