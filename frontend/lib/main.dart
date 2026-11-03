
import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/appointment_create_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/appointment_waiting_screen.dart';

void main() {
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
        '/appointment-create': (context) =>
            const AppointmentCreateScreen(),

        // Issue #13: 약속 대기 화면
        '/appointment-waiting': (context) =>
            const AppointmentWaitingScreen(),
      },
    );
  }
}