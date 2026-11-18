import 'dart:async';

import 'package:flutter/material.dart';

import '../services/eta_api_service.dart';
import '../services/eta_websocket_service.dart';
import '../services/guest_identity_service.dart';

class AppointmentWaitingScreen extends StatefulWidget {
  const AppointmentWaitingScreen({super.key});

  @override
  State<AppointmentWaitingScreen> createState() =>
      _AppointmentWaitingScreenState();
}

class _AppointmentWaitingScreenState extends State<AppointmentWaitingScreen> {
  static const Color _navy = Color(0xFF19374C);
  static const Color _blue = Color(0xFF7DD3F5);
  static const Color _background = Color(0xFFF5FAFE);
  static const Color _subText = Color(0xFF7990A3);

  DateTime _sharingStartAt = DateTime.now();
  late final Timer _timer;

  int? _appointmentId;
  Map<String, dynamic>? _detail;
  List<Map<String, String>> _friends = [];

  bool _detailRequested = false;
  bool _isLoading = true;
  bool _isCheckingSocket = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_detailRequested) return;
    _detailRequested = true;

    final arguments = ModalRoute.of(context)?.settings.arguments;

    if (arguments is int) {
      _appointmentId = arguments;
      _fetchDetail();
    } else {
      _isLoading = false;
      _error = '약속 ID가 없어요. 홈에서 약속을 선택해 주세요.';
    }
  }

  Future<void> _fetchDetail() async {
    final id = _appointmentId;
    if (id == null) return;

    try {
      final detail = await EtaApiService.getAppointmentDetail(id);

      final startAt = DateTime.tryParse(
        detail['radarStartAt']?.toString() ?? '',
      );

      if (startAt == null) {
        throw const FormatException('레이더 시작 시간을 확인할 수 없어요.');
      }

      final participants = detail['participants'];
      if (participants is! List) {
        throw const FormatException('참가자 목록 형식이 올바르지 않아요.');
      }

      final friends = <Map<String, String>>[];

      for (final item in participants) {
        if (item is! Map) continue;

        final participant = Map<String, dynamic>.from(item);
        final nickname = participant['nickname']?.toString() ?? '참가자';

        final isMe = participant['participantId'] == detail['myParticipantId'];

        final isHost = participant['isHost'] == true;
        final isReady = participant['isReady'] == true;

        friends.add({
          'initial': nickname.isEmpty ? '?' : nickname[0],
          'name': isMe ? '나 ($nickname)' : nickname,
          'description': isHost ? '방장' : '참여 완료',
          'ready': isReady ? 'true' : 'false',
        });
      }

      if (!mounted) return;

      setState(() {
        _detail = detail;
        _sharingStartAt = startAt.toLocal();
        _friends = friends;
        _isLoading = false;
        _error = null;
      });

      debugPrint(
        'ETA 상세 조회 성공: appointmentId=$id, '
        'myParticipantId=${detail['myParticipantId']}',
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = '약속 정보를 불러오지 못했어요: $error';
      });
    }
  }

  String _meetingTimeLabel() {
    final value = _detail?['meetAt']?.toString();
    final parsed = DateTime.tryParse(value ?? '');

    if (parsed == null) return '시간 정보 없음';

    final date = parsed.toLocal();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final period = date.hour < 12 ? '오전' : '오후';
    final minute = date.minute.toString().padLeft(2, '0');

    return '${date.month}월 ${date.day}일 $period $hour:$minute';
  }

  String _placeName() {
    final place = _detail?['targetPlace'];
    if (place is Map) {
      return place['name']?.toString() ?? '장소 미정';
    }
    return '장소 미정';
  }

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _remainingTime {
    final difference = _sharingStartAt.difference(DateTime.now());
    final totalSeconds = difference.inSeconds < 0 ? 0 : difference.inSeconds;

    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _checkWebSocketConnection() async {
    if (_isCheckingSocket) return;

    final appointmentId = _appointmentId;
    final participantId = _detail?['myParticipantId'];

    if (appointmentId == null || participantId is! int) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('약속 또는 참가자 ID가 없어요.')));
      return;
    }

    setState(() => _isCheckingSocket = true);

    final socket = EtaWebSocketService();

    try {
      final guestUuid = await GuestIdentityService.getOrCreateUuid();

      await socket.connect(
        appointmentId: appointmentId,
        participantId: participantId,
        guestUuid: guestUuid,
        onConnected: () {
          debugPrint('ETA WebSocket 연결 성공');
        },
        onMessage: (message) {
          debugPrint('ETA WebSocket 수신: $message');
        },
        onError: (error) {
          debugPrint('ETA WebSocket 수신 오류: $error');
        },
        onDisconnected: () {
          debugPrint('ETA WebSocket 연결 종료');
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('WebSocket 연결 성공!')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('WebSocket 연결 실패: $error'),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      await socket.dispose();

      if (mounted) {
        setState(() => _isCheckingSocket = false);
      }
    }
  }

  void _openLiveRadar() {
    final appointmentId = _appointmentId;
    final participantId = _detail?['myParticipantId'];

    if (appointmentId == null || participantId is! int) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('약속 참가자 정보를 확인할 수 없어요.')));
      return;
    }

    if (DateTime.now().isBefore(_sharingStartAt)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('아직 레이더 시작 시간이 아니에요.')));
      return;
    }

    String nickname = '나';
    final participants = _detail?['participants'];

    if (participants is List) {
      for (final item in participants) {
        if (item is Map && item['participantId'] == participantId) {
          nickname = item['nickname']?.toString() ?? '나';
          break;
        }
      }
    }

    Navigator.pushNamed(
      context,
      '/live-map',
      arguments: {
        'appointmentId': appointmentId,
        'myParticipantId': participantId,
        'nickname': nickname,
      },
    );
  }

  Future<void> _showLeaveDialog() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '약속에서 나갈까요?',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '나가면 위치 공유가 중단되고\n'
                  '이 약속의 지각비 정산에서 제외돼요.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: _subText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 48),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext, false);
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          side: const BorderSide(color: Color(0xFFD7E8F4)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          '취소',
                          style: TextStyle(
                            color: _navy,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext, true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF25559),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          '나가기',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    if (shouldLeave == true) {
      // 현재는 더미 데이터 UI이므로 홈으로만 이동
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  Widget _buildFriend(Map<String, String> friend) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFE7F5FD),
            child: Text(
              friend['initial']!,
              style: const TextStyle(
                color: Color(0xFF1685B6),
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend['name']!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  friend['description']!,
                  style: const TextStyle(fontSize: 12, color: _subText),
                ),
              ],
            ),
          ),
          Text(
            friend['ready'] == 'true' ? '준비 완료' : '대기 중',
            style: TextStyle(
              color: Color(0xFF0788C0),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: _background,
        appBar: AppBar(title: const Text('약속 대기')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_appointmentId == null) {
                      Navigator.maybePop(context);
                      return;
                    }
                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });
                    _fetchDetail();
                  },
                  child: Text(_appointmentId == null ? '돌아가기' : '다시 시도'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            color: Color(0xFF1685B6),
                            size: 21,
                          ),
                          onPressed: () => Navigator.maybePop(context),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _detail?['title']?.toString() ?? '약속',
                                style: TextStyle(
                                  color: _navy,
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${_meetingTimeLabel()} · ${_placeName()}',
                                style: TextStyle(color: _subText, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final id = _appointmentId;
                            if (id == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('약속 정보를 확인할 수 없어요.'),
                                ),
                              );
                              return;
                            }
                            Navigator.pushNamed(
                              context,
                              '/appointment-detail',
                              arguments: id,
                            );
                          },
                          child: const Text(
                            '상세',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0788C0),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // 카운트다운 영역
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 22,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 190,
                            height: 190,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFE8F6FE),
                              border: Border.all(color: _blue, width: 5),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  '위치 공유 시작까지',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _subText,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _remainingTime,
                                  style: const TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                    color: _navy,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  '분 : 초',
                                  style: TextStyle(
                                    color: _subText,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            '약속 30분 전부터 위치 공유가 시작돼요',
                            style: TextStyle(
                              color: Color(0xFF0788C0),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 26),

                    Text(
                      '함께할 친구 ${_friends.length}명',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: _navy,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: _friends.map(_buildFriend).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isCheckingSocket
                      ? null
                      : _checkWebSocketConnection,
                  child: Text(
                    _isCheckingSocket ? '연결 확인 중...' : 'WebSocket 연결 테스트',
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _openLiveRadar,
                  child: const Text('실시간 레이더 입장'),
                ),
              ),
            ),

            // 약속 나가기 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _showLeaveDialog,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFD7E8F4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: const Text(
                    '약속 나가기',
                    style: TextStyle(
                      fontSize: 17,
                      color: _navy,
                      fontWeight: FontWeight.bold,
                    ),
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
