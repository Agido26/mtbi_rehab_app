import 'package:flutter/material.dart';
import 'screens/doctor_home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cognitive Rehab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

enum _AuthRole { none, patient, doctor }

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  bool _isLoading = true;
  _AuthRole _role = _AuthRole.none;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAuth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ✅ لما التطبيق يتقفل تماماً → logout → المرة الجاية يفتح من Login
    if (state == AppLifecycleState.detached) {
      AuthService().logout();
    }
  }

  Future<void> _checkAuth() async {
    final auth = AuthService();
    final doctorLoggedIn = await auth.isDoctorLoggedIn();
    final patientLoggedIn = doctorLoggedIn ? false : await auth.isLoggedIn();
    setState(() {
      _role = doctorLoggedIn
          ? _AuthRole.doctor
          : (patientLoggedIn ? _AuthRole.patient : _AuthRole.none);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    switch (_role) {
      case _AuthRole.doctor:
        return const DoctorHomeScreen();
      case _AuthRole.patient:
        return const MainScreen();
      case _AuthRole.none:
        return const LoginScreen();
    }
  }
}
