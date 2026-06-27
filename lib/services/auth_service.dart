import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/doctor.dart';
import '../database/database_helper.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  Doctor? _currentDoctor;

  Doctor? get currentDoctor => _currentDoctor;
  int get currentDoctorId => _currentDoctor?.id ?? 1;
  bool get isLoggedIn => _currentDoctor != null;

  void setDoctor(Doctor doctor) => _currentDoctor = doctor;

  Future<void> logout() async {
    _currentDoctor = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('doctorId');
    await prefs.setBool('isLoggedIn', false);
  }

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final doctorId = prefs.getInt('doctorId');
    if (doctorId == null) return false;
    final db = DatabaseHelper();
    final doctor = await db.getDoctorById(doctorId);
    if (doctor == null) return false;
    _currentDoctor = doctor;
    return true;
  }

  Future<void> persistLogin(int doctorId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('doctorId', doctorId);
    await prefs.setBool('isLoggedIn', true);
  }

  // Creates or updates the config doctor in the database, keeping name and
  // clinicName in sync with AppConfig on every fresh login.
  Future<Doctor> ensureConfigDoctor() async {
    final db = DatabaseHelper();
    final now = DateTime.now().toIso8601String();
    final existing = await db.getDoctorByUsername('__config__');
    if (existing != null) {
      final updated = existing.copyWith(
        name: AppConfig.doctorName,
        clinicName: AppConfig.clinicName,
      );
      await db.updateDoctor(updated);
      return updated;
    }
    final doctor = Doctor(
      name: AppConfig.doctorName,
      clinicName: AppConfig.clinicName,
      username: '__config__',
      password: AppConfig.licenseKey,
      specialty: '',
      phone: '',
      createdAt: now,
    );
    final id = await db.insertDoctor(doctor);
    return doctor.copyWith(id: id);
  }
}
