import 'package:flutter/material.dart';

enum Difficulty { easy, medium, hard }

extension DifficultyExt on Difficulty {
  String get displayName {
    switch (this) {
      case Difficulty.easy:
        return 'Easy';
      case Difficulty.medium:
        return 'Medium';
      case Difficulty.hard:
        return 'Hard';
    }
  }

  Color get color {
    switch (this) {
      case Difficulty.easy:
        return Colors.green;
      case Difficulty.medium:
        return Colors.orange;
      case Difficulty.hard:
        return Colors.red;
    }
  }

  int get cardsCount {
    switch (this) {
      case Difficulty.easy:
        return 3;
      case Difficulty.medium:
        return 4;
      case Difficulty.hard:
        return 5;
    }
  }

  int get roundsCount {
    switch (this) {
      case Difficulty.easy:
        return 5;
      case Difficulty.medium:
        return 4;
      case Difficulty.hard:
        return 3;
    }
  }

  int get peeksAllowed {
    switch (this) {
      case Difficulty.easy:
        return 3;
      case Difficulty.medium:
        return 2;
      case Difficulty.hard:
        return 1;
    }
  }

  int get peekDurationSeconds {
    switch (this) {
      case Difficulty.easy:
        return 5;
      case Difficulty.medium:
        return 4;
      case Difficulty.hard:
        return 3;
    }
  }

  int get pointsPerRound {
    switch (this) {
      case Difficulty.easy:
        return 10;
      case Difficulty.medium:
        return 12;
      case Difficulty.hard:
        return 15;
    }
  }

  int get roundTimeLimitSeconds {
    switch (this) {
      case Difficulty.easy:
        return 60;
      case Difficulty.medium:
        return 45;
      case Difficulty.hard:
        return 30;
    }
  }
}

/// Shape identifiers — MUST match order in the .mind file.
/// targetIndex 0 = circle, 1 = star, 2 = triangle, 3 = heart, 4 = square
const List<String> kAllShapeIds = [
  'circle',
  'star',
  'triangle',
  'heart',
  'square'
];

/// Colors used for silhouettes and 3D models
const Map<String, Color> kShapeColors = {
  'circle': Color(0xFFE53935), // red
  'star': Color(0xFFFDD835), // yellow
  'triangle': Color(0xFF43A047), // green
  'heart': Color(0xFFE91E63), // pink
  'square': Color(0xFF1E88E5), // blue
};

class ShapeMatchConfig {
  final Difficulty difficulty;
  final List<String> shapeIds; // subset of kAllShapeIds for this level
  final int cardsCount;
  final int roundsCount;
  final int peeksAllowed;
  final int peekDurationSeconds;
  final int showResultsDurationSeconds;
  final int pointsPerRound;
  final int roundTimeLimitSeconds;

  const ShapeMatchConfig({
    required this.difficulty,
    required this.shapeIds,
    required this.cardsCount,
    required this.roundsCount,
    required this.peeksAllowed,
    required this.peekDurationSeconds,
    required this.showResultsDurationSeconds,
    required this.pointsPerRound,
    required this.roundTimeLimitSeconds,
  });

  factory ShapeMatchConfig.forDifficulty(Difficulty difficulty) {
    final count = difficulty.cardsCount;
    return ShapeMatchConfig(
      difficulty: difficulty,
      shapeIds: kAllShapeIds.sublist(0, count),
      cardsCount: count,
      roundsCount: difficulty.roundsCount,
      peeksAllowed: difficulty.peeksAllowed,
      peekDurationSeconds: difficulty.peekDurationSeconds,
      showResultsDurationSeconds: 3,
      pointsPerRound: difficulty.pointsPerRound,
      roundTimeLimitSeconds: difficulty.roundTimeLimitSeconds,
    );
  }
}
