import 'package:flutter/material.dart';
import '../../widgets/common/app_scaffold.dart';

class CupShuffleGame extends StatefulWidget {
  const CupShuffleGame({super.key});

  @override
  State<CupShuffleGame> createState() => _CupShuffleGameState();
}

class _CupShuffleGameState extends State<CupShuffleGame> {
  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Cup Shuffle',
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.threed_rotation, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'AR Game Coming Soon',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'This game will use ARCore for Android',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
