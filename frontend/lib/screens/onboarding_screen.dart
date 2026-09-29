import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Widget _building({
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFFD5EAF3),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _pageDot() {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Color(0xFFD9E8EF),
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FBFE),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // 앱 이름
              const Text(
                '이따',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF17354A),
                ),
              ),

              const SizedBox(height: 35),

              // 지도 일러스트
              SizedBox(
                width: double.infinity,
                height: 246,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 지도 배경
                    Container(
                      width: double.infinity,
                      height: 246,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF7FC),
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),

                    // 세로 도로
                    Container(
                      width: 22,
                      height: 246,
                      color: Colors.white,
                    ),

                    // 가로 도로
                    Container(
                      width: double.infinity,
                      height: 22,
                      color: Colors.white,
                    ),

                    // 왼쪽 위 건물
                    Positioned(
                      top: 24,
                      left: 24,
                      child: _building(width: 95, height: 70),
                    ),

                    // 오른쪽 위 건물
                    Positioned(
                      top: 24,
                      right: 24,
                      child: _building(width: 95, height: 70),
                    ),

                    // 왼쪽 아래 건물
                    Positioned(
                      bottom: 24,
                      left: 24,
                      child: _building(width: 100, height: 75),
                    ),

                    // 오른쪽 아래 건물
                    Positioned(
                      bottom: 24,
                      right: 24,
                      child: _building(width: 95, height: 75),
                    ),

                    // 위치 핀
                    const Icon(
                      Icons.location_on,
                      size: 42,
                      color: Color(0xFF1685B5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // 메인 문구
              const Text(
                '이따 말고,\n지금 어디쯤?',
                style: TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF17364A),
                ),
              ),

              const SizedBox(height: 18),

              // 설명
              const Text(
                '친구의 위치부터 도착, 지각비 정산까지.\n기다리는 시간을 가볍게 만들어 보세요.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: Color(0xFF8299AA),
                ),
              ),

              const SizedBox(height: 18),

              // 위치 공유 안내 카드
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F5FC),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '약속 30분 전부터만 공유해요',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF17354A),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '끝나면 위치 공유도 자동으로 종료돼요.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8299AA),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 페이지 표시 점
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 20,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1685B5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _pageDot(),
                  const SizedBox(width: 10),
                  _pageDot(),
                ],
              ),

              const SizedBox(height: 22),

              // 다음 버튼
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SecondOnboardingScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF71CCF2),
                    foregroundColor: const Color(0xFF17354A),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    '다음',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 하단 안내
              const Center(
                child: Text(
                  '위치 권한은 필요한 순간에 요청해요.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8299AA),
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

class SecondOnboardingScreen extends StatefulWidget {
  const SecondOnboardingScreen({super.key});

  @override
  State<SecondOnboardingScreen> createState() => _SecondOnboardingScreenState();
}

class _SecondOnboardingScreenState extends State<SecondOnboardingScreen> {
  String _nickname = '';
  String? _nicknameError;

  void _completeOnboarding() {
    final nickname = _nickname.trim();
    if (nickname.length < 2 || nickname.length > 10) {
      setState(() => _nicknameError = '닉네임을 2~10자로 입력해주세요.');
      return;
    }

    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ThirdOnboardingScreen(nickname: nickname),
      ),
    );
  }

  Widget _avatar(String name) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Text(
        name,
        style: const TextStyle(
          color: Color(0xFF1685B5),
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _ring(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFB9E6F8), width: 1.5),
      ),
    );
  }

  Widget _radar() {
    return Container(
      width: double.infinity,
      height: 246,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7FC),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          _ring(210),
          _ring(142),
          _ring(76),
          Container(
            width: 66,
            height: 66,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF7DD4F7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_outlined,
              size: 30,
              color: Color(0xFF1685B5),
            ),
          ),
          Positioned(left: 62, top: 64, child: _avatar('나')),
          Positioned(right: 49, top: 55, child: _avatar('윤')),
          Positioned(right: 66, bottom: 48, child: _avatar('민')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FBFE),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, _) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      '이따',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF17354A),
                      ),
                    ),
                    const SizedBox(height: 35),
                    _radar(),
                    const SizedBox(height: 32),
                    const Text(
                      '친구들이 오는 길을\n한 눈에 확인해요.',
                      style: TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: Color(0xFF17364A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '약속 30분 전부터 친구들의 위치와 이동 속도를\n실시간으로 확인할 수 있어요.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xFF8299AA),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5F5FC),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '필요한 순간에만 위치를 공유해요',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF17354A),
                            ),
                          ),
                          SizedBox(height: 7),
                          Text(
                            '약속 전후의 짧은 시간에만 위치를 사용해요.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8299AA),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const _SmallPageDot(),
                        const SizedBox(width: 10),
                        Container(
                          width: 20,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1685B5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const _SmallPageDot(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '닉네임 설정',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF17364A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      maxLength: 10,
                      onChanged: (value) {
                        _nickname = value;
                        if (_nicknameError != null) {
                          setState(() => _nicknameError = null);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: '2~10자 닉네임을 입력해주세요',
                        errorText: _nicknameError,
                        hintStyle: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8299AA),
                        ),
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFD5EAF3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFD5EAF3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF1685B5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _completeOnboarding,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7DD4F7),
                          foregroundColor: const Color(0xFF17364A),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '다음',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        '위치 권한은 필요한 순간에 요청해요.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8299AA),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SmallPageDot extends StatelessWidget {
  const _SmallPageDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Color(0xFFD9E8EF),
        shape: BoxShape.circle,
      ),
    );
  }
}

class ThirdOnboardingScreen extends StatelessWidget {
  const ThirdOnboardingScreen({super.key, required this.nickname});

  final String nickname;

  void _goHome(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/',
      (route) => false,
      arguments: nickname,
    );
  }

  
  Future<void> _showPermissionNotice(BuildContext context) async {
    try {
      // 1. 휴대폰의 위치 서비스가 켜져 있는지 확인
      bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!context.mounted) return;

      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('휴대폰의 위치 서비스를 켜주세요.'),
          ),
        );
        return;
      }

      // 2. 현재 위치 권한 확인
      LocationPermission permission =
          await Geolocator.checkPermission();

      // 3. 아직 허용하지 않았다면 실제 권한 요청
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (!context.mounted) return;

      // 4. 사용자가 권한을 거부한 경우
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('위치 권한이 허용되지 않았어요.'),
          ),
        );
        return;
      }

      // 5. 권한이 영구적으로 거부된 경우
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('설정에서 위치 권한을 허용해주세요.'),
            action: SnackBarAction(
              label: '설정 열기',
              onPressed: () {
                Geolocator.openAppSettings();
              },
            ),
          ),
        );
        return;
      }

      // 6. 권한이 허용되면 홈 화면으로 이동
      _goHome(context);

    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('위치 권한 확인 중 문제가 발생했어요.'),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FBFE),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 36),
                    const Text(
                      '이따',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF17364A),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Container(
                      width: double.infinity,
                      height: 238,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF7FC),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 146,
                              height: 146,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_on_outlined,
                                size: 62,
                                color: Color(0xFF1685B5),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 46,
                                height: 46,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF7DD4F7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.lock_outline,
                                  size: 23,
                                  color: Color(0xFF1685B5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 42),
                    const Text(
                      '필요한 순간에만,\n위치를 공유해요.',
                      style: TextStyle(
                        fontSize: 29,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF17364A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '약속 30분 전부터 종료 시점까지만 위치를 사용해요.\n친구 위치 확인과 자동 체크인에 활용돼요.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: Color(0xFF8299AA),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5F5FC),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '항상 위치를 추적하지 않아요',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF17364A),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '약속이 끝나면 위치 공유도 자동으로 종료돼요.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8299AA),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const _SmallPageDot(),
                        const SizedBox(width: 10),
                        const _SmallPageDot(),
                        const SizedBox(width: 10),
                        Container(
                          width: 20,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1685B5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => _showPermissionNotice(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7DD4F7),
                          foregroundColor: const Color(0xFF17364A),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '위치 허용하기',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => _goHome(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF17364A),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFD5EAF3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '지금은 안 할게요',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
