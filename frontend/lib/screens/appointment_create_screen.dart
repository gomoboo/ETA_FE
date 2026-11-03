import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'place_search_screen.dart';
import '../services/eta_api_service.dart';

class AppointmentCreateScreen extends StatefulWidget {
  const AppointmentCreateScreen({super.key});

  @override
  State<AppointmentCreateScreen> createState() =>
      _AppointmentCreateScreenState();
}

class _AppointmentCreateScreenState extends State<AppointmentCreateScreen> {
  static const Color _background = Color(0xFFF7FBFF);
  static const Color _navy = Color(0xFF18354A);
  static const Color _blue = Color(0xFF1685B5);
  static const Color _buttonBlue = Color(0xFF7DD3F7);
  static const Color _border = Color(0xFFD7E5EC);
  static const Color _gray = Color(0xFF7D919F);
  static const Color _selectedBackground = Color(0xFFE2F5FC);

  final TextEditingController _titleController = TextEditingController();

  PlaceResult? _selectedPlace;
  DateTime? _selectedAppointmentDateTime;
  int _locationShareMinutes = 30;

  bool _showValidationErrors = false;
  bool _isCreating = false;
  bool _creationFailed = false;

  bool get _isTitleInvalid =>
      _showValidationErrors && _titleController.text.trim().isEmpty;

  bool get _isPlaceInvalid => _showValidationErrors && _selectedPlace == null;

  bool get _isDateTimeInvalid =>
      _showValidationErrors && _selectedAppointmentDateTime == null;

  bool get _isPenaltyInvalid {
    if (!_showValidationErrors) return false;
    if (_penaltyMode == 'none') return false;

    if (_penaltyMode == 'lateFee') {
      if (_lateFeeOption.isEmpty) return true;

      if (_lateFeeOption == 'custom') {
        return _customLateFeeAmount.trim().isEmpty;
      }

      return false;
    }

    if (_penaltyMode == 'penalty') {
      if (_penaltyOption.isEmpty) return true;

      if (_penaltyOption == 'custom') {
        return _customPenaltyText.trim().isEmpty;
      }

      return false;
    }

    return true;
  }

  String _penaltyMode = 'none';
  String _lateFeeOption = '';
  String _penaltyOption = '';
  String _customPenaltyText = '';
  String _customLateFeeInterval = '1분';
  String _customLateFeeAmount = '';

  String _inviteLink = '';
  static const List<String> _lateFeeIntervals = [
    '1분',
    '5분',
    '10분',
    '30분',
    '1시간',
    '1시간 이상',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // ===============================================================
  // 약속 생성
  // 나중에 백엔드 연동 시 이 함수 내부만 수정
  // ===============================================================

  Future<void> _createAppointment() async {
    if (_isCreating) return;

    setState(() {
      _showValidationErrors = true;
      _creationFailed = false;
    });

    final isValid =
        !_isTitleInvalid &&
        !_isPlaceInvalid &&
        !_isDateTimeInvalid &&
        !_isPenaltyInvalid;

    if (!isValid) return;

    if (_penaltyMode == 'none') {
      _showCreateError(
        '지각 규칙 없음은 서버 지원 확인 후 사용할 수 있어요. '
        '현재는 벌칙 또는 지각비를 선택해 주세요.',
      );
      return;
    }

    final place = _selectedPlace!;
    final meetAt = _selectedAppointmentDateTime!;

    if (!meetAt.isAfter(DateTime.now())) {
      _showCreateError('현재 이후의 약속 시간을 선택해 주세요.');
      return;
    }

    String penaltyType = 'PENALTY';
    String? penaltyContent;
    int finePerMinute = 0;

    if (_penaltyMode == 'lateFee') {
      penaltyType = 'FEE';

      if (_lateFeeOption == 'custom' && _customLateFeeInterval != '1분') {
        _showCreateError(
          '현재 서버는 1분당 지각비만 지원해요. '
          '직접 입력에서 1분을 선택해 주세요.',
        );
        return;
      }

      final amountText = _lateFeeOption == 'custom'
          ? _customLateFeeAmount
          : _lateFeeOption;

      finePerMinute =
          int.tryParse(amountText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

      if (finePerMinute <= 0) {
        _showCreateError('지각비는 0원보다 커야 해요.');
        return;
      }
    } else if (_penaltyMode == 'penalty') {
      final penaltyLabels = {'coffee': '커피 사기', 'snack': '간식 사기'};

      penaltyContent = _penaltyOption == 'custom'
          ? _customPenaltyText.trim()
          : penaltyLabels[_penaltyOption];

      if (penaltyContent == null || penaltyContent.isEmpty) {
        _showCreateError('벌칙을 선택해 주세요.');
        return;
      }
    }

    final radarStartType = switch (_locationShareMinutes) {
      10 => '10M_BEFORE',
      20 => '20M_BEFORE',
      30 => '30M_BEFORE',
      60 => '1H_BEFORE',
      _ => 'CUSTOM',
    };

    final requestBody = <String, dynamic>{
      'title': _titleController.text.trim(),
      'targetPlaceName': place.name,
      'targetAddress': place.address,
      'targetLatitude': place.latitude,
      'targetLongitude': place.longitude,
      'meetAt': meetAt.toUtc().toIso8601String(),
      'radarStartType': radarStartType,
      if (radarStartType == 'CUSTOM')
        'customRadarMinutesBefore': _locationShareMinutes,
      'penaltyType': penaltyType,
      'penaltyContent': penaltyContent,
      'finePerMinute': finePerMinute,
    };

    setState(() {
      _isCreating = true;
    });

    var navigationStarted = false;
    try {
      final response = await EtaApiService.createAppointment(requestBody);

      final appointmentId = response['appointmentId'];

      if (appointmentId is! int) {
        throw const FormatException('서버에서 약속 ID를 확인하지 못했어요.');
      }

      if (!mounted) return;

      Navigator.of(
        context,
      ).pushReplacementNamed('/appointment-detail', arguments: appointmentId);
      navigationStarted = true;
    } catch (error) {
      if (!mounted) return;
      debugPrint('약속 생성 API 오류: $error');
      setState(() {
        _creationFailed = true;
      });
    } finally {
      if (mounted && !navigationStarted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  void _showCreateError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ===============================================================
  // 약속 생성 후 친구 초대 Overlay
  // ===============================================================

  Future<void> _showInviteSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (sheetContext) {
        return Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단 핸들
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7E5EC),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    '약속이 만들어졌어요! 🎉',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    '친구에게 링크를 보내 함께 약속에 참여해보세요.',
                    style: TextStyle(fontSize: 12, color: _gray),
                  ),

                  const SizedBox(height: 26),

                  // 카카오톡 공유
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(sheetContext);

                        await _shareToKakao();

                        if (!mounted) return;

                        _goHomeAfterCreate();
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '카카오톡으로 공유',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 링크 복사
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () async {
                        final copied = await _copyInviteLink();

                        if (!mounted) return;

                        if (copied) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('초대 링크가 복사됐어요.'),
                              duration: Duration(seconds: 2),
                            ),
                          );

                          await Future.delayed(
                            const Duration(milliseconds: 500),
                          );

                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }

                          if (!mounted) return;

                          _goHomeAfterCreate();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('링크 복사에 실패했어요.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _navy,
                        side: const BorderSide(color: _border, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '링크 복사',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 나중에 하기
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);

                        _goHomeAfterCreate();
                      },
                      child: const Text(
                        '나중에 하기',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _gray,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===============================================================
  // 초대 링크 복사
  // 나중에 서버에서 받은 링크로 _inviteLink 값 변경
  // ===============================================================

  Future<bool> _copyInviteLink() async {
    await Clipboard.setData(ClipboardData(text: _inviteLink));

    final copiedData = await Clipboard.getData(Clipboard.kTextPlain);

    return copiedData?.text == _inviteLink;
  }

  // ===============================================================
  // 카카오톡 공유
  // 지금은 UI 동작만 확인
  // ===============================================================

  Future<void> _shareToKakao() async {
    // TODO: 카카오 SDK 연결 후 실제 공유 기능 구현
  }

  // ===============================================================
  // 약속 생성 이후 홈으로 이동
  // ===============================================================

  void _goHomeAfterCreate() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<int?> _showCustomLocationTimePicker() async {
    int selectedMinutes = _locationShareMinutes;

    final controller = FixedExtentScrollController(
      initialItem: selectedMinutes - 1,
    );

    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 330,
            child: Column(
              children: [
                const SizedBox(height: 10),

                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                      },
                      child: const Text('취소', style: TextStyle(color: _gray)),
                    ),

                    const Text(
                      '시간 선택',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _navy,
                      ),
                    ),

                    TextButton(
                      onPressed: () {
                        Navigator.pop(sheetContext, selectedMinutes);
                      },
                      child: const Text(
                        '완료',
                        style: TextStyle(
                          color: _blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const Divider(height: 1),

                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 150,
                      child: CupertinoPicker(
                        scrollController: controller,
                        itemExtent: 42,
                        useMagnifier: true,
                        magnification: 1.12,
                        squeeze: 1.05,
                        selectionOverlay:
                            const CupertinoPickerDefaultSelectionOverlay(),
                        onSelectedItemChanged: (index) {
                          selectedMinutes = index + 1;
                        },
                        children: List.generate(
                          59,
                          (index) => Center(
                            child: Text(
                              '${index + 1}분 전',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: _navy,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<void> _showLocationShareSheet() async {
    final selectedMinutes = await showModalBottomSheet<int>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  const Text(
                    '위치 공유 시작 시간',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _navy,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    '기본값은 약속 30분 전이에요.',
                    style: TextStyle(fontSize: 13, color: _gray),
                  ),

                  const SizedBox(height: 20),

                  ...[
                    (10, '10분 전'),
                    (20, '20분 전'),
                    (30, '30분 전'),
                    (60, '1시간 전'),
                    (0, '직접 설정'),
                  ].map((option) {
                    final isSelected = _locationShareMinutes == option.$1;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: isSelected
                            ? const Color(0xFFEAF7FD)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () async {
                            if (option.$1 == 0) {
                              Navigator.pop(sheetContext);

                              final customMinutes =
                                  await _showCustomLocationTimePicker();

                              if (!mounted || customMinutes == null) return;

                              setState(() {
                                _locationShareMinutes = customMinutes;
                              });
                            } else {
                              Navigator.pop(sheetContext, option.$1);
                            }
                          },
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? _blue : _border,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  option.$2,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: _navy,
                                  ),
                                ),
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  size: 21,
                                  color: isSelected ? _blue : _gray,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || selectedMinutes == null) return;

    setState(() {
      _locationShareMinutes = selectedMinutes;
    });
  }

  Future<void> _showCustomPenaltySheet() async {
    String draftText = _customPenaltyText;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final canApply = draftText.trim().isNotEmpty;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  height: 390,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 핸들
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: _border,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          const Text(
                            '직접 벌칙 만들기',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _navy,
                            ),
                          ),

                          const SizedBox(height: 6),

                          const Text(
                            '친구들이 바로 이해할 수 있게 짧게 적어주세요.',
                            style: TextStyle(fontSize: 12, color: _gray),
                          ),

                          const SizedBox(height: 18),

                          // 직접 입력
                          TextFormField(
                            initialValue: draftText,
                            maxLength: 30,
                            autofocus: true,
                            onChanged: (value) {
                              setModalState(() {
                                draftText = value;
                              });
                            },
                            style: const TextStyle(fontSize: 13, color: _navy),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '예) 지각하면 노래 한 곡 부르기',
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: _gray,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 15,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: _border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: _blue,
                                  width: 1.2,
                                ),
                              ),
                            ),
                          ),

                          const Spacer(),

                          // 적용
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: canApply
                                  ? () {
                                      // 키보드부터 닫기
                                      FocusScope.of(sheetContext).unfocus();

                                      Navigator.pop(
                                        sheetContext,
                                        draftText.trim(),
                                      );
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: _blue,
                                disabledBackgroundColor: const Color(
                                  0xFFDDEBF2,
                                ),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                '적용',
                                style: TextStyle(
                                  fontSize: 14,
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
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _customPenaltyText = result;
        _penaltyOption = 'custom';
      });
    }
  }

  Future<void> _showLateFeeIntervalPicker() async {
    String draftInterval = _customLateFeeInterval;

    final initialIndex = _lateFeeIntervals.indexOf(_customLateFeeInterval);

    final scrollController = FixedExtentScrollController(
      initialItem: initialIndex < 0 ? 0 : initialIndex,
    );

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (sheetContext) {
        return Container(
          height: 300,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 10),

                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                          },
                          child: const Text(
                            '취소',
                            style: TextStyle(color: _gray, fontSize: 14),
                          ),
                        ),
                      ),

                      const Expanded(
                        child: Center(
                          child: Text(
                            '지각 기준 선택',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _navy,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(
                        width: 80,
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(sheetContext, draftInterval);
                          },
                          child: const Text(
                            '완료',
                            style: TextStyle(
                              color: _blue,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: _border),

                Expanded(
                  child: CupertinoPicker(
                    scrollController: scrollController,
                    itemExtent: 44,
                    useMagnifier: true,
                    magnification: 1.1,
                    squeeze: 1.05,
                    onSelectedItemChanged: (index) {
                      draftInterval = _lateFeeIntervals[index];
                    },
                    children: _lateFeeIntervals
                        .map(
                          (item) => Center(
                            child: Text(
                              item,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: _navy,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    scrollController.dispose();

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _customLateFeeInterval = result;
      });
    }
  }

  Future<void> _showCustomLateFeeAmountSheet() async {
    String draftAmount = _customLateFeeAmount;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final canApply = draftAmount.trim().isNotEmpty;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  height: 300,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 핸들
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: _border,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          const Text(
                            '지각비 직접 설정',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _navy,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            '$_customLateFeeInterval 기준으로 적용할 금액을 입력해주세요.',
                            style: const TextStyle(fontSize: 12, color: _gray),
                          ),

                          const SizedBox(height: 18),

                          // 금액 직접 입력
                          TextFormField(
                            initialValue: draftAmount,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(7),
                            ],
                            onChanged: (value) {
                              setModalState(() {
                                draftAmount = value;
                              });
                            },
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _navy,
                            ),
                            decoration: InputDecoration(
                              hintText: '예) 500',
                              hintStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _gray,
                              ),
                              suffixText: '원',
                              suffixStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _gray,
                              ),
                              counterText: '',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 15,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: _border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: _blue,
                                  width: 1.2,
                                ),
                              ),
                            ),
                          ),

                          const Spacer(),

                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: canApply
                                  ? () {
                                      FocusScope.of(sheetContext).unfocus();

                                      Navigator.pop(
                                        sheetContext,
                                        draftAmount.trim(),
                                      );
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: _blue,
                                disabledBackgroundColor: const Color(
                                  0xFFDDEBF2,
                                ),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                '적용',
                                style: TextStyle(
                                  fontSize: 14,
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
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _customLateFeeAmount = result;
        _lateFeeOption = 'custom';
      });
    }
  }

  String _formatLateFeeAmount(String value) {
    final number = int.tryParse(value);

    if (number == null) {
      return value;
    }

    return number.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }

  // ===============================================================
  // 날짜 · 시간 문자열
  // ===============================================================

  String _formatAppointmentDateTime(DateTime dateTime) {
    final isPm = dateTime.hour >= 12;

    int hour = dateTime.hour % 12;

    if (hour == 0) {
      hour = 12;
    }

    final month = dateTime.month.toString().padLeft(2, '0');

    final day = dateTime.day.toString().padLeft(2, '0');

    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '${dateTime.year}. $month. $day / '
        '${isPm ? '오후' : '오전'} $hour:$minute';
  }

  // ===============================================================
  // iPhone 스타일 시/분 휠
  // ===============================================================

  Future<_WheelTimeResult?> _showWheelTimePicker({
    required BuildContext context,
    required int initialHour,
    required int initialMinute,
  }) async {
    int selectedHour = initialHour;
    int selectedMinute = initialMinute;

    final hourController = FixedExtentScrollController(
      initialItem: initialHour - 1,
    );

    final minuteController = FixedExtentScrollController(
      initialItem: initialMinute,
    );

    final result = await showCupertinoModalPopup<_WheelTimeResult>(
      context: context,
      builder: (popupContext) {
        return Container(
          height: 300,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // 상단 핸들
                const SizedBox(height: 10),

                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                const SizedBox(height: 8),

                // 취소 / 제목 / 완료
                SizedBox(
                  height: 50,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            Navigator.pop(popupContext);
                          },
                          child: const Text(
                            '취소',
                            style: TextStyle(fontSize: 14, color: _gray),
                          ),
                        ),
                      ),

                      const Expanded(
                        child: Center(
                          child: Text(
                            '시간 선택',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _navy,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(
                        width: 80,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            Navigator.pop(
                              popupContext,
                              _WheelTimeResult(
                                hour: selectedHour,
                                minute: selectedMinute,
                              ),
                            );
                          },
                          child: const Text(
                            '완료',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _blue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: _border),

                // 시 / 분 휠
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 시간 1 ~ 12
                      SizedBox(
                        width: 90,
                        child: CupertinoPicker(
                          scrollController: hourController,
                          itemExtent: 42,
                          looping: true,
                          useMagnifier: true,
                          magnification: 1.12,
                          squeeze: 1.05,
                          selectionOverlay:
                              const CupertinoPickerDefaultSelectionOverlay(),
                          onSelectedItemChanged: (index) {
                            selectedHour = index + 1;
                          },
                          children: List.generate(12, (index) {
                            return Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: _navy,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          ':',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                        ),
                      ),

                      // 분 00 ~ 59
                      SizedBox(
                        width: 90,
                        child: CupertinoPicker(
                          scrollController: minuteController,
                          itemExtent: 42,
                          looping: true,
                          useMagnifier: true,
                          magnification: 1.12,
                          squeeze: 1.05,
                          selectionOverlay:
                              const CupertinoPickerDefaultSelectionOverlay(),
                          onSelectedItemChanged: (index) {
                            selectedMinute = index;
                          },
                          children: List.generate(60, (index) {
                            return Center(
                              child: Text(
                                index.toString().padLeft(2, '0'),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: _navy,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    hourController.dispose();
    minuteController.dispose();

    return result;
  }

  // ===============================================================
  // 날짜 · 시간 선택 Overlay
  // ===============================================================

  Future<void> _showDateTimeSheet() async {
    DateTime selectedDate = _selectedAppointmentDateTime ?? DateTime.now();

    DateTime visibleMonth = DateTime(selectedDate.year, selectedDate.month);

    bool isPm = selectedDate.hour >= 12;

    int selectedHour12 = selectedDate.hour % 12;

    if (selectedHour12 == 0) {
      selectedHour12 = 12;
    }

    int selectedMinute = selectedDate.minute;

    bool showPastTimeError = false;

    final result = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final firstDay = DateTime(visibleMonth.year, visibleMonth.month, 1);

            final daysInMonth = DateTime(
              visibleMonth.year,
              visibleMonth.month + 1,
              0,
            ).day;

            final leadingEmpty = firstDay.weekday % 7;

            return Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                height: 510,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // =============================================
                        // 핸들
                        // =============================================

                        const SizedBox(height: 12),

                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: _border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        const SizedBox(height: 17),

                        // =============================================
                        // 제목
                        // =============================================
                        const Text(
                          '날짜 · 시간 선택',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // =============================================
                        // 월 이동
                        // =============================================
                        SizedBox(
                          height: 28,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              InkWell(
                                onTap: () {
                                  setModalState(() {
                                    visibleMonth = DateTime(
                                      visibleMonth.year,
                                      visibleMonth.month - 1,
                                    );
                                  });
                                },
                                child: const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: Icon(
                                    Icons.chevron_left_rounded,
                                    size: 17,
                                    color: _navy,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 7),

                              Text(
                                '${visibleMonth.year}년 ${visibleMonth.month}월',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _navy,
                                ),
                              ),

                              const SizedBox(width: 7),

                              InkWell(
                                onTap: () {
                                  setModalState(() {
                                    visibleMonth = DateTime(
                                      visibleMonth.year,
                                      visibleMonth.month + 1,
                                    );
                                  });
                                },
                                child: const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 17,
                                    color: _navy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 6),

                        // =============================================
                        // 달력
                        // =============================================
                        SizedBox(
                          width: double.infinity,
                          height: 171,
                          child: Column(
                            children: [
                              const SizedBox(
                                height: 20,
                                child: Row(
                                  children: [
                                    _CalendarWeekday('일'),
                                    _CalendarWeekday('월'),
                                    _CalendarWeekday('화'),
                                    _CalendarWeekday('수'),
                                    _CalendarWeekday('목'),
                                    _CalendarWeekday('금'),
                                    _CalendarWeekday('토'),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 3),

                              Expanded(
                                child: GridView.builder(
                                  padding: EdgeInsets.zero,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 7,
                                        childAspectRatio: 1.8,
                                      ),
                                  itemCount: leadingEmpty + daysInMonth,
                                  itemBuilder: (context, index) {
                                    if (index < leadingEmpty) {
                                      return const SizedBox();
                                    }

                                    final day = index - leadingEmpty + 1;

                                    final isSelected =
                                        selectedDate.year ==
                                            visibleMonth.year &&
                                        selectedDate.month ==
                                            visibleMonth.month &&
                                        selectedDate.day == day;

                                    return InkWell(
                                      onTap: () {
                                        setModalState(() {
                                          selectedDate = DateTime(
                                            visibleMonth.year,
                                            visibleMonth.month,
                                            day,
                                            selectedDate.hour,
                                            selectedDate.minute,
                                          );
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Center(
                                        child: Container(
                                          width: 30,
                                          height: 30,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? _selectedBackground
                                                : Colors.transparent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '$day',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w400,
                                              color: isSelected ? _blue : _navy,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        const Divider(height: 1, thickness: 1, color: _border),

                        const SizedBox(height: 18),

                        // =============================================
                        // 시간
                        // =============================================
                        const Text(
                          '시간',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // =============================================
                        // 오전 / 오후 / 시간
                        // =============================================
                        Row(
                          children: [
                            SizedBox(
                              width: 80,
                              child: _timeChoiceButton(
                                label: '오전',
                                selected: !isPm,
                                onTap: () {
                                  setModalState(() {
                                    isPm = false;
                                  });
                                },
                              ),
                            ),

                            const SizedBox(width: 10),

                            SizedBox(
                              width: 80,
                              child: _timeChoiceButton(
                                label: '오후',
                                selected: isPm,
                                onTap: () {
                                  setModalState(() {
                                    isPm = true;
                                  });
                                },
                              ),
                            ),

                            const SizedBox(width: 12),

                            // =========================================
                            // 시간 선택창
                            // =========================================
                            InkWell(
                              onTap: () async {
                                final picked = await _showWheelTimePicker(
                                  context: context,
                                  initialHour: selectedHour12,
                                  initialMinute: selectedMinute,
                                );

                                if (picked != null) {
                                  setModalState(() {
                                    selectedHour12 = picked.hour;

                                    selectedMinute = picked.minute;
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 160,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _border, width: 1),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$selectedHour12',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _navy,
                                      ),
                                    ),

                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text(
                                        ':',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: _navy,
                                        ),
                                      ),
                                    ),

                                    Text(
                                      selectedMinute.toString().padLeft(2, '0'),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _navy,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // =============================================
                        // 취소 / 선택 완료
                        // =============================================
                        Row(
                          children: [
                            SizedBox(
                              width: 160,
                              height: 44,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  side: const BorderSide(
                                    color: _border,
                                    width: 1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  '취소',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _navy,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 22),

                            SizedBox(
                              width: 160,
                              height: 44,
                              child: ElevatedButton(
                                onPressed: () {
                                  int hour24;

                                  if (isPm) {
                                    hour24 = selectedHour12 == 12
                                        ? 12
                                        : selectedHour12 + 12;
                                  } else {
                                    hour24 = selectedHour12 == 12
                                        ? 0
                                        : selectedHour12;
                                  }

                                  final appointmentDateTime = DateTime(
                                    selectedDate.year,
                                    selectedDate.month,
                                    selectedDate.day,
                                    hour24,
                                    selectedMinute,
                                  );

                                  if (appointmentDateTime.isBefore(
                                    DateTime.now(),
                                  )) {
                                    setModalState(() {
                                      showPastTimeError = true;
                                    });
                                    return;
                                  }

                                  Navigator.pop(
                                    sheetContext,
                                    appointmentDateTime,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  elevation: 0,
                                  backgroundColor: _blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  '선택 완료',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        SizedBox(
                          height: 24,
                          child: Center(
                            child: Visibility(
                              visible: showPastTimeError,
                              maintainSize: true,
                              maintainAnimation: true,
                              maintainState: true,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 15,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    '현재 시간 이후로 설정해 주세요.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 0),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedAppointmentDateTime = result;
      });
    }
  }

  // ===============================================================
  // 오전 / 오후 버튼
  // ===============================================================

  Widget _timeChoiceButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _blue : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? _blue : _border, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : _navy,
          ),
        ),
      ),
    );
  }

  // ===============================================================

  bool _allowExitFromCreate = false;
  bool _exitDialogOpen = false;

  Future<void> _confirmCancelCreate() async {
    if (!mounted || _exitDialogOpen || _isCreating) return;

    _exitDialogOpen = true;

    try {
      final shouldCancel = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierColor: const Color(0x660D2535),
        builder: (dialogContext) {
          return Dialog(
            backgroundColor: Colors.white,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '작성을 취소할까요?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF19364C),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '지금 나가면 작성한 내용이 사라져요.\n'
                    '계속 작성하거나 취소할 수 있어요.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7B94A6),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop(false);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF19364C),
                              side: const BorderSide(color: Color(0xFFD9EBF6)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              '계속 작성',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop(true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7BD0F4),
                              foregroundColor: const Color(0xFF19364C),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              '작성 취소',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (!mounted || shouldCancel != true) return;

      // 실제 화면을 떠날 때만 뒤로가기를 허용
      setState(() {
        _allowExitFromCreate = true;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    } finally {
      _exitDialogOpen = false;
    }
  }

  // 메인 화면
  // ===============================================================

  @override
  Widget build(BuildContext context) {
    // 피그마 기준 높이 844dp. 긴 화면의 추가 공간만 분배.
    final double extraGap = ((MediaQuery.of(context).size.height - 844.0) / 4.0)
        .clamp(0.0, 20.0)
        .toDouble();

    return PopScope(
      canPop: _allowExitFromCreate,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_allowExitFromCreate) {
          _confirmCancelCreate();
        }
      },
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Column(
            children: [
              // 상단 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
                child: Row(
                  children: [
                    InkWell(
                      onTap: _confirmCancelCreate,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: _blue,
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    const Text(
                      '약속 만들기',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _isCreating
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 42,
                              height: 42,
                              child: CircularProgressIndicator(
                                strokeWidth: 4,
                                color: Color(0xFFA6BAC6),
                              ),
                            ),
                            SizedBox(height: 18),
                            Text(
                              '약속을 만들고 있어요',
                              style: TextStyle(
                                color: Color(0xFF51697A),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 약속 이름
                            _sectionLabel('약속 이름'),

                            const SizedBox(height: 8),

                            TextField(
                              controller: _titleController,
                              onChanged: (_) {
                                if (_showValidationErrors) {
                                  setState(() {});
                                }
                              },
                              style: const TextStyle(
                                fontSize: 13,
                                color: _navy,
                              ),
                              decoration: _inputDecoration().copyWith(
                                constraints: const BoxConstraints.tightFor(
                                  height: 51,
                                ),
                                isDense: true,
                                hintText: '약속 이름을 입력해 주세요',
                                hintStyle: const TextStyle(
                                  fontSize: 13,
                                  color: _gray,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide(
                                    color: _isTitleInvalid
                                        ? const Color(0xFF1685B5)
                                        : _border,
                                    width: _isTitleInvalid ? 1.5 : 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide(
                                    color: _isTitleInvalid
                                        ? const Color(0xFF1685B5)
                                        : _blue,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(
                              height: 26 + extraGap * 0.4,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _isTitleInvalid ? '약속 이름을 입력해 주세요.' : '',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF1685B5),
                                  ),
                                ),
                              ),
                            ),

                            // 약속 장소
                            _sectionLabel('약속 장소'),

                            const SizedBox(height: 8),

                            _tapField(
                              hasError: _isPlaceInvalid,
                              icon: Icons.search_rounded,
                              text: _selectedPlace?.name ?? '장소 검색',
                              textColor: _selectedPlace == null ? _gray : _navy,
                              trailing: const Icon(
                                Icons.location_on_outlined,
                                size: 21,
                                color: _blue,
                              ),
                              onTap: () async {
                                final result = await Navigator.of(context)
                                    .push<PlaceResult>(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const PlaceSearchScreen(),
                                      ),
                                    );

                                if (result != null) {
                                  setState(() {
                                    _selectedPlace = result;
                                  });
                                }
                              },
                            ),

                            // 약속 장소 미입력 경고
                            SizedBox(
                              height: 26 + extraGap * 0.4,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _isPlaceInvalid ? '약속 장소를 선택해 주세요.' : '',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF1685B5),
                                  ),
                                ),
                              ),
                            ),

                            // 날짜 · 시간
                            _sectionLabel('날짜 · 시간'),

                            const SizedBox(height: 8),

                            _tapField(
                              hasError: _isDateTimeInvalid,
                              text: _selectedAppointmentDateTime == null
                                  ? '날짜 설정 / 시간 설정'
                                  : _formatAppointmentDateTime(
                                      _selectedAppointmentDateTime!,
                                    ),
                              textColor: _selectedAppointmentDateTime == null
                                  ? _gray
                                  : _navy,
                              trailing: const Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                                color: _gray,
                              ),
                              onTap: _showDateTimeSheet,
                            ),

                            // 날짜·시간 미입력 경고
                            SizedBox(
                              height: 26 + extraGap * 0.4,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _isDateTimeInvalid
                                      ? '현재 이후의 날짜와 시간을 선택해 주세요.'
                                      : '',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF1685B5),
                                  ),
                                ),
                              ),
                            ),

                            // 위치 공유
                            _sectionLabel('위치 공유 시작'),

                            const SizedBox(height: 8),

                            _tapField(
                              height: 35,
                              radius: 14,
                              text: _locationShareMinutes == 60
                                  ? '약속 1시간 전'
                                  : '약속 $_locationShareMinutes분 전',
                              textColor: _navy,
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                                size: 19,
                                color: _gray,
                              ),
                              onTap: _showLocationShareSheet,
                            ),

                            SizedBox(height: 16 + extraGap),

                            // 페널티 설정
                            // 페널티 설정
                            _sectionLabel('지각 규칙'),

                            const SizedBox(height: 9),

                            Row(
                              children: [
                                _figmaRuleChoice(
                                  height: 48,
                                  radius: 14,
                                  label: '벌칙',
                                  selected: _penaltyMode == 'penalty',
                                  onTap: () {
                                    setState(() {
                                      _penaltyMode = 'penalty';
                                      if (_penaltyOption.isEmpty) {
                                        _penaltyOption = 'coffee';
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                _figmaRuleChoice(
                                  height: 48,
                                  radius: 14,
                                  label: '지각비',
                                  selected: _penaltyMode == 'lateFee',
                                  onTap: () {
                                    setState(() {
                                      _penaltyMode = 'lateFee';
                                      if (_lateFeeOption.isEmpty) {
                                        _lateFeeOption = '1000';
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                _figmaRuleChoice(
                                  height: 48,
                                  radius: 14,
                                  label: '없음',
                                  selected: _penaltyMode == 'none',
                                  onTap: () {
                                    setState(() {
                                      _penaltyMode = 'none';
                                    });
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            if (_penaltyMode == 'none')
                              _figmaRuleSummary('지각비 · 벌칙 없음'),

                            if (_penaltyMode == 'lateFee')
                              _lateFeeOptions()
                            else if (_penaltyMode == 'penalty')
                              _penaltyOptions(),

                            const SizedBox(height: 18),
                          ],
                        ),
                      ),
              ),
              if (!_isCreating && _creationFailed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 18,
                        color: Color(0xFFFF5D5D),
                      ),
                      const SizedBox(width: 7),
                      const Expanded(
                        child: Text(
                          '약속을 생성하지 못했어요. 연결을 확인하고 다시 시도해 주세요.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFFF5D5D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!_isCreating)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _createAppointment,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: _buttonBlue,
                        foregroundColor: _navy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _isCreating ? '약속을 만들고 있어요' : '약속 만들기',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ===============================================================
  // 지각비 옵션
  // ===============================================================

  Future<String?> _showCustomRuleSheet({
    required String title,
    required String description,
    required String hint,
    required String note,
    required String initialText,
    required bool isFee,
  }) async {
    var draftValue = initialText;

    return await showModalBottomSheet<String>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, refresh) {
            final value = draftValue.trim();
            final valid = isFee
                ? RegExp(r'^[0-9]+$').hasMatch(value) &&
                      (int.tryParse(value) ?? 0) > 0
                : value.isNotEmpty;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 5,
                            decoration: BoxDecoration(
                              color: const Color(0xFFC6D1D8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF19364C),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8099AA),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          initialValue: initialText,
                          keyboardType: isFee
                              ? TextInputType.number
                              : TextInputType.text,
                          maxLines: 1,
                          onChanged: (text) {
                            refresh(() {
                              draftValue = text;
                            });
                          },
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF19364C),
                          ),
                          decoration: InputDecoration(
                            hintText: hint,
                            hintStyle: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFFA1B3C1),
                            ),
                            suffixIcon: isFee
                                ? const Padding(
                                    padding: EdgeInsets.only(right: 14),
                                    child: Center(
                                      widthFactor: 1,
                                      child: Text(
                                        '원/분',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1685B5),
                                        ),
                                      ),
                                    ),
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFFF7FBFF),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 16,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE4F1F9),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF66C9F4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          note,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8099AA),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(sheetContext).pop();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF19364C),
                                    side: const BorderSide(
                                      color: Color(0xFFE1EFF8),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text('취소'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: valid
                                      ? () {
                                          Navigator.of(sheetContext).pop(value);
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    disabledBackgroundColor: const Color(
                                      0xFF7BD0F4,
                                    ),
                                    disabledForegroundColor: const Color(
                                      0xFF19364C,
                                    ),
                                    backgroundColor: const Color(0xFF7BD0F4),
                                    foregroundColor: const Color(0xFF19364C),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text('적용'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openCustomPenaltySheet() async {
    final result = await _showCustomRuleSheet(
      title: '벌칙 직접 입력',
      description: '친구들이 이해하기 쉽게 짧게 적어 주세요.',
      hint: '예: 다음 약속에 커피 사기',
      note: '입력한 벌칙이 약속의 지각 규칙으로 적용돼요.',
      initialText: _customPenaltyText,
      isFee: false,
    );

    if (!mounted || result == null) return;

    setState(() {
      _customPenaltyText = result;
      _penaltyOption = 'custom';
    });
  }

  Future<void> _openCustomLateFeeSheet() async {
    final result = await _showCustomRuleSheet(
      title: '지각비 직접 입력',
      description: '지각 1분마다 적용할 금액을 입력해 주세요.',
      hint: '금액 입력',
      note: '0원은 입력할 수 없어요. 비용이 없으면 ‘없음’을 선택해 주세요.',
      initialText: _customLateFeeAmount,
      isFee: true,
    );

    if (!mounted || result == null) return;

    setState(() {
      _customLateFeeAmount = result;
      _customLateFeeInterval = '1분';
      _lateFeeOption = 'custom';
    });
  }

  Widget _figmaRuleChoice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    double height = 40,
    double radius = 12,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE7F6FE) : Colors.white,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected
                  ? const Color(0xFF7DD3F7)
                  : const Color(0xFFE5F2FA),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected
                  ? const Color(0xFF1685B5)
                  : const Color(0xFF718696),
            ),
          ),
        ),
      ),
    );
  }

  Widget _figmaRuleSummary(String message) {
    return Container(
      width: double.infinity,
      height: 42,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7FE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF1685B5),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _lateFeeOptions() {
    final summary = switch (_lateFeeOption) {
      '500' => '지각 1분당 500원',
      '1000' => '지각 1분당 1,000원',
      'custom' =>
        _customLateFeeAmount.trim().isEmpty
            ? '지각비 금액을 입력해 주세요.'
            : '지각 1분당 ${_customLateFeeAmount.trim()}원',
      _ => '1분당 금액을 선택해 주세요.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _sectionLabel('1분당 금액'),
        const SizedBox(height: 9),
        Row(
          children: [
            _figmaRuleChoice(
              label: '500원',
              selected: _lateFeeOption == '500',
              onTap: () => setState(() {
                _lateFeeOption = '500';
              }),
            ),
            const SizedBox(width: 8),
            _figmaRuleChoice(
              label: '1,000원',
              selected: _lateFeeOption == '1000',
              onTap: () => setState(() {
                _lateFeeOption = '1000';
              }),
            ),
            const SizedBox(width: 8),
            _figmaRuleChoice(
              label: '직접 입력',
              selected: _lateFeeOption == 'custom',
              onTap: _openCustomLateFeeSheet,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _figmaRuleSummary(summary),
      ],
    );
  }

  Widget _customLateFeeDisplayField() {
    final intervalLabel = _customLateFeeInterval == '1시간 이상'
        ? '1시간 이상'
        : '$_customLateFeeInterval당';

    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              _showValidationErrors &&
                  _penaltyMode == 'lateFee' &&
                  _lateFeeOption == 'custom' &&
                  _customLateFeeAmount.trim().isEmpty
              ? Colors.red
              : _border,
          width:
              _showValidationErrors &&
                  _penaltyMode == 'lateFee' &&
                  _lateFeeOption == 'custom' &&
                  _customLateFeeAmount.trim().isEmpty
              ? 1.5
              : 1,
        ),
      ),
      child: Row(
        children: [
          // 왼쪽: 지각 시간 기준
          Expanded(
            flex: 4,
            child: InkWell(
              onTap: _showLateFeeIntervalPicker,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        intervalLabel,
                        style: const TextStyle(fontSize: 12, color: _gray),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 17,
                      color: _gray,
                    ),
                  ],
                ),
              ),
            ),
          ),

          Container(width: 1, height: 24, color: _border),

          // 오른쪽: 금액
          Expanded(
            flex: 5,
            child: InkWell(
              onTap: _showCustomLateFeeAmountSheet,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _customLateFeeAmount.isEmpty
                            ? '금액 입력'
                            : _formatLateFeeAmount(_customLateFeeAmount),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _customLateFeeAmount.isEmpty
                              ? FontWeight.w500
                              : FontWeight.w700,
                          color: _customLateFeeAmount.isEmpty ? _gray : _navy,
                        ),
                      ),
                    ),

                    const Text(
                      '원',
                      style: TextStyle(fontSize: 12, color: _gray),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // 벌칙 옵션
  // ===============================================================

  Widget _penaltyOptions() {
    final summary = switch (_penaltyOption) {
      'coffee' => '지각한 사람은 커피 사기',
      'snack' => '지각한 사람은 간식 사기',
      'custom' =>
        _customPenaltyText.trim().isEmpty
            ? '벌칙을 직접 입력해 주세요.'
            : '지각한 사람은 ${_customPenaltyText.trim()}',
      _ => '벌칙을 선택해 주세요.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _sectionLabel('벌칙 선택'),
        const SizedBox(height: 9),
        Row(
          children: [
            _figmaRuleChoice(
              label: '커피 사기',
              selected: _penaltyOption == 'coffee',
              onTap: () => setState(() {
                _penaltyOption = 'coffee';
              }),
            ),
            const SizedBox(width: 8),
            _figmaRuleChoice(
              label: '간식 사기',
              selected: _penaltyOption == 'snack',
              onTap: () => setState(() {
                _penaltyOption = 'snack';
              }),
            ),
            const SizedBox(width: 8),
            _figmaRuleChoice(
              label: '직접 입력',
              selected: _penaltyOption == 'custom',
              onTap: _openCustomPenaltySheet,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _figmaRuleSummary(summary),
      ],
    );
  }

  Widget _customPenaltyDisplayField() {
    return InkWell(
      onTap: () {
        _showCustomPenaltySheet();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                _showValidationErrors &&
                    _penaltyMode == 'penalty' &&
                    _penaltyOption == 'custom' &&
                    _customPenaltyText.trim().isEmpty
                ? Colors.red
                : _border,
            width:
                _showValidationErrors &&
                    _penaltyMode == 'penalty' &&
                    _penaltyOption == 'custom' &&
                    _customPenaltyText.trim().isEmpty
                ? 1.5
                : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _customPenaltyText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _navy,
                ),
              ),
            ),

            const SizedBox(width: 8),

            const Icon(Icons.edit_outlined, size: 18, color: _gray),
          ],
        ),
      ),
    );
  }

  Widget _penaltyChip({required String label, required String value}) {
    final selected = _penaltyOption == value;

    final hasError =
        _showValidationErrors &&
        _penaltyMode == 'penalty' &&
        _penaltyOption.isEmpty;

    return InkWell(
      onTap: () async {
        if (value == 'custom') {
          setState(() {
            _penaltyOption = 'custom';
          });

          await _showCustomPenaltySheet();
          return;
        }

        setState(() {
          _penaltyOption = value;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          color: selected ? _selectedBackground : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasError
                ? Colors.red
                : selected
                ? _selectedBackground
                : _border,
            width: hasError ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 13,
              color: selected ? _blue : _gray,
            ),

            const SizedBox(width: 3),

            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? _blue : _gray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===============================================================
  // 공통 선택 버튼
  // ===============================================================

  Widget _choiceButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool hasError = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _selectedBackground : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasError
                ? Colors.red
                : selected
                ? _selectedBackground
                : _border,
            width: hasError ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 14,
              color: selected ? _blue : _gray,
            ),

            const SizedBox(width: 4),

            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? _blue : _gray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallChoice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool hasError = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _selectedBackground : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasError
                ? Colors.red
                : selected
                ? _selectedBackground
                : _border,
            width: hasError ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 12,
              color: selected ? _blue : _gray,
            ),

            const SizedBox(width: 3),

            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? _blue : _gray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===============================================================
  // 공통 UI
  // ===============================================================

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: _navy,
      ),
    );
  }

  Widget _tapField({
    IconData? icon,
    required String text,
    required Widget trailing,
    required VoidCallback onTap,
    Color textColor = _gray,
    bool hasError = false,
    double height = 51,
    double radius = 18,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: hasError ? const Color(0xFF1685B5) : _border,
            width: hasError ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19, color: _gray),
              const SizedBox(width: 9),
            ],

            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 12, color: textColor),
              ),
            ),

            trailing,
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _blue, width: 1.2),
      ),
    );
  }
}

// ===============================================================
// 달력 요일
// ===============================================================

class _CalendarWeekday extends StatelessWidget {
  final String text;

  const _CalendarWeekday(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontSize: 10, color: Color(0xFF7D919F)),
        ),
      ),
    );
  }
}

// ===============================================================
// 휠 시간 선택 결과
// ===============================================================

class _WheelTimeResult {
  final int hour;
  final int minute;

  const _WheelTimeResult({required this.hour, required this.minute});
}
