import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../models/game_result.dart';
import '../../../models/maze_config.dart';
import '../../../services/auth_service.dart';
import '../../../services/game_data_service.dart';

class MazeGameScreen extends StatefulWidget {
  final MazeDifficulty difficulty;
  const MazeGameScreen({super.key, required this.difficulty});

  @override
  State<MazeGameScreen> createState() => _MazeGameScreenState();
}

class _MazeGameScreenState extends State<MazeGameScreen> {
  late List<List<int>> _grid;
  late int _cellSize;
  late int _gridSize;

  double _playerX = 1.0;
  double _playerY = 1.0;
  final List<Offset> _trail = [];

  int _timeLeft = 0;
  Timer? _timer;
  Timer? _moveTimer; // ✅ للتحرك المستمر
  bool _isFinished = false;
  bool _isSuccess = false;

  int _resetCount = 0;
  DateTime? _startTime;

  // ✅ Joystick state
  double _joystickX = 0.0; // -1 إلى 1
  double _joystickY = 0.0; // -1 إلى 1
  bool _isJoystickActive = false;

  bool _isRetreating = false;
  Timer? _retreatTimer;

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  void _startNewGame() {
    _gridSize = widget.difficulty.gridSize;
    _grid = MazeGenerator.generate(_gridSize);
    _playerX = 1.0;
    _playerY = 1.0;
    _trail.clear();
    _timeLeft = widget.difficulty.timeLimitSeconds;
    _isFinished = false;
    _isSuccess = false;
    _resetCount = 0;
    _isRetreating = false;
    _joystickX = 0.0;
    _joystickY = 0.0;
    _isJoystickActive = false;
    _startTime = DateTime.now();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) _endGame(false);
      });
    });

    // ✅ حركة مستمرة كل 16ms (~60fps)
    _moveTimer?.cancel();
    _moveTimer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      if (!mounted || _isFinished || _isRetreating) return;
      if (_isJoystickActive && (_joystickX != 0 || _joystickY != 0)) {
        _movePlayer();
      }
    });
  }

  void _endGame(bool success) {
    _timer?.cancel();
    _moveTimer?.cancel();
    _retreatTimer?.cancel();
    setState(() {
      _isFinished = true;
      _isSuccess = success;
    });
    _saveResult(success);
  }

  Future<void> _saveResult(bool success) async {
    final duration = DateTime.now().difference(_startTime!).inSeconds;
    final result = GameResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: AuthService().currentPatient!.id,
      gameType: GameType.maze,
      score: success ? widget.difficulty.timeLimitSeconds - _timeLeft + 100 : 0,
      totalAttempts: 1,
      correctAttempts: success ? 1 : 0,
      durationSeconds: duration,
      playedAt: DateTime.now(),
      metadata: {
        'difficulty': widget.difficulty.name,
        'resetCount': _resetCount,
        'completed': success,
      },
    );
    await GameDataService().saveResult(result);
  }

  // ✅ حركة اللاعب بناءً على joystick
  void _movePlayer() {
    final speed = 0.08; // سرعة الحركة (خلايا في الثانية)
    final newX = _playerX + _joystickX * speed;
    final newY = _playerY + _joystickY * speed;

    // التحقق من الاصطدام
    final canMoveX = _isPath(newX, _playerY);
    final canMoveY = _isPath(_playerX, newY);

    setState(() {
      if (canMoveX) _playerX = newX;
      if (canMoveY) _playerY = newY;

      // إضافة نقطة للمسار
      if (_trail.isEmpty ||
          (_playerX - _trail.last.dx).abs() > 0.05 ||
          (_playerY - _trail.last.dy).abs() > 0.05) {
        _trail.add(Offset(_playerX, _playerY));
      }
    });

    // التحقق من الوصول للنهاية
    final endX = _gridSize - 2;
    final endY = _gridSize - 2;
    if ((_playerX - endX).abs() < 0.6 && (_playerY - endY).abs() < 0.6) {
      _endGame(true);
    }
  }

  bool _isPath(double gx, double gy) {
    if (gx < 0 || gx >= _gridSize || gy < 0 || gy >= _gridSize) return false;
    final ix = gx.floor().clamp(0, _gridSize - 1);
    final iy = gy.floor().clamp(0, _gridSize - 1);
    return _grid[iy][ix] != 0;
  }

  void _startRetreat() {
    if (_isRetreating || _trail.isEmpty) {
      setState(() {
        _playerX = 1.0;
        _playerY = 1.0;
      });
      return;
    }

    _isRetreating = true;
    _retreatTimer?.cancel();
    _retreatTimer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_trail.length > 1) {
          _trail.removeLast();
          final last = _trail.last;
          _playerX = last.dx;
          _playerY = last.dy;
        } else {
          _trail.clear();
          _playerX = 1.0;
          _playerY = 1.0;
          _isRetreating = false;
          t.cancel();
        }
      });
    });
  }

  void _resetPlayer() {
    if (_isRetreating) return;
    setState(() {
      _resetCount++;
      _isJoystickActive = false;
      _joystickX = 0.0;
      _joystickY = 0.0;
    });
    _startRetreat();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _moveTimer?.cancel();
    _retreatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width - 32;
    _cellSize = (screenWidth / _gridSize).floor();
    final mazePixelSize = _cellSize * _gridSize;

    return Scaffold(
      appBar: AppBar(
        title: Text('Maze - ${widget.difficulty.displayName}'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                '⏱ $_timeLeft',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Use the joystick to move. Lift joystick to reset!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: CustomPaint(
                    size: Size(
                        mazePixelSize.toDouble(), mazePixelSize.toDouble()),
                    painter: MazePainter(
                      grid: _grid,
                      cellSize: _cellSize,
                      playerX: _playerX,
                      playerY: _playerY,
                      trail: _trail,
                      isRetreating: _isRetreating,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // ✅ Joystick في الزاوية السفلية اليسرى
          Positioned(
            left: 24,
            bottom: 24,
            child: _buildJoystick(),
          ),
          if (_isFinished) _buildResultOverlay(),
        ],
      ),
    );
  }

  // ✅ Joystick Widget
  Widget _buildJoystick() {
    const joystickSize = 120.0;
    const knobSize = 50.0;

    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          _isJoystickActive = true;
        });
      },
      onPanUpdate: (details) {
        final dx = details.localPosition.dx - joystickSize / 2;
        final dy = details.localPosition.dy - joystickSize / 2;
        final distance = sqrt(dx * dx + dy * dy);
        const maxDistance = joystickSize / 2 - knobSize / 2;

        double normalizedX = 0.0;
        double normalizedY = 0.0;

        if (distance > 0) {
          final clampedDistance = distance.clamp(0.0, maxDistance);
          normalizedX = (dx / distance) * (clampedDistance / maxDistance);
          normalizedY = (dy / distance) * (clampedDistance / maxDistance);
        }

        setState(() {
          _joystickX = normalizedX;
          _joystickY = normalizedY;
        });
      },
      onPanEnd: (_) {
        setState(() {
          _isJoystickActive = false;
          _joystickX = 0.0;
          _joystickY = 0.0;
        });
        _resetPlayer(); // ✅ رفع joystick = رجوع للبداية
      },
      child: Container(
        width: joystickSize,
        height: joystickSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[300],
          border: Border.all(color: Colors.grey[400]!, width: 2),
        ),
        child: Stack(
          children: [
            Positioned(
              left: joystickSize / 2 -
                  knobSize / 2 +
                  _joystickX * (joystickSize / 2 - knobSize / 2),
              top: joystickSize / 2 -
                  knobSize / 2 +
                  _joystickY * (joystickSize / 2 - knobSize / 2),
              child: Container(
                width: knobSize,
                height: knobSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      _isJoystickActive ? Colors.teal[700] : Colors.teal[400],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isSuccess ? Icons.check_circle : Icons.error_outline,
                  color: _isSuccess ? Colors.green : Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  _isSuccess ? 'Completed!' : 'Time\'s Up!',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Resets: $_resetCount'),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to Menu'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// رسم المتاهة (مبسط - بدون offset)
// ============================================================
class MazePainter extends CustomPainter {
  final List<List<int>> grid;
  final int cellSize;
  final double playerX;
  final double playerY;
  final List<Offset> trail;
  final bool isRetreating;

  MazePainter({
    required this.grid,
    required this.cellSize,
    required this.playerX,
    required this.playerY,
    required this.trail,
    required this.isRetreating,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final wallPaint = Paint()..color = const Color(0xFF37474F);
    final pathPaint = Paint()..color = const Color(0xFFF5F5F5);
    final startPaint = Paint()..color = const Color(0xFF42A5F5);
    final endPaint = Paint()..color = const Color(0xFF66BB6A);

    final trailPaint = Paint()
      ..color = const Color(0xFF26A69A)
      ..strokeWidth = cellSize * 0.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final playerPaint = Paint()..color = const Color(0xFF00695C);
    final playerGlow = Paint()
      ..color = const Color(0xFF00695C).withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    const wallMargin = 0.2;
    final margin = cellSize * wallMargin;
    final radius = cellSize * 0.1;

    // 1. خلفية الممرات
    for (int y = 0; y < grid.length; y++) {
      for (int x = 0; x < grid[y].length; x++) {
        canvas.drawRect(
          Rect.fromLTWH(x * cellSize.toDouble(), y * cellSize.toDouble(),
              cellSize.toDouble(), cellSize.toDouble()),
          pathPaint,
        );
      }
    }

    // 2. الجدران
    for (int y = 0; y < grid.length; y++) {
      for (int x = 0; x < grid[y].length; x++) {
        if (grid[y][x] == 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                x * cellSize.toDouble() + margin,
                y * cellSize.toDouble() + margin,
                cellSize.toDouble() - (margin * 2),
                cellSize.toDouble() - (margin * 2),
              ),
              Radius.circular(radius),
            ),
            wallPaint,
          );
        }
      }
    }

    // 3. البداية والنهاية
    for (int y = 0; y < grid.length; y++) {
      for (int x = 0; x < grid[y].length; x++) {
        final cell = grid[y][x];
        final rect = Rect.fromLTWH(x * cellSize.toDouble(),
            y * cellSize.toDouble(), cellSize.toDouble(), cellSize.toDouble());

        if (cell == 2) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  rect.deflate(cellSize * 0.1), Radius.circular(radius)),
              startPaint);
          final textPainter = TextPainter(
            text: TextSpan(
                text: 'START',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: cellSize * 0.18,
                    fontWeight: FontWeight.bold)),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(
              canvas,
              Offset(x * cellSize + (cellSize - textPainter.width) / 2,
                  y * cellSize + (cellSize - textPainter.height) / 2));
        } else if (cell == 3) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  rect.deflate(cellSize * 0.1), Radius.circular(radius)),
              endPaint);
          _drawStar(
              canvas,
              Offset(x * cellSize.toDouble() + cellSize / 2,
                  y * cellSize.toDouble() + cellSize / 2),
              cellSize * 0.35,
              const Color(0xFF1B5E20));
        }
      }
    }

    // 4. رسم الخط
    if (trail.length > 1) {
      final path = Path();
      path.moveTo(trail.first.dx * cellSize + cellSize / 2,
          trail.first.dy * cellSize + cellSize / 2);
      for (int i = 1; i < trail.length; i++) {
        path.lineTo(trail[i].dx * cellSize + cellSize / 2,
            trail[i].dy * cellSize + cellSize / 2);
      }
      canvas.drawPath(path, trailPaint);
    }

    // 5. رسم اللاعب
    final playerCenter = Offset(
        playerX * cellSize + cellSize / 2, playerY * cellSize + cellSize / 2);
    canvas.drawCircle(playerCenter, cellSize * 0.5, playerGlow);
    canvas.drawCircle(playerCenter, cellSize * 0.3, playerPaint);
    canvas.drawCircle(
        playerCenter, cellSize * 0.12, Paint()..color = Colors.white);

    // 6. مؤشر التراجع
    if (isRetreating && trail.isNotEmpty) {
      final retreatPaint = Paint()
        ..color = const Color(0xFFFF5252).withOpacity(0.5)
        ..strokeWidth = cellSize * 0.25
        ..strokeCap = StrokeCap.round;
      final last = trail.last;
      canvas.drawCircle(
        Offset(last.dx * cellSize + cellSize / 2,
            last.dy * cellSize + cellSize / 2),
        cellSize * 0.25,
        retreatPaint,
      );
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()..color = color;
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final r = i.isEven ? radius : radius * 0.45;
      final angle = (i * 36 - 90) * 3.14159 / 180;
      final point =
          Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant MazePainter oldDelegate) {
    return oldDelegate.playerX != playerX ||
        oldDelegate.playerY != playerY ||
        oldDelegate.trail.length != trail.length ||
        oldDelegate.isRetreating != isRetreating;
  }
}
