import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../models/game_result.dart';
import '../../../models/game_session.dart';
import '../../../models/shape_match_config.dart';
import '../../../services/auth_service.dart';
import '../../../services/game_data_service.dart';
import '../../../widgets/common/app_scaffold.dart';
import '../../../widgets/games/camera_background.dart';
import '../../../widgets/games/game_hud.dart';
import '../../../widgets/games/shape_painter.dart';

class ShapeMatchGame extends StatefulWidget {
  final Difficulty difficulty;

  const ShapeMatchGame({
    super.key,
    required this.difficulty,
  });

  @override
  State<ShapeMatchGame> createState() => _ShapeMatchGameState();
}

class _ShapeMatchGameState extends State<ShapeMatchGame> {
  late final ShapeMatchConfig _config;
  late final GameSession _session;
  late final List<GameShape> _shapes; // CHANGED: GameShape not ShapeType
  final Set<String> _matchedShapeIds =
      {}; // Tracks which shape IDs are already placed

  Timer? _timer;
  int _remainingTime = 0;
  int _wrongAttempts = 0;
  int _hintsUsed = 0;
  bool _gameOver = false;
  bool _isPaused = false;

  final GlobalKey _dragAreaKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _config = ShapeMatchConfig.forDifficulty(widget.difficulty);
    _shapes = List.from(_config.shapes);
    _remainingTime = _config.timeLimitSeconds;

    _shapes.shuffle();

    final patient = AuthService().currentPatient!;
    _session = GameSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: patient.id,
      gameType: GameType.shapeMatch,
      startedAt: DateTime.now(),
    );

    _requestCameraPermission();
    _startTimer();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (!status.isGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Camera permission needed for background')),
      );
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused || _gameOver) return;
      setState(() {
        _remainingTime--;
        if (_remainingTime <= 0) _endGame(false);
      });
    });
  }

  void _onWrongAttempt() {
    setState(() {
      _wrongAttempts++;
      _matchedShapeIds.clear(); // Reset ALL shapes back

      if (_wrongAttempts >= _config.maxWrongAttempts) {
        _endGame(false);
      }
    });
  }

  void _onCorrectMatch(int index) {
    setState(() {
      _matchedShapeIds
          .add(_config.shapes[index].id); // Mark this target's shape as placed

      if (_matchedShapeIds.length == _config.shapes.length) {
        _endGame(true);
      }
    });
  }

  void _endGame(bool won) {
    _timer?.cancel();
    _gameOver = true;

    _session
      ..score = won
          ? (_remainingTime * 10 +
              (_config.maxWrongAttempts - _wrongAttempts) * 5)
          : 0
      ..totalAttempts = _wrongAttempts + _matchedShapeIds.length
      ..correctAttempts = _matchedShapeIds.length
      ..durationSeconds = _config.timeLimitSeconds - _remainingTime;

    _session.endSession();

    final result = _session.toResult().copyWith(
      metadata: {
        'difficulty': widget.difficulty.name,
        'wrongAttempts': _wrongAttempts,
        'hintsUsed': _hintsUsed,
        'timeRemaining': _remainingTime,
        'won': won,
      },
    );

    GameDataService().saveResult(result);
    _showGameOverDialog(won);
  }

  void _showGameOverDialog(bool won) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(won ? '🎉 Level Complete!' : '⏰ Time\'s Up!',
            textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Score: ${_session.score}'),
            const SizedBox(height: 8),
            Text('Wrong attempts: $_wrongAttempts'),
            const SizedBox(height: 8),
            Text('Time left: $_remainingTime seconds'),
            if (_hintsUsed > 0) ...[
              const SizedBox(height: 8),
              Text('Hints used: $_hintsUsed'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Exit'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _restartGame();
            },
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  void _restartGame() {
    setState(() {
      _shapes.shuffle();
      _matchedShapeIds.clear(); // FIXED: clear the set
      _wrongAttempts = 0;
      _hintsUsed = 0;
      _gameOver = false;
      _remainingTime = _config.timeLimitSeconds;
    });
    _startTimer();
  }

  void _useHint() {
    if (_hintsUsed >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hints remaining!')),
      );
      return;
    }
    setState(() => _hintsUsed++);
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      _timer?.cancel();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Paused'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _togglePause();
              },
              child: const Text('Resume'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Quit'),
            ),
          ],
        ),
      );
    } else {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Shape Match - ${widget.difficulty.displayName}',
      showBackButton: false,
      body: Stack(
        children: [
          const CameraBackground(),
          Container(color: Colors.black.withOpacity(0.3)),
          _buildGameContent(),
          GameHUD(
            difficulty: widget.difficulty,
            remainingTime: _remainingTime,
            wrongAttempts: _wrongAttempts,
            maxWrongAttempts: _config.maxWrongAttempts,
            matchedCount: _matchedShapeIds.length,
            totalShapes: _config.shapes.length,
            onPause: _togglePause,
            onHint: _useHint,
          ),
        ],
      ),
    );
  }

  Widget _buildGameContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final targetY = height * 0.2;
        final shapeY = height * 0.65;
        final spacing = width / (_config.shapes.length + 1);

        return Stack(
          key: _dragAreaKey,
          children: [
            // Targets (top row) — always show, highlight if already filled
            for (int i = 0; i < _config.shapes.length; i++)
              Positioned(
                left: spacing * (i + 1) - 40,
                top: targetY,
                child: _buildTarget(i, _config.shapes[i]),
              ),

            // Draggables (bottom row) — ONLY show if not yet matched
            for (int i = 0; i < _shapes.length; i++)
              if (!_matchedShapeIds
                  .contains(_shapes[i].id)) // FIXED: check by ID
                Positioned(
                  left: spacing * (i + 1) - 40,
                  top: shapeY,
                  child: _buildDraggable(i),
                ),
          ],
        );
      },
    );
  }

  Widget _buildTarget(int index, GameShape expectedShape) {
    final isAlreadyFilled = _matchedShapeIds.contains(expectedShape.id);

    return DragTarget<GameShape>(
      onWillAcceptWithDetails: (details) =>
          !isAlreadyFilled &&
          details.data.id ==
              expectedShape.id, // FIXED: reject if already filled
      onAcceptWithDetails: (details) {
        if (details.data.id == expectedShape.id) {
          _onCorrectMatch(index);
        } else {
          _onWrongAttempt();
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isAlreadyFilled
                ? Colors.green.withOpacity(0.5) // Show filled state
                : (isHighlighted
                    ? Colors.green.withOpacity(0.3)
                    : Colors.transparent),
            border: Border.all(
              color: isAlreadyFilled
                  ? Colors.green
                  : (isHighlighted ? Colors.green : Colors.white70),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: isAlreadyFilled
              ? const Icon(Icons.check,
                  color: Colors.green, size: 40) // Show checkmark
              : (expectedShape.isCustomImage
                  ? Image.asset(expectedShape.shadowPath!, fit: BoxFit.contain)
                  : CustomPaint(
                      painter: ShapePainter(
                        type: expectedShape.type!,
                        color: Colors.white,
                        isShadow: true,
                        strokeWidth: 2,
                      ),
                    )),
        );
      },
    );
  }

  Widget _buildDraggable(int index) {
    final shape = _shapes[index];

    return Draggable<GameShape>(
      data: shape,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: shape.isCustomImage ? null : shape.color!.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: shape.isCustomImage
              ? Image.asset(shape.imagePath!, fit: BoxFit.contain)
              : CustomPaint(
                  painter: ShapePainter(
                    type: shape.type!,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
      childWhenDragging: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white30),
        ),
      ),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: shape.isCustomImage ? null : shape.color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: shape.isCustomImage
            ? Image.asset(shape.imagePath!, fit: BoxFit.contain)
            : CustomPaint(
                painter: ShapePainter(
                  type: shape.type!,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
