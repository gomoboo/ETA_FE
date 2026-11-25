import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'eta_api_service.dart';
import 'guest_identity_service.dart';

class EtaHomeLoadResult {
  const EtaHomeLoadResult({required this.data, required this.fromCache});

  final Map<String, dynamic> data;
  final bool fromCache;
}

class EtaHomeCacheService {
  static const _keyPrefix = 'eta_home_cache_v1_';

  static Future<EtaHomeLoadResult> load() async {
    try {
      final data = await EtaApiService.getHomeAppointments();

      try {
        final uuid = await GuestIdentityService.getOrCreateUuid();
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('$_keyPrefix$uuid', jsonEncode(data));
      } catch (error) {
        debugPrint('약속 목록 캐시 저장 실패: $error');
      }

      return EtaHomeLoadResult(data: data, fromCache: false);
    } catch (error) {
      // 서버의 정상적인 API 거부나 데이터 오류는
      // 오래된 목록으로 숨기지 않는다.
      if (error is! SocketException &&
          error is! TimeoutException &&
          error is! http.ClientException) {
        rethrow;
      }

      try {
        final uuid = await GuestIdentityService.getOrCreateUuid();
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('$_keyPrefix$uuid');

        if (raw == null) rethrow;

        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          rethrow;
        }

        return EtaHomeLoadResult(data: decoded, fromCache: true);
      } catch (_) {
        rethrow;
      }
    }
  }
}
