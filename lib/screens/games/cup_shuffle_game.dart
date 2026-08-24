import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../../models/game_result.dart';
import '../../models/game_session.dart';
import '../../models/cupshuffleconfig.dart';
import '../../services/auth_service.dart';
import '../../services/game_data_service.dart';
import '../../widgets/common/app_scaffold.dart';

enum GamePhase {
  loading,
  ready,
  playing,
  shuffling,
  guessing,
  sessionEnd,
}

class CupShuffleGame extends StatefulWidget {
  final CupShuffleConfig config;
  const CupShuffleGame({super.key, required this.config});

  @override
  State<CupShuffleGame> createState() => _CupShuffleGameState();
}

class _CupShuffleGameState extends State<CupShuffleGame> {
  WebViewController? _webController;
  GameSession? _session;
  HttpServer? _localServer;

  GamePhase _phase = GamePhase.loading;
  String _statusText = "Loading AR...";
  int _score = 0;
  int _wrongAttempts = 0;
  int _correctAttempts = 0;
  bool _isInitialized = false;

  // ===== Session / Rounds / Metrics =====
  int _currentRound = 0;
  final List<bool> _roundResults = [];
  final List<double> _responseTimes = [];
  final List<String> _errorPositions = [];
  DateTime? _shuffleEndTime;

  CupShuffleConfig get _config => widget.config;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _localServer?.close(force: true);
    super.dispose();
  }

  // ============================================================
  // LOCAL HTTP SERVER (بدون تغيير)
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
      if (cameraStatus.isPermanentlyDenied && mounted) _showPermissionDialog();
      return;
    }

    final port = await _startAssetServer();

    final patient = AuthService().currentPatient!;
    _session = GameSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: patient.id,
      gameType: GameType.cupShuffle,
      startedAt: DateTime.now(),
    );

    _initWebView(port);

    setState(() => _isInitialized = true);
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
            'This game needs camera access for AR. Please enable it in app settings.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.pop(context);
              },
              child: const Text('Open Settings')),
        ],
      ),
    );
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
      ..loadRequest(Uri.parse('http://127.0.0.1:$port/index.html'));

    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      androidController
          .setOnPlatformPermissionRequest((request) => request.grant());
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }

    _webController = controller;
  }

  // ============================================================
  // JS MESSAGES + METRICS
  // ============================================================
  void _handleJSMessage(String message) {
    try {
      final data = jsonDecode(message);
      final event = data['event'];
      final payload = data['data'] ?? {};

      switch (event) {
        case 'arReady':
          setState(() {
            _phase = GamePhase.ready;
            _statusText = "Press Start to begin";
          });
          break;

        case 'gamePlaced':
          _sendToJS('shuffle', {'count': _config.shufflesPerRound});
          setState(() {
            _phase = GamePhase.shuffling;
            _statusText = "Watch the shuffle...";
          });
          break;

        case 'shuffleComplete':
          _shuffleEndTime = DateTime.now();
          setState(() {
            _phase = GamePhase.guessing;
            _statusText = "Pick a cup!";
          });
          break;

        case 'cupTapped':
          if (_shuffleEndTime != null) {
            final rt =
                DateTime.now().difference(_shuffleEndTime!).inMilliseconds /
                    1000.0;
            _responseTimes.add(rt);
            _shuffleEndTime = null;
          }
          _sendToJS('reveal', {'index': payload['index']});
          break;

        case 'cupRevealed':
          final isCorrect = payload['isCorrect'] as bool;
          if (isCorrect) {
            _score += 10;
            _correctAttempts++;
            _roundResults.add(true);
            _nextRound();
          } else {
            _wrongAttempts++;
            _errorPositions.add(payload['position']?.toString() ?? 'unknown');
            setState(() => _statusText = "Empty! Try again");
          }
          break;
      }
    } catch (e) {
      debugPrint('JS Message parse error: $e');
    }
  }

  // ============================================================
  // GAME FLOW
  // ============================================================
  void _handleStart() {
    if (_phase != GamePhase.ready) return;
    setState(() {
      _currentRound++;
      _phase = GamePhase.playing;
      _statusText = "Round $_currentRound/${_config.roundsCount}";
    });
    _sendToJS('startGame', {'cups': _config.cupsCount});
  }

  void _nextRound() {
    if (_currentRound >= _config.roundsCount) {
      _endSessionAndShowSummary();
    } else {
      _sendToJS('reset');
      setState(() {
        _phase = GamePhase.ready;
        _statusText = "Round done! Press Start for next";
      });
    }
  }

  void _resetSession() {
    _sendToJS('reset');
    setState(() {
      _currentRound = 0;
      _score = 0;
      _wrongAttempts = 0;
      _correctAttempts = 0;
      _roundResults.clear();
      _responseTimes.clear();
      _errorPositions.clear();
      _phase = GamePhase.ready;
      _statusText = "Press Start to begin";
    });
  }

  void _endSessionAndShowSummary() {
    _saveSession();
    setState(() => _phase = GamePhase.sessionEnd);
    _showSessionSummaryDialog();
  }

  void _showSessionSummaryDialog() {
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
            Text('Correct: $_correctAttempts / ${_config.roundsCount}'),
            Text('Wrong attempts: $_wrongAttempts'),
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
      ..totalAttempts = _wrongAttempts + _correctAttempts
      ..correctAttempts = _correctAttempts
      ..durationSeconds =
          DateTime.now().difference(_session!.startedAt).inSeconds;

    _session!.endSession();
    final result = _session!.toResult().copyWith(metadata: _buildMetrics());
    await GameDataService().saveResult(result);
  }

  Map<String, dynamic> _buildMetrics() {
    return {
      'difficulty': _config.difficulty.name,
      'cupsCount': _config.cupsCount,
      'roundsCompleted': _currentRound,
      'roundsTotal': _config.roundsCount,
      'roundResults': _roundResults,
      'responseTimes': _responseTimes,
      'errorPositions': _errorPositions,
      'firstAttemptCorrect': _roundResults.where((r) => r).length,
      'fatigueIndex': _computeFatigue(),
    };
  }

  double _computeFatigue() {
    if (_responseTimes.length < 2) return 1.0;
    final half = _responseTimes.length ~/ 2;
    final first = _responseTimes.sublist(0, half);
    final second = _responseTimes.sublist(_responseTimes.length - half);
    final avgFirst = first.reduce((a, b) => a + b) / first.length;
    final avgSecond = second.reduce((a, b) => a + b) / second.length;
    if (avgFirst == 0) return 1.0;
    return avgSecond / avgFirst;
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
        title: 'Cup Shuffle AR',
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
      title: 'Cup Shuffle AR',
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
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Round $_currentRound/${_config.roundsCount}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _config.difficulty.color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _config.difficulty.displayName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Score: $_score",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
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
                _buildButton("Start", Icons.play_arrow, Colors.green,
                    _phase == GamePhase.ready, _handleStart),
                _buildButton(
                    "Reset",
                    Icons.refresh,
                    Colors.red,
                    _phase != GamePhase.loading &&
                        _phase != GamePhase.shuffling,
                    _resetSession),
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
