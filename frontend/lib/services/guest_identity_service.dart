
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class GuestIdentityService {
  static const String _guestUuidKey = 'guest_uuid';

  static Future<String> getOrCreateGuestUuid() async {
    final prefs = await SharedPreferences.getInstance();

    // 이미 저장된 UUID가 있다면 그대로 사용
    final savedUuid = prefs.getString(_guestUuidKey);

    if (savedUuid != null && savedUuid.isNotEmpty) {
      return savedUuid;
    }

    // 처음 실행한 경우 UUID 생성
    final newUuid = const Uuid().v4();

    // 생성한 UUID를 기기에 저장
    final saved = await prefs.setString(_guestUuidKey, newUuid);

    if (!saved) {
      throw Exception('게스트 UUID 저장에 실패했습니다.');
    }

    return newUuid;
  }
}
