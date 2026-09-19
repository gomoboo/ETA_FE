import 'package:flutter/material.dart';

class AppointmentCreateScreen extends StatelessWidget {
  const AppointmentCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('약속 생성'),
      ),
      body: const Center(
        child: Text('약속 생성 화면'),
      ),
    );
  }
}