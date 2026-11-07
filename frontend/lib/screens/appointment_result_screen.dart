import 'package:flutter/material.dart';

import '../services/eta_api_service.dart';

/// 피그마 S-53~55 / UI 설계서 S-56~58 지각 정산 화면.
/// 정산 상태: 설계서 S-59(로딩), S-60(미정산), S-61(전원 도착), S-62(오류).
class AppointmentResultScreen extends StatefulWidget {
  const AppointmentResultScreen({super.key, required this.appointmentId});

  final int appointmentId;

  @override
  State<AppointmentResultScreen> createState() =>
      _AppointmentResultScreenState();
}

class _SettlementViewData {
  const _SettlementViewData({
    required this.appointment,
    required this.upcoming,
    this.settlement,
  });

  final Map<String, dynamic> appointment;
  final Map<String, dynamic>? settlement;
  final bool upcoming;
}

class _AppointmentResultScreenState extends State<AppointmentResultScreen> {
  static const _navy = Color(0xFF18354A);
  static const _gray = Color(0xFF607280);
  static const _accent = Color(0xFF1577A5);
  static const _red = Color(0xFFC24545);
  static const _blue = Color(0xFF7DD3F7);
  static const _background = Color(0xFFF7FBFF);
  static const _pale = Color(0xFFEAF7FE);

  late Future<_SettlementViewData> _resultFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<_SettlementViewData> _loadResult() async {
    // 상세 정보를 먼저 확인한다. 아직 약속 시각이 오지 않았다면 정산
    // API의 실패를 네트워크 오류로 오인하지 않도록 호출하지 않는다.
    final appointment = await EtaApiService.getAppointmentDetail(
      widget.appointmentId,
    );
    final meetAt = DateTime.tryParse(appointment['meetAt']?.toString() ?? '')
        ?.toLocal();
    if (meetAt != null && meetAt.isAfter(DateTime.now())) {
      return _SettlementViewData(appointment: appointment, upcoming: true);
    }

    // 서버가 정산 결과를 실제로 제공하는 경우에만 완료된 정산으로 표시한다.
    final settlement = await EtaApiService.getSettlement(widget.appointmentId);
    return _SettlementViewData(
      appointment: appointment,
      settlement: settlement,
      upcoming: false,
    );
  }

  void _reload() => _resultFuture = _loadResult();
  void _retry() => setState(_reload);

  void _goToAppointmentList() {
    // 현재 스택에 홈 화면이 있다면 기존 탭 상태를 유지하며 복귀한다.
    // 홈이 없다면 초기 온보딩 화면으로 잘못 돌아가지 않도록 새 홈을 연다.
    final navigator = Navigator.of(context);
    var foundHome = false;
    navigator.popUntil((route) {
      if (route.settings.name == '/') {
        foundHome = true;
        return true;
      }
      return route.isFirst;
    });
    if (!foundHome) {
      navigator.pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  String _money(int amount) => amount.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    return '${value.hour < 12 ? '오전' : '오후'} '
        '$hour:${value.minute.toString().padLeft(2, '0')}';
  }

  Widget _primaryButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: _navy,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _secondaryButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: TextButton(
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(fontSize: 13, color: _gray)),
      ),
    );
  }

  Widget _stateMessage({
    required IconData icon,
    required String title,
    required String description,
    required String primaryLabel,
    required VoidCallback onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
    Color iconColor = _gray,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _navy,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 13),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _gray, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 28),
            _primaryButton(primaryLabel, onPrimary),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 9),
              _secondaryButton(secondaryLabel, onSecondary),
            ],
          ],
        ),
      ),
    );
  }

  Widget _loadingState() {
    Widget bar(double width, {double height = 15}) => Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFE4EDF2),
        borderRadius: BorderRadius.circular(7),
      ),
    );

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 146,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _pale,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(165, height: 21),
                const SizedBox(height: 16),
                bar(200),
                const SizedBox(height: 19),
                bar(125),
              ],
            ),
          ),
          const SizedBox(height: 25),
          bar(165, height: 20),
          const SizedBox(height: 16),
          for (var i = 0; i < 3; i++) ...[
            Container(
              height: 82,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 20,
                      backgroundColor: Color(0xFFE4EDF2),
                    ),
                    const SizedBox(width: 13),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        bar(105),
                        const SizedBox(height: 9),
                        bar(75, height: 12),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _participantCard(Map participant, String mode, int? myParticipantId) {
    final status = participant['arrivalStatus']?.toString() ?? '';
    final lateMinutes = (participant['lateMinutes'] as num?)?.toInt() ?? 0;
    final fineAmount = (participant['fineAmount'] as num?)?.toInt() ?? 0;
    final isLate = status == 'LATE';
    final participantId = (participant['participantId'] as num?)?.toInt();
    final nickname = participantId != null && participantId == myParticipantId
        ? '나'
        : (participant['nickname']?.toString() ?? '참가자');
    final statusLabel = switch (status) {
      'EARLY' => '일찍',
      'ON_TIME' => '정시',
      'LATE' => '지각',
      _ => '미도착',
    };
    final detail = switch (mode) {
      'FEE' => isLate ? '$lateMinutes분 · ${_money(fineAmount)}원' : '0원',
      'PENALTY' => isLate ? '$lateMinutes분 · 벌칙 대상' : '벌칙 없음',
      _ =>
        isLate
            ? '$lateMinutes분 늦음'
            : (status == 'EARLY' || status == 'ON_TIME'
                  ? '시간 내 도착'
                  : '도착 확인 전'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 21,
            backgroundColor: _pale,
            child: Icon(Icons.person_outline, color: _gray, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                // 정산 API에 실제 도착 시각이 없으므로 예시값을 만들지 않는다.
                const Text(
                  '도착 시각 정보 없음',
                  style: TextStyle(color: _gray, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                statusLabel,
                style: TextStyle(
                  color: isLate ? _red : _accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(detail, style: const TextStyle(color: _gray, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultContent(_SettlementViewData data, List<Map> participants) {
    final appointment = data.appointment;
    final settlement = data.settlement!;
    final penalty = appointment['penalty'];
    final mode = penalty is Map ? penalty['type']?.toString() ?? '' : '';
    final content = penalty is Map
        ? penalty['content']?.toString().trim() ?? ''
        : '';
    final fee = penalty is Map
        ? (penalty['finePerMinute'] as num?)?.toInt() ?? 0
        : 0;
    final ruleText = switch (mode) {
      'FEE' => '지각 1분당 ${_money(fee)}원',
      'PENALTY' =>
        content.isEmpty
            ? '벌칙 모드'
            : (content.startsWith('지각') ? content : '지각한 사람은 $content'),
      _ => '지각비·벌칙 없음',
    };
    final meetAt = DateTime.tryParse(appointment['meetAt']?.toString() ?? '')
        ?.toLocal();
    final dateText = meetAt == null
        ? '약속 시간 확인 필요'
        : '${meetAt.month}월 ${meetAt.day}일 · ${_time(meetAt)} · 약속 종료';
    final myParticipantId = (appointment['myParticipantId'] as num?)?.toInt();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _pale,
              borderRadius: BorderRadius.circular(21),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settlement['title']?.toString() ??
                      appointment['title']?.toString() ??
                      '약속',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 11),
                Text(
                  dateText,
                  style: const TextStyle(fontSize: 12, color: _gray),
                ),
                const SizedBox(height: 17),
                Text(
                  ruleText,
                  style: const TextStyle(
                    color: _accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            '참가자별 도착 기록',
            style: TextStyle(
              color: _navy,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 13),
          for (final person in participants)
            _participantCard(person, mode, myParticipantId),
          if (mode == 'FEE') ...[
            const SizedBox(height: 3),
            Text(
              '총 지각비  ${_money((settlement['totalFineAmount'] as num?)?.toInt() ?? 0)}원',
              textAlign: TextAlign.end,
              style: const TextStyle(color: _navy, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 5),
        ],
      ),
    );
  }

  Widget _settledView(_SettlementViewData data) {
    final settlement = data.settlement;
    final rawParticipants = settlement?['participants'];
    final participants = rawParticipants is List
        ? rawParticipants.whereType<Map>().toList()
        : <Map>[];

    if (participants.isEmpty) {
      return _stateMessage(
        icon: Icons.hourglass_empty,
        title: '아직 정산할 수 없어요',
        description: '참가자의 도착 기록이 생기면\n지각 정산을 확인할 수 있어요.',
        primaryLabel: '다시 확인',
        onPrimary: _retry,
        secondaryLabel: '약속 목록으로',
        onSecondary: _goToAppointmentList,
      );
    }

    final allArrivedOnTime = participants.every((person) {
      final status = person['arrivalStatus']?.toString();
      return status == 'EARLY' || status == 'ON_TIME';
    });

    if (allArrivedOnTime) {
      return _stateMessage(
        icon: Icons.check_circle_outline,
        title: '전원 무사 도착!',
        description: '지각한 사람이 없어서\n정산할 내용이 없어요.',
        primaryLabel: '홈으로 가기',
        onPrimary: _goToAppointmentList,
        iconColor: _accent,
      );
    }

    return Column(
      children: [
        Expanded(child: _resultContent(data, participants)),
        const SizedBox(height: 12),
        _primaryButton('지각 체포 영장 발급', () {
          // 영장 UI(S-63~66)는 후속 화면 연결 시 구현한다.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('지각 체포 영장 화면은 아직 연결되지 않았어요.')),
          );
        }),
        _secondaryButton('약속 목록으로', _goToAppointmentList),
        const SizedBox(height: 7),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 22),
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 19),
                    color: _accent,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '지각 정산',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: _navy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Expanded(
                child: FutureBuilder<_SettlementViewData>(
                  future: _resultFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return _loadingState();
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return _stateMessage(
                        icon: Icons.error_outline,
                        title: '지각 정산을 불러오지 못했어요',
                        description: '네트워크 연결 또는 약속 종료 상태를\n확인하고 다시 시도해 주세요.',
                        primaryLabel: '다시 시도',
                        onPrimary: _retry,
                        secondaryLabel: '약속 목록으로',
                        onSecondary: _goToAppointmentList,
                      );
                    }
                    final data = snapshot.requireData;
                    if (data.upcoming) {
                      final date = DateTime.tryParse(
                        data.appointment['meetAt']?.toString() ?? '',
                      )?.toLocal();
                      final timeDescription = date == null
                          ? '약속이 종료되면 정산 결과를 확인할 수 있어요.'
                          : '약속 시간은 ${date.month}월 ${date.day}일 ${_time(date)}예요.\n'
                                '약속이 종료되면 정산을 확인할 수 있어요.';
                      return _stateMessage(
                        icon: Icons.schedule,
                        title: '아직 정산할 수 없어요',
                        description: timeDescription,
                        primaryLabel: '다시 확인',
                        onPrimary: _retry,
                        secondaryLabel: '이전 화면으로',
                        onSecondary: () => Navigator.of(context).maybePop(),
                      );
                    }
                    return _settledView(data);
                  },
                ),
              ),
              const SizedBox(height: 13),
            ],
          ),
        ),
      ),
    );
  }
}
