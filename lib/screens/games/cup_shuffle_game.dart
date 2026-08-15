import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/game_result.dart';
import '../../models/game_session.dart';
import '../../services/auth_service.dart';
import '../../services/game_data_service.dart';
import '../../widgets/common/app_scaffold.dart';

enum GamePhase {
  loading,
  ready,
  placed,
  shuffling,
  guessing,
  revealed,
}

class CupShuffleGame extends StatefulWidget {
  const CupShuffleGame({super.key});

  @override
  State<CupShuffleGame> createState() => _CupShuffleGameState();
}

class _CupShuffleGameState extends State<CupShuffleGame> {
  late final WebViewController _webController;
  late final GameSession _session;

  GamePhase _phase = GamePhase.loading;
  String _statusText = "Loading AR...";
  int _score = 0;
  int _wrongAttempts = 0;
  int _ballIndex = -1;

  @override
  void initState() {
    super.initState();

    _initWebView();

    final patient = AuthService().currentPatient!;
    _session = GameSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: patient.id,
      gameType: GameType.cupShuffle,
      startedAt: DateTime.now(),
    );
  }

  void _initWebView() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..enableZoom(false)
      ..addJavaScriptChannel(
        'FlutterApp',
        onMessageReceived: (JavaScriptMessage message) {
          _handleJSMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // Page loaded, wait for AR ready event from JS
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _statusText = "AR Error: ${error.description}";
            });
          },
        ),
      )
      ..loadFlutterAsset('assets/ar/index.html');
  }

  void _handleJSMessage(String message) {
    try {
      final data = jsonDecode(message);
      final event = data['event'];
      final payload = data['data'] ?? {};

      switch (event) {
        case 'arReady':
          setState(() {
            _phase = GamePhase.ready;
            _statusText = "Tap 'Place Game' to start";
          });
          break;

        case 'arError':
          setState(() {
            _statusText = "AR Error: ${payload['message']}";
          });
          break;

        case 'gamePlaced':
          setState(() {
            _phase = GamePhase.placed;
            _ballIndex = payload['ballIndex'] ?? 0;
            _statusText = "Press Shuffle to start!";
          });
          break;

        case 'shuffleComplete':
          setState(() {
            _phase = GamePhase.guessing;
            _statusText = "Pick a cup!";
          });
          break;

        case 'gameReset':
          setState(() {
            _phase = GamePhase.ready;
            _statusText = "Tap 'Place Game' to start";
            _score = 0;
            _wrongAttempts = 0;
          });
          break;

        case 'cupTapped':
          // User tapped a cup in AR
          final cupIndex = payload['index'] as int;
          _sendToJS('reveal', {'index': cupIndex});
          break;

        case 'cupRevealed':
          final isCorrect = payload['isCorrect'] as bool;
          final revealedBallIndex = payload['ballIndex'] as int;

          setState(() {
            _phase = GamePhase.revealed;
            if (isCorrect) {
              _score += 10;
              _statusText = "Correct! Ball found! +10 points";
            } else {
              _wrongAttempts++;
              _statusText =
                  "Wrong! Ball was under cup ${revealedBallIndex + 1}";
            }
          });

          _saveSession();
          break;
      }
    } catch (e) {
      debugPrint('JS Message parse error: $e');
    }
  }

  void _sendToJS(String command, [Map<String, dynamic>? data]) {
    final js = data != null
        ? 'receiveFromFlutter("$command", ${jsonEncode(data)})'
        : 'receiveFromFlutter("$command")';
    _webController.runJavaScript(js);
  }

  void _handlePlaceGame() {
    if (_phase != GamePhase.ready) return;
    _sendToJS('startGame');
  }

  void _handleShuffle() {
    if (_phase != GamePhase.placed) return;
    _sendToJS('shuffle');
    setState(() {
      _phase = GamePhase.shuffling;
      _statusText = "Shuffling... Watch closely!";
    });
  }

  void _handleReset() {
    _sendToJS('reset');
    setState(() {
      _phase = GamePhase.ready;
      _statusText = "Tap 'Place Game' to start";
      _score = 0;
      _wrongAttempts = 0;
    });
  }

  Future<void> _saveSession() async {
    _session
      ..score = _score
      ..totalAttempts = _wrongAttempts + (_score > 0 ? 1 : 0)
      ..correctAttempts = _score > 0 ? 1 : 0
      ..durationSeconds =
          DateTime.now().difference(_session.startedAt).inSeconds;

    _session.endSession();
    await GameDataService().saveResult(_session.toResult());
  }

  Future<void> _saveAndExit() async {
    await _saveSession();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session saved!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Cup Shuffle AR',
      actions: [
        IconButton(
          icon: const Icon(Icons.save),
          onPressed: _saveAndExit,
          tooltip: 'Save & Exit',
        ),
      ],
      body: Stack(
        children: [
          // WebView with MindAR
          WebViewWidget(controller: _webController),

          // Game overlay UI
          _buildOverlay(),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return SafeArea(
      child: Column(
        children: [
          // Status banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  "Score: $_score",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Bottom controls
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildButton("Place", Icons.place, Colors.blue,
                    _phase == GamePhase.ready, _handlePlaceGame),
                _buildButton("Shuffle", Icons.shuffle, Colors.orange,
                    _phase == GamePhase.placed, _handleShuffle),
                _buildButton(
                    "Reset",
                    Icons.refresh,
                    Colors.red,
                    _phase != GamePhase.loading &&
                        _phase != GamePhase.shuffling,
                    _handleReset),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
    String label,
    IconData icon,
    Color color,
    bool enabled,
    VoidCallback onTap,
  ) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
