import 'package:flutter/material.dart';

enum CupDifficulty { easy, medium, hard }

extension CupDifficultyExt on CupDifficulty {
  String get displayName {
    switch (this) {
      case CupDifficulty.easy:
        return 'Easy';
      case CupDifficulty.medium:
        return 'Medium';
      case CupDifficulty.hard:
        return 'Hard';
    }
  }

  int get cupsCount {
    switch (this) {
      case CupDifficulty.easy:
        return 3;
      case CupDifficulty.medium:
        return 4;
      case CupDifficulty.hard:
        return 5;
    }
  }

  int get roundsCount {
    switch (this) {
      case CupDifficulty.easy:
        return 5;
      case CupDifficulty.medium:
        return 4;
      case CupDifficulty.hard:
        return 3;
    }
  }

  int get shufflesPerRound {
    switch (this) {
      case CupDifficulty.easy:
        return 3;
      case CupDifficulty.medium:
        return 5;
      case CupDifficulty.hard:
        return 7;
    }
  }

  // ⬇️ ده السطر الناقص — لازم يكون جوا الـ extension
  int get pointsPerRound {
    switch (this) {
      case CupDifficulty.easy:
        return 10;
      case CupDifficulty.medium:
        return 12;
      case CupDifficulty.hard:
        return 15;
    }
  }

  Color get color {
    switch (this) {
      case CupDifficulty.easy:
        return Colors.green;
      case CupDifficulty.medium:
        return Colors.orange;
      case CupDifficulty.hard:
        return Colors.red;
    }
  }
}

class CupShuffleConfig {
  final CupDifficulty difficulty;

  const CupShuffleConfig({required this.difficulty});

  int get cupsCount => difficulty.cupsCount;
  int get roundsCount => difficulty.roundsCount;
  int get shufflesPerRound => difficulty.shufflesPerRound;
}
