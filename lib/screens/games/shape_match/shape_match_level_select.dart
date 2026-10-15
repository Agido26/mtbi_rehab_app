import 'package:flutter/material.dart';
import '../../../models/shape_match_config.dart';
import '../../../widgets/common/app_scaffold.dart';
import 'shape_match_game.dart';

class ShapeMatchLevelSelect extends StatelessWidget {
  const ShapeMatchLevelSelect({super.key});

  void _startGame(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ShapeMatchGame(difficulty: Difficulty.easy),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ShapeMatchConfig.forDifficulty(Difficulty.easy);

    return AppScaffold(
      title: 'Shape Match',
      body: Column(
        children: [
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Match the AR shapes to the order shown at the top of the screen!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 32),
          // ✅ Single "Standard" mode card (no medium/hard)
          GestureDetector(
            onTap: () => _startGame(context),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.sentiment_satisfied,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Standard',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${config.cardsCount} shapes • ${config.roundsCount} rounds • ${config.peeksAllowed} peeks',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.green),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
