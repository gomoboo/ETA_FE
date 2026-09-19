import 'package:flutter/material.dart';
import 'screens/appointment_create_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '너 지금 어디야?',
      home: const AppointmentCreateScreen(),
    );
  }
}