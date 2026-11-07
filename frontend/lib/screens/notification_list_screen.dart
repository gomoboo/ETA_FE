import 'package:flutter/material.dart';

class NotificationListScreen extends StatelessWidget {
  const NotificationListScreen({super.key});

  static const Color _background = Color(0xFFF7FBFF);
  static const Color _navy = Color(0xFF18354A);
  static const Color _subText = Color(0xFF607280);
  static const Color _blue = Color(0xFF1577A5);

  // 실제 알림 API 연동 전 UI 확인용 예시 데이터
  static const List<_NotificationItem> _notifications = [
    _NotificationItem(
      title: '정산 결과가 준비됐어요',
      description: '강남역 맛집 탐방 · 도착 기록과 지각비를 확인해요.',
      time: '5분 전',
      isNew: true,
    ),
    _NotificationItem(
      title: '민수님이 도착했어요',
      description: '강남역 맛집 탐방 · 친구의 도착 상태를 확인해요.',
      time: '20분 전',
    ),
    _NotificationItem(
      title: '지민님이 찌르기를 보냈어요',
      description: '강남역 맛집 탐방 · 출발 신호가 도착했어요.',
      time: '45분 전',
    ),
    _NotificationItem(
      title: '위치 공유가 시작됐어요',
      description: '강남역 맛집 탐방 · 친구들이 오는 길을 확인해요.',
      time: '1시간 전',
    ),
  ];

  Widget _notificationCard(_NotificationItem item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: item.isNew ? const Color(0xFFEAF7FE) : Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _navy,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            item.description,
            style: const TextStyle(fontSize: 14, height: 1.5, color: _subText),
          ),
          const SizedBox(height: 26),
          Text(
            item.time,
            style: TextStyle(
              fontSize: 13,
              color: item.isNew ? _blue : _subText,
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
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        title: const Text(
          '알림',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: _navy,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 44, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '약속 소식을 확인해 보세요',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '최근 알림',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 18),
              for (final item in _notifications) ...[
                _notificationCard(item),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationItem {
  const _NotificationItem({
    required this.title,
    required this.description,
    required this.time,
    this.isNew = false,
  });

  final String title;
  final String description;
  final String time;
  final bool isNew;
}
