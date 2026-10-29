import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const Color _background = Color(0xFFF7FBFF);
  static const Color _navy = Color(0xFF18354A);
  static const Color _gray = Color(0xFF718696);
  static const Color _blue = Color(0xFF7DD3F7);
  static const Color _cardBlue = Color(0xFFEAF7FE);
  static const Color _accentBlue = Color(0xFF1685B5);

  @override
  Widget build(BuildContext context) {
    final nickname =
    ModalRoute.of(context)?.settings.arguments as String?;
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 상단 로고 + 알림
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '이따',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.notifications_none_rounded,
                            size: 26,
                            color: _accentBlue,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    const Text(
                      '오늘도, 제시간에 만나요',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      '진행 중인 약속',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _gray,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 진행 중 약속 카드
                    Container(
                      width: double.infinity,
                      height: 207,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _cardBlue,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '강남역 맛집 탐방',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _navy,
                            ),
                          ),

                          const SizedBox(height: 3),

                          const Text(
                            '오늘 오후 2:30 · 강남역 11번 출구',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: _gray,
                            ),
                          ),

                          const SizedBox(height: 10),

                          const Text(
                            '위치 공유 중',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _accentBlue,
                            ),
                          ),

                          const SizedBox(height: 8),

                          const Text(
                            '친구 4명이 함께하고 있어요',
                            style: TextStyle(
                              fontSize: 13,
                              color: _accentBlue,
                            ),
                          ),

                          const Spacer(),

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  '/live-map',
                                  arguments: nickname,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _blue,
                                foregroundColor: _navy,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                '실시간 위치 보기',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      '예정된 약속',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),

                    const SizedBox(height: 12),

                    _UpcomingAppointmentCard(
                      title: '학교 근처 카페',
                      description: '내일 오후 6:00 · 참가자 2명',
                    ),

                    const SizedBox(height: 12),

                    _UpcomingAppointmentCard(
                      title: '주말 영화 보기',
                      description: '9월 26일 오후 4:00 · 참가자 3명',
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/appointment-create',
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _blue,
                          foregroundColor: _navy,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '+ 새 약속 만들기',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const _BottomNavigation(),
          ],
        ),
      ),
    );
  }
}

class _UpcomingAppointmentCard extends StatelessWidget {
  const _UpcomingAppointmentCard({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 89,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF18354A),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF718696),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      color: Colors.white,
      padding: const EdgeInsets.only(
        left: 38,
        right: 38,
        top: 12,
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _BottomNavigationItem(
            icon: Icons.home_outlined,
            label: '홈',
            selected: true,
          ),
          _BottomNavigationItem(
            icon: Icons.calendar_today_outlined,
            label: '약속',
          ),
          _BottomNavigationItem(
            icon: Icons.person_outline_rounded,
            label: '마이',
          ),
        ],
      ),
    );
  }
}

class _BottomNavigationItem extends StatelessWidget {
  const _BottomNavigationItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? const Color(0xFF1685B5)
        : const Color(0xFF718696);

    return SizedBox(
      width: 48,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
            color: color,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight:
                  selected ? FontWeight.w700 : FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}