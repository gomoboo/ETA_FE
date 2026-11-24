import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'eta_api_service.dart';
import 'eta_arrival_cache_service.dart';
import 'eta_notification_service.dart';
import 'eta_websocket_service.dart';
import 'guest_identity_service.dart';
import 'location_tracking_service.dart';

class EtaRadarSession {
  EtaRadarSession._(this.appointmentId, this.participantId);

  static final Map<int, EtaRadarSession> _sessions = {};

  static Future<void> stopAll() async {
    final sessions = List<EtaRadarSession>.of(_sessions.values);
    await Future.wait<void>(sessions.map((session) => session.stop()));
  }

  static EtaRadarSession getOrCreate({
    required int appointmentId,
    required int participantId,
  }) {
    final existing = _sessions[appointmentId];

    if (existing != null) {
      if (existing.participantId != participantId) {
        throw StateError('참가자 정보가 일치하지 않습니다.');
      }
      return existing;
    }

    return _sessions.putIfAbsent(
      appointmentId,
      () => EtaRadarSession._(appointmentId, participantId),
    );
  }

  final int appointmentId;
  final int participantId;

  final _location = LocationTrackingService();
  final _socket = EtaWebSocketService();

  final _locations = StreamController<LocationSample>.broadcast();
  final _messages = StreamController<String>.broadcast();
  final _connections = StreamController<bool>.broadcast();

  Stream<LocationSample> get locations => _locations.stream;
  Stream<String> get messages => _messages.stream;
  Stream<bool> get connections => _connections.stream;

  bool get isConnected => _socket.isConnected;
  bool get hasArrived => _arrived;

  Map<String, dynamic>? _appointmentDetail;

  LocationSample? latestLocation;
  String? latestMapSync;
  DateTime? lastMapSyncAt;
  bool hasConnectionIssue = false;
  int? sharedFriendCount;

  bool get isClosed => _closed;
  bool get isTracking => _location.isRunning;

  Timer? _lifecycleTimer;
  Timer? _deadlineTimer;
  DateTime? _stopAt;
  bool _checkingLifecycle = false;

  bool _started = false;
  bool _closed = false;
  bool _arrived = false;

  Future<void> start() async {
    if (_started || _closed) return;
    _started = true;

    try {
      final detail = await EtaApiService.getAppointmentDetail(appointmentId);

      if (_closed) return;

      _appointmentDetail = detail;

      final meetAt = DateTime.tryParse(detail['meetAt']?.toString() ?? '');

      if (meetAt == null) {
        throw StateError('약속 시간 확인 실패');
      }

      _stopAt = meetAt.add(const Duration(hours: 1));

      final remaining = _stopAt!.difference(DateTime.now());

      if (remaining <= Duration.zero) {
        await stop();
        return;
      }

      _deadlineTimer = Timer(remaining, () {
        unawaited(stop());
      });

      await _checkLifecycle();
      if (_closed) return;

      _lifecycleTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(_checkLifecycle()),
      );

      await Future.wait<void>([_connect(), _startTracking()]);
    } catch (error) {
      debugPrint('ETA 세션 시작 실패: $error');
      await stop();
    }
  }

  Future<void> _checkLifecycle() async {
    if (_closed || _checkingLifecycle) return;
    _checkingLifecycle = true;

    try {
      if (!await LocationTrackingService.isConsentGranted()) {
        await stop();
        return;
      }

      if (_closed) return;

      final home = await EtaApiService.getHomeAppointments();
      final active = home['activeAppointments'];
      final upcoming = home['upcomingAppointments'];

      if (_closed) return;
      if (active is! List || upcoming is! List) return;

      final exists = [...active, ...upcoming].any(
        (item) =>
            item is Map &&
            item['appointmentId']?.toString() == appointmentId.toString(),
      );

      if (!exists) {
        debugPrint('ETA 세션: 현재 약속 목록에서 제외됨');
        await stop();
      }
    } catch (error) {
      debugPrint('ETA 세션: 약속 상태 확인 보류');
    } finally {
      _checkingLifecycle = false;
    }
  }

  Future<void> _connect() async {
    try {
      final uuid = await GuestIdentityService.getOrCreateUuid();
      if (_closed) return;

      await _socket.connect(
        appointmentId: appointmentId,
        participantId: participantId,
        guestUuid: uuid,
        onConnected: () {
          if (_closed) return;
          hasConnectionIssue = false;
          _connections.add(true);

          final sample = latestLocation;
          if (sample != null) _sendLocation(sample);
        },
        onMessage: _handleMessage,
        onError: (error) {
          if (!_closed) {
            hasConnectionIssue = true;
            _connections.add(false);
          }
          debugPrint('ETA 세션: WebSocket 연결 오류');
        },
        onDisconnected: () {
          if (!_closed) {
            hasConnectionIssue = true;
            _connections.add(false);
          }
        },
      );
    } catch (error) {
      if (!_closed) {
        hasConnectionIssue = true;
        _connections.add(false);
      }
      debugPrint('ETA 세션: 연결 실패');
    }
  }

  Future<void> _startTracking() async {
    if (_closed || _arrived) return;

    await _location.start(
      onLocation: (sample) {
        if (_closed || _arrived) return;

        latestLocation = sample;
        _locations.add(sample);
        _sendLocation(sample);
      },
      onError: (error) {
        debugPrint('ETA 세션: GPS 수집 실패');
      },
    );

    if (_closed || _arrived) _location.stop();
  }

  void _sendLocation(LocationSample sample) {
    final stopAt = _stopAt;

    if (stopAt != null && !DateTime.now().isBefore(stopAt)) {
      unawaited(stop());
      return;
    }

    if (_closed || _arrived || !_socket.isConnected) return;

    _socket.send({
      'type': 'location:update',
      'latitude': sample.latitude,
      'longitude': sample.longitude,
      'speedKmh': sample.speedKmh < 0 ? 0.0 : sample.speedKmh,
    });

    debugPrint('ETA 세션: GPS 위치 전송');
  }

  void _handleMessage(String message) {
    if (_closed) return;

    try {
      final data = jsonDecode(message);

      if (data is Map) {
        if (data['type'] == 'map:sync') {
          final participants = data['participants'];

          if (participants is List) {
            latestMapSync = message;
            lastMapSyncAt = DateTime.now();

            sharedFriendCount = participants.where((person) {
              return person is Map &&
                  person['participantId'] != null &&
                  person['participantId'].toString() !=
                      participantId.toString() &&
                  person['latitude'] is num &&
                  person['longitude'] is num;
            }).length;
          }
        }

        if (data['type'] == 'checkin:completed') {
          final arrivedId = int.tryParse(
            data['participantId']?.toString() ?? '',
          );
          final arrivedAt = DateTime.tryParse(
            data['arrivedAt']?.toString() ?? '',
          );

          if (arrivedId != null && arrivedAt != null) {
            unawaited(
              EtaArrivalCacheService.save(
                appointmentId: appointmentId,
                participantId: arrivedId,
                arrivedAt: arrivedAt,
              ),
            );
          }
        }

        if (data['type'] == 'checkin:completed' &&
            data['participantId']?.toString() == participantId.toString()) {
          _arrived = true;
          _location.stop();
          debugPrint('ETA 세션: 본인 도착 확정, GPS 중단');
        }
      }

      if (data is Map && !_messages.hasListener) {
        unawaited(_saveOffscreenNotification(data));
      }

      _messages.add(message);
    } catch (error) {
      debugPrint('ETA 세션: 메시지 처리 실패');
    }
  }

  Future<void> _saveOffscreenNotification(Map data) async {
    try {
      final type = data['type'];
      final eventTitle = data['appointmentTitle']?.toString().trim() ?? '';
      final cachedTitle = _appointmentDetail?['title']?.toString().trim() ?? '';

      final title = eventTitle.isNotEmpty
          ? eventTitle
          : cachedTitle.isNotEmpty
          ? cachedTitle
          : '약속';

      if (type == 'poke:received') {
        final sender = data['senderNickname']?.toString().trim() ?? '';
        final nickname = sender.isEmpty ? '친구' : sender;
        final pokeId =
            data['pokeId']?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString();

        await EtaNotificationService.saveNotification(
          id: 'poke:$appointmentId:$pokeId',
          type: 'poke',
          title: '$nickname님이 찌르기를 보냈어요',
          description: '$title · 출발 신호가 도착했어요.',
          appointmentId: appointmentId,
        );
      }

      if (type == 'checkin:completed') {
        final arrivedId = int.tryParse(data['participantId']?.toString() ?? '');

        if (arrivedId == null || arrivedId == participantId) return;

        var nickname = data['nickname']?.toString().trim() ?? '';
        final participants = _appointmentDetail?['participants'];

        if (nickname.isEmpty && participants is List) {
          for (final person in participants) {
            if (person is Map &&
                person['participantId']?.toString() == arrivedId.toString()) {
              nickname = person['nickname']?.toString().trim() ?? '';
              break;
            }
          }
        }

        if (nickname.isEmpty) nickname = '친구';

        await EtaNotificationService.saveNotification(
          id: 'arrival:$appointmentId:$arrivedId',
          type: 'arrival',
          title: '$nickname님이 도착했어요',
          description: '$title · 친구의 도착 상태를 확인해요.',
          appointmentId: appointmentId,
        );
      }
    } catch (error) {
      debugPrint('ETA 세션: 화면 밖 알림 저장 실패: $error');
    }
  }

  void send(Map<String, dynamic> payload) {
    if (!_closed) _socket.send(payload);
  }

  Future<void> stop() async {
    if (_closed) return;
    _closed = true;

    _lifecycleTimer?.cancel();
    _deadlineTimer?.cancel();

    _lifecycleTimer = null;
    _deadlineTimer = null;

    _location.stop();
    await _socket.dispose();

    _sessions.remove(appointmentId);

    await _locations.close();
    await _messages.close();
    await _connections.close();
  }
}
