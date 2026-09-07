import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

enum WebSocketState { disconnected, connecting, connected }

/// Robust WebSocket client for real-time telemetry streaming and bidirectional
/// marine communication with the ORCA backend.
class WebSocketClient {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  WebSocketState _state = WebSocketState.disconnected;
  String? _lastUrl;

  final _stateController = StreamController<WebSocketState>.broadcast();
  final _messageController = StreamController<dynamic>.broadcast();

  WebSocketState get state => _state;
  Stream<WebSocketState> get stateStream => _stateController.stream;
  Stream<dynamic> get messageStream => _messageController.stream;
  bool get isConnected => _state == WebSocketState.connected;

  /// Connect to the specified WebSocket URL (e.g., ws://localhost:8000/api/v1/ws/telemetry)
  Future<void> connect(String url) async {
    if (_state == WebSocketState.connected && _lastUrl == url) return;

    _lastUrl = url;
    _setState(WebSocketState.connecting);

    try {
      final uri = Uri.parse(url);
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        (message) {
          _messageController.add(message);
        },
        onDone: () {
          debugPrint('[WebSocketClient] Connection closed.');
          _setState(WebSocketState.disconnected);
        },
        onError: (error) {
          debugPrint('[WebSocketClient] Error: $error');
          _setState(WebSocketState.disconnected);
        },
        cancelOnError: true,
      );

      _setState(WebSocketState.connected);
      debugPrint('[WebSocketClient] Connected to $url');
    } catch (e) {
      debugPrint('[WebSocketClient] Failed to connect: $e');
      _setState(WebSocketState.disconnected);
    }
  }

  /// Send message (string or JSON-serializable Map) over the active socket
  void send(dynamic message) {
    if (_state != WebSocketState.connected || _channel == null) {
      debugPrint('[WebSocketClient] Cannot send message: not connected.');
      return;
    }

    try {
      final payload = (message is Map || message is List) ? jsonEncode(message) : message.toString();
      _channel!.sink.add(payload);
    } catch (e) {
      debugPrint('[WebSocketClient] Error sending message: $e');
    }
  }

  /// Disconnect and cleanly close channel
  Future<void> disconnect() async {
    _setState(WebSocketState.disconnected);
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close(status.normalClosure);
    _channel = null;
  }

  void _setState(WebSocketState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(_state);
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
    await _messageController.close();
  }
}
