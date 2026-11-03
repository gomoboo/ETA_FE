
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('라우팅 테스트'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 기존 약속 생성 화면 이동
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/appointment-create',
                );
              },
              child: const Text('약속 생성 화면으로 이동'),
            ),

            const SizedBox(height: 20),

            // Issue #13: 약속 대기 화면 이동
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/appointment-waiting',
                );
              },
              child: const Text('약속 대기 화면으로 이동'),
            ),
          ],
        ),
      ),
    );
  }
}
