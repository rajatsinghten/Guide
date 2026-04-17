import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

/// Represents an active verification session
class VerificationSession {
  final String sessionId;
  final String nonce;
  final DateTime startTime;
  String? videoPath;
  final List<AppUsageEvent> appUsageLog = [];
  bool driverAppOpened = false;

  VerificationSession({
    required this.sessionId,
    required this.nonce,
    required this.startTime,
  });

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'nonce': nonce,
        'start_time': startTime.toIso8601String(),
        'video_path': videoPath,
        'driver_app_opened': driverAppOpened,
        'app_usage_log': appUsageLog.map((e) => e.toJson()).toList(),
        'duration_seconds': DateTime.now().difference(startTime).inSeconds,
      };
}

class AppUsageEvent {
  final String packageName;
  final DateTime timestamp;
  final String eventType; // 'foreground' | 'background'

  AppUsageEvent({
    required this.packageName,
    required this.timestamp,
    required this.eventType,
  });

  Map<String, dynamic> toJson() => {
        'package_name': packageName,
        'timestamp': timestamp.toIso8601String(),
        'event_type': eventType,
      };
}

class VerificationService {
  static const _channel = MethodChannel('com.gigshield/recording');
  static const _appChannel = MethodChannel('com.gigshield/app_detection');

  static const List<String> _driverPackages = [
    'com.zomato.delivery',
    'in.swiggy.deliveryapp',
    'com.ubercab.driver',
    'com.ola.driver', // extra: Ola captain
  ];

  VerificationSession? _currentSession;
  Timer? _nonceRefreshTimer;
  Timer? _foregroundPollTimer;
  String _currentNonce = '';

  VerificationSession? get currentSession => _currentSession;
  String get currentNonce => _currentNonce;

  // ── Session creation ─────────────────────────────────────────────────────

  VerificationSession createSession() {
    final session = VerificationSession(
      sessionId: const Uuid().v4(),
      nonce: _generateNonce(),
      startTime: DateTime.now(),
    );
    _currentSession = session;
    _currentNonce = session.nonce;
    return session;
  }

  String _generateNonce({int length = 8}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous chars
    final rng = Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── Recording ────────────────────────────────────────────────────────────

  Future<bool> startRecording() async {
    if (_currentSession == null) return false;
    try {
      final result = await _channel.invokeMethod<bool>('startRecording', {
        'sessionId': _currentSession!.sessionId,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw VerificationException('Recording failed: ${e.message}');
    }
  }

  Future<String?> stopRecording() async {
    try {
      final path = await _channel.invokeMethod<String>('stopRecording');
      if (_currentSession != null && path != null) {
        _currentSession!.videoPath = path;
      }
      _stopPolling();
      return path;
    } on PlatformException catch (e) {
      throw VerificationException('Stop recording failed: ${e.message}');
    }
  }

  // ── Nonce rotation ───────────────────────────────────────────────────────

  void startNonceRotation(void Function(String) onNonceChanged) {
    _nonceRefreshTimer?.cancel();
    _nonceRefreshTimer =
        Timer.periodic(const Duration(seconds: 3), (_) {
      _currentNonce = _generateNonce();
      _currentSession?.appUsageLog.add(AppUsageEvent(
        packageName: '__nonce_rotated__',
        timestamp: DateTime.now(),
        eventType: _currentNonce,
      ));
      onNonceChanged(_currentNonce);
    });
  }

  void stopNonceRotation() {
    _nonceRefreshTimer?.cancel();
  }

  // ── App detection ────────────────────────────────────────────────────────

  Future<Map<String, bool>> checkInstalledDriverApps() async {
    try {
      final result = await _appChannel.invokeMethod<Map>(('checkInstalledApps'), {
        'packages': _driverPackages,
      });
      return Map<String, bool>.from(result ?? {});
    } on PlatformException catch (e) {
      throw VerificationException('App check failed: ${e.message}');
    }
  }

  Future<String?> getForegroundApp() async {
    try {
      return await _appChannel.invokeMethod<String>('getForegroundApp');
    } on PlatformException {
      return null;
    }
  }

  bool isDriverApp(String? packageName) {
    if (packageName == null) return false;
    return _driverPackages.contains(packageName);
  }

  void startForegroundPolling() {
    _foregroundPollTimer?.cancel();
    _foregroundPollTimer =
        Timer.periodic(const Duration(seconds: 2), (_) async {
      final pkg = await getForegroundApp();
      if (pkg != null && _currentSession != null) {
        final isDriver = isDriverApp(pkg);
        if (isDriver) {
          _currentSession!.driverAppOpened = true;
        }
        final lastEvent = _currentSession!.appUsageLog.isNotEmpty
            ? _currentSession!.appUsageLog.last
            : null;
        if (lastEvent == null ||
            lastEvent.packageName != pkg ||
            lastEvent.eventType != 'foreground') {
          _currentSession!.appUsageLog.add(AppUsageEvent(
            packageName: pkg,
            timestamp: DateTime.now(),
            eventType: 'foreground',
          ));
        }
      }
    });
  }

  void _stopPolling() {
    _foregroundPollTimer?.cancel();
  }

  void dispose() {
    _nonceRefreshTimer?.cancel();
    _foregroundPollTimer?.cancel();
  }
}

class VerificationException implements Exception {
  final String message;
  VerificationException(this.message);

  @override
  String toString() => 'VerificationException: $message';
}
