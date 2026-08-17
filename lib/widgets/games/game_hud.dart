import 'package:flutter/material.dart';
import '../../models/shape_match_config.dart';

class GameHUD extends StatelessWidget {
  final Difficulty difficulty;
  final int remainingTime;
  final int wrongAttempts;
  final int maxWrongAttempts;
  final int matchedCount;
  final int totalShapes;
  final VoidCallback onPause;
  final VoidCallback onHint;

  const GameHUD({
    super.key,
    required this.difficulty,
    required this.remainingTime,
    required this.wrongAttempts,
    required this.maxWrongAttempts,
    required this.matchedCount,
    required this.totalShapes,
    required this.onPause,
    required this.onHint,
  });

  @override
  Widget build(BuildContext context) {
    final timeColor = remainingTime <= 10 ? Colors.red : Colors.white;
    final attemptsColor =
        wrongAttempts >= maxWrongAttempts - 2 ? Colors.red : Colors.orange;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Top bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Level badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    difficulty.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Timer
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer, color: timeColor, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '${remainingTime}s',
                        style: TextStyle(
                          color: timeColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Pause button
                GestureDetector(
                  onTap: onPause,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pause, color: Colors.white),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Bottom stats bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Progress
                  _buildStat(
                    Icons.check_circle,
                    '$matchedCount/$totalShapes',
                    Colors.green,
                  ),
                  // Wrong attempts
                  _buildStat(
                    Icons.error,
                    '$wrongAttempts/$maxWrongAttempts',
                    attemptsColor,
                  ),
                  // Hint button
                  GestureDetector(
                    onTap: onHint,
                    child: _buildStat(
                      Icons.lightbulb,
                      'Hint',
                      Colors.yellow,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
