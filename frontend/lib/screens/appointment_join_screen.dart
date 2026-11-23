import 'package:flutter/material.dart';

import '../services/eta_api_service.dart';
import '../services/guest_identity_service.dart';

class AppointmentJoinScreen extends StatefulWidget {
  const AppointmentJoinScreen({super.key});

  @override
  State<AppointmentJoinScreen> createState() => _AppointmentJoinScreenState();
}

class _AppointmentJoinScreenState extends State<AppointmentJoinScreen> {
  static const _navy = Color(0xFF18354A);
  static const _blue = Color(0xFF7DD3F7);
  static const _background = Color(0xFFF7FBFF);

  final _codeController = TextEditingController();

  Map<String, dynamic>? _invitation;
  String? _verifiedCode;
  String? _error;

  bool _loading = false;
  bool _joining = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '시간 정보 없음';

    final local = date.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');

    return '${local.month}월 ${local.day}일 '
        '${local.hour}:$minute';
  }

  Future<void> _lookupInvite() async {
    final code = _codeController.text.trim().toUpperCase();

    if (code.isEmpty) {
      setState(() {
        _error = '초대 코드를 입력해 주세요.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _invitation = null;
      _verifiedCode = null;
    });

    try {
      final result = await EtaApiService.previewInvite(code);

      if (!mounted) return;

      setState(() {
        _invitation = result;
        _verifiedCode = code;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = '약속을 찾지 못했어요.\n$error';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _joinAppointment() async {
    final code = _verifiedCode;
    if (code == null || _joining) return;

    setState(() {
      _joining = true;
      _error = null;
    });

    try {
      final nickname = await GuestIdentityService.getNickname();

      final result = await EtaApiService.joinAppointment(
        code,
        nickname: nickname,
      );

      if (!mounted) return;

      final rawId = result['appointmentId'] ?? _invitation?['appointmentId'];

      final appointmentId = rawId is int
          ? rawId
          : int.tryParse(rawId?.toString() ?? '');

      if (appointmentId == null) {
        setState(() {
          _error =
              '참여 요청은 처리됐지만 약속 ID를 확인하지 못했어요. '
              '홈에서 약속 목록을 확인해 주세요.';
        });
        return;
      }

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/appointment-waiting',
        ModalRoute.withName('/'),
        arguments: appointmentId,
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = '약속 참여에 실패했어요.\n$error';
      });
    } finally {
      if (mounted) {
        setState(() => _joining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitation = _invitation;
    final place =
        invitation?['targetPlaceName'] ??
        (invitation?['targetPlace'] is Map
            ? invitation!['targetPlace']['name']
            : null);

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        foregroundColor: _navy,
        title: const Text(
          '약속 참여하기',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '친구가 보낸 초대 코드를\n입력해 주세요',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '초대 코드로 약속을 확인하고 참여할 수 있어요.',
                style: TextStyle(color: Color(0xFF718696)),
              ),
              const SizedBox(height: 32),

              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: '초대 코드 입력',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onChanged: (_) {
                  setState(() {
                    _invitation = null;
                    _verifiedCode = null;
                    _error = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading || _joining ? null : _lookupInvite,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: _navy,
                  ),
                  child: Text(_loading ? '확인 중...' : '약속 확인하기'),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],

              if (invitation != null) ...[
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFDCEBF3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '초대받은 약속',
                        style: TextStyle(color: Color(0xFF718696)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        invitation['title']?.toString() ?? '약속',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _navy,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text('일시: ${_formatDate(invitation['meetAt'])}'),
                      const SizedBox(height: 8),
                      Text('장소: ${place ?? '장소 정보 없음'}'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _joining ? null : _joinAppointment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_joining ? '참여 중...' : '이 약속에 참여하기'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
