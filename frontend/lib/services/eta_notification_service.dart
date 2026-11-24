import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

class EtaNotificationService {
  static final _revision = ValueNotifier<int>(0);

  static ValueListenable<int> get changes => _revision;

  static Future<bool> hasUnreadNotifications() async {
    final items = await getNotifications();
    return items.any((item) => item['isRead'] != true);
  }

  static const String _storageKey = 'eta_notifications_v1';

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(hours: 24));

      final items = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) {
            final createdAt = DateTime.tryParse(
              item['createdAt']?.toString() ?? '',
            );

            return createdAt != null &&
                !createdAt.isBefore(cutoff) &&
                !createdAt.isAfter(now);
          })
          .toList();

      // 만료된 알림은 화면에서 숨길 뿐 아니라 저장소에서도 제거한다.
      if (items.length != decoded.length) {
        await prefs.setString(_storageKey, jsonEncode(items));
      }

      items.sort((a, b) {
        final aTime = DateTime.tryParse(a['createdAt']?.toString() ?? '');
        final bTime = DateTime.tryParse(b['createdAt']?.toString() ?? '');
        return (bTime ?? DateTime(1970)).compareTo(aTime ?? DateTime(1970));
      });

      return items;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveNotification({
    required String id,
    required String type,
    required String title,
    required String description,
    required int appointmentId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getNotifications();

    // 동일 이벤트 중복 저장 방지
    if (items.any((item) => item['id'] == id)) return;

    items.insert(0, {
      'id': id,
      'type': type,
      'title': title,
      'description': description,
      'appointmentId': appointmentId,
      'createdAt': DateTime.now().toIso8601String(),
      'isRead': false,
    });

    // 최근 100개까지 기기에 보관
    if (items.length > 100) {
      items.removeRange(100, items.length);
    }

    final saved = await prefs.setString(_storageKey, jsonEncode(items));
    if (saved) {
      _revision.value++;
    }
  }

  static Future<void> markNotificationsAsRead(Iterable<String> ids) async {
    final idSet = ids.toSet();
    if (idSet.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final items = await getNotifications();
    var changed = false;

    for (final item in items) {
      if (idSet.contains(item['id']?.toString()) && item['isRead'] != true) {
        item['isRead'] = true;
        changed = true;
      }
    }

    if (changed) {
      final saved = await prefs.setString(_storageKey, jsonEncode(items));
      if (saved) {
        _revision.value++;
      }
    }
  }

  static Future<void> markAsRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getNotifications();

    for (final item in items) {
      if (item['id'] == id) {
        item['isRead'] = true;
      }
    }

    final saved = await prefs.setString(_storageKey, jsonEncode(items));
    if (saved) {
      _revision.value++;
    }
  }
}
