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

/// Defines a shape using either built-in painter OR custom images
class GameShape {
  final String id;
  final String displayName;

  // For built-in painted shapes
  final ShapeType? type;
  final Color? color;

  // For custom images
  final String? imagePath;
  final String? shadowPath;

  const GameShape.builtIn({
    required this.id,
    required this.displayName,
    required this.type,
    required this.color,
  })  : imagePath = null,
        shadowPath = null;

  const GameShape.custom({
    required this.id,
    required this.displayName,
    required this.imagePath,
    required this.shadowPath,
  })  : type = null,
        color = null;

  bool get isCustomImage => imagePath != null;
}

/// Built-in shape types (for CustomPaint)
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

class ShapeMatchConfig {
  final Difficulty difficulty;
  final List<GameShape> shapes;
  final int timeLimitSeconds;
  final int maxWrongAttempts;

  const ShapeMatchConfig({
    required this.difficulty,
    required this.shapes,
    required this.timeLimitSeconds,
    required this.maxWrongAttempts,
  });

  factory ShapeMatchConfig.forDifficulty(Difficulty difficulty) {
    // CHOOSE YOUR SHAPES HERE:
    // Option 1: Built-in painted shapes (works immediately)
    final builtInShapes = [
      const GameShape.builtIn(
          id: 'circle',
          displayName: 'Circle',
          type: ShapeType.circle,
          color: Colors.red),
      const GameShape.builtIn(
          id: 'square',
          displayName: 'Square',
          type: ShapeType.square,
          color: Colors.blue),
      const GameShape.builtIn(
          id: 'triangle',
          displayName: 'Triangle',
          type: ShapeType.triangle,
          color: Colors.green),
      const GameShape.builtIn(
          id: 'star',
          displayName: 'Star',
          type: ShapeType.star,
          color: Colors.orange),
      const GameShape.builtIn(
          id: 'heart',
          displayName: 'Heart',
          type: ShapeType.heart,
          color: Colors.pink),
    ];

    // Option 2: Custom images (uncomment when you have images)
    /*
    final customShapes = [
      GameShape.custom(id: 'circle', displayName: 'Circle', imagePath: 'assets/shapes/circle/shape.png', shadowPath: 'assets/shapes/circle/shadow.png'),
      GameShape.custom(id: 'star', displayName: 'Star', imagePath: 'assets/shapes/star/shape.png', shadowPath: 'assets/shapes/star/shadow.png'),
      // Add more...
    ];
    */

    final count = difficulty == Difficulty.easy
        ? 3
        : difficulty == Difficulty.medium
            ? 4
            : 5;
    final selected = builtInShapes.sublist(0, count);
    // final selected = customShapes.sublist(0, count); // Use this for custom images

    return ShapeMatchConfig(
      difficulty: difficulty,
      shapes: selected,
      timeLimitSeconds: difficulty.timeLimitSeconds,
      maxWrongAttempts: difficulty.maxWrongAttempts,
    );
  }
}
