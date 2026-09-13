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

  /// 🎯 أشكال كل مستوى
  List<String> get shapeIds {
    switch (this) {
      case Difficulty.easy:
        return ['circle', 'triangle', 'cube'];
      case Difficulty.medium:
        return ['circle', 'triangle', 'cube', 'star'];
      case Difficulty.hard:
        return ['cat', 'dog', 'star', 'diamond'];
    }
  }

  int get cardsCount => shapeIds.length;

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
        return 2;
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
        return 25;
    }
  }

  /// 🔥 الصعب بس: الترتيب يختفي بعد الـ peek
  bool get hideSequenceAfterPeek => this == Difficulty.hard;
}

class ShapeMatchConfig {
  final Difficulty difficulty;
  final List<String> shapeIds;
  final int cardsCount;
  final int roundsCount;
  final int peeksAllowed;
  final int peekDurationSeconds;
  final int showResultsDurationSeconds;
  final int pointsPerRound;
  final int roundTimeLimitSeconds;
  final bool hideSequenceAfterPeek;

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
    required this.hideSequenceAfterPeek,
  });

  factory ShapeMatchConfig.forDifficulty(Difficulty difficulty) {
    return ShapeMatchConfig(
      difficulty: difficulty,
      shapeIds: difficulty.shapeIds,
      cardsCount: difficulty.cardsCount,
      roundsCount: difficulty.roundsCount,
      peeksAllowed: difficulty.peeksAllowed,
      peekDurationSeconds: difficulty.peekDurationSeconds,
      showResultsDurationSeconds: 3,
      pointsPerRound: difficulty.pointsPerRound,
      roundTimeLimitSeconds: difficulty.roundTimeLimitSeconds,
      hideSequenceAfterPeek: difficulty.hideSequenceAfterPeek,
    );
  }
}
