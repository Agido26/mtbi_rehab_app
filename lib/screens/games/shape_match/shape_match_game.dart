import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../models/game_result.dart';
import '../../../models/game_session.dart';
import '../../../models/shape_match_config.dart';
import '../../../services/auth_service.dart';
import '../../../services/game_data_service.dart';
import '../../../widgets/common/app_scaffold.dart';

enum ShapePhase { loading, ready, playing, results, sessionEnd }

/// ✅ لو نتيجة اختبار test_targets.html طلعت ترتيب مختلف، عدّل هنا بس
const List<int> kShapeToTarget = [0, 1, 2, 3, 4];

class ShapeMatchGame extends StatefulWidget {
  final Difficulty difficulty;
  const ShapeMatchGame({super.key, required this.difficulty});

  @override
  State<ShapeMatchGame> createState() => _ShapeMatchGameState();
}

class _ShapeMatchGameState extends State<ShapeMatchGame> {
  WebViewController? _webController;
  GameSession? _session;
  HttpServer? _localServer;
  Timer? _roundTimer;

  ShapePhase _phase = ShapePhase.loading;
  String _statusText = "Loading AR...";
  int _score = 0;
  int _currentRound = 0;
  int _peeksLeft = 0;
  int _peeksUsed = 0;
  int _secondsLeft = 0;
  bool _isInitialized = false;

  final List<double> _roundAccuracies = [];
  final List<double> _roundTimes = [];
  List<String> _sequence = [];
  List<int> _correctOrder = [];

  late final ShapeMatchConfig _config =
      ShapeMatchConfig.forDifficulty(widget.difficulty);

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _roundTimer?.cancel();
    _localServer?.close(force: true);
    super.dispose();
  }

  // ============================================================
  // LOCAL HTTP SERVER
  // ============================================================
  Future<int> _startAssetServer() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    debugPrint('[SERVER] Started on port ${server.port}');

    server.listen((HttpRequest request) async {
      final path = request.uri.path.replaceFirst('/', '');
      final assetPath = 'assets/ar/$path';

      request.response.headers.set('Access-Control-Allow-Origin', '*');
      request.response.headers
          .set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      request.response.headers.set('Access-Control-Allow-Headers', '*');

      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
        return;
      }

      try {
        final data = await rootBundle.load(assetPath);
        final bytes = data.buffer.asUint8List();

        final ext = path.split('.').last.toLowerCase();
        ContentType contentType;
        switch (ext) {
          case 'html':
            contentType = ContentType.html;
            break;
          case 'js':
            contentType = ContentType('application', 'javascript');
            break;
          case 'css':
            contentType = ContentType('text', 'css');
            break;
          case 'mind':
            contentType = ContentType('application', 'octet-stream');
            break;
          default:
            contentType = ContentType('application', 'octet-stream');
        }

        request.response
          ..headers.contentType = contentType
          ..headers.set('Content-Length', bytes.length.toString())
          ..add(bytes);
        await request.response.close();
      } catch (e) {
        debugPrint('[SERVER] 404 for /$path : $e');
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    });

    _localServer = server;
    return server.port;
  }

  // ============================================================
  // INIT
  // ============================================================
  Future<void> _initialize() async {
    final isLoggedIn = await AuthService().isLoggedIn();
    if (!isLoggedIn || AuthService().currentPatient == null) {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
      }
      return;
    }

    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      setState(() => _statusText = "Camera permission is required for AR");
      return;
    }

    final port = await _startAssetServer();

    final patient = AuthService().currentPatient!;
    _session = GameSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: patient.id,
      gameType: GameType.shapeMatch,
      startedAt: DateTime.now(),
    );

    _initWebView(port);
    setState(() => _isInitialized = true);
  }

  void _initWebView(int port) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..enableZoom(false)
      ..addJavaScriptChannel('FlutterApp',
          onMessageReceived: (JavaScriptMessage message) {
        _handleJSMessage(message.message);
      })
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) => debugPrint('[WEBVIEW] Page finished: $url'),
        onWebResourceError: (error) {
          debugPrint('[WEBVIEW] Resource error: ${error.description}');
        },
      ))
      ..loadRequest(Uri.parse('http://127.0.0.1:$port/shapematch_game.html'));

    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      androidController
          .setOnPlatformPermissionRequest((request) => request.grant());
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }

    _webController = controller;
  }

  // ============================================================
  // JS MESSAGES
  // ============================================================
  void _handleJSMessage(String message) {
    try {
      final data = jsonDecode(message);
      final event = data['event'];
      final payload = data['data'] ?? {};

      switch (event) {
        case 'arReady':
          setState(() {
            _phase = ShapePhase.ready;
            _statusText = "Press Start to begin";
          });
          break;

        case 'roundReady':
          // JS built the shape meshes — nothing needed here
          break;

        case 'peekEnded':
          if (_phase == ShapePhase.playing) {
            setState(() => _statusText = 'Arrange the cards, then press Check');
          }
          break;

        case 'checkResult':
          final allDetected = payload['allDetected'] as bool;
          if (!allDetected) {
            setState(() =>
                _statusText = '📷 Show ALL cards to the camera, then Check');
            return;
          }
          _roundTimer?.cancel();

          final patientOrder =
              (payload['patientOrder'] as List).map((e) => e as int).toList();

          int correctCount = 0;
          final results = <Map<String, dynamic>>[];
          for (int i = 0; i < _correctOrder.length; i++) {
            final t = _correctOrder[i];
            final posCorrect = patientOrder.indexOf(t) == i;
            if (posCorrect) correctCount++;
            results.add({'targetIndex': t, 'correct': posCorrect});
          }

          final accuracy = correctCount / _config.cardsCount;
          final points = (_config.pointsPerRound * accuracy).round();
          _score += points;
          _roundAccuracies.add(accuracy);
          _roundTimes
              .add((_config.roundTimeLimitSeconds - _secondsLeft).toDouble());

          setState(() =>
              _statusText = '${(accuracy * 100).round()}% correct → +$points');

          _sendToJS('showResults', {
            'results': results,
            'durationSeconds': _config.showResultsDurationSeconds,
            'accuracyPercent': (accuracy * 100).round(),
          });
          setState(() => _phase = ShapePhase.results);
          break;

        case 'resultsHidden':
          _nextRound();
          break;
      }
    } catch (e) {
      debugPrint('JS Message parse error: $e');
    }
  }

  // ============================================================
  // GAME FLOW
  // ============================================================
  void _startRound() {
    if (_phase != ShapePhase.ready) return;

    _currentRound++;
    _sequence = List<String>.from(_config.shapeIds)..shuffle();
    _correctOrder = _sequence
        .map((id) => kShapeToTarget[kAllShapeIds.indexOf(id)])
        .toList();

    _peeksLeft = _config.peeksAllowed;
    _secondsLeft = _config.roundTimeLimitSeconds;

    setState(() {
      _phase = ShapePhase.playing;
      _statusText = 'Press Show to peek, arrange, then Check';
    });

    _sendToJS('startRound', {
      'shapeIds': _sequence,
      'correctOrder': _correctOrder,
    });

    _roundTimer?.cancel();
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _onTimeUp();
      }
    });
  }

  void _peek() {
    if (_phase != ShapePhase.playing || _peeksLeft <= 0) return;
    setState(() {
      _peeksLeft--;
      _peeksUsed++;
      _statusText = '👀 Memorize the shapes!';
    });
    _sendToJS('showPeek', {'durationSeconds': _config.peekDurationSeconds});
  }

  void _check() {
    if (_phase != ShapePhase.playing) return;
    _sendToJS('check');
  }

  void _onTimeUp() {
    if (_phase != ShapePhase.playing) return;
    _roundAccuracies.add(0);
    _roundTimes.add(_config.roundTimeLimitSeconds.toDouble());
    setState(() {
      _phase = ShapePhase.results;
      _statusText = "⏰ Time's up!";
    });
    _sendToJS('showResults', {
      'results': _correctOrder
          .map((t) => {'targetIndex': t, 'correct': false})
          .toList(),
      'durationSeconds': _config.showResultsDurationSeconds,
      'accuracyPercent': 0,
    });
  }

  void _nextRound() {
    if (_currentRound >= _config.roundsCount) {
      _endSessionAndShowSummary();
    } else {
      _sendToJS('reset');
      setState(() {
        _phase = ShapePhase.ready;
        _statusText = 'Round done! Press Start for next';
      });
    }
  }

  void _resetSession() {
    _roundTimer?.cancel();
    _sendToJS('reset');
    setState(() {
      _currentRound = 0;
      _score = 0;
      _peeksUsed = 0;
      _roundAccuracies.clear();
      _roundTimes.clear();
      _phase = ShapePhase.ready;
      _statusText = "Press Start to begin";
    });
  }

  void _endSessionAndShowSummary() {
    _saveSession();
    setState(() => _phase = ShapePhase.sessionEnd);
    _showSessionSummaryDialog();
  }

  void _showSessionSummaryDialog() {
    final avgAcc = _roundAccuracies.isEmpty
        ? 0.0
        : _roundAccuracies.reduce((a, b) => a + b) / _roundAccuracies.length;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mode: ${_config.difficulty.displayName}',
                style: TextStyle(
                    color: _config.difficulty.color,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Score: $_score'),
            Text('Average accuracy: ${(avgAcc * 100).round()}%'),
            Text('Peeks used: $_peeksUsed'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetSession();
            },
            child: const Text('Play Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Change Level'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SAVE + METRICS
  // ============================================================
  Future<void> _saveSession() async {
    if (_session == null) return;
    _session!
      ..score = _score
      ..totalAttempts = _roundAccuracies.length
      ..correctAttempts = _roundAccuracies.where((a) => a == 1.0).length
      ..durationSeconds =
          DateTime.now().difference(_session!.startedAt).inSeconds;

    _session!.endSession();
    final result = _session!.toResult().copyWith(metadata: _buildMetrics());
    debugPrint(
        '📊 [METRICS] Score=$_score | AvgAcc=${(_roundAccuracies.isEmpty ? 0 : _roundAccuracies.reduce((a, b) => a + b) / _roundAccuracies.length * 100).toStringAsFixed(0)}% | Peeks=$_peeksUsed');
    await GameDataService().saveResult(result);
  }

  Map<String, dynamic> _buildMetrics() {
    final avgAcc = _roundAccuracies.isEmpty
        ? 0.0
        : _roundAccuracies.reduce((a, b) => a + b) / _roundAccuracies.length;
    return {
      'difficulty': _config.difficulty.name,
      'cardsCount': _config.cardsCount,
      'roundsCompleted': _currentRound,
      'roundsTotal': _config.roundsCount,
      'roundAccuracies': _roundAccuracies,
      'roundTimes': _roundTimes,
      'peeksUsed': _peeksUsed,
      'averageAccuracy': avgAcc,
    };
  }

  void _sendToJS(String command, [Map<String, dynamic>? data]) {
    if (_webController == null) return;
    final js = data != null
        ? 'receiveFromFlutter("$command", ${jsonEncode(data)})'
        : 'receiveFromFlutter("$command")';
    _webController!.runJavaScript(js);
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return AppScaffold(
        title: 'Shape Match AR',
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_statusText),
            ],
          ),
        ),
      );
    }

    return AppScaffold(
      title: 'Shape Match AR',
      body: Stack(children: [
        WebViewWidget(controller: _webController!),
        _buildOverlay(),
      ]),
    );
  }

  Widget _buildOverlay() {
    return SafeArea(
      child: Column(
        children: [
          const Spacer(),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text('Round $_currentRound/${_config.roundsCount}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14)),
                    Text('Score: $_score',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    Text('👀 $_peeksLeft',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14)),
                    Text('⏱ $_secondsLeft',
                        style: TextStyle(
                            color: _secondsLeft <= 10
                                ? Colors.redAccent
                                : Colors.white70,
                            fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildButton("Start", Icons.play_arrow, Colors.green,
                        _phase == ShapePhase.ready, _startRound),
                    _buildButton("Show", Icons.visibility, Colors.orange,
                        _phase == ShapePhase.playing && _peeksLeft > 0, _peek),
                    _buildButton("Check", Icons.check_circle, Colors.blue,
                        _phase == ShapePhase.playing, _check),
                    _buildButton("Reset", Icons.refresh, Colors.red,
                        _phase != ShapePhase.loading, _resetSession),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String label, IconData icon, Color color, bool enabled,
      VoidCallback onTap) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
