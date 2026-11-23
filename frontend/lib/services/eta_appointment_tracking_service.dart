import 'package:flutter/foundation.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'eta_api_service.dart';
import 'eta_notification_service.dart';

class EtaAppointmentTrackingService {
  static const String _storageKey = 'eta_tracked_appointments_v1';

  static Future<List<Map<String, dynamic>>> getTrackedAppointments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> rememberAppointments(
    Iterable<Map<String, dynamic>> appointments,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final tracked = await getTrackedAppointments();

    for (final appointment in appointments) {
      final rawId = appointment['appointmentId'];
      final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');

      if (id == null) continue;

      final title = appointment['title']?.toString().trim() ?? '';
      final meetAt = appointment['meetAt']?.toString() ?? '';

      final index = tracked.indexWhere((item) => item['appointmentId'] == id);

      final entry = {'appointmentId': id, 'title': title, 'meetAt': meetAt};

      if (index >= 0) {
        tracked[index] = entry;
      } else {
        tracked.add(entry);
      }
    }

    await prefs.setString(_storageKey, jsonEncode(tracked));
  }

  // 현재 목록에서 사라졌고 실제 정산 결과가 제공되는 약속만 조회한다.
  static Future<List<Map<String, dynamic>>> getPastSettledAppointments() async {
    final homeData = await EtaApiService.getHomeAppointments();
    final tracked = await getTrackedAppointments();

    final currentIds = <int>{};

    for (final key in ['activeAppointments', 'upcomingAppointments']) {
      final items = homeData[key];
      if (items is! List) continue;

      for (final item in items) {
        if (item is! Map) continue;
        final id = int.tryParse(item['appointmentId']?.toString() ?? '');
        if (id != null) currentIds.add(id);
      }
    }

    final result = <Map<String, dynamic>>[];

    for (final item in tracked) {
      final id = int.tryParse(item['appointmentId']?.toString() ?? '');

      if (id == null || currentIds.contains(id)) continue;

      final meetAt = DateTime.tryParse(item['meetAt']?.toString() ?? '');

      if (meetAt == null || meetAt.isAfter(DateTime.now())) continue;

      try {
        final settlement = await EtaApiService.getSettlement(id);

        if (settlement['participants'] is! List) continue;

        result.add({
          'appointmentId': id,
          'title': item['title'],
          'meetAt': item['meetAt'],
          'settlement': settlement,
        });
      } catch (error) {
        debugPrint('지난 약속 정산 조회 보류 ($id): $error');
      }
    }

    result.sort((a, b) {
      final aTime = DateTime.tryParse(a['meetAt']?.toString() ?? '');
      final bTime = DateTime.tryParse(b['meetAt']?.toString() ?? '');

      return (bTime ?? DateTime(1970)).compareTo(aTime ?? DateTime(1970));
    });

    return result;
  }

  static Future<void> checkSettlementNotifications(
    Map<String, dynamic> homeData,
  ) async {
    final tracked = await getTrackedAppointments();
    if (tracked.isEmpty) return;

    final currentIds = <int>{};

    for (final key in ['activeAppointments', 'upcomingAppointments']) {
      final items = homeData[key];
      if (items is! List) continue;

      for (final item in items) {
        if (item is! Map) continue;
        final id = int.tryParse(item['appointmentId']?.toString() ?? '');
        if (id != null) currentIds.add(id);
      }
    }

    final notifications = await EtaNotificationService.getNotifications();
    final notifiedIds = notifications
        .map((item) => item['id']?.toString())
        .toSet();

    final now = DateTime.now();

    for (final appointment in tracked) {
      final id = int.tryParse(appointment['appointmentId']?.toString() ?? '');
      if (id == null || currentIds.contains(id)) continue;

      final meetAt = DateTime.tryParse(appointment['meetAt']?.toString() ?? '')
          ?.toLocal();

      if (meetAt == null || meetAt.isAfter(now)) continue;
      if (notifiedIds.contains('settlement:$id')) continue;

      try {
        final detail = await EtaApiService.getAppointmentDetail(id);
        final status = (detail['status'] ?? detail['appointmentStatus'])
            ?.toString()
            .toUpperCase();

        // 서버에서 종료가 확정된 경우에만 진행한다.
        if (status != 'COMPLETED') continue;

        final settlement = await EtaApiService.getSettlement(id);

        // 실제 정산 데이터인지 확인한다.
        if (settlement['participants'] is! List) continue;

        final title = detail['title']?.toString().trim().isNotEmpty == true
            ? detail['title'].toString().trim()
            : appointment['title']?.toString().trim() ?? '';

        if (title.isEmpty) continue;

        await EtaNotificationService.saveNotification(
          id: 'settlement:$id',
          type: 'settlement',
          title: '정산 결과가 준비됐어요',
          description: '$title · 도착 기록과 지각비를 확인해요.',
          appointmentId: id,
        );

        debugPrint('정산 결과 알림 저장 완료: $id');
      } catch (error) {
        debugPrint('정산 결과 확인 보류 ($id): $error');
      }
    }
  }
}
