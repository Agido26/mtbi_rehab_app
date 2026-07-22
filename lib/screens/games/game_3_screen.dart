import 'package:flutter/material.dart';
import '../../widgets/common/app_scaffold.dart';

class Game3Screen extends StatelessWidget {
  const Game3Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Spatial Memory',
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.memory, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Coming Soon',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
