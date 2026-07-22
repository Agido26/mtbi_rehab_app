import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/patient.dart';

class AuthService {
  static const String _currentPatientKey = 'current_patient';
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  Patient? _currentPatient;

  Patient? get currentPatient => _currentPatient;

  Future<bool> isLoggedIn() async {
    if (_currentPatient != null) return true;
    final prefs = await SharedPreferences.getInstance();
    final patientJson = prefs.getString(_currentPatientKey);
    if (patientJson != null) {
      _currentPatient = Patient.fromJson(jsonDecode(patientJson));
      return true;
    }
    return false;
  }

  Future<Patient> login(String username) async {
    final prefs = await SharedPreferences.getInstance();

    // Check if patient already exists
    final existingJson = prefs.getString('patient_$username');

    Patient patient;
    if (existingJson != null) {
      patient = Patient.fromJson(jsonDecode(existingJson));
      patient = patient.copyWith(lastLogin: DateTime.now());
    } else {
      // Create new patient
      patient = Patient(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        username: username.trim(),
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );
    }

    // Save patient
    await prefs.setString(
        'patient_${patient.username}', jsonEncode(patient.toJson()));
    await prefs.setString(_currentPatientKey, jsonEncode(patient.toJson()));

    _currentPatient = patient;
    return patient;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentPatientKey);
    _currentPatient = null;
  }
}
