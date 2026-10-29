import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import 'screens/home_screen.dart';
import 'screens/appointment_create_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/live_map_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const kakaoNativeAppKey =
      String.fromEnvironment('KAKAO_NATIVE_APP_KEY');

  if (kakaoNativeAppKey.isEmpty) {
    throw StateError('KAKAO_NATIVE_APP_KEY가 설정되지 않았습니다.');
  }

  await KakaoMapSdk.instance.initialize(kakaoNativeAppKey);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // 앱을 실행하면 처음 보여줄 화면
      initialRoute: '/onboarding',

      // 화면 경로 설정
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/': (context) => const HomeScreen(),
        '/appointment-create': (context) => const AppointmentCreateScreen(),
        '/live-map': (context) => const LiveMapScreen(),
      },
    );
  }
}