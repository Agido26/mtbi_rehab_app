import 'package:flutter/material.dart';
import '../models/game_result.dart';

class GameCard extends StatelessWidget {
  final GameType gameType;
  final VoidCallback onTap;
  final bool isLocked;

  const GameCard({
    super.key,
    required this.gameType,
    required this.onTap,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isLocked ? Colors.grey[300] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!isLocked)
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
          border: Border.all(
            color: isLocked ? Colors.grey[400]! : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isLocked
                    ? Colors.grey[400]
                    : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIcon(),
                color: isLocked
                    ? Colors.grey[600]
                    : Theme.of(context).colorScheme.primary,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gameType.displayName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isLocked ? Colors.grey[600] : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    gameType.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: isLocked ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isLocked ? Icons.lock : Icons.arrow_forward_ios,
              color: isLocked ? Colors.grey[500] : Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (gameType) {
      case GameType.cupShuffle:
        return Icons.threed_rotation;
      case GameType.visualScanning:
        return Icons.visibility;
      case GameType.shapeMatch: // ADD THIS
        return Icons.interests; // or any icon you like
    }
  }
}
