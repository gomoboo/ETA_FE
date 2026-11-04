import 'package:flutter/material.dart';

enum ArrivalCheckinStatus { early, onTime, late, checking, disconnected }

class ArrivalCheckinScreen extends StatelessWidget {
  const ArrivalCheckinScreen({
    super.key,
    required this.status,
    required this.nickname,
    required this.placeName,
    required this.meetAt,
    this.arrivedAt,
    this.finalLateMinutes,
    this.allArrived = false,
  });

  final ArrivalCheckinStatus status;
  final String nickname;
  final String placeName;
  final DateTime meetAt;
  final DateTime? arrivedAt;
  final int? finalLateMinutes;
  final bool allArrived;

  static const _navy = Color(0xFF18354A);
  static const _gray = Color(0xFF718696);
  static const _blue = Color(0xFF7DD3F7);
  static const _background = Color(0xFFF7FBFF);

  String _timeText(DateTime? date) {
    if (date == null) return '아직 기록 없음';

    final local = date.toLocal();
    final period = local.hour < 12 ? '오전' : '오후';
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');

    return '$period $hour:$minute';
  }

  String get _title {
    switch (status) {
      case ArrivalCheckinStatus.early:
      case ArrivalCheckinStatus.onTime:
      case ArrivalCheckinStatus.late:
        return '$nickname님이 도착했어요!';
      case ArrivalCheckinStatus.checking:
        return '도착을 확인하고 있어요';
      case ArrivalCheckinStatus.disconnected:
        return '도착을 확인하지 못했어요';
    }
  }

  String get _description {
    switch (status) {
      case ArrivalCheckinStatus.early:
      case ArrivalCheckinStatus.onTime:
        return '약속 장소 30m 반경 안으로 들어와\n자동으로 체크인 되었어요.';
      case ArrivalCheckinStatus.late:
        return allArrived
            ? '30m 반경 진입으로 자동 체크인했어요.\n지각 확정 · 전원 도착 완료'
            : '30m 반경 진입으로 자동 체크인했어요.\n지각이 확정되었어요.';
      case ArrivalCheckinStatus.checking:
        return '위치 정보를 받아 약속 장소\n30m 안에 있는지 확인하고 있어요.';
      case ArrivalCheckinStatus.disconnected:
        return '인터넷 연결이 끊겼어요.\n연결되면 자동으로 다시 확인해요.';
    }
  }

  String get _statusText {
    switch (status) {
      case ArrivalCheckinStatus.early:
        if (arrivedAt == null) return '일찍 도착';
        final minutes = meetAt.difference(arrivedAt!).inMinutes;
        return '${minutes < 0 ? 0 : minutes}분 일찍 도착';
      case ArrivalCheckinStatus.onTime:
        return '정시 도착';
      case ArrivalCheckinStatus.late:
        return finalLateMinutes == null ? '지각 확정' : '$finalLateMinutes분 지각';
      case ArrivalCheckinStatus.checking:
        return '확인 중';
      case ArrivalCheckinStatus.disconnected:
        return '연결 끊김';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isError = status == ArrivalCheckinStatus.disconnected;
    final isChecking = status == ArrivalCheckinStatus.checking;
    final isLate = status == ArrivalCheckinStatus.late;

    final statusColor = isLate
        ? const Color(0xFFB42318)
        : const Color(0xFF16856B);

    final statusBackground = isLate
        ? const Color(0xFFFFECE9)
        : const Color(0xFFE6F6F0);

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 22),
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new),
                    color: const Color(0xFF1685B5),
                    iconSize: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '도착 체크인',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: _navy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 220,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F7FF),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Center(
                          child: Container(
                            width: 146,
                            height: 146,
                            padding: const EdgeInsets.all(21),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: _blue,
                              ),
                              child: Icon(
                                isError
                                    ? Icons.priority_high_rounded
                                    : isChecking
                                    ? Icons.more_horiz
                                    : Icons.check_rounded,
                                color: _navy,
                                size: 58,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 35),
                      Text(
                        _title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: _navy,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.7,
                          color: _gray,
                        ),
                      ),
                      const SizedBox(height: 20),
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
                            Text(
                              placeName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: _navy,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '도착 시간  ${isChecking ? '확인 중' : _timeText(arrivedAt)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: _gray,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '약속 시간  ${_timeText(meetAt)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: _gray,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: isError || isChecking
                                    ? const Color(0xFFE8F7FF)
                                    : statusBackground,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _statusText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isError || isChecking
                                      ? _navy
                                      : statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: _navy,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: const Text(
                    '지도로 돌아가기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
