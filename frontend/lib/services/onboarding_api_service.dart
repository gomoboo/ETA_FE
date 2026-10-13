
import 'dart:convert';

import 'package:http/http.dart' as http;

class OnboardingApiService {
  static const String _baseUrl = 'http://15.165.148.253';

  static Future<Map<String, dynamic>> registerUser({
    required String guestUuid,
    required String nickname,
    String? profileCharacter,
    required bool locationTermsAgreed,
    required bool notificationAllowed,
    String? fcmToken,
  }) async {
    final url = Uri.parse('$_baseUrl/api/v1/users/onboarding');

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'guestUuid': guestUuid,
            'nickname': nickname,
            'profileCharacter': profileCharacter,
            'locationTermsAgreed': locationTermsAgreed,
            'notificationAllowed': notificationAllowed,
            'fcmToken': fcmToken,
          }),
        )
        .timeout(const Duration(seconds: 10));

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode != 200) {
      throw Exception(
        '온보딩 API 오류: ${response.statusCode} - $decoded',
      );
    }

    if (decoded is! Map<String, dynamic> ||
        decoded['success'] != true ||
        decoded['data'] is! Map<String, dynamic>) {
      throw Exception('온보딩 응답 형식이 올바르지 않습니다.');
    }

    return decoded['data'] as Map<String, dynamic>;
  }
}
