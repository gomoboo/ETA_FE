import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

enum WarrantPenaltyMode { none, fee, penalty }

class WarrantDisplayData {
  const WarrantDisplayData({
    required this.defendant,
    required this.charge,
    required this.lateMinutes,
    required this.verdict,
    required this.penaltyMode,
    this.feeAmount,
    this.penaltyContent,
    this.finalPenalty = '',
    this.shareCardImageUrl,
    this.shareLinkUrl,
  });

  final String defendant;
  final String charge;
  final int lateMinutes;
  final String verdict;
  final WarrantPenaltyMode penaltyMode;
  final int? feeAmount;
  final String? penaltyContent;
  final String finalPenalty;
  final String? shareCardImageUrl;
  final String? shareLinkUrl;

  factory WarrantDisplayData.fromApi(
    Map<String, dynamic> json, {
    required WarrantPenaltyMode penaltyMode,
  }) {
    final minutes = json['lateMinutes'];
    if (minutes is! num) {
      throw const FormatException('영장 지각 시간 데이터가 올바르지 않습니다.');
    }

    return WarrantDisplayData(
      defendant: json['defendantNickname']?.toString() ?? '확인 필요',
      charge: json['chargeTitle']?.toString() ?? '확인 필요',
      lateMinutes: minutes.toInt(),
      verdict: json['judgmentText']?.toString() ?? '확인 필요',
      penaltyMode: penaltyMode,
      finalPenalty: json['finalPenalty']?.toString() ?? '결과 확인 필요',
      shareCardImageUrl: json['shareCardImageUrl']?.toString(),
      shareLinkUrl: json['shareLinkUrl']?.toString(),
    );
  }
}

class AppointmentWarrantScreen extends StatefulWidget {
  const AppointmentWarrantScreen({super.key, required this.warrants});

  final List<WarrantDisplayData> warrants;

  @override
  State<AppointmentWarrantScreen> createState() =>
      _AppointmentWarrantScreenState();
}

class _AppointmentWarrantScreenState extends State<AppointmentWarrantScreen> {
  static const _navy = Color(0xFF18354A);
  static const _blue = Color(0xFF1685B5);
  static const _sky = Color(0xFF7DD3F7);
  static const _background = Color(0xFFF7FBFF);
  static const _gray = Color(0xFF718696);

  int _currentIndex = 0;

  final GlobalKey _warrantCardKey = GlobalKey();

  String _lateTime(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours == 0) return '$remainingMinutes분';
    if (remainingMinutes == 0) return '$hours시간';

    return '$hours시간 $remainingMinutes분';
  }

  String _money(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
  }

  Widget _informationBlock(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: _gray)),
        const SizedBox(height: 7),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _navy,
          ),
        ),
      ],
    );
  }

  Widget _penaltyResult(WarrantDisplayData warrant) {
    String title;
    String fallback;

    switch (warrant.penaltyMode) {
      case WarrantPenaltyMode.none:
        title = '선택한 규칙에 따른 결과';
        fallback = '지각비 · 벌칙 없음';
      case WarrantPenaltyMode.fee:
        title = '최종 지각비';
        fallback = warrant.feeAmount == null
            ? '지각비 확인 필요'
            : '${_money(warrant.feeAmount!)}원';
      case WarrantPenaltyMode.penalty:
        title = '최종 벌칙';
        fallback = warrant.penaltyContent ?? '벌칙 확인 필요';
    }

    final result = warrant.finalPenalty.trim().isNotEmpty
        ? warrant.finalPenalty
        : fallback;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFDEBE8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB43635),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            result,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: _navy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _warrantCard(WarrantDisplayData warrant) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 20, 26, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFD8E9F2), width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'LATENESS WARRANT',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFFB43635),
              ),
            ),
          ),
          const SizedBox(height: 9),
          const Center(
            child: Text(
              '지각 체포 영장',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: _navy,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFD8E9F2)),
          const SizedBox(height: 18),
          _informationBlock('피고인', warrant.defendant),
          const SizedBox(height: 10),
          _informationBlock('죄목', warrant.charge),
          const SizedBox(height: 10),
          _informationBlock('지각 시간', _lateTime(warrant.lateMinutes)),
          const SizedBox(height: 10),
          _informationBlock(
            '판결',
            warrant.penaltyMode == WarrantPenaltyMode.none
                ? '지각비·벌칙 없음'
                : '약속 시간 ${_lateTime(warrant.lateMinutes)} 초과 검거',
          ),
          const SizedBox(height: 16),
          _penaltyResult(warrant),
        ],
      ),
    );
  }

  void _nextWarrant() {
    if (widget.warrants.length <= 1) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('다른 영장이 없어요.')));
      return;
    }

    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.warrants.length;
    });
  }


  Future<void> _saveWarrantImage() async {
    try {
      final renderObject =
          _warrantCardKey.currentContext?.findRenderObject();

      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('영장 카드 영역을 찾을 수 없습니다.');
      }

      final image = await renderObject.toImage(pixelRatio: 2.0);

      try {
        final byteData = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );

        if (byteData == null) {
          throw StateError('이미지를 생성하지 못했습니다.');
        }

        final bytes = byteData.buffer.asUint8List();

        await Gal.putImageBytes(
          bytes,
          name: 'ETA_Warrant_${DateTime.now().millisecondsSinceEpoch}',
        );
      } finally {
        image.dispose();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('영장 이미지가 사진 앱에 저장됐어요.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이미지를 저장하지 못했어요. 사진 접근 권한을 확인해 주세요.'),
        ),
      );
      debugPrint('영장 이미지 저장 오류: $error');
    }
  }

  Future<void> _copyWarrantLink() async {
    final link = widget.warrants[_currentIndex].shareLinkUrl?.trim();

    if (link == null || link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이 영장에 제공된 공유 링크가 없어요.')),
      );
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: link));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('영장 링크를 복사했어요.')),
      );
    } catch (error) {
      debugPrint('영장 링크 복사 실패: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('링크를 복사하지 못했어요.')),
      );
    }
  }

  Future<void> _shareWarrantImage() async {
    try {
      final renderObject =
          _warrantCardKey.currentContext?.findRenderObject();

      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('영장 카드 영역을 찾을 수 없습니다.');
      }

      final image = await renderObject.toImage(pixelRatio: 2.0);

      late final Uint8List bytes;

      try {
        final byteData = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );

        if (byteData == null) {
          throw StateError('영장 이미지를 생성하지 못했습니다.');
        }

        bytes = byteData.buffer.asUint8List();
      } finally {
        image.dispose();
      }

      if (!mounted) return;

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
            ),
          ],
          fileNameOverrides: ['ETA_Warrant.png'],
        ),
      );
    } catch (error) {
      debugPrint('영장 이미지 공유 실패: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('영장 이미지를 공유하지 못했어요.'),
        ),
      );
    }
  }

  void _showShareSheet() {
    Widget shareOption(String title, String message, {VoidCallback? onTap}) {
      return SizedBox(
        width: double.infinity,
        height: 58,
        child: OutlinedButton(
          onPressed: () {
            Navigator.of(context).pop();
            if (onTap != null) {
              onTap();
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          },
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _navy,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            side: const BorderSide(
              color: Color(0xFFD8E9F2),
              width: 1.3,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _navy,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 22,
                color: Color(0xFF718696),
              ),
            ],
          ),
        ),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (sheetContext) {
        return Container(
          height: MediaQuery.sizeOf(sheetContext).height * 0.46,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCEAF2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    '지각 체포 영장 공유',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 44),
                  shareOption(
                    '카카오톡으로 공유',
                    '카카오톡 공유 기능 연결이 필요해요.',
                    onTap: _shareWarrantImage,
                  ),
                  const SizedBox(height: 14),
                  shareOption(
                    '이미지 저장',
                    '이미지 저장 기능 연결이 필요해요.',
                    onTap: _saveWarrantImage,
                  ),
                  const SizedBox(height: 14),
                  shareOption(
                    '링크 복사',
                    '영장 링크 복사 기능 연결이 필요해요.',
                    onTap: _copyWarrantLink,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.warrants.isEmpty) {
      return Scaffold(
        backgroundColor: _background,
        appBar: AppBar(title: const Text('지각 체포 영장')),
        body: const Center(child: Text('발급된 영장이 없어요.')),
      );
    }

    final warrant = widget.warrants[_currentIndex];

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _navy,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 72,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: _blue),
        ),
        title: const Text(
          '지각 체포 영장',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _navy,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: RepaintBoundary(
                          key: _warrantCardKey,
                          child: _warrantCard(warrant),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _nextWarrant,
                child: const Text(
                  '다른 영장 보기',
                  style: TextStyle(fontSize: 15, color: _blue),
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _showShareSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _sky,
                    foregroundColor: _navy,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: const Text(
                    '이 영장 공유하기',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
