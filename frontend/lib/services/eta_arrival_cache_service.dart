import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EtaArrivalCacheService {
  static final Map<String, DateTime> _memory = {};

  static String _key(int appointmentId, int participantId) =>
      'eta_arrived_at_v1:$appointmentId:$participantId';

  static Future<void> save({
    required int appointmentId,
    required int participantId,
    required DateTime arrivedAt,
  }) async {
    final key = _key(appointmentId, participantId);
    _memory[key] = arrivedAt;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, arrivedAt.toUtc().toIso8601String());
    } catch (error) {
      debugPrint('도착 시각 저장 실패: $error');
    }
  }

  static Future<DateTime?> read(int appointmentId, int participantId) async {
    final key = _key(appointmentId, participantId);

    if (_memory.containsKey(key)) return _memory[key];

    try {
      final prefs = await SharedPreferences.getInstance();
      return DateTime.tryParse(prefs.getString(key) ?? '');
    } catch (_) {
      return null;
    }
  }
}
