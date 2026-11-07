import 'package:flutter/material.dart';

import '../services/eta_api_service.dart';
import 'appointments_tab.dart';
import 'my_tab_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FBFF),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: _selectedTab == 0
                  ? _FigmaHomeTab(
                      onAllAppointments: () {
                        setState(() => _selectedTab = 1);
                      },
                    )
                  : _selectedTab == 1
                  ? const AppointmentsTab()
                  : const MyTabScreen(),
            ),
            _BottomNavigation(
              selectedIndex: _selectedTab,
              onTap: (index) {
                setState(() => _selectedTab = index);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FigmaHomeTab extends StatefulWidget {
  const _FigmaHomeTab({required this.onAllAppointments});

  final VoidCallback onAllAppointments;

  @override
  State<_FigmaHomeTab> createState() => _FigmaHomeTabState();
}

class _FigmaHomeTabState extends State<_FigmaHomeTab> {
  static const _navy = Color(0xFF18354A);
  static const _blue = Color(0xFF7DD3F7);
  static const _accent = Color(0xFF1685B5);
  static const _gray = Color(0xFF718696);
  static const _card = Color(0xFFEAF7FE);

  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = EtaApiService.getHomeAppointments();
  }

  void _reload() {
    setState(() {
      _future = EtaApiService.getHomeAppointments();
    });
  }

  DateTime? _parseTime(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return '날짜 확인 필요';

    const days = ['월', '화', '수', '목', '금', '토', '일'];
    final today = DateTime.now();

    final isToday =
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;

    final prefix = isToday ? '오늘 · ' : '';

    return '$prefix${date.month}월 ${date.day}일'
        ' (${days[date.weekday - 1]})';
  }

  String _timeLabel(DateTime? date) {
    if (date == null) return '시간 확인 필요';

    final period = date.hour < 12 ? '오전' : '오후';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');

    return '$period $hour:$minute';
  }

  Future<void> _openLocation(Map<String, dynamic> appointment) async {
    final id = appointment['appointmentId'];

    if (id is! int) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('약속 ID를 확인할 수 없어요.')));
      return;
    }

    if (appointment['isLocationSharingActive'] != true) {
      await Navigator.pushNamed(context, '/appointment-waiting', arguments: id);
      if (mounted) _reload();
      return;
    }

    try {
      final detail = await EtaApiService.getAppointmentDetail(id);

      if (!mounted) return;

      final myId = detail['myParticipantId'];

      if (myId is! int) {
        await Navigator.pushNamed(
          context,
          '/appointment-waiting',
          arguments: id,
        );
      } else {
        String nickname = '나';
        final members = detail['participants'];

        if (members is List) {
          for (final member in members) {
            if (member is Map && member['participantId'] == myId) {
              nickname = member['nickname']?.toString() ?? '나';
              break;
            }
          }
        }

        await Navigator.pushNamed(
          context,
          '/live-map',
          arguments: {
            'appointmentId': id,
            'myParticipantId': myId,
            'nickname': nickname,
          },
        );
      }

      if (mounted) _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('실시간 위치 화면을 열지 못했어요.')));
    }
  }

  Widget _loadingBar(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _loadingContent() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _loadingBar(160, 17),
              const SizedBox(height: 16),
              _loadingBar(110, 12),
              const SizedBox(height: 14),
              _loadingBar(180, 32),
              const SizedBox(height: 22),
              _loadingBar(130, 14),
              const SizedBox(height: 15),
              _loadingBar(190, 14),
              const SizedBox(height: 24),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '•••  약속을 불러오는 중이에요',
          style: TextStyle(fontSize: 12, color: _gray),
        ),
      ],
    );
  }

  Widget _errorContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              '!',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.bold,
                color: _accent,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            '홈 정보를 불러오지 못했어요',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _navy,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '네트워크 연결이 원활하지 않아요.\n'
            '연결 상태를 확인하고 다시 시도해 주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.5, color: _gray),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _reload,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: _navy,
                elevation: 0,
              ),
              child: const Text('다시 시도'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _appointmentCard(Map<String, dynamic> item) {
    final date = _parseTime(item['meetAt']);
    final isSharing = item['isLocationSharingActive'] == true;
    final count = item['participantCount'] is int
        ? item['participantCount'] as int
        : 0;
    final friendCount = count > 0 ? count - 1 : 0;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _card,
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
                  color: _navy,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _dateLabel(date),
                style: const TextStyle(
                  fontSize: 12,
                  color: _accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _timeLabel(date),
                style: const TextStyle(
                  fontSize: 31,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                item['targetPlaceName']?.toString() ?? '장소 확인 필요',
                style: const TextStyle(
                  fontSize: 15,
                  color: _accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isSharing ? '위치 공유 중' : '위치 공유 꺼짐',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSharing ? _accent : _gray,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                friendCount == 0
                    ? '아직 참여한 친구가 없어요'
                    : '친구 $friendCount명이 함께하고 있어요',
                style: const TextStyle(fontSize: 12, color: _accent),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => _openLocation(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: _navy,
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
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: TextButton(
            onPressed: widget.onAllAppointments,
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '전체 약속 보기',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text(
            '다른 약속과 초대 코드는 약속 탭에서 확인해요.',
            style: TextStyle(fontSize: 11, color: _accent),
          ),
        ),
      ],
    );
  }

  Widget _emptyContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            '지금 확인할 약속이 없어요',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _navy,
            ),
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: widget.onAllAppointments,
            child: const Text('전체 약속 보기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                onPressed: () => Navigator.pushNamed(context, '/notifications'),
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: _accent,
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
          const SizedBox(height: 15),
          const Text(
            '지금 확인할 약속',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _gray,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return _loadingContent();
              }

              if (snapshot.hasError) {
                return _errorContent();
              }

              final data = snapshot.data ?? {};
              final active = (data['activeAppointments'] as List? ?? [])
                  .whereType<Map<String, dynamic>>()
                  .toList();
              final upcoming = (data['upcomingAppointments'] as List? ?? [])
                  .whereType<Map<String, dynamic>>()
                  .toList();

              if (active.isNotEmpty) {
                return _appointmentCard(active.first);
              }

              if (upcoming.isNotEmpty) {
                return _appointmentCard(upcoming.first);
              }

              return _emptyContent();
            },
          ),
        ],
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
  const _BottomNavigation({required this.selectedIndex, required this.onTap});

  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(38, 12, 38, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _BottomNavigationItem(
            icon: Icons.home_outlined,
            label: '홈',
            selected: selectedIndex == 0,
            onTap: () => onTap(0),
          ),
          _BottomNavigationItem(
            icon: Icons.calendar_today_outlined,
            label: '약속',
            selected: selectedIndex == 1,
            onTap: () => onTap(1),
          ),
          _BottomNavigationItem(
            icon: Icons.person_outline_rounded,
            label: '마이',
            selected: selectedIndex == 2,
            onTap: () => onTap(2),
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
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF1685B5) : const Color(0xFF718696);

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 52,
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
      ),
    );
  }
}
