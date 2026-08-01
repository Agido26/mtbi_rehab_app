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

  int get shapeCount {
    switch (this) {
      case Difficulty.easy:
        return 3;
      case Difficulty.medium:
        return 4;
      case Difficulty.hard:
        return 5;
    }
  }

  int get timeLimitSeconds {
    switch (this) {
      case Difficulty.easy:
        return 60;
      case Difficulty.medium:
        return 45;
      case Difficulty.hard:
        return 30;
    }
  }

  int get maxWrongAttempts {
    switch (this) {
      case Difficulty.easy:
        return 10;
      case Difficulty.medium:
        return 8;
      case Difficulty.hard:
        return 5;
    }
  }
}

enum ShapeType {
  circle,
  square,
  triangle,
  star,
  diamond,
  hexagon,
  heart,
  cross,
  moon,
  arrow,
}

extension ShapeTypeExt on ShapeType {
  String get displayName {
    return name[0].toUpperCase() + name.substring(1);
  }
}

class ShapeMatchConfig {
  final Difficulty difficulty;
  final List<ShapeType> shapes;
  final List<Color> colors;
  final int timeLimitSeconds;
  final int maxWrongAttempts;

  const ShapeMatchConfig({
    required this.difficulty,
    required this.shapes,
    required this.colors,
    required this.timeLimitSeconds,
    required this.maxWrongAttempts,
  });

  factory ShapeMatchConfig.forDifficulty(Difficulty difficulty) {
    final allShapes = ShapeType.values;
    final count = difficulty.shapeCount;
    final selected = allShapes.sublist(0, count);

    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
    ].sublist(0, count);

    return ShapeMatchConfig(
      difficulty: difficulty,
      shapes: selected,
      colors: colors,
      timeLimitSeconds: difficulty.timeLimitSeconds,
      maxWrongAttempts: difficulty.maxWrongAttempts,
    );
  }
}
