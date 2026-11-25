import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class GuestIdentityService {
  static const String _uuidKey = 'eta_guest_uuid';
  static const String _nicknameKey = 'eta_nickname';
  static const String _onboardingKey = 'eta_onboarding_completed';

  static Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();

    final uuid = prefs.getString(_uuidKey)?.trim() ?? '';
    final nickname = prefs.getString(_nicknameKey)?.trim() ?? '';

    if (uuid.isEmpty || nickname.isEmpty) return false;

    final completed = prefs.getBool(_onboardingKey);

    if (completed != null) return completed;

    // 기존 가입자의 저장 데이터 호환
    return prefs.containsKey('eta_location_consent');
  }

  static Future<void> markOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setBool(_onboardingKey, true);

    if (!saved) {
      throw StateError('온보딩 완료 상태 저장에 실패했습니다.');
    }
  }

  static Future<String> getOrCreateUuid() async {
    final prefs = await SharedPreferences.getInstance();

    final savedUuid = prefs.getString(_uuidKey);

    if (savedUuid != null && savedUuid.isNotEmpty) {
      return savedUuid;
    }

    final newUuid = const Uuid().v4();
    final saved = await prefs.setString(_uuidKey, newUuid);

    if (!saved) {
      throw StateError('기기 UUID 저장에 실패했습니다.');
    }

    return newUuid;
  }

  static Future<void> saveNickname(String nickname) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_nicknameKey, nickname.trim());

    if (!saved) {
      throw StateError('닉네임 저장에 실패했습니다.');
    }
  }

  static Future<String?> getNickname() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nicknameKey);
  }
}
