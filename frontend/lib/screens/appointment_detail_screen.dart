import 'package:flutter/material.dart';

import '../services/eta_api_service.dart';
import 'friend_invite_screen.dart';
import 'appointment_result_screen.dart';

class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({super.key});

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  static const navy = Color(0xFF18354A);
  static const accent = Color(0xFF1685B5);
  static const blue = Color(0xFF7DD3F7);
  static const gray = Color(0xFF718696);
  static const pale = Color(0xFFEAF7FE);
  static const background = Color(0xFFF7FBFF);

  Future<Map<String, dynamic>>? detailFuture;
  int? appointmentId;
  bool initialized = false;
  bool _isLeaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    initialized = true;

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is int) {
      appointmentId = args;
      detailFuture = EtaApiService.getAppointmentDetail(args);
    }
  }

  void reload() {
    final id = appointmentId;
    if (id == null) return;

    setState(() {
      detailFuture = EtaApiService.getAppointmentDetail(id);
    });
  }

  DateTime? parseDate(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  }

  String dateText(DateTime? date) {
    if (date == null) return '날짜 확인 필요';

    const weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];

    return '${date.month}월 ${date.day}일 '
        '${weekdays[date.weekday - 1]}';
  }

  String timeText(DateTime? date) {
    if (date == null) return '시간 확인 필요';

    final period = date.hour < 12 ? '오전' : '오후';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');

    return '$period $hour:$minute';
  }

  String penaltyText(dynamic value) {
    if (value is! Map) return '규칙 정보 없음';

    final type = value['type']?.toString();
    final content = value['content']?.toString();
    final fine = value['finePerMinute'];

    if (type == 'FEE') {
      return '지각 1분당 ${fine ?? 0}원';
    }

    if (content != null && content.trim().isNotEmpty) {
      return content;
    }

    return '지각비 · 벌칙 없음';
  }

  void showPendingNotice(String feature) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$feature 기능은 다음 단계에서 연결할게요.')));
  }

  Future<void> _confirmLeaveAppointment() async {
    final id = appointmentId;
    if (id == null || _isLeaving || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0x660D2535),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 34, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '약속에서 나갈까요?',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '나가면 위치 공유가 중단되고\n'
                  '이 약속의 지각비 정산에서 제외돼요.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: gray,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop(false);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: navy,
                            side: const BorderSide(color: Color(0xFFD7E9F4)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            '취소',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop(true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF05458),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            '나가기',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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

    if (!mounted || confirmed != true) return;

    setState(() {
      _isLeaving = true;
    });

    try {
      await EtaApiService.leaveAppointment(id);

      if (!mounted) return;

      // 이전 약속 상세 화면으로 돌아갈 수 없도록
      // 홈으로 이동하면서 기존 화면 스택 정리
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (error) {
      debugPrint('약속 나가기 실패: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('약속에서 나가지 못했어요. 연결을 확인하고 다시 시도해 주세요.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLeaving = false;
        });
      }
    }
  }

  Widget detailContent(Map<String, dynamic> detail) {
    final date = parseDate(detail['meetAt']);
    final radarStart = parseDate(detail['radarStartAt']);

    final place = detail['targetPlace'];
    final placeName = place is Map
        ? place['name']?.toString() ?? '장소 확인 필요'
        : '장소 확인 필요';

    final rawParticipants = detail['participants'];
    final participants = rawParticipants is List
        ? rawParticipants.whereType<Map>().toList()
        : <Map>[];

    final names = participants
        .map((p) => p['nickname']?.toString() ?? '참가자')
        .join(' · ');

    String locationDescription = '위치 공유 시작 시간 확인 필요';

    if (date != null && radarStart != null) {
      final minutes = date.difference(radarStart).inMinutes;

      if (minutes > 0) {
        final before = minutes == 60 ? '1시간' : '$minutes분';

        locationDescription = '약속 $before 전부터 종료 시점까지 위치를 공유해요.';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          detail['title']?.toString() ?? '약속',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: navy,
          ),
        ),

        const SizedBox(height: 22),

        // 만나는 날짜 · 시간 · 장소
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '만나는 날짜와 시간',
                style: TextStyle(fontSize: 13, color: gray),
              ),

              const SizedBox(height: 16),

              Text(
                dateText(date),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: navy,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                timeText(date),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),

              const SizedBox(height: 24),

              const Divider(height: 1, thickness: 1, color: Color(0xFFE1F0F8)),

              const SizedBox(height: 24),

              const Text('만나는 장소', style: TextStyle(fontSize: 13, color: gray)),

              const SizedBox(height: 14),

              Text(
                placeName,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: navy,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 참가자 및 지각 규칙
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
          decoration: BoxDecoration(
            color: pale,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '참가자 ${participants.length}명',
                style: const TextStyle(fontSize: 13, color: gray),
              ),

              const SizedBox(height: 12),

              Text(
                names.isEmpty ? '참가자 정보가 없어요' : names,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: navy,
                ),
              ),

              const SizedBox(height: 26),

              const Text('지각 규칙', style: TextStyle(fontSize: 13, color: gray)),

              const SizedBox(height: 12),

              Text(
                penaltyText(detail['penalty']),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        Text(
          locationDescription,
          style: const TextStyle(fontSize: 13, color: gray),
        ),
      ],
    );
  }

  Future<void> _openFriendInvite() async {
    final future = detailFuture;
    if (future == null) return;

    try {
      final data = await future;
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => FriendInviteScreen(detail: data)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('초대 정보를 불러오지 못했어요.')));
    }
  }

  Widget _bottomActionsByStatus() {
    final future = detailFuture;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final detail = snapshot.data!;
        final status = (detail['status'] ?? detail['appointmentStatus'])
            ?.toString()
            .toUpperCase();

        if (status == 'CANCELLED') {
          return const SizedBox.shrink();
        }

        if (status != 'COMPLETED') {
          return bottomActions();
        }

        final id = appointmentId;
        if (id == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => AppointmentResultScreen(appointmentId: id),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: blue,
                foregroundColor: navy,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                '약속 결과 보기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget bottomActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _openFriendInvite,
              style: ElevatedButton.styleFrom(
                backgroundColor: blue,
                foregroundColor: navy,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                '친구 초대',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isLeaving ? null : _confirmLeaveAppointment,
            child: const Text(
              '약속 나가기',
              style: TextStyle(color: navy, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: navy,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          '약속 상세',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: detailFuture == null
                  ? const Center(child: Text('약속 ID를 확인할 수 없어요.'))
                  : FutureBuilder<Map<String, dynamic>>(
                      future: detailFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('약속 정보를 불러오지 못했어요.'),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: reload,
                                  child: const Text('다시 시도'),
                                ),
                              ],
                            ),
                          );
                        }

                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                          child: detailContent(snapshot.data ?? {}),
                        );
                      },
                    ),
            ),
            _bottomActionsByStatus(),
          ],
        ),
      ),
    );
  }
}
