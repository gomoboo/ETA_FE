import 'package:flutter/material.dart';

import '../services/eta_notification_service.dart';

class EtaNotificationIcon extends StatelessWidget {
  const EtaNotificationIcon({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: EtaNotificationService.changes,
      builder: (context, revision, child) {
        return FutureBuilder<bool>(
          future: EtaNotificationService.hasUnreadNotifications(),
          builder: (context, snapshot) {
            final hasUnread = snapshot.data == true;

            return Semantics(
              label: hasUnread ? '읽지 않은 알림 있음' : '알림',
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 30,
                    color: color,
                  ),
                  if (hasUnread)
                    Positioned(
                      top: 0,
                      right: 1,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF05458),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
