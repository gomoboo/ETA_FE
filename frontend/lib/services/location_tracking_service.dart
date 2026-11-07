import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

class LocationSample {
  final double latitude;
  final double longitude;
  final double speedKmh;
  final double accuracy;
  final DateTime collectedAt;

  const LocationSample({
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.accuracy,
    required this.collectedAt,
  });
}

class LocationTrackingService {
  static const String _consentKey = 'eta_location_consent';
  static final Set<LocationTrackingService> _activeTrackers = {};

  static Future<bool> isConsentGranted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consentKey) ?? false;
  }

  static Future<void> setConsentGranted(bool granted) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setBool(_consentKey, granted);

    if (!saved) {
      throw StateError('위치 동의 설정 저장에 실패했습니다.');
    }

    if (!granted) {
      for (final tracker in _activeTrackers.toList()) {
        tracker.stop();
      }
    }
  }

  Timer? _timer;

  bool _isRunning = false;
  bool _isCollecting = false;

  bool get isRunning => _isRunning;

  /// GPS 수집 시작
  ///
  /// 현재는 10초마다 위치를 수집해서 onLocation으로 전달한다.
  /// 나중에 Socket.IO 연결 시 onLocation에서 서버로 전송하면 된다.
  Future<void> start({
    required void Function(LocationSample sample) onLocation,
    void Function(Object error)? onError,
  }) async {
    if (_isRunning) {
      return;
    }

    if (!await isConsentGranted()) {
      onError?.call(StateError('위치 정보 이용에 동의하지 않았습니다.'));
      return;
    }

    final canUseLocation = await _prepareLocationPermission();

    if (!canUseLocation) {
      onError?.call(Exception('위치 권한을 사용할 수 없습니다.'));
      return;
    }

    if (!await isConsentGranted()) return;

    _isRunning = true;
    _activeTrackers.add(this);

    // 시작하자마자 한 번 수집
    await _collectLocation(onLocation: onLocation, onError: onError);

    // 첫 GPS 요청 중 stop()이 호출됐다면 타이머를 시작하지 않음
    if (!_isRunning) return;

    // 이후 10초마다 수집
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      _collectLocation(onLocation: onLocation, onError: onError);
    });
  }

  /// GPS 수집 중지
  void stop() {
    _timer?.cancel();
    _timer = null;

    _isRunning = false;
    _isCollecting = false;
    _activeTrackers.remove(this);
  }

  Future<bool> _prepareLocationPermission() async {
    debugPrint('📍 [GPS] 위치 서비스 확인 시작');

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    debugPrint('📍 [GPS] 위치 서비스 활성화: $serviceEnabled');

    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    debugPrint('📍 [GPS] 현재 권한 상태: $permission');

    if (permission == LocationPermission.denied) {
      debugPrint('📍 [GPS] 위치 권한 요청');

      permission = await Geolocator.requestPermission();

      debugPrint('📍 [GPS] 요청 후 권한 상태: $permission');
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<void> _collectLocation({
    required void Function(LocationSample sample) onLocation,
    void Function(Object error)? onError,
  }) async {
    // 앞선 GPS 요청이 아직 끝나지 않았다면
    // 중복 요청하지 않음
    if (_isCollecting) {
      return;
    }

    _isCollecting = true;

    try {
      debugPrint('📍 [GPS] 현재 위치 요청 시작');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      debugPrint('📍 [GPS] 현재 위치 수신 성공');

      final speedKmh = position.speed < 0 ? 0.0 : position.speed * 3.6;

      final sample = LocationSample(
        latitude: position.latitude,
        longitude: position.longitude,
        speedKmh: speedKmh,
        accuracy: position.accuracy,
        collectedAt: DateTime.now(),
      );

      if (_isRunning && await isConsentGranted()) {
        onLocation(sample);
      }
    } catch (e) {
      onError?.call(e);
    } finally {
      _isCollecting = false;
    }
  }

  void dispose() {
    stop();
  }
}
