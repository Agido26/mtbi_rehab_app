import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
// IMPORTANT: This import brings in the Android-specific permission API
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../../models/game_result.dart';
import '../../models/game_session.dart';
import '../../services/auth_service.dart';
import '../../services/game_data_service.dart';
import '../../widgets/common/app_scaffold.dart';

enum GamePhase { loading, ready, placed, shuffling, guessing, revealed }

class CupShuffleGame extends StatefulWidget {
  const CupShuffleGame({super.key});

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
  String _serverUrl = "";

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
  // LOCAL HTTP SERVER (same as before)
  // ============================================================
  Future<int> _startAssetServer() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    server.listen((HttpRequest request) async {
      final path = request.uri.path.replaceFirst('/', '');
      final assetPath = 'assets/ar/$path';

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
          default:
            contentType = ContentType('application', 'octet-stream');
            break;
        }

        request.response
          ..headers.contentType = contentType
          ..headers.set('Access-Control-Allow-Origin', '*')
          ..headers.set('Content-Length', bytes.length.toString())
          ..add(bytes);
        await request.response.close();
      } catch (e) {
        request.response.statusCode = 404;
        await request.response.close();
      }
    });

    _localServer = server;
    return server.port;
  }

  // ============================================================
  // AUTH + CAMERA + WEBVIEW INIT
  // ============================================================
  Future<void> _initialize() async {
    // 1. Check auth
    final isLoggedIn = await AuthService().isLoggedIn();
    if (!isLoggedIn || AuthService().currentPatient == null) {
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
      return;
    }

    // 2. Request camera permission (app level)
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      setState(() {
        _statusText = "Camera permission is required for AR";
      });
      if (cameraStatus.isPermanentlyDenied && mounted) {
        _showPermissionDialog();
      }
      return;
    }

    // 3. Start local asset server
    final port = await _startAssetServer();
    _serverUrl = 'http://127.0.0.1:$port/index.html';

    // 4. Create session
    final patient = AuthService().currentPatient!;
    _session = GameSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: patient.id,
      gameType: GameType.cupShuffle,
      startedAt: DateTime.now(),
    );

    setState(() {
      _isInitialized = true;
    });
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
          'This game needs camera access for AR. Please enable it in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _initWebView(int port) {
    final controller = WebViewController()
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
          onPageFinished: (String url) {},
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _statusText = "AR Error: ${error.description}";
            });
          },
        ),
      )
      ..loadRequest(Uri.parse('http://127.0.0.1:$port/index.html'));

    // ============================================================
    // THE FIX: Grant camera permission inside the WebView
    // ============================================================
    if (controller.platform is AndroidWebViewController) {
      (controller.platform as AndroidWebViewController)
          .setOnPlatformPermissionRequest((request) => request.grant());
    }

    _webController = controller;
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
            _correctAttempts = 0;
          });
          break;

        case 'cupTapped':
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
              _correctAttempts++;
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
    if (_webController == null) return;
    final js = data != null
        ? 'receiveFromFlutter("$command", ${jsonEncode(data)})'
        : 'receiveFromFlutter("$command")';
    _webController!.runJavaScript(js);
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
      _correctAttempts = 0;
    });
  }

  Future<void> _saveSession() async {
    if (_session == null) return;
    _session!
      ..score = _score
      ..totalAttempts = _wrongAttempts + _correctAttempts
      ..correctAttempts = _correctAttempts
      ..durationSeconds =
          DateTime.now().difference(_session!.startedAt).inSeconds;

    _session!.endSession();
    await GameDataService().saveResult(_session!.toResult());
  }

  Future<void> _saveAndExit() async {
    await _saveSession();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Session saved!')));
      Navigator.pop(context);
    }
  }

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

    // Initialize WebView here (after _isInitialized is true)
    if (_webController == null) {
      _initWebView(_localServer!.port);
    }

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
          WebViewWidget(controller: _webController!),
          _buildOverlay(),
        ],
      ),
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
                _buildButton(
                  "Place",
                  Icons.place,
                  Colors.blue,
                  _phase == GamePhase.ready,
                  _handlePlaceGame,
                ),
                _buildButton(
                  "Shuffle",
                  Icons.shuffle,
                  Colors.orange,
                  _phase == GamePhase.placed,
                  _handleShuffle,
                ),
                _buildButton(
                  "Reset",
                  Icons.refresh,
                  Colors.red,
                  _phase != GamePhase.loading && _phase != GamePhase.shuffling,
                  _handleReset,
                ),
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
