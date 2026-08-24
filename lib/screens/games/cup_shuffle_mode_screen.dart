import 'package:flutter/material.dart';
import '../../models/cupshuffleconfig.dart';
import '../../widgets/common/app_scaffold.dart';
import 'cup_shuffle_game.dart';

class CupShuffleModeScreen extends StatelessWidget {
  const CupShuffleModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Cup Shuffle AR',
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Choose Difficulty',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Find the ball hidden under the cups',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              _buildModeCard(
                context,
                CupDifficulty.easy,
                '3 Cups • 5 Rounds • 3 Shuffles',
                'Best for beginners or when tired',
              ),
              const SizedBox(height: 16),
              _buildModeCard(
                context,
                CupDifficulty.medium,
                '4 Cups • 4 Rounds • 5 Shuffles',
                'Moderate challenge',
              ),
              const SizedBox(height: 16),
              _buildModeCard(
                context,
                CupDifficulty.hard,
                '5 Cups • 3 Rounds • 7 Shuffles',
                'Maximum cognitive load',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard(
    BuildContext context,
    CupDifficulty diff,
    String subtitle,
    String description,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CupShuffleGame(
                config: CupShuffleConfig(difficulty: diff),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: diff.color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.sports_esports, color: diff.color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      diff.displayName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: diff.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text(
                      description,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: diff.color),
            ],
          ),
        ),
      ),
    );
  }
}
