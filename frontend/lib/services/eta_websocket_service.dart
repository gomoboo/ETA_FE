import 'dart:async';
import 'dart:convert';
import 'dart:io';

class EtaWebSocketService {
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  bool _disposed = false;
  bool _connecting = false;
  Timer? _retryTimer;

  bool get isConnected => _socket?.readyState == WebSocket.open;

  Future<void> connect({
    required int appointmentId,
    required int participantId,
    required String guestUuid,
    required void Function() onConnected,
    required void Function(String message) onMessage,
    required void Function(Object error) onError,
    required void Function() onDisconnected,
  }) async {
    if (_disposed) {
      throw StateError('이미 종료된 WebSocket 서비스입니다.');
    }

    if (_connecting || isConnected) return;

    _connecting = true;
    _retryTimer?.cancel();
    _retryTimer = null;

    void scheduleRetry() {
      if (_disposed || _retryTimer != null) return;

      _retryTimer = Timer(const Duration(seconds: 2), () {
        _retryTimer = null;

        unawaited(
          connect(
            appointmentId: appointmentId,
            participantId: participantId,
            guestUuid: guestUuid,
            onConnected: onConnected,
            onMessage: onMessage,
            onError: onError,
            onDisconnected: onDisconnected,
          ),
        );
      });
    }

    final uri = Uri(
      scheme: 'ws',
      host: '15.165.148.253',
      port: 80,
      path: '/api/v1/ws/appointments/$appointmentId',
      queryParameters: {
        'participant_id': participantId.toString(),
        'guestUuid': guestUuid,
      },
    );

    try {
      final socket = await WebSocket.connect(uri.toString())
          .timeout(const Duration(seconds: 10));

      if (_disposed) {
        await socket.close();
        return;
      }

      _socket = socket;

      _subscription = socket.listen(
        (message) {
          if (message is String) {
            onMessage(message);
          }
        },
        onError: (Object error) {
          onError(error);

          if (!identical(_socket, socket)) return;

          _socket = null;
          unawaited(socket.close());
          scheduleRetry();
        },
        onDone: () {
          if (!identical(_socket, socket)) return;

          _socket = null;
          onDisconnected();

          // 서버가 접근 권한 없음/종료된 약속으로 연결을 거부한 경우
          // 무한 재연결하지 않음
          if (socket.closeCode == WebSocketStatus.policyViolation) {
            return;
          }

          scheduleRetry();
        },
        cancelOnError: false,
      );

      onConnected();
    } catch (error) {
      if (!_disposed) {
        onError(error);
        scheduleRetry();
      }
    } finally {
      _connecting = false;
    }
  }

  void send(Map<String, dynamic> payload) {
    final socket = _socket;

    if (socket == null || socket.readyState != WebSocket.open) {
      return;
    }

    socket.add(jsonEncode(payload));
  }

  Future<void> dispose() async {
    _disposed = true;

    _retryTimer?.cancel();
    _retryTimer = null;

    final subscription = _subscription;
    _subscription = null;

    if (subscription != null) {
      await subscription.cancel();
    }

    final socket = _socket;
    _socket = null;

    if (socket != null) {
      await socket.close(WebSocketStatus.normalClosure);
    }
  }
}
