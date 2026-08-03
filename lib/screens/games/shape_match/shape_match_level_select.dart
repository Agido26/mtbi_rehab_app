import 'package:flutter/material.dart';
import '../../../models/shape_match_config.dart';
import '../../../widgets/common/app_scaffold.dart';
import 'shape_match_game.dart';

class ShapeMatchLevelSelect extends StatelessWidget {
  const ShapeMatchLevelSelect({super.key});

  void _startGame(BuildContext context, Difficulty difficulty) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShapeMatchGame(difficulty: difficulty),
      ),
    );
  }

  Widget _buildLevelCard(
    BuildContext context,
    Difficulty difficulty,
    Color color,
    IconData icon,
  ) {
    final config = ShapeMatchConfig.forDifficulty(difficulty);

    return GestureDetector(
      onTap: () => _startGame(context, difficulty),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    difficulty.displayName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${config.shapes.length} shapes • ${config.timeLimitSeconds}s • ${config.maxWrongAttempts} max wrong',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Shape Match',
      body: Column(
        children: [
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Drag colored shapes to their matching shadows before time runs out!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 32),
          _buildLevelCard(
            context,
            Difficulty.easy,
            Colors.green,
            Icons.sentiment_satisfied,
          ),
          _buildLevelCard(
            context,
            Difficulty.medium,
            Colors.orange,
            Icons.sentiment_neutral,
          ),
          _buildLevelCard(
            context,
            Difficulty.hard,
            Colors.red,
            Icons.sentiment_very_dissatisfied,
          ),
        ],
      ),
    );
  }
}
