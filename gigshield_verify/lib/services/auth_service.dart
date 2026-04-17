import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../app/constants.dart';

/// Represents a registered GigShield worker.
class Worker {
  final String id;
  final String name;
  final String phone;
  final String city;
  final String pincode;
  final String platform;
  final double avgWeeklyIncomeInr;
  final String vehicleType;

  Worker({
    required this.id,
    required this.name,
    required this.phone,
    required this.city,
    required this.pincode,
    required this.platform,
    required this.avgWeeklyIncomeInr,
    required this.vehicleType,
  });

  factory Worker.fromJson(Map<String, dynamic> json) => Worker(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        city: json['city'] as String,
        pincode: json['pincode'] as String,
        platform: json['platform'] as String,
        avgWeeklyIncomeInr: (json['avg_weekly_income_inr'] as num).toDouble(),
        vehicleType: json['vehicle_type'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'city': city,
        'pincode': pincode,
        'platform': platform,
        'avg_weekly_income_inr': avgWeeklyIncomeInr,
        'vehicle_type': vehicleType,
      };
}

/// Handles authentication: login, register, token storage, logout.
class AuthService {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  AuthService._();

  Worker? _currentWorker;
  String? _token;

  Worker? get currentWorker => _currentWorker;
  String? get token => _token;
  bool get isLoggedIn => _token != null;

  // ── Initialise from storage ──────────────────────────────────────────────

  Future<bool> tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AppConstants.prefJwt);
    final workerJson = prefs.getString(AppConstants.prefWorkerJson);
    if (_token == null) return false;
    if (workerJson != null) {
      try {
        _currentWorker = Worker.fromJson(
          jsonDecode(workerJson) as Map<String, dynamic>,
        );
      } catch (_) {}
    }
    // Validate token with API
    try {
      final fresh = await _fetchMe();
      _currentWorker = fresh;
      await prefs.setString(AppConstants.prefWorkerJson, jsonEncode(fresh.toJson()));
      return true;
    } catch (_) {
      // Token invalid / server offline — clear
      await logout();
      return false;
    }
  }

  // ── Register ─────────────────────────────────────────────────────────────

  Future<void> register({
    required String name,
    required String phone,
    required String city,
    required String pincode,
    required String platform,
    required double avgWeeklyIncomeInr,
    required String vehicleType,
  }) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/api/v1/workers/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'city': city,
        'pincode': pincode,
        'platform': platform,
        'avg_weekly_income_inr': avgWeeklyIncomeInr,
        'vehicle_type': vehicleType,
      }),
    );
    if (res.statusCode == 409) {
      throw Exception('Phone number already registered');
    }
    if (res.statusCode != 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['detail'] ?? 'Registration failed');
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<Worker> login({required String phone, required String otp}) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/api/v1/workers/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'otp': otp}),
    );
    if (res.statusCode == 401) {
      throw Exception('Invalid phone number or OTP');
    }
    if (res.statusCode != 200) {
      throw Exception('Login failed');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    _token = data['access_token'] as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefJwt, _token!);
    final worker = await _fetchMe();
    _currentWorker = worker;
    await prefs.setString(AppConstants.prefWorkerJson, jsonEncode(worker.toJson()));
    return worker;
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    _token = null;
    _currentWorker = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefJwt);
    await prefs.remove(AppConstants.prefWorkerJson);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<Worker> _fetchMe() async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/v1/workers/me'),
      headers: {'Authorization': 'Bearer $_token'},
    );
    if (res.statusCode != 200) throw Exception('Session expired');
    return Worker.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // ── Verification flag (once per device) ──────────────────────────────────

  Future<bool> isVerified() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.prefVerified) ?? false;
  }

  Future<void> markVerified() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefVerified, true);
  }
}
