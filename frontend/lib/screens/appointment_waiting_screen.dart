import 'dart:async';
import 'package:flutter/material.dart';

class AppointmentWaitingScreen extends StatefulWidget {
  const AppointmentWaitingScreen({super.key});

  @override
  State<AppointmentWaitingScreen> createState() =>
      _AppointmentWaitingScreenState();
}

class _AppointmentWaitingScreenState
    extends State<AppointmentWaitingScreen> {
  static const Color _navy = Color(0xFF19374C);
  static const Color _blue = Color(0xFF7DD3F5);
  static const Color _background = Color(0xFFF5FAFE);
  static const Color _subText = Color(0xFF7990A3);

  late final DateTime _sharingStartAt;
  late final Timer _timer;

  final List<Map<String, String>> _friends = [
    {'initial': '나', 'name': '나', 'description': '방장 · 초대 완료'},
    {'initial': '지', 'name': '지민', 'description': '참여 완료'},
    {'initial': '서', 'name': '서연', 'description': '참여 완료'},
    {'initial': '민', 'name': '민수', 'description': '참여 완료'},
  ];

  @override
  void initState() {
    super.initState();

    // 테스트용 카운트다운: 화면 진입 시 28분 45초
    _sharingStartAt = DateTime.now().add(
      const Duration(minutes: 28, seconds: 45),
    );

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _remainingTime {
    final difference = _sharingStartAt.difference(DateTime.now());
    final totalSeconds =
        difference.inSeconds < 0 ? 0 : difference.inSeconds;

    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
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
                          side: const BorderSide(
                            color: Color(0xFFD7E8F4),
                          ),
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
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/',
        (route) => false,
      );
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: _subText,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            '준비 완료',
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
                              const Text(
                                '강남역 맛집 탐방',
                                style: TextStyle(
                                  color: _navy,
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '오늘 오후 2:30 · 강남역 11번 출구',
                                style: TextStyle(
                                  color: _subText,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '약속 상세 화면은 다음 단계에서 연결합니다.',
                                ),
                              ),
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
                              border: Border.all(
                                color: _blue,
                                width: 5,
                              ),
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

                    const Text(
                      '함께할 친구 4명',
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
                    side: const BorderSide(
                      color: Color(0xFFD7E8F4),
                    ),
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