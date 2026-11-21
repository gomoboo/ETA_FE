import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../services/location_tracking_service.dart';
import '../services/eta_websocket_service.dart';
import '../services/guest_identity_service.dart';
import '../services/eta_api_service.dart';
import 'arrival_checkin_screen.dart';
import 'appointment_result_screen.dart';

class FriendRadarData {
  const FriendRadarData({
    required this.id,
    required this.name,
    required this.initial,
    required this.position,
    required this.distanceText,
    required this.speedKmh,
    required this.status,
    this.warning = false,
  });

  final String id;
  final String name;
  final String initial;
  final LatLng position;

  final String distanceText;
  final double speedKmh;
  final String status;
  final bool warning;

  String get detail {
    final speedText = speedKmh == speedKmh.roundToDouble()
        ? speedKmh.toStringAsFixed(0)
        : speedKmh.toStringAsFixed(1);

    return '$distanceText · ${speedText}km/h';
  }

  FriendRadarData copyWith({
    LatLng? position,
    String? distanceText,
    double? speedKmh,
    String? status,
    bool? warning,
  }) {
    return FriendRadarData(
      id: id,
      name: name,
      initial: initial,
      position: position ?? this.position,
      distanceText: distanceText ?? this.distanceText,
      speedKmh: speedKmh ?? this.speedKmh,
      status: status ?? this.status,
      warning: warning ?? this.warning,
    );
  }
}

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  // ===============================================================
  // Figma 기준
  // ===============================================================

  static const double _collapsedHeight = 300;
  static const int _collapsedFriendLimit = 3;
  static const double _radarHeaderHeight = 118;
  static const int _initialMapZoomLevel = 16;
  static const double _friendGap = 12;
  static const double _pokeButtonHeight = 32;
  static const double _pokeButtonGap = 12;

  double get _expandedHeight {
    final extraRows = _friends.length - _collapsedFriendLimit;
    if (extraRows <= 0) return _collapsedHeight;

    final desiredHeight =
        _collapsedHeight +
        extraRows * (_FriendStatusRow.rowHeight + _friendGap);
    final availableHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.paddingOf(context).vertical -
        _radarHeaderHeight -
        _pokeButtonHeight -
        _pokeButtonGap;

    if (availableHeight <= _collapsedHeight) return _collapsedHeight;
    return desiredHeight.clamp(_collapsedHeight, availableHeight).toDouble();
  }

  bool get _canExpandSheet => _expandedHeight > _collapsedHeight;

  double _sheetProgress = 0;

  double get _sheetHeight =>
      _collapsedHeight + (_expandedHeight - _collapsedHeight) * _sheetProgress;

  set _sheetHeight(double height) {
    final travel = _expandedHeight - _collapsedHeight;
    _sheetProgress = travel > 0
        ? ((height - _collapsedHeight) / travel).clamp(0.0, 1.0).toDouble()
        : 0.0;
  }

  int get _collapsedFriendCount =>
      _friends.length.clamp(0, _collapsedFriendLimit).toInt();

  bool _isDragging = false;

  // ===============================================================
  // 색상
  // ===============================================================

  static const Color _background = Color(0xFFF7FBFF);
  static const Color _navy = Color(0xFF18354A);
  static const Color _gray = Color(0xFF718696);
  static const Color _blue = Color(0xFF1685B5);

  // 친구 마커 배경색
  static const Color _friendMarkerBackground = Color(0xFFECF7FD);

  // 찌르기 버튼
  static const Color _pokeBackground = Color(0xFFFFFDED);
  static const Color _pokeBorder = Color(0xFFFAEB08);
  static const Color _pokeText = Color(0xFFD1C40F);

  // ===============================================================
  // GPS
  // ===============================================================

  final LocationTrackingService _locationTrackingService =
      LocationTrackingService();

  LocationSample? _latestLocation;

  final EtaWebSocketService _socketService = EtaWebSocketService();
  bool _socketStarted = false;
  bool _myArrivalConfirmed = false;
  int? _activeAppointmentId;

  // ===============================================================
  // Kakao Map
  // ===============================================================

  KakaoMapController? _mapController;
  Poi? _myPoi;

  final Map<String, Poi> _friendPois = {};

  List<FriendRadarData> _friends = [
    FriendRadarData(
      id: 'friend-jimin',
      name: '지민',
      initial: '지',
      position: LatLng(37.5012, 127.0258),
      distanceText: '1.2km',
      speedKmh: 12,
      status: '15분 후',
    ),
    FriendRadarData(
      id: 'friend-seoyeon',
      name: '서연',
      initial: '서',
      position: LatLng(37.4958, 127.0322),
      distanceText: '450m',
      speedKmh: 5,
      status: '8분 후',
    ),
    FriendRadarData(
      id: 'friend-minsu',
      name: '민수',
      initial: '민',
      position: LatLng(37.4938, 127.0215),
      distanceText: '2.3km',
      speedKmh: 0,
      status: '침대 의심',
      warning: true,
    ),
  ];

  bool _didMoveCameraToMyLocation = false;

  // ===============================================================
  // 사용자 닉네임
  // HomeScreen에서 route argument로 전달받음
  // 전달되지 않으면 임시로 '나'
  // ===============================================================

  String _myNickname = '나';
  bool _didReadNickname = false;

  String get _myInitial {
    final nickname = _myNickname.trim();

    if (nickname.isEmpty) {
      return '나';
    }

    return nickname.substring(0, 1);
  }

  // ===============================================================
  // 바텀시트 진행도
  // ===============================================================

  // ===============================================================
  // 초기화
  // ===============================================================

  @override
  void initState() {
    super.initState();

    _startLocationTracking();
    _appointmentClockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _cachedAppointmentDetail != null) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didReadNickname) {
      return;
    }

    final arguments = ModalRoute.of(context)?.settings.arguments;

    if (arguments is Map) {
      final appointmentId = arguments['appointmentId'];
      final participantId = arguments['myParticipantId'];

      if (appointmentId is int) {
        _activeAppointmentId = appointmentId;
      }
      final nickname = arguments['nickname'];

      if (nickname is String && nickname.trim().isNotEmpty) {
        _myNickname = nickname.trim();
      }

      if (appointmentId is int && participantId is int) {
        _friends = [];
        unawaited(_connectRealtime(appointmentId, participantId));
      }
    } else if (arguments is String && arguments.trim().isNotEmpty) {
      _myNickname = arguments.trim();
    }

    _didReadNickname = true;
  }

  // ===============================================================
  // GPS 10초 주기 수집
  // ===============================================================

  Future<void> _connectRealtime(int appointmentId, int participantId) async {
    if (_socketStarted) return;
    _socketStarted = true;
    unawaited(_loadAppointmentDetail(appointmentId));

    try {
      final guestUuid = await GuestIdentityService.getOrCreateUuid();

      if (!mounted) return;

      await _socketService.connect(
        appointmentId: appointmentId,
        participantId: participantId,
        guestUuid: guestUuid,
        onConnected: () {
          debugPrint('ETA WebSocket: 레이더 연결 성공');
          if (mounted && _checkingScreenOpen && !_myArrivalConfirmed) {
            _checkingStatus.value = ArrivalCheckinStatus.checking;
          }
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('실시간 서버 연결 성공')));
          }
        },
        onMessage: (message) {
          unawaited(
            _handleRealtimeMessage(message, participantId, appointmentId),
          );
        },
        onError: (error) {
          debugPrint('ETA WebSocket 오류: $error');
          if (mounted && _checkingScreenOpen && !_myArrivalConfirmed) {
            _checkingStatus.value = ArrivalCheckinStatus.disconnected;
          }
        },
        onDisconnected: () {
          debugPrint('ETA WebSocket 연결 종료');
          if (mounted && _checkingScreenOpen && !_myArrivalConfirmed) {
            _checkingStatus.value = ArrivalCheckinStatus.disconnected;
          }
        },
      );
    } catch (error) {
      debugPrint('ETA WebSocket 연결 실패: $error');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('실시간 연결 실패: $error')));
      }
    }
  }

  Future<void> _handleRealtimeMessage(
    String message,
    int myParticipantId,
    int appointmentId,
  ) async {
    try {
      final decoded = jsonDecode(message);
      if (decoded is! Map<String, dynamic>) return;

      if (decoded['type'] == 'checkin:completed') {
        final arrivedId = decoded['participantId'];
        if (arrivedId is! int) return;

        if (arrivedId == myParticipantId) {
          _myArrivalConfirmed = true;
          _locationTrackingService.stop();
          debugPrint('ETA 체크인: 본인 도착 확정, GPS 수집 중단');
        }

        await _openArrivalResult(decoded, appointmentId);
        return;
      }

      if (decoded['type'] != 'map:sync') {
        debugPrint('ETA WebSocket 수신 이벤트: ${decoded['type']}');
        return;
      }

      final participants = decoded['participants'];
      if (participants is! List) return;

      debugPrint('ETA WebSocket: map:sync ${participants.length}명 수신');

      for (final item in participants) {
        if (item is! Map) continue;

        final id = item['participantId'];
        final name = item['nickname'];
        final latitude = item['latitude'];
        final longitude = item['longitude'];

        if (id is! int || id == myParticipantId) continue;
        if (name is! String || name.trim().isEmpty) continue;
        if (latitude is! num || longitude is! num) continue;

        final distance = item['distanceMeter'];
        final speed = item['speedKmh'];
        final eta = item['estimatedArrivalMinutes'];
        final movement = item['movementState'];

        final distanceText = distance is num
            ? (distance >= 1000
                  ? '${(distance / 1000).toStringAsFixed(1)}km'
                  : '${distance.round()}m')
            : '거리 확인 중';

        final etaMinutes = eta is num && eta.isFinite && eta >= 0
            ? eta.ceil()
            : null;

        final meetAt = DateTime.tryParse(
          _cachedAppointmentDetail?['meetAt']?.toString() ?? '',
        )?.toLocal();

        final secondsRemaining = meetAt?.difference(DateTime.now()).inSeconds;

        final minutesRemaining = secondsRemaining == null
            ? null
            : secondsRemaining > 0
            ? (secondsRemaining + 59) ~/ 60
            : 0;

        final lateRisk =
            etaMinutes != null &&
            minutesRemaining != null &&
            etaMinutes > minutesRemaining;

        String status = etaMinutes == null ? '위치 확인 중' : '$etaMinutes분 후';

        if (movement == 'ARRIVED') {
          status = '도착 완료';
        } else if (movement == 'SUSPECTED_NOT_DEPARTED') {
          status = '미출발 의심';
        } else if (movement == 'LATE' ||
            (minutesRemaining != null && minutesRemaining <= 0)) {
          status = '지각 중';
        } else if (lateRisk) {
          status = '$etaMinutes분 후 · 지각 위험';
        }

        if (!mounted) return;

        await _updateFriendData(
          id: 'participant-$id',
          name: name,
          position: LatLng(latitude.toDouble(), longitude.toDouble()),
          distanceText: distanceText,
          speedKmh: speed is num ? speed.toDouble() : 0,
          status: status,
          warning:
              lateRisk ||
              movement == 'SUSPECTED_NOT_DEPARTED' ||
              movement == 'LATE',
        );
      }
    } catch (error) {
      debugPrint('ETA WebSocket 메시지 처리 실패: $error');
    }
  }

  // 서버 체크인 결과를 최신 피그마 도착 화면에 연결
  final Set<String> _shownArrivalEvents = {};
  Map<String, dynamic>? _cachedAppointmentDetail;
  Map<String, dynamic>? _cachedAppointmentDetail;
  int? _activeAppointmentId;

  Timer? _appointmentClockTimer;

  String get _radarAppointmentTitle {
    final title = _cachedAppointmentDetail?['title']?.toString().trim();
    return title == null || title.isEmpty ? '약속 정보 확인 중' : title;
  }

  String _radarTimeLabel() {
    final meetAt = DateTime.tryParse(
      _cachedAppointmentDetail?['meetAt']?.toString() ?? '',
    )?.toLocal();

    if (meetAt == null) return '약속 시간 확인 중';

    final seconds = meetAt.difference(DateTime.now()).inSeconds;

    if (seconds > 0) {
      return '약속까지 ${(seconds + 59) ~/ 60}분';
    }

    final minutes = DateTime.now().difference(meetAt).inMinutes;
    return minutes == 0 ? '약속 시간이 되었어요' : '약속 시간 $minutes분 경과';
  }

  bool _appointmentPlaceMarkerAdded = false;
  bool _appointmentPlaceMarkerLoading = false;

  static const double _radarMarkerDiameter = 36;
  static const double _radarMarkerBorderWidth = 2.5;

  Future<void> _renderAppointmentPlaceMarker() async {
    if (_appointmentPlaceMarkerAdded || _appointmentPlaceMarkerLoading) {
      return;
    }

    final controller = _mapController;
    final detail = _cachedAppointmentDetail;

    if (!mounted || controller == null || detail == null) return;

    double? coordinate(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '');
    }

    final targetPlace = detail['targetPlace'];
    if (targetPlace is! Map) return;

    final latitude = coordinate(targetPlace['latitude']);
    final longitude = coordinate(targetPlace['longitude']);
    final placeName = targetPlace['name']?.toString().trim() ?? '';

    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        placeName.isEmpty) {
      debugPrint('ETA 레이더: 약속 장소명 또는 좌표가 없어 마커 생략');
      return;
    }

    _appointmentPlaceMarkerLoading = true;

    try {
      final icon = await KImage.fromWidget(
        SizedBox(
          width: 220,
          height: 100,
          child: Column(
            children: [
              Container(
                width: _radarMarkerDiameter,
                height: _radarMarkerDiameter,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1179AB), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.13),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFF1179AB),
                  size: 24,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxWidth: 210),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  placeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F3448),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Size(220, 100),
      );

      if (!mounted || !identical(_mapController, controller)) return;

      final position = LatLng(latitude, longitude);
      await controller.labelLayer.addPoi(
        position,
        id: 'eta-appointment-place',
        style: PoiStyle(anchor: const KPoint(0.5, 0.20), icon: icon),
      );

      _appointmentPlaceMarkerAdded = true;
      if (!mounted || !identical(_mapController, controller)) return;

      await controller.moveCamera(
        CameraUpdate.newCenterPosition(
          position,
          zoomLevel: _initialMapZoomLevel,
        ),
      );
      debugPrint('ETA 레이더: 약속 장소 마커 표시 완료 - $placeName');
    } catch (error) {
      debugPrint('ETA 레이더: 약속 장소 마커 표시 실패 - $error');
    } finally {
      _appointmentPlaceMarkerLoading = false;
    }
  }

  Future<void> _loadAppointmentDetail(int appointmentId) async {
    try {
      final detail = await EtaApiService.getAppointmentDetail(appointmentId);

      if (!mounted) return;

      setState(() {
        _cachedAppointmentDetail = detail;
      });
      debugPrint('ETA 체크인: 약속 상세 정보 미리 저장 완료');
      await _renderAppointmentPlaceMarker();

      final sample = _latestLocation;
      if (sample != null) _maybeShowArrivalChecking(sample);
    } catch (error) {
      debugPrint('ETA 체크인: 약속 상세 정보 사전 조회 실패: $error');
    }
  }

  Future<void> _openArrivalResult(
    Map<String, dynamic> event,
    int appointmentId,
  ) async {
    final rawStatus = event['arrivalStatus']?.toString();

    final ArrivalCheckinStatus? status = switch (rawStatus) {
      'EARLY' => ArrivalCheckinStatus.early,
      'ON_TIME' => ArrivalCheckinStatus.onTime,
      'LATE' => ArrivalCheckinStatus.late,
      _ => null,
    };

    final arrivedAt = DateTime.tryParse(event['arrivedAt']?.toString() ?? '');

    if (status == null || arrivedAt == null) {
      debugPrint('ETA 체크인: 도착 상태 또는 시간이 없어 화면 표시 생략');
      return;
    }

    final eventKey = '${event["participantId"]}:${event["arrivedAt"]}';

    if (!_shownArrivalEvents.add(eventKey)) return;

    try {
      final detail =
          _cachedAppointmentDetail ??
          await EtaApiService.getAppointmentDetail(appointmentId);

      if (!mounted) return;

      _cachedAppointmentDetail = detail;

      final meetAt = DateTime.tryParse(detail['meetAt']?.toString() ?? '');

      final place = detail['targetPlace'];
      final placeName = place is Map ? place['name']?.toString() : null;

      if (meetAt == null || placeName == null || placeName.trim().isEmpty) {
        debugPrint('ETA 체크인: 약속 시간 또는 장소 확인 실패');
        _shownArrivalEvents.remove(eventKey);
        return;
      }

      final nickname = event['nickname']?.toString() ?? '참가자';

      final lateMinutes = event['finalLateMinutes'];

      if (!mounted) return;

      // 본인 도착이 확정되면 S-51을 먼저 제거한다.
      final checkingRoute = _checkingRoute;

      if (_myArrivalConfirmed &&
          checkingRoute != null &&
          checkingRoute.isActive) {
        Navigator.of(context).removeRoute(checkingRoute);
        _checkingRoute = null;
        _checkingScreenOpen = false;
      }

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ArrivalCheckinScreen(
            status: status,
            nickname: nickname,
            placeName: placeName,
            meetAt: meetAt,
            arrivedAt: arrivedAt,
            finalLateMinutes: lateMinutes is num ? lateMinutes.toInt() : null,
            allArrived: event['allArrived'] == true,
          ),
        ),
      );
    } catch (error) {
      _shownArrivalEvents.remove(eventKey);
      debugPrint('ETA 체크인 화면 연결 실패: $error');
    }
  }

  // S-51 표시 판단용 거리 계산
  // 실제 도착 확정은 반드시 서버에서 처리한다.
  double? _distanceToMeetingPlace(LocationSample sample) {
    final place = _cachedAppointmentDetail?['targetPlace'];
    if (place is! Map) return null;

    final latitude = place['latitude'];
    final longitude = place['longitude'];

    if (latitude is! num || longitude is! num) return null;

    return Geolocator.distanceBetween(
      sample.latitude,
      sample.longitude,
      latitude.toDouble(),
      longitude.toDouble(),
    );
  }

  // S-51: 도착 확인 중 화면 표시
  bool _checkingScreenOpen = false;
  MaterialPageRoute<void>? _checkingRoute;
  final ValueNotifier<ArrivalCheckinStatus> _checkingStatus = ValueNotifier(
    ArrivalCheckinStatus.checking,
  );

  void _maybeShowArrivalChecking(LocationSample sample) {
    if (!mounted || _myArrivalConfirmed || _checkingScreenOpen) return;
    if (!_socketService.isConnected) return;

    final distance = _distanceToMeetingPlace(sample);
    if (distance == null || distance > 30) return;

    final detail = _cachedAppointmentDetail;
    if (detail == null) return;

    final meetAt = DateTime.tryParse(detail['meetAt']?.toString() ?? '');
    final place = detail['targetPlace'];
    final placeName = place is Map ? place['name']?.toString() : null;

    if (meetAt == null || placeName == null) return;

    _checkingScreenOpen = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _myArrivalConfirmed) {
        _checkingScreenOpen = false;
        return;
      }

      _checkingStatus.value = ArrivalCheckinStatus.checking;

      final route = MaterialPageRoute<void>(
        builder: (_) => ValueListenableBuilder<ArrivalCheckinStatus>(
          valueListenable: _checkingStatus,
          builder: (context, currentStatus, _) => ArrivalCheckinScreen(
            status: currentStatus,
            nickname: _myNickname,
            placeName: placeName,
            meetAt: meetAt,
          ),
        ),
      );

      _checkingRoute = route;

      unawaited(
        Navigator.of(context).push<void>(route).then((_) {
          if (identical(_checkingRoute, route)) {
            _checkingRoute = null;
          }
          _checkingScreenOpen = false;
        }),
      );
    });
  }

  void _radarNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openSettlementFromRadar() async {
    final id = _activeAppointmentId;

    if (id == null) {
      _radarNotice('약속 정보를 확인할 수 없어요.');
      return;
    }

    try {
      final settlement = await EtaApiService.getSettlement(id);
      if (!mounted) return;

      final participants = settlement['participants'];
      if (participants is! List || participants.isEmpty) {
        _radarNotice('아직 정산 결과가 준비되지 않았어요.');
        return;
      }

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => AppointmentResultScreen(appointmentId: id),
        ),
      );
    } catch (error) {
      debugPrint('레이더 정산 화면 이동 실패: $error');
      if (error.toString().contains('아직 정산할 수 없는 약속')) {
        _radarNotice('약속이 종료되면 정산을 확인할 수 있어요.');
      } else {
        _radarNotice('정산 정보를 확인하지 못했어요.');
      }
    }
  }

  Future<void> _startLocationTracking() async {
    await _locationTrackingService.start(
      onLocation: (sample) {
        if (!mounted || _myArrivalConfirmed) return;

        _maybeShowArrivalChecking(sample);

        final distance = _distanceToMeetingPlace(sample);
        if (distance != null) {
          debugPrint(
            'ETA 체크인: 약속 장소까지 거리 '
            '${distance.toStringAsFixed(1)}m',
          );
        }

        setState(() {
          _latestLocation = sample;
        });

        // 실제 GPS 좌표로 내 마커 갱신
        _updateMyLocationMarker(sample);

        debugPrint('==============================');
        debugPrint('📍 GPS 위치 수집 완료');
        debugPrint('위도: ${sample.latitude}');
        debugPrint('경도: ${sample.longitude}');
        debugPrint('속도: ${sample.speedKmh.toStringAsFixed(1)} km/h');
        debugPrint('정확도: ${sample.accuracy.toStringAsFixed(1)} m');
        debugPrint('시간: ${sample.collectedAt}');
        debugPrint('==============================');

        // 나중에 Socket.IO 전송
        _sendLocationToServer(sample);
      },
      onError: (error) {
        debugPrint('GPS 수집 실패: $error');
      },
    );
  }

  // ===============================================================
  // 나중에 백엔드 Socket.IO 연결
  // ===============================================================

  void _sendLocationToServer(LocationSample sample) {
    if (_myArrivalConfirmed || !_socketService.isConnected) return;

    _socketService.send({
      'type': 'location:update',
      'latitude': sample.latitude,
      'longitude': sample.longitude,
      'speedKmh': sample.speedKmh < 0 ? 0.0 : sample.speedKmh,
    });

    debugPrint('ETA WebSocket: GPS 위치 전송');
  }

  // ===============================================================
  // 친구 / 내 원형 마커 이미지
  // ===============================================================

  Future<KImage> _buildCircleMarkerIcon({
    required String initial,
    required Color backgroundColor,
    required Color textColor,
  }) async {
    return KImage.fromWidget(
      Container(
        width: _radarMarkerDiameter,
        height: _radarMarkerDiameter,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: _radarMarkerBorderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          initial,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const Size(_radarMarkerDiameter, _radarMarkerDiameter),
    );
  }

  // ===============================================================
  // 더미 친구 마커
  // 나중에 서버 친구 위치 데이터로 교체
  // ===============================================================

  Future<void> _renderFriendMarkers(KakaoMapController controller) async {
    for (final friend in _friends) {
      if (_friendPois.containsKey(friend.id)) {
        continue;
      }

      final icon = await _buildCircleMarkerIcon(
        initial: friend.initial,
        backgroundColor: _friendMarkerBackground,
        textColor: const Color(0xFF1F3448),
      );

      final poi = await controller.labelLayer.addPoi(
        friend.position,
        id: friend.id,
        style: PoiStyle(icon: icon),
      );

      _friendPois[friend.id] = poi;
    }
  }

  Future<void> _updateFriendData({
    required String id,
    String? name,
    LatLng? position,
    String? distanceText,
    double? speedKmh,
    String? status,
    bool? warning,
  }) async {
    final index = _friends.indexWhere((friend) => friend.id == id);

    if (index == -1) {
      if (!mounted || position == null || name == null || name.trim().isEmpty) {
        return;
      }

      final nickname = name.trim();
      final friend = FriendRadarData(
        id: id,
        name: nickname,
        initial: nickname.substring(0, 1),
        position: position,
        distanceText: distanceText ?? '거리 확인 중',
        speedKmh: speedKmh ?? 0,
        status: status ?? '위치 확인 중',
        warning: warning ?? false,
      );

      setState(() {
        _friends.add(friend);
      });

      final controller = _mapController;
      if (controller != null && !_friendPois.containsKey(id)) {
        final icon = await _buildCircleMarkerIcon(
          initial: friend.initial,
          backgroundColor: _friendMarkerBackground,
          textColor: const Color(0xFF1F3448),
        );

        if (!mounted || _friendPois.containsKey(id)) return;

        final poi = await controller.labelLayer.addPoi(
          position,
          id: id,
          style: PoiStyle(icon: icon),
        );

        _friendPois[id] = poi;
      }

      return;
    }

    final current = _friends[index];

    final updated = current.copyWith(
      position: position,
      distanceText: distanceText,
      speedKmh: speedKmh,
      status: status,
      warning: warning,
    );

    if (mounted) {
      setState(() {
        _friends[index] = updated;
      });
    }

    if (position != null) {
      final poi = _friendPois[id];

      if (poi != null) {
        await poi.move(position, 500);
      }
    }
  }

  // ===============================================================
  // 내 실제 GPS 위치 마커
  // ===============================================================

  Future<void> _updateMyLocationMarker(LocationSample sample) async {
    final controller = _mapController;

    if (controller == null) {
      return;
    }

    final position = LatLng(sample.latitude, sample.longitude);

    // 최초 한 번만 마커 생성
    if (_myPoi == null) {
      final icon = await _buildCircleMarkerIcon(
        initial: _myInitial,

        // 친구와 색상 반전
        backgroundColor: const Color(0xFF3875A1),
        textColor: Colors.white,
      );

      _myPoi = await controller.labelLayer.addPoi(
        position,
        id: 'my-location',
        style: PoiStyle(icon: icon),
      );
    } else {
      // 이후 GPS가 들어오면 기존 마커 이동
      await _myPoi!.move(position, 500);
    }

    // 약속 정보 없이 레이더를 열면 내 위치를 중심으로 표시한다.
    if (!_didMoveCameraToMyLocation && mounted) {
      final arguments = ModalRoute.of(context)?.settings.arguments;
      if (arguments is Map && arguments['appointmentId'] is int) return;

      _didMoveCameraToMyLocation = true;

      await controller.moveCamera(
        CameraUpdate.newCenterPosition(
          position,
          zoomLevel: _initialMapZoomLevel,
        ),
        animation: const CameraAnimation(700),
      );
    }
  }

  // ===============================================================
  // 바텀시트 드래그
  // ===============================================================

  void _onDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _sheetHeight = (_sheetHeight - details.delta.dy)
          .clamp(_collapsedHeight, _expandedHeight)
          .toDouble();
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    bool shouldExpand;

    if (velocity < -300) {
      shouldExpand = true;
    } else if (velocity > 300) {
      shouldExpand = false;
    } else {
      final middle = (_collapsedHeight + _expandedHeight) / 2;

      shouldExpand = _sheetHeight >= middle;
    }

    setState(() {
      _isDragging = false;

      _sheetHeight = shouldExpand ? _expandedHeight : _collapsedHeight;
    });
  }

  // ===============================================================
  // dispose
  // ===============================================================

  @override
  void dispose() {
    _appointmentClockTimer?.cancel();
    _locationTrackingService.dispose();
    unawaited(_socketService.dispose());
    _checkingStatus.dispose();

    super.dispose();
  }

  // ===============================================================
  // 화면
  // ===============================================================

  @override
  Widget build(BuildContext context) {
    const headerBottom = _radarHeaderHeight - 12;
    final meetAt = DateTime.tryParse(
      _cachedAppointmentDetail?['meetAt']?.toString() ?? '',
    );
    final hasMeetingTimePassed =
        meetAt != null && !DateTime.now().isBefore(meetAt);
    final mapOffset = hasMeetingTimePassed ? 0.0 : _collapsedHeight / 2;

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // =========================================================
            // 카카오 지도
            // =========================================================

            Positioned.fill(
              top: headerBottom - mapOffset,
              bottom: mapOffset,
              child: Container(
                color: const Color(0xFFEBF2F6),
                child: Stack(
                  children: [
                    KakaoMap(
                      option: const KakaoMapOption(
                        position: LatLng(37.4979, 127.0276),
                        zoomLevel: _initialMapZoomLevel,
                        mapType: MapType.normal,
                      ),
                      onMapReady: (KakaoMapController controller) async {
                        _mapController = controller;
                        _appointmentPlaceMarkerAdded = false;
                        await _renderAppointmentPlaceMarker();

                        debugPrint('카카오 지도 로딩 완료');

                        await _renderFriendMarkers(controller);

                        // GPS가 지도보다 먼저 잡혔다면
                        // 바로 내 위치 마커 표시
                        if (_latestLocation != null) {
                          await _updateMyLocationMarker(_latestLocation!);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            // =========================================================
            // 상단 헤더
            // =========================================================
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: headerBottom,
              child: Container(
                color: _background,
                padding: const EdgeInsets.fromLTRB(12, 8, 24, 12),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 48,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: _blue,
                        ),
                      ),
                    ),

                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _radarAppointmentTitle,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _navy,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            hasMeetingTimePassed
                                ? '약속 시간이 지났어요 · 위치 공유 중'
                                : '${_radarTimeLabel()} · 위치 공유 중',
                            style: TextStyle(
                              fontSize: 12,
                              color: hasMeetingTimePassed
                                  ? const Color(0xFFA23030)
                                  : _blue,
                            ),
                          ),
                        ],
                      ),
                    ),

                    TextButton(
                      onPressed: _openSettlementFromRadar,
                      child: const Text(
                        '지각 정산',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (!hasMeetingTimePassed)
              AnimatedPositioned(
                duration: _isDragging
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                left: 0,
                right: 0,
                bottom: _sheetHeight + _pokeButtonGap,
                height: _pokeButtonHeight,
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        debugPrint('찌르기 버튼 클릭');

                        // TODO:
                        // 나중에 poke:send 연결
                      },
                      child: Container(
                        width: 67,
                        height: _pokeButtonHeight,
                        decoration: BoxDecoration(
                          color: _pokeBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _pokeBorder, width: 1.5),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: Icon(
                                Icons.bolt_rounded,
                                size: 16,
                                color: _pokeBorder,
                              ),
                            ),
                            SizedBox(width: 2),
                            Text(
                              '찌르기',
                              style: TextStyle(
                                fontFamily: 'Noto Sans KR',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _pokeText,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // =========================================================
            // 친구 상태 바텀시트
            // =========================================================
            if (!hasMeetingTimePassed)
              AnimatedPositioned(
                duration: _isDragging
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                left: 0,
                right: 0,
                bottom: 0,
                height: _sheetHeight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // =================================================
                        // 친구 정보
                        // =================================================

                        Positioned(
                          top: 16,
                          left: 24,
                          right: 24,
                          bottom: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 손잡이
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onVerticalDragStart: _canExpandSheet
                                    ? _onDragStart
                                    : null,
                                onVerticalDragUpdate: _canExpandSheet
                                    ? _onDragUpdate
                                    : null,
                                onVerticalDragEnd: _canExpandSheet
                                    ? _onDragEnd
                                    : null,
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 20,
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Container(
                                      width: 40,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFB7C4CB),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const Row(
                                children: [
                                  Text(
                                    '친구들은 오는 중',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: _navy,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '방금 업데이트',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _gray,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 18),
                              Expanded(
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  physics: const ClampingScrollPhysics(),
                                  itemCount: _sheetProgress == 0
                                      ? _collapsedFriendCount
                                      : _friends.length,
                                  itemBuilder: (context, index) {
                                    final friend = _friends[index];

                                    return Padding(
                                      padding: EdgeInsets.only(
                                        left: 8,
                                        right: 8,
                                        bottom: index == _friends.length - 1
                                            ? 0
                                            : _friendGap,
                                      ),
                                      child: _FriendStatusRow(
                                        initial: friend.initial,
                                        name: friend.name,
                                        detail: friend.detail,
                                        status: friend.status,
                                        warning: friend.warning,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        // =================================================
                        // 펼침 상태 버튼
                        // =================================================
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// 친구 상태 Row
// =================================================================

class _FriendStatusRow extends StatelessWidget {
  static const double rowHeight = 50;

  const _FriendStatusRow({
    required this.initial,
    required this.name,
    required this.detail,
    required this.status,
    this.warning = false,
  });

  final String initial;
  final String name;
  final String detail;
  final String status;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: rowHeight,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFECF7FD),
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Color(0xFF3875A1),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1F3448),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF70879A),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status,
            maxLines: 1,
            style: TextStyle(
              color: warning
                  ? const Color(0xFF966236)
                  : const Color(0xFF3875A1),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
