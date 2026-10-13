import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; 

import 'guest_identity_service.dart';
import 'onboarding_api_service.dart';

class OnboardingRegistrationService {
  static const String _userIdKey = 'user_id';

  static Future<int> register({
    required String nickname,
    required bool locationTermsAgreed,
    required bool notificationAllowed,
  }) async {
    // 기존 UUID가 있으면 재사용하고, 없으면 새로 생성
    final guestUuid =
        await GuestIdentityService.getOrCreateGuestUuid();

    // 서버에 온보딩 정보 전송
    final result = await OnboardingApiService.registerUser(
      guestUuid: guestUuid,
      nickname: nickname,
      profileCharacter: null,
      locationTermsAgreed: locationTermsAgreed,
      notificationAllowed: notificationAllowed,
      fcmToken: null,
    );

    // 서버가 발급한 사용자 ID 확인
    final userId = result['userId'];

    if (userId is! int) {
      throw Exception('서버에서 올바른 userId를 받지 못했습니다.');
    }

    // 사용자 ID를 기기에 저장
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setInt(_userIdKey, userId);

    if (!saved) {
      throw Exception('사용자 ID 저장에 실패했습니다.');
    }

    debugPrint('온보딩 등록 성공! userId: $userId');
    debugPrint('서버 온보딩 응답: $result');

    return userId;
  }
}
