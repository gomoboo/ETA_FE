import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/guest_identity_service.dart';
import '../services/location_tracking_service.dart';

class MyTabScreen extends StatefulWidget {
  const MyTabScreen({super.key});

  @override
  State<MyTabScreen> createState() => _MyTabScreenState();
}

class _MyTabScreenState extends State<MyTabScreen> {
  static const _background = Color(0xFFF7FBFF);
  static const _navy = Color(0xFF18354A);
  static const _gray = Color(0xFF607280);
  static const _blue = Color(0xFF7DD3F7);
  static const _accent = Color(0xFF1577A5);

  final TextEditingController _nicknameController = TextEditingController();

  String _nickname = '';
  String? _nicknameError;
  bool _editing = false;
  bool _consent = false;
  bool _loading = true;
  bool _savingNickname = false;
  bool _savingConsent = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final nickname = await GuestIdentityService.getNickname();
      final consent = await LocationTrackingService.isConsentGranted();

      if (!mounted) return;

      setState(() {
        _nickname = nickname ?? '';
        _nicknameController.text = _nickname;
        _consent = consent;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('설정을 불러오지 못했어요.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveNickname() async {
    final nickname = _nicknameController.text.trim();

    if (nickname.length < 2 || nickname.length > 10) {
      setState(() {
        _nicknameError = '닉네임은 2~10자로 입력해 주세요.';
      });
      return;
    }

    if (_savingNickname) return;
    setState(() => _savingNickname = true);

    try {
      await GuestIdentityService.saveNickname(nickname);

      if (!mounted) return;

      setState(() {
        _nickname = nickname;
        _editing = false;
        _nicknameError = null;
      });

      _showMessage('기기에 닉네임을 저장했어요.');
    } catch (_) {
      if (mounted) _showMessage('닉네임을 저장하지 못했어요.');
    } finally {
      if (mounted) setState(() => _savingNickname = false);
    }
  }

  Future<void> _changeConsent(bool value) async {
    if (_savingConsent) return;
    setState(() => _savingConsent = true);

    try {
      if (value) {
        final enabled = await Geolocator.isLocationServiceEnabled();
        if (!enabled) {
          if (mounted) _showMessage('기기의 위치 서비스를 켜주세요.');
          return;
        }

        var permission = await Geolocator.checkPermission();

        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (mounted) _showMessage('위치 권한을 허용해야 동의할 수 있어요.');
          return;
        }
      }

      await LocationTrackingService.setConsentGranted(value);

      if (!mounted) return;

      setState(() => _consent = value);
      _showMessage(value ? '위치 정보 이용에 동의했어요.' : '위치 동의를 해제하고 GPS 수집을 중단했어요.');
    } catch (_) {
      if (mounted) _showMessage('위치 동의 설정을 변경하지 못했어요.');
    } finally {
      if (mounted) setState(() => _savingConsent = false);
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Widget _nicknameCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('닉네임', style: TextStyle(fontSize: 14, color: _gray)),
                const SizedBox(height: 14),
                Text(
                  _nickname.isEmpty ? '닉네임 없음' : _nickname,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              setState(() {
                if (_editing) {
                  _nicknameController.text = _nickname;
                }
                _editing = !_editing;
                _nicknameError = null;
              });
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFEAF7FE),
              foregroundColor: _accent,
              side: const BorderSide(color: _blue),
              padding: const EdgeInsets.symmetric(
                horizontal: 21.9,
                vertical: 12.2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11.3),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: 0,
                  child: Text(
                    '닉네임 변경',
                    style: const TextStyle(
                      fontSize: 14.6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  _editing ? '취소' : '닉네임 변경',
                  style: const TextStyle(
                    fontSize: 14.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nicknameEditor() {
    const nicknameAccent = Color(0xFF1577A5);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: TextField(
                    controller: _nicknameController,
                    maxLength: 10,
                    scrollPadding: const EdgeInsets.only(bottom: 120),
                    style: const TextStyle(fontSize: 16, color: _navy),
                    onChanged: (value) {
                      final error = value.trim().length == 1
                          ? '닉네임은 2~10자로 입력해 주세요.'
                          : null;

                      if (_nicknameError != error) {
                        setState(() => _nicknameError = error);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: '2~10자 닉네임',
                      counterText: '',
                      isDense: true,
                      filled: true,
                      fillColor: _background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD5EAF3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _nicknameError != null
                              ? nicknameAccent
                              : const Color(0xFFD5EAF3),
                          width: _nicknameError != null ? 2 : 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: nicknameAccent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _savingNickname ? null : _saveNickname,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: _navy,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          if (_nicknameError != null) ...[
            const SizedBox(height: 14),
            Text(
              _nicknameError!,
              style: const TextStyle(fontSize: 13, color: nicknameAccent),
            ),
          ],
        ],
      ),
    );
  }

  Widget _locationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '위치 정보 이용 동의',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
              ),
              Switch(
                value: _consent,
                onChanged: _savingConsent ? null : _changeConsent,
                activeTrackColor: _blue,
                activeThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFF9BA7AF),
                inactiveThumbColor: Colors.white,
                trackOutlineColor: const WidgetStatePropertyAll(
                  Colors.transparent,
                ),
                thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
                  if (states.contains(WidgetState.selected)) return null;
                  return const Icon(
                    Icons.circle,
                    color: Colors.transparent,
                    size: 16,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _consent ? '동의함' : '동의 안 함',
            style: TextStyle(
              color: _consent ? _accent : _gray,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '약속에 필요한 시간에만 내 위치를 사용해요.\n'
            '끄면 위치 수집과 자동 체크인이 중단돼요.',
            style: TextStyle(color: _gray, fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '마이',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                    IconButton(
                      tooltip: '알림 목록',
                      onPressed: () {
                        Navigator.pushNamed(context, '/notifications');
                      },
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: _accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Text(
                  '내 정보',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 22),
                _nicknameCard(),
                if (_editing) ...[
                  const SizedBox(height: 16),
                  _nicknameEditor(),
                ],
                const SizedBox(height: 18),
                _locationCard(),
                const SizedBox(height: 20),
                const Text(
                  '기기 위치 권한이 없으면 켤 때 권한을 요청해요.',
                  style: TextStyle(fontSize: 12, color: _gray),
                ),
              ],
            ),
    );
  }
}
