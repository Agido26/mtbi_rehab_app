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

class ShapeMatchGame extends StatefulWidget {
  final Difficulty difficulty;
  const ShapeMatchGame({super.key, required this.difficulty});

  @override
  State<ShapeMatchGame> createState() => _ShapeMatchGameState();
}

class _ShapeMatchGameState extends State<ShapeMatchGame>
    with WidgetsBindingObserver {
  // ===== علم الاختبار الوحيد في Flutter (يقابل TEST_MODE في الـ HTML) =====
  static const bool kTestMode = true; // ← false لما تخلص الاختبارات

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
  DateTime _roundStartedAt = DateTime.now();

  late final ShapeMatchConfig _config =
      ShapeMatchConfig.forDifficulty(widget.difficulty);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _roundTimer?.cancel();
    _localServer?.close(force: true);
    super.dispose();
  }

  // ✅ عند قلب الشاشة: MindAR ما بيتأقلمش مع الأبعاد الجديدة → إعادة تهيئة نظيفة
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!_isInitialized) return;

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _roundTimer?.cancel();

      // لو كنا وسط جولة، ألغها عشان Start يعيد نفس الجولة مش اللي بعدها
      if (_phase == ShapePhase.playing || _phase == ShapePhase.results) {
        _currentRound = _currentRound > 0 ? _currentRound - 1 : 0;
      }

      _webController?.reload();
      setState(() {
        _phase = ShapePhase.loading;
        _statusText = 'Re-initializing camera for new orientation...';
      });
    });
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
      ..loadRequest(Uri.parse(
          'http://127.0.0.1:$port/shapematch_game.html?level=${widget.difficulty.name}'));

    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      androidController
          .setOnPlatformPermissionRequest((request) => request.grant());
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }

    _webController = controller;
  }

  // ============================================================
  // JS MESSAGES (العقد النهائي)
  // ============================================================
  void _handleJSMessage(String message) {
    try {
      final data = jsonDecode(message);
      final event = data['event'];
      final payload = data['data'] ?? {};

      switch (event) {
        case 'cameraInfo':
          debugPrint('═══════════════════════════════════════');
          debugPrint('📷 CAMERA INFO');
          debugPrint('  Requested : ${payload['requested']}');
          debugPrint('  Actual    : ${payload['actual']}');
          debugPrint('  FPS       : ${payload['fps']}');
          debugPrint(
              '  Focus     : ${payload['focusMode']} (supported: ${payload['supportedFocus']})');
          debugPrint('  Exposure  : ${payload['exposureMode']}');
          debugPrint('  Label     : ${payload['label']}');
          debugPrint('═══════════════════════════════════════');
          break;
        case 'arReady':
          setState(() {
            _phase = ShapePhase.ready;
            _statusText = "Press Start to begin";
          });
          break;

        case 'roundReady':
          break;

        case 'peekEnded':
          if (_phase == ShapePhase.playing) {
            setState(() => _statusText = 'Arrange the cards, then press Check');
          }
          break;

        case 'checkResult':
          final allDetected = payload['allDetected'] as bool;
          if (!allDetected) {
            final missing = (payload['missingCount'] as int?) ?? 0;
            setState(() => _statusText =
                '📷 $missing card(s) missing — show ALL cards to camera');
            return;
          }
          _roundTimer?.cancel();

          final patientOrder =
              (payload['patientOrder'] as List).map((e) => e as int).toList();

          int correctCount = 0;
          final results = <Map<String, dynamic>>[];
          for (int i = 0; i < _correctOrder.length; i++) {
            final t = _correctOrder[i];
            final ok = i < patientOrder.length && patientOrder[i] == t;
            if (ok) correctCount++;
            results.add({'targetIndex': t, 'correct': ok});
          }

          final accuracy = correctCount / _config.cardsCount;
          final points = (_config.pointsPerRound * accuracy).round();
          _score += points;
          _roundAccuracies.add(accuracy);
          _roundTimes.add(
              DateTime.now().difference(_roundStartedAt).inSeconds.toDouble());

          setState(() =>
              _statusText = '${(accuracy * 100).round()}% correct → +$points');

          _sendToJS('showResults', {
            'results': results,
            'durationSeconds': _config.showResultsDurationSeconds,
            'accuracyPercent': (accuracy * 100).round(),
          });
          setState(() => _phase = ShapePhase.results);

          // ✅ في وضع الاختبار: الجولة الجاية تلقائياً بعد 5 ثواني
          if (kTestMode) {
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted && _phase == ShapePhase.results) _nextRound();
            });
          }
          break;

        case 'resultsHidden':
          if (!kTestMode) _nextRound();
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

    // 1) ترتيب الأشكال المطلوب (silhouettes فوق)
    _sequence = List<String>.from(_config.shapeIds)..shuffle();

    // 2) قاعدة المدى: البطاقات النشطة = [0 .. cardsCount-1]
    final activeTargets = List<int>.generate(_config.cardsCount, (i) => i);

    // 3) 🎲 توزيع عشوائي للأشكال على البطاقات
    final shuffledShapes = List<String>.from(_config.shapeIds)..shuffle();
    final assignment = <Map<String, dynamic>>[];
    for (int i = 0; i < activeTargets.length; i++) {
      assignment.add({'target': activeTargets[i], 'shape': shuffledShapes[i]});
    }

    // 4) correctOrder: أنهي بطاقة شايلة كل شكل في الـ sequence
    final targetOfShape = <String, int>{
      for (final a in assignment) a['shape'] as String: a['target'] as int,
    };
    _correctOrder = _sequence.map((s) => targetOfShape[s]!).toList();

    _peeksLeft = _config.peeksAllowed;
    _secondsLeft = _config.roundTimeLimitSeconds;
    _roundStartedAt = DateTime.now();

    setState(() {
      _phase = ShapePhase.playing;
      _statusText = 'Press Show to peek, arrange, then Check';
    });

    _sendToJS('startRound', {
      'sequence': _sequence,
      'assignment': assignment,
      'correctOrder': _correctOrder,
      'hideSequenceAfterPeek': _config.hideSequenceAfterPeek, // ✅ الجديد
    });

    _roundTimer?.cancel();
    if (!kTestMode) {
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
    final avgAcc = _roundAccuracies.isEmpty
        ? 0.0
        : _roundAccuracies.reduce((a, b) => a + b) / _roundAccuracies.length;
    debugPrint('📊 [METRICS] Score=$_score | '
        'AvgAcc=${(avgAcc * 100).toStringAsFixed(0)}% | Peeks=$_peeksUsed');
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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

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

    final body = Stack(children: [
      WebViewWidget(controller: _webController!),
      _buildOverlay(isLandscape),
    ]);

    // ✅ landscape: بدون AppBar نهائياً — الكاميرا تاخد كل الشاشة
    if (isLandscape) {
      return Scaffold(backgroundColor: Colors.black, body: body);
    }

    return AppScaffold(title: 'Shape Match AR', body: body);
  }

  Widget _buildOverlay(bool isLandscape) {
    // ✅ landscape: شريط واحد رفيع (معلومات + حالة + أزرار في سطر واحد)
    if (isLandscape) {
      return SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text(
                    'R$_currentRound/${_config.roundsCount} • $_score pts • 👀$_peeksLeft • ${kTestMode ? "∞" : "⏱$_secondsLeft"}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusText,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildButton("Start", Icons.play_arrow, Colors.green,
                      _phase == ShapePhase.ready, _startRound,
                      iconSize: 16, paddingH: 8, paddingV: 4, fontSize: 9),
                  const SizedBox(width: 6),
                  _buildButton("Show", Icons.visibility, Colors.orange,
                      _phase == ShapePhase.playing && _peeksLeft > 0, _peek,
                      iconSize: 16, paddingH: 8, paddingV: 4, fontSize: 9),
                  const SizedBox(width: 6),
                  _buildButton("Check", Icons.check_circle, Colors.blue,
                      _phase == ShapePhase.playing, _check,
                      iconSize: 16, paddingH: 8, paddingV: 4, fontSize: 9),
                  const SizedBox(width: 6),
                  _buildButton("Reset", Icons.refresh, Colors.red,
                      _phase != ShapePhase.loading, _resetSession,
                      iconSize: 16, paddingH: 8, paddingV: 4, fontSize: 9),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ✅ portrait: التصميم الحالي زي ما هو
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
                    Text(kTestMode ? '⏱ ∞' : '⏱ $_secondsLeft',
                        style: TextStyle(
                            color: !kTestMode && _secondsLeft <= 10
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

  Widget _buildButton(
    String label,
    IconData icon,
    Color color,
    bool enabled,
    VoidCallback onTap, {
    double iconSize = 22,
    double paddingH = 16,
    double paddingV = 10,
    double fontSize = 11,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding:
              EdgeInsets.symmetric(horizontal: paddingH, vertical: paddingV),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: iconSize),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
