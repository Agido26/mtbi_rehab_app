import 'package:flutter/material.dart';
import '../models/doctor.dart';
import '../services/auth_service.dart';
import 'doctor_home_screen.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _usernameController = TextEditingController();
  final _doctorNameController = TextEditingController();
  final _registerPassController = TextEditingController();
  final _loginPassController = TextEditingController();

  List<Doctor> _doctors = [];
  String? _loginDoctorId;
  bool _registerMode = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadDoctors();
  }

  @override
  void dispose() {
    _tab.dispose();
    _usernameController.dispose();
    _doctorNameController.dispose();
    _registerPassController.dispose();
    _loginPassController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    final docs = await AuthService().getDoctors();
    if (mounted) setState(() => _doctors = docs);
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }

  Future<void> _loginPatient() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      _showError('Please enter your username');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthService().login(username);
      if (mounted) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainScreen()));
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitDoctor() async {
    setState(() => _isLoading = true);
    try {
      if (_registerMode) {
        final doctor = await AuthService().registerDoctor(
            _doctorNameController.text, _registerPassController.text);
        await AuthService()
            .loginDoctor(doctor.id, _registerPassController.text);
      } else {
        if (_loginDoctorId == null) {
          throw Exception('Select your name from the list');
        }
        await AuthService()
            .loginDoctor(_loginDoctorId!, _loginPassController.text);
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DoctorHomeScreen()));
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.healing, size: 64, color: Colors.white),
              const SizedBox(height: 12),
              const Text(
                'Cognitive Rehab',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const Text(
                'AR-based rehabilitation for mTBI patients',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tab,
                        labelColor: Theme.of(context).colorScheme.primary,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Theme.of(context).colorScheme.primary,
                        tabs: const [
                          Tab(icon: Icon(Icons.person), text: 'Patient'),
                          Tab(
                              icon: Icon(Icons.medical_services),
                              text: 'Doctor'),
                        ],
                      ),
                      const Divider(height: 24),
                      Expanded(
                        child: TabBarView(
                          controller: _tab,
                          children: [_buildPatientTab(), _buildDoctorTab()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PATIENT TAB (بدون dropdown)
  // ============================================================
  Widget _buildPatientTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        TextField(
          controller: _usernameController,
          decoration: const InputDecoration(
            labelText: 'Username',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _loginPatient(),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your username to start the session. Your doctor will add you to their patient list.',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _loginPatient,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Start Session', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DOCTOR TAB
  // ============================================================
  Widget _buildDoctorTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
                value: true,
                label: Text('Register'),
                icon: Icon(Icons.person_add)),
            ButtonSegment(
                value: false, label: Text('Login'), icon: Icon(Icons.login)),
          ],
          selected: {_registerMode},
          onSelectionChanged: (s) => setState(() => _registerMode = s.first),
        ),
        const SizedBox(height: 20),
        if (_registerMode) ...[
          TextField(
            controller: _doctorNameController,
            decoration: const InputDecoration(
              labelText: 'Doctor name',
              prefixIcon: Icon(Icons.badge),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _registerPassController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock),
              border: OutlineInputBorder(),
            ),
          ),
        ] else ...[
          DropdownButtonFormField<String>(
            value: _loginDoctorId,
            decoration: const InputDecoration(
              labelText: 'Doctor',
              prefixIcon: Icon(Icons.badge),
              border: OutlineInputBorder(),
            ),
            items: _doctors
                .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name)))
                .toList(),
            onChanged: (v) => setState(() => _loginDoctorId = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _loginPassController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock),
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitDoctor,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(_registerMode ? 'Create Doctor Account' : 'Enter Clinic',
                    style: const TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }
}
