import 'dart:convert';

import 'package:http/http.dart' as http;

import 'guest_identity_service.dart';

class EtaApiService {
  static const String baseUrl = 'http://15.165.148.253/api/v1';

  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool useGuestUuid = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);

    final headers = <String, String>{'Content-Type': 'application/json'};

    if (useGuestUuid) {
      headers['X-Guest-UUID'] = await GuestIdentityService.getOrCreateUuid();
    }

    final http.Response response;

    if (method == 'POST') {
      response = await http
          .post(uri, headers: headers, body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 15));
    } else {
      response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map<String, dynamic>) {
      throw Exception('서버 응답 형식이 올바르지 않습니다.');
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] != true) {
      throw Exception(
        decoded['message']?.toString() ??
            decoded['detail']?.toString() ??
            'API 요청 실패 (${response.statusCode})',
      );
    }

    final data = decoded['data'];

    if (data is Map<String, dynamic>) {
      return data;
    }

    return {};
  }

  static Future<Map<String, dynamic>> registerUser({
    required String nickname,
    required bool locationTermsAgreed,
    bool notificationAllowed = false,
  }) async {
    final uuid = await GuestIdentityService.getOrCreateUuid();

    final result = await _request(
      'POST',
      '/users/onboarding',
      useGuestUuid: false,
      body: {
        'guestUuid': uuid,
        'nickname': nickname,
        'locationTermsAgreed': locationTermsAgreed,
        'notificationAllowed': notificationAllowed,
      },
    );

    await GuestIdentityService.saveNickname(nickname);
    return result;
  }

  static Future<Map<String, dynamic>> searchPlaces(String query) {
    return _request(
      'GET',
      '/places/search',
      query: {'query': query},
      useGuestUuid: false,
    );
  }

  static Future<Map<String, dynamic>> createAppointment(
    Map<String, dynamic> appointmentData,
  ) {
    return _request('POST', '/appointments', body: appointmentData);
  }

  static Future<Map<String, dynamic>> getHomeAppointments() {
    return _request('GET', '/appointments/home');
  }

  static Future<Map<String, dynamic>> getAppointmentDetail(int appointmentId) {
    return _request('GET', '/appointments/$appointmentId');
  }

  static Future<Map<String, dynamic>> previewInvite(String inviteCode) {
    return _request(
      'GET',
      '/appointments/invite/${Uri.encodeComponent(inviteCode)}',
      useGuestUuid: false,
    );
  }

  static Future<Map<String, dynamic>> joinAppointment(
    String inviteCode, {
    String? nickname,
  }) {
    return _request(
      'POST',
      '/appointments/invite/${Uri.encodeComponent(inviteCode)}/join',
      body: {'nickname': nickname},
    );
  }

  static Future<Map<String, dynamic>> getSettlement(int appointmentId) {
    return _request('GET', '/appointments/$appointmentId/settlement');
  }
}
