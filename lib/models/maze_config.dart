import 'dart:math';

enum MazeDifficulty { easy, medium, hard }

extension MazeDifficultyExt on MazeDifficulty {
  String get displayName {
    switch (this) {
      case MazeDifficulty.easy:
        return 'Easy';
      case MazeDifficulty.medium:
        return 'Medium';
      case MazeDifficulty.hard:
        return 'Hard';
    }
  }

  // أحجام الشبكة (يجب أن تكون أرقاماً فردية لخوارزمية التوليد)
  int get gridSize {
    switch (this) {
      case MazeDifficulty.easy:
        return 7; // 7x7
      case MazeDifficulty.medium:
        return 9; // 9x9
      case MazeDifficulty.hard:
        return 11; // 11x11
    }
  }

  int get timeLimitSeconds {
    switch (this) {
      case MazeDifficulty.easy:
        return 60;
      case MazeDifficulty.medium:
        return 45;
      case MazeDifficulty.hard:
        return 30;
    }
  }
}

class MazeGenerator {
  /// يولد متاهة عشوائية.
  /// 0 = جدار, 1 = ممر, 2 = بداية, 3 = نهاية
  static List<List<int>> generate(int size) {
    // تهيئة الشبكة بالجدران (0)
    final grid = List.generate(size, (_) => List.filled(size, 0));

    // خوارزمية Recursive Backtracker مبسطة
    final stack = <(int, int)>[];
    final start = (1, 1);
    grid[start.$1][start.$2] = 1;
    stack.add(start);

    final directions = [(0, -2), (0, 2), (-2, 0), (2, 0)];
    final random = Random();

    while (stack.isNotEmpty) {
      final current = stack.last;
      final neighbors = <(int, int, int, int)>[];

      for (final dir in directions) {
        final nx = current.$1 + dir.$1;
        final ny = current.$2 + dir.$2;
        if (nx > 0 &&
            nx < size - 1 &&
            ny > 0 &&
            ny < size - 1 &&
            grid[ny][nx] == 0) {
          neighbors.add(
              (nx, ny, current.$1 + dir.$1 ~/ 2, current.$2 + dir.$2 ~/ 2));
        }
      }

      if (neighbors.isNotEmpty) {
        final next = neighbors[random.nextInt(neighbors.length)];
        grid[next.$2][next.$1] = 1; // الممر الجديد
        grid[next.$4][next.$3] = 1; // الجدار بين الحالي والجديد
        stack.add((next.$1, next.$2));
      } else {
        stack.removeLast();
      }
    }

    // تعيين البداية والنهاية
    grid[1][1] = 2; // بداية
    grid[size - 2][size - 2] = 3; // نهاية

    return grid;
  }
}
