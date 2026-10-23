import 'package:flutter/material.dart';
import '../../../models/maze_config.dart';
import '../../../widgets/common/app_scaffold.dart';
import 'maze_game_screen.dart';

class MazeLevelSelect extends StatelessWidget {
  const MazeLevelSelect({super.key});

  void _startGame(BuildContext context, MazeDifficulty difficulty) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MazeGameScreen(difficulty: difficulty),
      ),
    );
  }

  Widget _buildLevelCard(
    BuildContext context,
    MazeDifficulty difficulty,
    Color color,
    IconData icon,
  ) {
    return GestureDetector(
      onTap: () => _startGame(context, difficulty),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
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
                    '${difficulty.gridSize}x${difficulty.gridSize} grid • ${difficulty.timeLimitSeconds}s time limit',
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
      title: 'Maze Runner',
      body: Column(
        children: [
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Trace the path to the star without lifting your finger or hitting the walls!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 32),
          _buildLevelCard(
            context,
            MazeDifficulty.easy,
            Colors.green,
            Icons.sentiment_satisfied,
          ),
          _buildLevelCard(
            context,
            MazeDifficulty.medium,
            Colors.orange,
            Icons.sentiment_neutral,
          ),
          _buildLevelCard(
            context,
            MazeDifficulty.hard,
            Colors.red,
            Icons.sentiment_very_dissatisfied,
          ),
        ],
      ),
    );
  }
}
