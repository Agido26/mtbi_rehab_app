import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/doctor.dart';
import '../models/patient.dart';

class AuthService {
  static const String _currentPatientKey = 'current_patient';
  static const String _currentDoctorKey = 'current_doctor';
  static const String _doctorsListKey = 'doctors_list';

  /// 🔑 كلمة السر الموحدة البسيطة للأطباء (دخول + تسجيل)
  static const String doctorPassword = 'doctor123';

  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  Patient? _currentPatient;
  Doctor? _currentDoctor;

  Patient? get currentPatient => _currentPatient;
  Doctor? get currentDoctor => _currentDoctor;

  // ============================================================
  // PATIENT
  // ============================================================
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

  /// ✅ الطبيب يضيف مريض لقائمته (موجود أو جديد)
  Future<Patient> addPatientToDoctor(String doctorId, String username) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      throw Exception('Enter patient username');
    }

    final existingJson = prefs.getString('patient_$trimmed');
    Patient patient;

    if (existingJson != null) {
      // مريض موجود → أضفه للطبيب (إذا مش تابع لطبيب تاني)
      patient = Patient.fromJson(jsonDecode(existingJson));
      if (patient.doctorId != null && patient.doctorId != doctorId) {
        throw Exception('Patient already assigned to another doctor');
      }
      patient = patient.copyWith(doctorId: doctorId);
    } else {
      // مريض جديد → أنشئه وتابعه للطبيب
      patient = Patient(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        username: trimmed,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        doctorId: doctorId,
      );
    }

    await prefs.setString(
        'patient_${patient.username}', jsonEncode(patient.toJson()));
    return patient;
  }

  /// تسجيل دخول المريض (موجود = يدخل، جديد = ينشأ بدون طبيب)
  Future<Patient> login(String username) async {
    final prefs = await SharedPreferences.getInstance();

    // جلسة واحدة فقط: دخول مريض يلغي جلسة الطبيب
    await prefs.remove(_currentDoctorKey);
    _currentDoctor = null;

    final existingJson = prefs.getString('patient_$username');

    Patient patient;
    if (existingJson != null) {
      patient = Patient.fromJson(jsonDecode(existingJson));
      patient = patient.copyWith(lastLogin: DateTime.now());
    } else {
      // مريض جديد بدون طبيب — الطبيب سيضيفه لاحقاً
      patient = Patient(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        username: username.trim(),
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        doctorId: null, // ✅ بدون طبيب
      );
    }

    await prefs.setString(
        'patient_${patient.username}', jsonEncode(patient.toJson()));
    await prefs.setString(_currentPatientKey, jsonEncode(patient.toJson()));

    _currentPatient = patient;
    return patient;
  }

  Future<List<Patient>> getAllPatients() async {
    final prefs = await SharedPreferences.getInstance();
    final patients = <Patient>[];
    for (final key in prefs.getKeys()) {
      if (key.startsWith('patient_')) {
        try {
          patients.add(Patient.fromJson(jsonDecode(prefs.getString(key)!)));
        } catch (_) {}
      }
    }
    return patients;
  }

  Future<List<Patient>> getPatientsForDoctor(String doctorId) async {
    final all = await getAllPatients();
    return all.where((p) => p.doctorId == doctorId).toList();
  }

  // ============================================================
  // DOCTOR
  // ============================================================
  Future<bool> isDoctorLoggedIn() async {
    if (_currentDoctor != null) return true;
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_currentDoctorKey);
    if (json != null) {
      _currentDoctor = Doctor.fromJson(jsonDecode(json));
      return true;
    }
    return false;
  }

  Future<List<Doctor>> getDoctors() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_doctorsListKey);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((e) => Doctor.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Doctor> registerDoctor(String name, String password) async {
    if (password != doctorPassword) {
      throw Exception('Wrong doctor password');
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw Exception('Enter the doctor name');
    }

    final prefs = await SharedPreferences.getInstance();
    final doctors = await getDoctors();

    if (doctors.any((d) => d.name.toLowerCase() == trimmed.toLowerCase())) {
      throw Exception('Doctor name already registered — use Login');
    }

    final doctor = Doctor(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: trimmed,
      createdAt: DateTime.now(),
    );
    doctors.add(doctor);
    await prefs.setString(
        _doctorsListKey, jsonEncode(doctors.map((d) => d.toJson()).toList()));

    return doctor;
  }

  Future<Doctor> loginDoctor(String doctorId, String password) async {
    if (password != doctorPassword) {
      throw Exception('Wrong password');
    }
    final doctors = await getDoctors();
    final doctor = doctors.firstWhere(
      (d) => d.id == doctorId,
      orElse: () => throw Exception('Doctor not found'),
    );

    final prefs = await SharedPreferences.getInstance();
    // جلسة واحدة فقط: دخول طبيب يلغي جلسة المريض
    await prefs.remove(_currentPatientKey);
    _currentPatient = null;

    await prefs.setString(_currentDoctorKey, jsonEncode(doctor.toJson()));
    _currentDoctor = doctor;
    return doctor;
  }

  Future<void> _adoptUnassignedPatients(String doctorId) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (!key.startsWith('patient_')) continue;
      try {
        final p = Patient.fromJson(jsonDecode(prefs.getString(key)!));
        if (p.doctorId == null) {
          final updated = p.copyWith(doctorId: doctorId);
          await prefs.setString(key, jsonEncode(updated.toJson()));
          if (_currentPatient?.id == p.id) _currentPatient = updated;
        }
      } catch (_) {}
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentPatientKey);
    await prefs.remove(_currentDoctorKey);
    _currentPatient = null;
    _currentDoctor = null;
  }
}
