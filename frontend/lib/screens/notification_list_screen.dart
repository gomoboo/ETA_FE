import 'package:flutter/material.dart';

import '../services/eta_notification_service.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  late Future<List<Map<String, dynamic>>> _notificationsFuture;
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<List<Map<String, dynamic>>> _loadNotifications() async {
    final items = await EtaNotificationService.getNotifications();

    if (mounted && _notificationCount != items.length) {
      setState(() {
        _notificationCount = items.length;
      });
    }

    // 처음 보는 알림은 이번 방문에서 파란색으로 표시한다.
    // 방문 기록은 저장하여 다음 방문부터 흰색으로 표시한다.
    await EtaNotificationService.markNotificationsAsRead(
      items.map((item) => item['id']?.toString()).whereType<String>(),
    );

    return items;
  }

  void _reload() {
    setState(() {
      _notificationsFuture = _loadNotifications();
    });
  }

  static const Color _background = Color(0xFFF7FBFF);
  static const Color _navy = Color(0xFF18354A);
  static const Color _subText = Color(0xFF607280);
  static const Color _blue = Color(0xFF1685B5);

  Widget _notificationCard(Map<String, dynamic> item) {
    final isNew = item['isRead'] != true;
    final createdAt = DateTime.tryParse(item['createdAt']?.toString() ?? '')
        ?.toLocal();

    String timeText = '';
    if (createdAt != null) {
      final minutes = DateTime.now().difference(createdAt).inMinutes;
      if (minutes < 1) {
        timeText = '방금 전';
      } else if (minutes < 60) {
        timeText = '$minutes분 전';
      } else if (minutes < 1440) {
        timeText = '${minutes ~/ 60}시간 전';
      } else {
        timeText = '${minutes ~/ 1440}일 전';
      }
    }

    return InkWell(
      onTap: () async {
        final id = item['id']?.toString();
        if (id != null) {
          await EtaNotificationService.markAsRead(id);
        }
        if (mounted) _reload();
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        decoration: BoxDecoration(
          color: isNew ? const Color(0xFFEAF7FE) : Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['title']?.toString() ?? '',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item['description']?.toString() ?? '',
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: _subText,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              timeText,
              style: TextStyle(fontSize: 12, color: isNew ? _blue : _subText),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 17, 24, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: _blue,
                      ),
                    ),
                  ),
                  const Text(
                    '알림',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: _notificationCount >= 6
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '약속 소식을 확인해 보세요',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      '최근 알림',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _notificationsFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final notifications = snapshot.data!;
                        if (notifications.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 65),
                            child: Center(
                              child: Text(
                                '아직 도착한 알림이 없어요.',
                                style: TextStyle(fontSize: 14, color: _subText),
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: [
                            for (final item in notifications) ...[
                              _notificationCard(item),
                              const SizedBox(height: 12),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
