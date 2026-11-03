import 'dart:async';
import 'dart:convert';
import 'dart:io';

class EtaWebSocketService {
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  bool _disposed = false;

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
      },
      onDone: onDisconnected,
      cancelOnError: false,
    );

    onConnected();
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
