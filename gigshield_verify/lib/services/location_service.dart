import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class LocationSample {
  final double lat;
  final double lon;
  final double accuracy;
  final double? speed; // m/s
  final bool isMock;
  final DateTime timestamp;

  LocationSample({
    required this.lat,
    required this.lon,
    required this.accuracy,
    this.speed,
    required this.isMock,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lon': lon,
        'accuracy': accuracy,
        'speed': speed,
        'is_mock': isMock,
        'timestamp': timestamp.toIso8601String(),
      };
}

class SpoofingResult {
  final int score; // 0 = clean, 100 = definitely spoofed
  final List<String> flags;

  SpoofingResult({required this.score, required this.flags});

  Map<String, dynamic> toJson() => {
        'spoofing_score': score,
        'flags': flags,
      };
}

class LocationService {
  static const _nativeChannel = MethodChannel('com.gigshield/location_native');

  final List<LocationSample> _samples = [];
  StreamSubscription<Position>? _positionSub;

  List<LocationSample> get samples => List.unmodifiable(_samples);

  // ── Permissions ──────────────────────────────────────────────────────────

  Future<bool> ensurePermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  // ── Collection ───────────────────────────────────────────────────────────

  void startCollection() {
    _samples.clear();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).listen(_onPosition, onError: (_) {});
  }

  void stopCollection() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  void _onPosition(Position pos) {
    _samples.add(LocationSample(
      lat: pos.latitude,
      lon: pos.longitude,
      accuracy: pos.accuracy,
      speed: pos.speed,
      isMock: pos.isMocked,
      timestamp: pos.timestamp,
    ));
  }

  // ── Developer options check (native) ────────────────────────────────────

  Future<bool> isDeveloperOptionsEnabled() async {
    try {
      return await _nativeChannel.invokeMethod<bool>('isDeveloperOptionsEnabled') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isMockLocationEnabled() async {
    try {
      return await _nativeChannel.invokeMethod<bool>('isMockLocationEnabled') ?? false;
    } on PlatformException {
      return false;
    }
  }

  // ── Analysis ─────────────────────────────────────────────────────────────

  Future<SpoofingResult> analyzeSpoofing() async {
    final flags = <String>[];
    int score = 0;

    // 1. Mock provider flag from geolocator
    final mockCount = _samples.where((s) => s.isMock).length;
    if (mockCount > 0) {
      flags.add('mock_provider_detected ($mockCount/${_samples.length} samples)');
      score += 40;
    }

    // 2. Developer options
    final devOptions = await isDeveloperOptionsEnabled();
    if (devOptions) {
      flags.add('developer_options_enabled');
      score += 15;
    }

    // 3. Mock location setting
    final mockEnabled = await isMockLocationEnabled();
    if (mockEnabled) {
      flags.add('allow_mock_location_setting_on');
      score += 20;
    }

    // 4. Unrealistic speed jumps (> 50 m/s = 180 km/h between 2s samples)
    if (_samples.length >= 2) {
      for (int i = 1; i < _samples.length; i++) {
        final prev = _samples[i - 1];
        final curr = _samples[i];
        final distanceM = Geolocator.distanceBetween(
          prev.lat, prev.lon, curr.lat, curr.lon,
        );
        final timeDiff =
            curr.timestamp.difference(prev.timestamp).inMilliseconds / 1000.0;
        if (timeDiff > 0) {
          final speed = distanceM / timeDiff;
          if (speed > 50) {
            flags.add('unrealistic_speed_jump: ${speed.toStringAsFixed(1)} m/s');
            score += 25;
            break; // count once
          }
        }
      }
    }

    // 5. Perfect accuracy (spoofed GPS often reports 0.0 accuracy)
    final perfectAccuracy = _samples.where((s) => s.accuracy == 0.0).length;
    if (perfectAccuracy > 0 && _samples.isNotEmpty) {
      flags.add('suspiciously_perfect_accuracy');
      score += 10;
    }

    // 6. Too few samples (might indicate passive spoofing / no actual movement)
    if (_samples.isEmpty) {
      flags.add('no_location_samples_collected');
      score += 5;
    }

    return SpoofingResult(
      score: min(score, 100),
      flags: flags,
    );
  }
}
