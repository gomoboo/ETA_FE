import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../services/location_tracking_service.dart';


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

  static const double _collapsedHeight = 301;
  static const double _expandedHeight = 391;

  double _sheetHeight = _collapsedHeight;
  bool _isDragging = false;

  // ===============================================================
  // 색상
  // ===============================================================

  static const Color _background = Color(0xFFF7FBFF);
  static const Color _navy = Color(0xFF18354A);
  static const Color _gray = Color(0xFF718696);
  static const Color _blue = Color(0xFF1685B5);
  static const Color _buttonBlue = Color(0xFF7DD3F7);

  // 친구 마커 배경색
  static const Color _friendMarkerBackground =
      Color(0xFFE1F6FF);

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

  double get _sheetProgress {
    return ((_sheetHeight - _collapsedHeight) /
            (_expandedHeight - _collapsedHeight))
        .clamp(0.0, 1.0);
  }

  double get _buttonProgress {
    return ((_sheetHeight - 345) /
            (_expandedHeight - 345))
        .clamp(0.0, 1.0);
  }

  double get _friendGap {
    return 12 + (2 * _sheetProgress);
  }

  // ===============================================================
  // 초기화
  // ===============================================================

  @override
  void initState() {
    super.initState();

    _startLocationTracking();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didReadNickname) {
      return;
    }

    final arguments =
        ModalRoute.of(context)?.settings.arguments;

    if (arguments is String &&
        arguments.trim().isNotEmpty) {
      _myNickname = arguments.trim();
    }

    _didReadNickname = true;
  }

  // ===============================================================
  // GPS 10초 주기 수집
  // ===============================================================

  Future<void> _startLocationTracking() async {
    await _locationTrackingService.start(
      onLocation: (sample) {
        if (!mounted) return;

        setState(() {
          _latestLocation = sample;
        });

        // 실제 GPS 좌표로 내 마커 갱신
        _updateMyLocationMarker(sample);

        debugPrint('==============================');
        debugPrint('📍 GPS 위치 수집 완료');
        debugPrint('위도: ${sample.latitude}');
        debugPrint('경도: ${sample.longitude}');
        debugPrint(
          '속도: ${sample.speedKmh.toStringAsFixed(1)} km/h',
        );
        debugPrint(
          '정확도: ${sample.accuracy.toStringAsFixed(1)} m',
        );
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

  void _sendLocationToServer(
    LocationSample sample,
  ) {
    // TODO: 백엔드 연결 후 location:update 전송
    //
    // socket.emit('location:update', {
    //   'roomId': roomId,
    //   'latitude': sample.latitude,
    //   'longitude': sample.longitude,
    //   'speedKmh': sample.speedKmh,
    // });
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
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          initial,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const Size(48, 48),
    );
  }

  // ===============================================================
  // 더미 친구 마커
  // 나중에 서버 친구 위치 데이터로 교체
  // ===============================================================

  Future<void> _renderFriendMarkers(
    KakaoMapController controller,
  ) async {
    for (final friend in _friends) {
      if (_friendPois.containsKey(friend.id)) {
        continue;
      }

      final icon = await _buildCircleMarkerIcon(
        initial: friend.initial,
        backgroundColor: _friendMarkerBackground,
        textColor: _blue,
      );

      final poi = await controller.labelLayer.addPoi(
        friend.position,
        id: friend.id,
        style: PoiStyle(
          icon: icon,
        ),
      );

      _friendPois[friend.id] = poi;
    }
  }

  Future<void> _updateFriendData({
    required String id,
    LatLng? position,
    String? distanceText,
    double? speedKmh,
    String? status,
    bool? warning,
  }) async {
    final index = _friends.indexWhere(
      (friend) => friend.id == id,
    );

    if (index == -1) {
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
        await poi.move(
          position,
          500,
        );
      }
    }
  }

  // ===============================================================
  // 내 실제 GPS 위치 마커
  // ===============================================================

  Future<void> _updateMyLocationMarker(
    LocationSample sample,
  ) async {
    final controller = _mapController;

    if (controller == null) {
      return;
    }

    final position = LatLng(
      sample.latitude,
      sample.longitude,
    );

    // 최초 한 번만 마커 생성
    if (_myPoi == null) {
      final icon =
          await _buildCircleMarkerIcon(
        initial: _myInitial,

        // 친구와 색상 반전
        backgroundColor: _blue,
        textColor: _friendMarkerBackground,
      );

      _myPoi =
          await controller.labelLayer.addPoi(
        position,
        id: 'my-location',
        style: PoiStyle(
          icon: icon,
        ),
      );
    } else {
      // 이후 GPS가 들어오면 기존 마커 이동
      await _myPoi!.move(
        position,
        500,
      );
    }

    // 지도 첫 진입 시 내 위치로 한 번 이동
    if (!_didMoveCameraToMyLocation) {
      _didMoveCameraToMyLocation = true;

      await controller.moveCamera(
        CameraUpdate.newCenterPosition(
          position,
          zoomLevel: 16,
        ),
        animation:
            const CameraAnimation(700),
      );
    }
  }

  // ===============================================================
  // 바텀시트 드래그
  // ===============================================================

  void _onDragStart(
    DragStartDetails details,
  ) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onDragUpdate(
    DragUpdateDetails details,
  ) {
    setState(() {
      _sheetHeight =
          (_sheetHeight - details.delta.dy)
              .clamp(
                _collapsedHeight,
                _expandedHeight,
              )
              .toDouble();
    });
  }

  void _onDragEnd(
    DragEndDetails details,
  ) {
    final velocity =
        details.primaryVelocity ?? 0;

    bool shouldExpand;

    if (velocity < -300) {
      shouldExpand = true;
    } else if (velocity > 300) {
      shouldExpand = false;
    } else {
      final middle =
          (_collapsedHeight +
                  _expandedHeight) /
              2;

      shouldExpand =
          _sheetHeight >= middle;
    }

    setState(() {
      _isDragging = false;

      _sheetHeight = shouldExpand
          ? _expandedHeight
          : _collapsedHeight;
    });
  }

  // ===============================================================
  // dispose
  // ===============================================================

  @override
  void dispose() {
    _locationTrackingService.dispose();

    super.dispose();
  }

  // ===============================================================
  // 화면
  // ===============================================================

  @override
  Widget build(BuildContext context) {
    final buttonProgress =
        _buttonProgress;

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
              top: 118,
              child: Container(
                color:
                    const Color(0xFFEBF2F6),
                child: Stack(
                  children: [
                    KakaoMap(
                      option:
                          const KakaoMapOption(
                        position: LatLng(
                          37.4979,
                          127.0276,
                        ),
                        zoomLevel: 16,
                        mapType:
                            MapType.normal,
                      ),
                      onMapReady:
                          (KakaoMapController
                              controller) async {
                        _mapController =
                            controller;

                        debugPrint(
                          '카카오 지도 로딩 완료',
                        );

                        await _renderFriendMarkers(controller);

                        // GPS가 지도보다 먼저 잡혔다면
                        // 바로 내 위치 마커 표시
                        if (_latestLocation !=
                            null) {
                          await _updateMyLocationMarker(
                            _latestLocation!,
                          );
                        }
                      },
                    ),

                    // =================================================
                    // 찌르기 버튼
                    // =================================================

                    Positioned(
                      left: 147,
                      top: 384,
                      child: Material(
                        color:
                            Colors.transparent,
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                          onTap: () {
                            debugPrint(
                              '찌르기 버튼 클릭',
                            );

                            // TODO:
                            // 나중에 poke:send 연결
                          },
                          child: Container(
                            width: 67,
                            height: 32,
                            decoration:
                                BoxDecoration(
                              color:
                                  _pokeBackground,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                16,
                              ),
                              border:
                                  Border.all(
                                color:
                                    _pokeBorder,
                                width: 1.5,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .center,
                              mainAxisSize:
                                  MainAxisSize
                                      .min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: Icon(
                                    Icons
                                        .bolt_rounded,
                                    size: 16,
                                    color:
                                        _pokeBorder,
                                  ),
                                ),
                                SizedBox(
                                  width: 2,
                                ),
                                Text(
                                  '찌르기',
                                  style:
                                      TextStyle(
                                    fontFamily:
                                        'Noto Sans KR',
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight
                                            .w700,
                                    color:
                                        _pokeText,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
              height: 118,
              child: Container(
                color: _background,
                padding:
                    const EdgeInsets.fromLTRB(
                  24,
                  20,
                  24,
                  12,
                ),
                child: Row(
                  children: [
                    IconButton(
                      padding:
                          EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(),
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pop();
                      },
                      icon: const Icon(
                        Icons
                            .arrow_back_ios_new_rounded,
                        size: 20,
                        color: _blue,
                      ),
                    ),

                    const SizedBox(
                      width: 14,
                    ),

                    const Expanded(
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .center,
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            '강남역 맛집 탐방',
                            style:
                                TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight
                                      .w700,
                              color: _navy,
                            ),
                          ),
                          SizedBox(
                            height: 4,
                          ),
                          Text(
                            '약속까지 12분 · 위치 공유 중',
                            style:
                                TextStyle(
                              fontSize: 12,
                              color: _blue,
                            ),
                          ),
                        ],
                      ),
                    ),

                    TextButton(
                      onPressed: () {
                        // TODO:
                        // 정산 화면 연결
                      },
                      child: const Text(
                        '정산',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              FontWeight
                                  .w700,
                          color: _blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // =========================================================
            // 친구 상태 바텀시트
            // =========================================================

            AnimatedPositioned(
              duration: _isDragging
                  ? Duration.zero
                  : const Duration(
                      milliseconds: 220,
                    ),
              curve: Curves.easeOut,
              left: 0,
              right: 0,
              bottom: 0,
              height: _sheetHeight,
              child: GestureDetector(
                behavior:
                    HitTestBehavior.opaque,
                onVerticalDragStart:
                    _onDragStart,
                onVerticalDragUpdate:
                    _onDragUpdate,
                onVerticalDragEnd:
                    _onDragEnd,
                child: Container(
                  decoration:
                      BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        const BorderRadius
                            .only(
                      topLeft:
                          Radius.circular(
                        28,
                      ),
                      topRight:
                          Radius.circular(
                        28,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(
                          alpha: 0.12,
                        ),
                        blurRadius: 18,
                        offset:
                            const Offset(
                          0,
                          -4,
                        ),
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
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            // 손잡이
                            Center(
                              child:
                                  Container(
                                width: 40,
                                height: 4,
                                decoration:
                                    BoxDecoration(
                                  color:
                                      const Color(
                                    0xFFB7C4CB,
                                  ),
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    10,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(
                              height: 16,
                            ),

                            const Row(
                              children: [
                                Text(
                                  '친구들은 오는 중',
                                  style:
                                      TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                        FontWeight
                                            .w700,
                                    color:
                                        _navy,
                                  ),
                                ),
                                SizedBox(
                                  width: 8,
                                ),
                                Text(
                                  '방금 업데이트',
                                  style:
                                      TextStyle(
                                    fontSize: 12,
                                    color:
                                        _gray,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height: 18,
                            ),

                            ...List.generate(
                              _friends.length,
                              (index) {
                                final friend = _friends[index];

                                return Padding(
                                  padding: EdgeInsets.only(
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

                            SizedBox(
                              height:
                                  _friendGap,
                            ),

                            const _FriendStatusRow(
                              initial: '서',
                              name: '서연',
                              detail:
                                  '450m · 5km/h',
                              status:
                                  '8분 후',
                            ),

                            SizedBox(
                              height:
                                  _friendGap,
                            ),

                            const _FriendStatusRow(
                              initial: '민',
                              name: '민수',
                              detail:
                                  '2.3km · 0km/h',
                              status:
                                  '침대 의심',
                              warning: true,
                            ),
                          ],
                        ),
                      ),

                      // =================================================
                      // 펼침 상태 버튼
                      // =================================================

                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: 20,
                        child: IgnorePointer(
                          ignoring:
                              buttonProgress <
                                  0.95,
                          child:
                              Transform.translate(
                            offset: Offset(
                              0,
                              8 *
                                  (1 -
                                      buttonProgress),
                            ),
                            child: Opacity(
                              opacity:
                                  buttonProgress,
                              child:
                                  SizedBox(
                                height: 52,
                                child:
                                    ElevatedButton(
                                  onPressed:
                                      buttonProgress >=
                                              0.95
                                          ? () {
                                              // TODO:
                                              // 내 도착 상태 확인
                                            }
                                          : null,
                                  style:
                                      ElevatedButton
                                          .styleFrom(
                                    backgroundColor:
                                        _buttonBlue,
                                    disabledBackgroundColor:
                                        _buttonBlue,
                                    foregroundColor:
                                        _navy,
                                    disabledForegroundColor:
                                        _navy,
                                    elevation: 0,
                                    shape:
                                        RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        14,
                                      ),
                                    ),
                                  ),
                                  child:
                                      const Text(
                                    '내 도착 상태 확인',
                                    style:
                                        TextStyle(
                                      fontSize:
                                          15,
                                      fontWeight:
                                          FontWeight
                                              .w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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

class _FriendStatusRow
    extends StatelessWidget {
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
      height: 44,
      child: Row(
        children: [
          // 친구 아이콘
          Container(
            width: 44,
            height: 44,
            alignment:
                Alignment.center,
            decoration:
                const BoxDecoration(
              color:
                  Color(0xFFEAF7FE),
              shape:
                  BoxShape.circle,
            ),
            child: Text(
              initial,
              style:
                  const TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w700,
                color:
                    Color(0xFF1685B5),
              ),
            ),
          ),

          const SizedBox(
            width: 14,
          ),

          // 이름 + 거리/속도
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment
                      .center,
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  name,
                  style:
                      const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight
                            .w700,
                    color:
                        Color(
                      0xFF18354A,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  detail,
                  style:
                      const TextStyle(
                    fontSize: 12,
                    color:
                        Color(
                      0xFF718696,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 예상 도착 / 경고
          Text(
            status,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  FontWeight.w700,
              color: warning
                  ? const Color(
                      0xFFD46B2B,
                    )
                  : const Color(
                      0xFF1685B5,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}