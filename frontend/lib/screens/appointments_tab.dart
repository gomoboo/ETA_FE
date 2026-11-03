import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/eta_api_service.dart';
import '../services/guest_identity_service.dart';

class AppointmentsTab extends StatefulWidget {
  const AppointmentsTab({super.key});

  @override
  State<AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends State<AppointmentsTab> {
  static const navy = Color(0xFF18354A);
  static const blue = Color(0xFF7DD3F7);
  static const accent = Color(0xFF1685B5);
  static const gray = Color(0xFF718696);
  static const pale = Color(0xFFEAF7FE);
  static const background = Color(0xFFF7FBFF);

  final codeController = TextEditingController();

  late Future<Map<String, dynamic>> appointmentsFuture;

  bool checkingCode = false;
  bool joining = false;
  String? codeError;

  @override
  void initState() {
    super.initState();
    appointmentsFuture = EtaApiService.getHomeAppointments();
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  void refresh() {
    setState(() {
      appointmentsFuture = EtaApiService.getHomeAppointments();
    });
  }

  int? toId(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  String formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();

    if (date == null) return '시간 확인 필요';

    final period = date.hour < 12 ? '오전' : '오후';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;

    return '${date.month}월 ${date.day}일 '
        '$period $hour:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> openAppointment(
    Map<String, dynamic> item, {
    bool liveMap = false,
  }) async {
    final id = toId(item['appointmentId']);

    if (id == null) return;

    try {
      if (liveMap && item['isLocationSharingActive'] == true) {
        final detail = await EtaApiService.getAppointmentDetail(id);

        if (!mounted) return;

        final participantId = toId(detail['myParticipantId']);

        if (participantId != null) {
          String nickname = '나';
          final participants = detail['participants'];

          if (participants is List) {
            for (final participant in participants) {
              if (participant is Map &&
                  participant['participantId'] == participantId) {
                nickname = participant['nickname']?.toString() ?? '나';
                break;
              }
            }
          }

          await Navigator.pushNamed(
            context,
            '/live-map',
            arguments: {
              'appointmentId': id,
              'myParticipantId': participantId,
              'nickname': nickname,
            },
          );
        } else {
          await Navigator.pushNamed(
            context,
            '/appointment-waiting',
            arguments: id,
          );
        }
      } else {
        await Navigator.pushNamed(
          context,
          '/appointment-waiting',
          arguments: id,
        );
      }

      if (mounted) refresh();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('약속 화면을 열지 못했어요.')));
    }
  }

  Future<void> checkCode() async {
    if (checkingCode || joining) return;

    final code = codeController.text.trim().toUpperCase();

    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(code)) {
      setState(() {
        codeError = '6자리 초대 코드를 입력해 주세요.';
      });
      return;
    }

    setState(() {
      checkingCode = true;
      codeError = null;
    });

    try {
      final preview = await EtaApiService.previewInvite(code);

      if (!mounted) return;

      setState(() {
        checkingCode = false;
      });

      // S-60 디자인 확인 전 임시 참여 확인 창
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('초대받은 약속'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preview['title']?.toString() ?? '약속',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text('일시: ${formatDate(preview['meetAt'])}'),
                const SizedBox(height: 8),
                Text('장소: ${preview['targetPlaceName'] ?? '장소 확인 필요'}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('참여하기'),
              ),
            ],
          );
        },
      );

      if (!mounted || confirm != true) return;

      setState(() {
        joining = true;
      });

      final nickname = await GuestIdentityService.getNickname();

      final joined = await EtaApiService.joinAppointment(
        code,
        nickname: nickname,
      );

      if (!mounted) return;

      final id = toId(joined['appointmentId'] ?? preview['appointmentId']);

      if (id == null) {
        setState(() {
          codeError =
              '참여 결과의 약속 ID를 확인하지 못했어요. '
              '약속 목록을 새로고침해 주세요.';
        });
        refresh();
        return;
      }

      codeController.clear();

      await Navigator.pushNamed(context, '/appointment-waiting', arguments: id);

      if (mounted) refresh();
    } catch (error) {
      if (!mounted) return;

      final message = error.toString().toLowerCase();

      setState(() {
        codeError =
            message.contains('404') ||
                message.contains('not_found') ||
                message.contains('not found')
            ? '일치하는 약속이 없어요. 코드를 확인해 주세요.'
            : '약속 정보를 확인하지 못했어요. 다시 시도해 주세요.';
      });
    } finally {
      if (mounted) {
        setState(() {
          checkingCode = false;
          joining = false;
        });
      }
    }
  }

  Widget inviteCard() {
    final enabled =
        codeController.text.length == 6 && !checkingCode && !joining;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '초대 코드로 참여',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: navy,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: TextField(
                    controller: codeController,
                    enabled: !checkingCode && !joining,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      hintText: '6자리 코드',
                      hintStyle: const TextStyle(color: gray, fontSize: 14),
                      filled: true,
                      fillColor: background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: const BorderSide(color: Color(0xFFE5F2FA)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: const BorderSide(color: accent),
                      ),
                    ),
                    onChanged: (_) {
                      setState(() {
                        codeError = null;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                width: 88,
                child: ElevatedButton(
                  onPressed: enabled ? checkCode : null,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: blue,
                    disabledBackgroundColor: const Color(0xFFB8E9FA),
                    foregroundColor: navy,
                    disabledForegroundColor: gray,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: Text(checkingCode || joining ? '확인 중' : '확인'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            codeError ??
                (checkingCode || joining
                    ? '약속 정보를 확인하고 있어요.'
                    : '친구에게 받은 6자리 코드를 입력해 주세요.'),
            style: TextStyle(
              fontSize: 11,
              color: codeError == null ? gray : accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: gray,
        ),
      ),
    );
  }

  Widget activeCard(Map<String, dynamic> item) {
    final count = toId(item['participantCount']) ?? 0;
    final friends = count > 0 ? count - 1 : 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: pale,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item['title']?.toString() ?? '약속',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: navy,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "${formatDate(item['meetAt'])} · "
            "${item['targetPlaceName'] ?? ''}",
            style: const TextStyle(fontSize: 12, color: gray),
          ),
          const SizedBox(height: 18),
          Text(
            item['isLocationSharingActive'] == true ? '위치 공유 중' : '위치 공유 대기 중',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            friends == 0 ? '아직 참여한 친구가 없어요' : '친구 $friends명이 함께하고 있어요',
            style: const TextStyle(fontSize: 12, color: accent),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => openAppointment(item, liveMap: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: blue,
                foregroundColor: navy,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '실시간 위치 보기',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget upcomingCard(Map<String, dynamic> item) {
    final count = toId(item['participantCount']) ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => openAppointment(item),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title']?.toString() ?? '약속',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  "${formatDate(item['meetAt'])} · 참가자 $count명",
                  style: const TextStyle(fontSize: 12, color: gray),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 30, 18, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: pale,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.remove, color: accent, size: 27),
          ),
          const SizedBox(height: 20),
          const Text(
            '아직 참여한 약속이 없어요',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: navy,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '위에서 초대 코드를 입력하거나\n'
            '새 약속을 만들어 친구들을 초대해 보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.5, color: gray),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () async {
                await Navigator.pushNamed(context, '/appointment-create');
                if (mounted) refresh();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: blue,
                foregroundColor: navy,
                elevation: 0,
              ),
              child: const Text('새 약속 만들기'),
            ),
          ),
        ],
      ),
    );
  }

  Widget errorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 30, 18, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: pale,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              '!',
              style: TextStyle(
                color: accent,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '약속 목록을 불러오지 못했어요',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: navy,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '네트워크 연결이 원활하지 않아요.\n'
            '연결 상태를 확인하고 다시 시도해 주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.5, color: gray),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: refresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: blue,
                foregroundColor: navy,
                elevation: 0,
              ),
              child: const Text('다시 시도'),
            ),
          ),
        ],
      ),
    );
  }

  Widget loadingState() {
    Widget bar(double width) => Container(
      height: 15,
      width: width,
      decoration: BoxDecoration(
        color: pale,
        borderRadius: BorderRadius.circular(6),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            '•••  약속 목록을 불러오는 중이에요',
            style: TextStyle(fontSize: 11, color: gray),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(140),
              const SizedBox(height: 14),
              bar(210),
              const SizedBox(height: 14),
              bar(95),
              const SizedBox(height: 20),
              bar(double.infinity),
            ],
          ),
        ),
        const SizedBox(height: 28),
        sectionTitle('예정된 약속'),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [bar(120), const SizedBox(height: 14), bar(200)],
          ),
        ),
      ],
    );
  }

  Widget appointmentList() {
    return FutureBuilder<Map<String, dynamic>>(
      future: appointmentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return loadingState();
        }

        if (snapshot.hasError) {
          return errorState();
        }

        final data = snapshot.data ?? {};

        final active = (data['activeAppointments'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();

        final upcoming = (data['upcomingAppointments'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();

        if (active.isEmpty && upcoming.isEmpty) {
          return emptyState();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (active.isNotEmpty) ...[
              sectionTitle('진행 중인 약속'),
              for (final item in active) activeCard(item),
              const SizedBox(height: 22),
            ],
            sectionTitle('예정된 약속'),
            if (upcoming.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '예정된 약속이 없어요.',
                  style: TextStyle(fontSize: 12, color: gray),
                ),
              ),
            for (final item in upcoming) upcomingCard(item),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '약속',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: navy,
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 34),
              const Text(
                '나의 약속',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: navy,
                ),
              ),
              const SizedBox(height: 22),
              inviteCard(),
              const SizedBox(height: 28),
              appointmentList(),
            ],
          ),
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: FloatingActionButton(
            heroTag: 'appointment-create-tab',
            elevation: 0,
            shape: const CircleBorder(),
            backgroundColor: blue,
            foregroundColor: navy,
            onPressed: () async {
              await Navigator.pushNamed(context, '/appointment-create');
              if (mounted) refresh();
            },
            child: const Icon(Icons.add, size: 30),
          ),
        ),
      ],
    );
  }
}
