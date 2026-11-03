import 'package:flutter/material.dart';

import '../services/eta_api_service.dart';
import '../services/guest_identity_service.dart';

class InvitedAppointmentScreen extends StatefulWidget {
  const InvitedAppointmentScreen({
    super.key,
    required this.inviteCode,
    required this.preview,
  });

  final String inviteCode;
  final Map<String, dynamic> preview;

  @override
  State<InvitedAppointmentScreen> createState() =>
      _InvitedAppointmentScreenState();
}

class _InvitedAppointmentScreenState extends State<InvitedAppointmentScreen> {
  static const navy = Color(0xFF18354A);
  static const blue = Color(0xFF7DD3F7);
  static const accent = Color(0xFF1685B5);
  static const gray = Color(0xFF718696);
  static const pale = Color(0xFFEAF7FE);
  static const background = Color(0xFFF7FBFF);

  final nicknameController = TextEditingController();

  bool joining = false;
  bool expired = false;
  String? nicknameError;
  String? joinError;

  @override
  void initState() {
    super.initState();

    const terminalStatuses = {
      'ENDED',
      'COMPLETED',
      'FINISHED',
      'EXPIRED',
      'CLOSED',
      'CANCELLED',
    };

    final status = widget.preview['status']?.toString().toUpperCase() ?? '';

    expired = terminalStatuses.contains(status);
    _loadNickname();
  }

  Future<void> _loadNickname() async {
    final nickname = await GuestIdentityService.getNickname();

    if (!mounted || nickname == null) return;

    final trimmed = nickname.trim();
    if (trimmed.runes.length >= 2 &&
        trimmed.runes.length <= 10 &&
        nicknameController.text.isEmpty) {
      nicknameController.text = trimmed;
    }
  }

  @override
  void dispose() {
    nicknameController.dispose();
    super.dispose();
  }

  String formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();

    if (date == null) return '날짜 확인 필요';

    final period = date.hour < 12 ? '오전' : '오후';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');

    return '${date.year}. '
        '${date.month.toString().padLeft(2, '0')}. '
        '${date.day.toString().padLeft(2, '0')} · '
        '$period $hour:$minute';
  }

  Future<void> joinAppointment() async {
    if (joining) return;

    final nickname = nicknameController.text.trim();

    if (nickname.runes.length < 2 || nickname.runes.length > 10) {
      setState(() {
        nicknameError = '닉네임은 2~10자로 입력해 주세요.';
      });
      return;
    }

    setState(() {
      joining = true;
      nicknameError = null;
      joinError = null;
    });

    try {
      final result = await EtaApiService.joinAppointment(
        widget.inviteCode,
        nickname: nickname,
      );

      if (!mounted) return;

      final rawId = result['appointmentId'];
      final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');

      if (id == null) {
        setState(() {
          joinError =
              '참여는 처리됐지만 약속 번호를 확인하지 못했어요. '
              '홈에서 약속 목록을 확인해 주세요.';
        });
        return;
      }

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/appointment-waiting',
        ModalRoute.withName('/'),
        arguments: id,
      );
    } catch (error) {
      if (!mounted) return;

      final message = error.toString().toLowerCase();

      if (message.contains('종료') ||
          message.contains('expired') ||
          message.contains('completed')) {
        setState(() => expired = true);
      } else {
        setState(() {
          joinError =
              '약속에 참여하지 못했어요. '
              '참여 상태와 네트워크를 확인해 주세요.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => joining = false);
      }
    }
  }

  Widget primaryButton({
    required String text,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: navy,
          disabledBackgroundColor: const Color(0xFFB8E9FA),
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

  Widget inviteDetails() {
    final p = widget.preview;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD7EAF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p['title']?.toString() ?? '약속',
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: navy,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            formatDate(p['meetAt']),
            style: const TextStyle(fontSize: 14, color: gray),
          ),
          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: accent, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  p['targetPlaceName']?.toString() ?? '장소 확인 필요',
                  style: const TextStyle(fontSize: 15, color: navy),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFFD7EAF5)),
          const SizedBox(height: 20),
          const Text(
            '지각 규칙',
            style: TextStyle(
              fontSize: 13,
              color: gray,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            p['penaltySummary']?.toString() ?? '규칙 정보 없음',
            style: const TextStyle(
              fontSize: 16,
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            '위치 공유',
            style: TextStyle(
              fontSize: 13,
              color: gray,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            p['radarStartSummary']?.toString() ?? '공유 시간 확인 필요',
            style: const TextStyle(fontSize: 14, color: navy, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget joinPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 42),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '약속에 초대받았어요',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: navy,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '약속 정보와 지각 규칙을 확인한 뒤 참여해 주세요.',
            style: TextStyle(fontSize: 13, color: gray),
          ),
          const SizedBox(height: 30),
          inviteDetails(),
          const SizedBox(height: 36),
          const Text(
            '닉네임 설정',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: navy,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nicknameController,
            maxLength: 10,
            decoration: InputDecoration(
              hintText: '2~10자 닉네임을 입력해 주세요',
              counterText: '',
              errorText: nicknameError,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 17,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: const BorderSide(color: Color(0xFFD7EAF5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: const BorderSide(color: accent),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
              ),
            ),
            onChanged: (_) {
              if (nicknameError != null) {
                setState(() => nicknameError = null);
              }
            },
          ),
          if (joinError != null) ...[
            const SizedBox(height: 10),
            Text(
              joinError!,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
          const SizedBox(height: 14),
          primaryButton(
            text: joining ? '참여 중...' : '약속 참여하기',
            onPressed: joining ? null : joinAppointment,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: joining ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: navy,
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFD7EAF5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '참여하지 않기',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget expiredPage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 35, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 215,
            decoration: BoxDecoration(
              color: pale,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 148,
                  height: 148,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    size: 74,
                    color: accent,
                  ),
                ),
                Positioned(
                  right: 88,
                  bottom: 31,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_outline, color: accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 42),
          const Text(
            '이 약속은 종료되었어요',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w700,
              color: navy,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '종료된 약속의 초대 링크로는\n'
            '더 이상 참가할 수 없어요.',
            style: TextStyle(fontSize: 16, color: gray, height: 1.6),
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: pale,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '새로운 약속을 확인해보세요',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: navy,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '홈에서 예정된 약속을 확인하거나\n'
                  '새 약속을 만들어 친구를 초대할 수 있어요.',
                  style: TextStyle(fontSize: 13, color: gray, height: 1.5),
                ),
              ],
            ),
          ),
          const Spacer(),
          primaryButton(
            text: '홈으로 돌아가기',
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
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
        toolbarHeight: 75,
        title: const Text(
          '약속 초대',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(child: expired ? expiredPage() : joinPage()),
    );
  }
}
