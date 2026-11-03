import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class FriendInviteScreen extends StatelessWidget {
  const FriendInviteScreen({super.key, required this.detail});

  final Map<String, dynamic> detail;

  static const navy = Color(0xFF18354A);
  static const blue = Color(0xFF1685B5);
  static const sky = Color(0xFF7DD3F7);
  static const gray = Color(0xFF718696);
  static const pale = Color(0xFFEAF7FE);
  static const background = Color(0xFFF7FBFF);

  String get title => detail['title']?.toString() ?? '약속';

  String get inviteUrl => detail['inviteUrl']?.toString().trim() ?? '';

  bool get hasLink {
    final uri = Uri.tryParse(inviteUrl);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  String get inviteCode {
    final direct = detail['inviteCode']?.toString().trim();

    if (direct != null && RegExp(r'^[A-Za-z0-9]{6}$').hasMatch(direct)) {
      return direct;
    }

    final uri = Uri.tryParse(inviteUrl);
    if (uri == null) return '코드 확인 필요';

    final values = [
      uri.queryParameters['inviteCode'],
      uri.queryParameters['invite_code'],
      uri.queryParameters['code'],
      if (uri.pathSegments.isNotEmpty) uri.pathSegments.last,
    ];

    for (final value in values) {
      if (value != null && RegExp(r'^[A-Za-z0-9]{6}$').hasMatch(value)) {
        return value;
      }
    }

    return '코드 확인 필요';
  }

  String get meetingText {
    final date = DateTime.tryParse(detail['meetAt']?.toString() ?? '')
        ?.toLocal();

    if (date == null) return '날짜 · 시간 확인 필요';

    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final period = date.hour < 12 ? '오전' : '오후';

    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '${date.year}. $month. $day · $period $hour:$minute';
  }

  String get placeText {
    final place = detail['targetPlace'];
    if (place is Map) {
      return place['name']?.toString() ?? '장소 확인 필요';
    }
    return '장소 확인 필요';
  }

  String get ruleText {
    final penalty = detail['penalty'];
    if (penalty is! Map) return '규칙 확인 필요';

    if (penalty['type'] == 'FEE') {
      return '지각 1분당 ${penalty['finePerMinute'] ?? 0}원';
    }

    final content = penalty['content']?.toString().trim() ?? '';
    return content.isEmpty ? '지각비 · 벌칙 없음' : content;
  }

  void showNotice(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textAlign: TextAlign.center),
          behavior: SnackBarBehavior.floating,
          backgroundColor: navy,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> copyLink(BuildContext context) async {
    if (!hasLink) return;

    try {
      await Clipboard.setData(ClipboardData(text: inviteUrl));
      if (!context.mounted) return;
      showNotice(context, '✓ 초대 링크를 복사했어요.');
    } catch (error) {
      if (!context.mounted) return;
      showNotice(context, '링크 복사에 실패했어요.');
    }
  }

  Future<void> shareLink(BuildContext context) async {
    if (!hasLink) return;

    try {
      final box = context.findRenderObject() as RenderBox?;

      await SharePlus.instance.share(
        ShareParams(
          text: '$title 약속에 초대할게!\n$inviteUrl',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      showNotice(context, '공유 화면을 열지 못했어요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: navy,
        elevation: 0,
        title: const Text(
          '친구 초대',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '친구를 초대해 보세요',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: navy,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '초대 링크를 친구에게 보내세요.',
                style: TextStyle(fontSize: 13, color: gray),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 30),
                decoration: BoxDecoration(
                  color: pale,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: navy,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      meetingText,
                      style: const TextStyle(fontSize: 13, color: gray),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      placeText,
                      style: const TextStyle(fontSize: 13, color: gray),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      ruleText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: blue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '초대 코드',
                      style: TextStyle(fontSize: 13, color: gray),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      inviteCode,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: navy,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: hasLink ? () => copyLink(context) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sky,
                    foregroundColor: navy,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '링크 복사',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (buttonContext) {
                  return SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: hasLink
                          ? () => shareLink(buttonContext)
                          : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: navy,
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: sky),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        '카카오톡으로 공유',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text(
                '참가자는 참여 전 지각 규칙을 확인하고 동의해요.',
                style: TextStyle(fontSize: 12, color: gray),
              ),
              if (!hasLink) ...[
                const SizedBox(height: 12),
                const Text(
                  '서버에서 초대 링크를 확인하지 못했어요.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFE65A5A)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
