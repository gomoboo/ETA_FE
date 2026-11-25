import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import 'services/guest_identity_service.dart';
import 'screens/home_screen.dart';
import 'screens/appointment_create_screen.dart';
import 'screens/appointment_detail_screen.dart';
import 'screens/appointment_join_screen.dart';
import 'screens/live_map_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/notification_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const kakaoNativeAppKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');

  if (kakaoNativeAppKey.isEmpty) {
    throw StateError('KAKAO_NATIVE_APP_KEY가 설정되지 않았습니다.');
  }

  await KakaoMapSdk.instance.initialize(kakaoNativeAppKey);

  final completed = await GuestIdentityService.hasCompletedOnboarding();

  runApp(MyApp(initialRoute: completed ? '/' : '/onboarding'));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.initialRoute = '/onboarding'});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: initialRoute,
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/': (context) => const HomeScreen(),
        '/appointment-create': (context) => const AppointmentCreateScreen(),
        '/appointment-waiting': (context) => const AppointmentDetailScreen(),
        '/appointment-detail': (context) => const AppointmentDetailScreen(),
        '/appointment-join': (context) => const AppointmentJoinScreen(),
        '/live-map': (context) => const LiveMapScreen(),
        '/notifications': (context) => const NotificationListScreen(),
      },
    );
  }
}
