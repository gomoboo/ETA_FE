import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class GuestIdentityService {
  static const String _uuidKey = 'eta_guest_uuid';
  static const String _nicknameKey = 'eta_nickname';

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
