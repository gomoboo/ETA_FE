import 'package:flutter/material.dart';

import 'appointment_result_screen.dart';
import '../services/eta_appointment_tracking_service.dart';

class PastAppointmentsScreen extends StatefulWidget {
  const PastAppointmentsScreen({super.key});

  @override
  State<PastAppointmentsScreen> createState() => _PastAppointmentsScreenState();
}

class _PastAppointmentsScreenState extends State<PastAppointmentsScreen> {
  bool _isRefreshing = false;

  List<Map<String, dynamic>> _pastAppointments = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      final items =
          await EtaAppointmentTrackingService.getPastSettledAppointments();

      if (!mounted) return;

      setState(() {
        _pastAppointments = items;
      });
    } catch (error) {
      debugPrint('지난 약속 조회 실패: $error');

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('지난 약속을 불러오지 못했어요.')));
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  String _formatMeetAt(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();

    if (date == null) return '약속 시간 확인 필요';

    final period = date.hour < 12 ? '오전' : '오후';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;

    return '${date.month}월 ${date.day}일 '
        '$period $hour:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _pastAppointmentCard(Map<String, dynamic> item) {
    final id = int.tryParse(item['appointmentId']?.toString() ?? '');

    final title = item['title']?.toString().trim();
    final name = title == null || title.isEmpty ? '지난 약속' : title;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: id == null
              ? null
              : () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => AppointmentResultScreen(
                        appointmentId: id,
                        fromPastAppointments: true,
                      ),
                    ),
                  );
                },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatMeetAt(item['meetAt']),
                  style: const TextStyle(fontSize: 13, color: _gray),
                ),
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '정산 내역 보기',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _accent,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: _accent),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const _navy = Color(0xFF18354A);
  static const _accent = Color(0xFF1685B5);
  static const _gray = Color(0xFF718696);
  static const _blue = Color(0xFF7DD3F7);
  static const _background = Color(0xFFF7FBFF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 22),

            // 기존 공통 헤더 규격 유지
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 24),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new),
                      iconSize: 20,
                      color: _accent,
                    ),
                  ),
                  const Text(
                    '지난 약속',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 68),

            Expanded(
              child: _isRefreshing
                  ? Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '•••',
                            style: TextStyle(
                              color: Color(0xFF1685B5),
                              fontSize: 18,
                              letterSpacing: 3,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '약속 목록을 불러오는 중이에요',
                            style: TextStyle(fontSize: 13, color: _gray),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _pastAppointments.isNotEmpty
                          ? Column(
                              children: [
                                for (final item in _pastAppointments)
                                  _pastAppointmentCard(item),
                              ],
                            )
                          : Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                22,
                                20,
                                22,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Column(
                                children: [
                                  // 파란 배경 + 진한 파란색 시계 아이콘
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F7FF),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(
                                      Icons.history_rounded,
                                      size: 30,
                                      color: _accent,
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  const Text(
                                    '표시할 지난 약속이 없어요',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: _navy,
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  const Text(
                                    '종료된 약속은 24시간 동안 저장돼요.\n'
                                    '이 기간에는 정산 내역을 다시 확인할 수 있어요.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.5,
                                      color: _gray,
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: _isRefreshing
                                          ? null
                                          : _refresh,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _blue,
                                        foregroundColor: _navy,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                      ),
                                      child: _isRefreshing
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                              ),
                                            )
                                          : const Text(
                                              '새로고침',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
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
