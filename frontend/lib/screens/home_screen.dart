import 'package:flutter/material.dart';

import '../services/eta_api_service.dart';

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
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/appointment-waiting');
        },
        icon: const Icon(Icons.schedule),
        label: const Text('약속 대기'),
      ),
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

                    const _HomeAppointmentsSection(),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/appointment-create');
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

class _HomeAppointmentsSection extends StatefulWidget {
  const _HomeAppointmentsSection();

  @override
  State<_HomeAppointmentsSection> createState() =>
      _HomeAppointmentsSectionState();
}

class _HomeAppointmentsSectionState extends State<_HomeAppointmentsSection> {
  late Future<Map<String, dynamic>> _homeFuture;

  @override
  void initState() {
    super.initState();
    _homeFuture = EtaApiService.getHomeAppointments();
  }

  void _reload() {
    setState(() {
      _homeFuture = EtaApiService.getHomeAppointments();
    });
  }

  String _formatDate(dynamic value) {
    try {
      final date = DateTime.parse(value.toString()).toLocal();
      final hour = date.hour > 12
          ? date.hour - 12
          : date.hour == 0
          ? 12
          : date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour < 12 ? '오전' : '오후';
      return '${date.month}월 ${date.day}일 $period $hour:$minute';
    } catch (_) {
      return '시간 확인 필요';
    }
  }

  void _openAppointment(Map<String, dynamic> item) {
    final id = item['appointmentId'];
    if (id is! int) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('약속 ID를 확인할 수 없어요.')));
      return;
    }
    Navigator.pushNamed(context, '/appointment-waiting', arguments: id);
  }

  Widget _activeCard(Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF7FE),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['title']?.toString() ?? '약속',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF18354A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "${_formatDate(item['meetAt'])} · "
              "${item['targetPlaceName'] ?? ''}",
              style: const TextStyle(fontSize: 13, color: Color(0xFF718696)),
            ),
            const SizedBox(height: 10),
            Text(
              item['isLocationSharingActive'] == true
                  ? '위치 공유 중'
                  : '위치 공유 대기 중',
              style: const TextStyle(fontSize: 12, color: Color(0xFF1685B5)),
            ),
            const SizedBox(height: 6),
            Text(
              "참가자 ${item['participantCount'] ?? 0}명",
              style: const TextStyle(fontSize: 13, color: Color(0xFF1685B5)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => _openAppointment(item),
                child: const Text('약속 상세 보기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _homeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Column(
            children: [
              const Text('약속 목록을 불러오지 못했어요.'),
              Text(
                snapshot.error.toString(),
                style: const TextStyle(fontSize: 12),
              ),
              TextButton(onPressed: _reload, child: const Text('다시 시도')),
            ],
          );
        }

        final data = snapshot.data ?? {};
        final active = (data['activeAppointments'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        final upcoming = (data['upcomingAppointments'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (active.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('진행 중인 약속이 없어요.'),
              ),

            for (final item in active) _activeCard(item),

            const SizedBox(height: 18),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    '예정된 약속',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF18354A),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _reload,
                  tooltip: '약속 목록 새로고침',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),

            if (upcoming.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('예정된 약속이 없어요.'),
              ),

            for (final item in upcoming)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: InkWell(
                  onTap: () => _openAppointment(item),
                  borderRadius: BorderRadius.circular(18),
                  child: _UpcomingAppointmentCard(
                    title: item['title']?.toString() ?? '약속',
                    description:
                        "${_formatDate(item['meetAt'])} · "
                        "참가자 ${item['participantCount'] ?? 0}명",
                  ),
                ),
              ),
          ],
        );
      },
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
            style: const TextStyle(fontSize: 13, color: Color(0xFF718696)),
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
      padding: const EdgeInsets.only(left: 38, right: 38, top: 12),
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
    final color = selected ? const Color(0xFF1685B5) : const Color(0xFF718696);

    return SizedBox(
      width: 48,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
