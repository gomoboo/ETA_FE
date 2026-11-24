import 'package:flutter/material.dart';

import '../services/eta_api_service.dart';
import '../services/eta_notification_service.dart';
import 'appointment_warrant_screen.dart';

/// 피그마 S-53~55 / UI 설계서 S-56~58 지각 정산 화면.
/// 정산 상태: 설계서 S-59(로딩), S-60(미정산), S-61(전원 도착), S-62(오류).
class AppointmentResultScreen extends StatefulWidget {
  const AppointmentResultScreen({
    super.key,
    required this.appointmentId,
    this.fromRadar = false,
    this.fromPastAppointments = false,
  });

  final int appointmentId;
  final bool fromRadar;
  final bool fromPastAppointments;

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
    final status = (appointment['status'] ?? appointment['appointmentStatus'])
        ?.toString()
        .toUpperCase();

    // 전원 도착으로 조기 종료된 약속도 정산할 수 있도록
    // 예정 시간이 아닌 실제 서버 종료 상태를 기준으로 판단한다.
    bool isCompleted = status == 'COMPLETED';

    if (status == null) {
      final home = await EtaApiService.getHomeAppointments();
      final active = home['activeAppointments'];
      final upcoming = home['upcomingAppointments'];

      if (active is! List || upcoming is! List) {
        throw StateError('약속 목록 응답 형식 오류');
      }

      final current = [...active, ...upcoming];

      isCompleted = !current.any(
        (item) =>
            item is Map &&
            item['appointmentId']?.toString() ==
                widget.appointmentId.toString(),
      );
    }

    if (!isCompleted) {
      return _SettlementViewData(appointment: appointment, upcoming: true);
    }

    // 서버가 정산 결과를 실제로 제공하는 경우에만 완료된 정산으로 표시한다.
    final settlement = await EtaApiService.getSettlement(widget.appointmentId);

    // 실제 정산 결과가 조회된 경우에만 알림 저장
    if (status == 'COMPLETED') {
      final title = appointment['title']?.toString().trim();

      if (title != null && title.isNotEmpty) {
        try {
          await EtaNotificationService.saveNotification(
            id: 'settlement:${widget.appointmentId}',
            type: 'settlement',
            title: '정산 결과가 준비됐어요',
            description: '$title · 도착 기록과 지각비를 확인해요.',
            appointmentId: widget.appointmentId,
          );
        } catch (error) {
          debugPrint('정산 알림 저장 실패: $error');
        }
      }
    }

    return _SettlementViewData(
      appointment: appointment,
      settlement: settlement,
      upcoming: false,
    );
  }

  void _reload() => _resultFuture = _loadResult();
  void _retry() => setState(_reload);

  void _goToAppointmentList() {
    // 지난 약속에서 진입했다면 해당 목록으로 돌아간다.
    if (widget.fromPastAppointments) {
      Navigator.of(context).pop();
      return;
    }

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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
    bool highlightedIcon = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (highlightedIcon)
              Container(
                width: 84,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F7FF),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, size: 36, color: iconColor),
              )
            else
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
    final isPenaltyTarget =
        isLate || (status == 'NOT_ARRIVED' && lateMinutes > 0);
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
      'PENALTY' => isPenaltyTarget ? '$lateMinutes분 · 벌칙 대상' : '벌칙 없음',
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
                  color: (isLate || statusLabel == '미도착') ? _red : _accent,
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

  Future<void> _openWarrants(_SettlementViewData data) async {
    try {
      final response = await EtaApiService.getWarrants(widget.appointmentId);

      final responseData = response['data'];
      final rawWarrants =
          response['warrants'] ??
          (responseData is Map ? responseData['warrants'] : null);

      if (rawWarrants is! List) {
        throw const FormatException('영장 목록 응답 형식 오류');
      }

      if (rawWarrants.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('발급된 지각 체포 영장이 없어요.')));
        return;
      }

      final penalty = data.appointment['penalty'];
      final penaltyType =
          ((penalty is Map ? penalty['type'] : null) ??
                  data.appointment['penaltyType'])
              ?.toString()
              .toUpperCase();

      final mode = switch (penaltyType) {
        'FEE' => WarrantPenaltyMode.fee,
        'PENALTY' => WarrantPenaltyMode.penalty,
        _ => WarrantPenaltyMode.none,
      };

      final warrants = rawWarrants.map((item) {
        if (item is! Map) {
          throw const FormatException('영장 항목 형식 오류');
        }

        return WarrantDisplayData.fromApi(
          Map<String, dynamic>.from(item),
          penaltyMode: mode,
        );
      }).toList();

      if (!mounted) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => AppointmentWarrantScreen(warrants: warrants),
        ),
      );
    } catch (error) {
      debugPrint('영장 조회 실패: $error');
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('영장 정보를 불러오지 못했어요.')));
    }
  }

  bool _isSettlementNotReady(Object? error) {
    final message = error?.toString() ?? '';
    return message.contains('SETTLEMENT_NOT_READY') ||
        message.contains('아직 정산할 수 없는 약속');
  }

  Widget _settlementStatusCard({
    required IconData icon,
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Transform.translate(
      offset: const Offset(0, -90),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _pale,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: _accent, size: 26),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _gray,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                _primaryButton(buttonLabel, onPressed),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _radarSettlementPending() {
    return _settlementStatusCard(
      icon: Icons.remove,
      title: '아직 정산할 수 없어요',
      description:
          '참가자의 도착 기록이 생기면\n'
          '이곳에서 지각 정산을 시작할 수 있어요.',
      buttonLabel: '실시간 레이더 보기',
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }

  Widget _settledView(_SettlementViewData data) {
    final settlement = data.settlement;
    final rawParticipants = settlement?['participants'];
    final participants = rawParticipants is List
        ? rawParticipants.whereType<Map>().toList()
        : <Map>[];

    if (participants.isEmpty) {
      if (widget.fromRadar) return _radarSettlementPending();

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
      return _settlementStatusCard(
        icon: Icons.check_rounded,
        title: '전원 무사 도착!',
        description: '지각한 사람이 없어서 정산할 내용이 없어요.',
        buttonLabel: '홈으로 가기',
        onPressed: () {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
        },
      );
    }

    return Column(
      children: [
        Expanded(child: _resultContent(data, participants)),
        const SizedBox(height: 12),
        _primaryButton('지각 체포 영장 발급', () => _openWarrants(data)),
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
              Transform.translate(
                offset: const Offset(-12, 0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_ios_new),
                        iconSize: 20,
                        color: const Color(0xFF1685B5),
                      ),
                    ),
                    const Text(
                      '지각 정산',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: FutureBuilder<_SettlementViewData>(
                  future: _resultFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return _loadingState();
                    }
                    if (widget.fromRadar &&
                        _isSettlementNotReady(snapshot.error)) {
                      return _radarSettlementPending();
                    }

                    if (snapshot.hasError || !snapshot.hasData) {
                      return _settlementStatusCard(
                        icon: Icons.priority_high_rounded,
                        title: '지각 정산 결과를 불러오지 못했어요',
                        description:
                            '네트워크 연결 문제로 도착 기록을\n'
                            '불러오지 못했어요. 연결 후 다시 시도해 주세요.',
                        buttonLabel: '다시 시도',
                        onPressed: _retry,
                      );
                    }

                    final data = snapshot.requireData;
                    if (data.upcoming) {
                      if (widget.fromRadar) return _radarSettlementPending();
                      final date = DateTime.tryParse(
                        data.appointment['meetAt']?.toString() ?? '',
                      )?.toLocal();
                      final timeDescription = date == null
                          ? '약속이 종료되면 정산 결과를 확인할 수 있어요.'
                          : '약속 시간은 ${date.month}월 ${date.day}일 ${_time(date)}예요.\n'
                                '약속이 종료되면 정산을 확인할 수 있어요.';
                      return _stateMessage(
                        icon: Icons.schedule,
                        iconColor: const Color(0xFF1685B5),
                        highlightedIcon: true,
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
