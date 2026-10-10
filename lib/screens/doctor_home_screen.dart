import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/patient.dart';
import '../services/auth_service.dart';
import '../services/game_data_service.dart';
import 'clinical_report_screen.dart';
import 'login_screen.dart';

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _PatientCardData {
  final Patient patient;
  final int sessions;
  final double avgAccuracy;
  final DateTime? lastPlayed;

  _PatientCardData({
    required this.patient,
    required this.sessions,
    required this.avgAccuracy,
    this.lastPlayed,
  });
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  final _gameDataService = GameDataService();
  List<_PatientCardData> _cards = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doctor = AuthService().currentDoctor;
    if (doctor == null) return;

    final patients = await AuthService().getPatientsForDoctor(doctor.id);
    final cards = <_PatientCardData>[];

    for (final p in patients) {
      final byGame = await _gameDataService.getProgressData(p.id);
      final all = byGame.values.expand((e) => e).toList();
      final avg = all.isEmpty
          ? 0.0
          : all.map((r) => r.accuracy).reduce((a, b) => a + b) / all.length;
      DateTime? last;
      for (final r in all) {
        if (last == null || r.playedAt.isAfter(last)) last = r.playedAt;
      }
      cards.add(_PatientCardData(
        patient: p,
        sessions: all.length,
        avgAccuracy: avg,
        lastPlayed: last,
      ));
    }

    cards.sort((a, b) => (b.lastPlayed ?? DateTime(2000))
        .compareTo(a.lastPlayed ?? DateTime(2000)));

    if (mounted) {
      setState(() {
        _cards = cards;
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctor = AuthService().currentDoctor;
    return Scaffold(
      appBar: AppBar(
        title: Text('My Patients — Dr. ${doctor?.name ?? ''}'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPatientDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Patient'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cards.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _cards.length,
                    itemBuilder: (context, i) => _buildCard(_cards[i]),
                  ),
                ),
    );
  }

  Widget _buildCard(_PatientCardData data) {
    final p = data.patient;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ClinicalReportScreen(patient: p)),
          );
          _load();
        },
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.shade100,
          child: Text(
            p.username.isNotEmpty ? p.username[0].toUpperCase() : '?',
            style: TextStyle(
                color: Colors.indigo.shade700, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(p.username,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${data.sessions} sessions'
          '${data.lastPlayed != null ? ' • last ${DateFormat('MMM d, HH:mm').format(data.lastPlayed!)}' : ' • no sessions yet'}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (data.sessions > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: data.avgAccuracy >= 0.7
                      ? Colors.green.withOpacity(0.12)
                      : Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(data.avgAccuracy * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color:
                        data.avgAccuracy >= 0.7 ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('No patients yet',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(
              'Patients choose you as their doctor when they register.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ADD PATIENT DIALOG
  // ============================================================
  // ============================================================
  // ADD PATIENT DIALOG — اختيار من قائمة المسجلين فقط (بدون كتابة)
  // ============================================================
  Future<void> _showAddPatientDialog() async {
    final doctor = AuthService().currentDoctor;
    if (doctor == null) return;

    // كل المرضى المسجلين في النظام اللي لسه مالهمش طبيب
    final all = await AuthService().getAllPatients();
    final candidates = all.where((p) => p.doctorId == null).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (!mounted) return;

    final selected = await showDialog<Patient>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Patient'),
        content: SizedBox(
          width: double.maxFinite,
          height: 320, // ✅ ارتفاع ثابت + ListView = سكرول بدون overflow
          child: candidates.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No unassigned patients.\nEvery registered patient already has a doctor.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = candidates[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.indigo.shade100,
                        child: Text(
                          p.username.isNotEmpty
                              ? p.username[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              color: Colors.indigo.shade700,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(p.username,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          'Registered ${p.createdAt.day}/${p.createdAt.month}/${p.createdAt.year}'),
                      trailing: const Icon(Icons.add_circle_outline,
                          color: Colors.indigo),
                      onTap: () => Navigator.pop(context, p),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    if (selected != null) {
      await _addPatient(selected.username);
    }
  }

  Future<void> _addPatient(String username) async {
    final doctor = AuthService().currentDoctor;
    if (doctor == null) return;

    try {
      await AuthService().addPatientToDoctor(doctor.id, username);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $username added to your patient list'),
            backgroundColor: Colors.green,
          ),
        );
        _load(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
