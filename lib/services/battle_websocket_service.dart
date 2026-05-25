import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_projects/config.dart';
// import 'package:flutter_projects/services/config.dart';

/// Battle WebSocket Service
/// All devices derive the server address from AppConfig.wsBaseUrl.
class BattleWebSocketService {
  // ── Singleton ───────────────────────────────────────────────────────────────
  // NOT a global singleton — each battle session creates its own instance.
  // The old singleton pattern caused stale stream events from a previous game
  // to fire into a new game's listeners.
  BattleWebSocketService();

  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  bool _isConnected = false;
  String? _connectedUserId;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Full WebSocket URL for this user, e.g. ws://host/ws/battle/<id>
  String wsUrlForUser(String userId) =>
      '${AppConfig.wsBaseUrl}/ws/battle/$userId';

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  bool get isConnected => _isConnected;

  // ── Connection ──────────────────────────────────────────────────────────────

  /// Connect to the battle WebSocket.
  /// Safe to call multiple times — closes the old socket first.
  Future<bool> connect(String userId) async {
    // If already connected for the same user, reuse the socket.
    if (_isConnected && _connectedUserId == userId) {
      debugPrint('⚠️ Already connected for user $userId');
      return true;
    }

    // Close any stale channel/controller from a previous session.
    await _cleanUp();

    try {
      final url = wsUrlForUser(userId);
      debugPrint('🔌 Connecting to: $url');

      _channel = WebSocketChannel.connect(Uri.parse(url));

      // Give the handshake time to complete.
      await Future.delayed(const Duration(milliseconds: 500));

      _channel!.stream.listen(
        (message) {
          try {
            debugPrint('📥 WS: $message');
            final data = json.decode(message as String) as Map<String, dynamic>;
            debugPrint('📨 Event: ${data['event']}');
            if (!_messageController.isClosed) {
              _messageController.add(data);
            }
          } catch (e) {
            debugPrint('❌ Parse error: $e  raw=$message');
          }
        },
        onError: (error) {
          debugPrint('❌ WebSocket error: $error');
          _isConnected = false;
        },
        onDone: () {
          debugPrint('🔌 WebSocket closed');
          _isConnected = false;
        },
        cancelOnError: false,
      );

      _isConnected = true;
      _connectedUserId = userId;
      debugPrint('✅ WebSocket connected');
      return true;
    } catch (e) {
      debugPrint('❌ Connection failed: $e');
      _isConnected = false;
      return false;
    }
  }

  // ── Room actions ────────────────────────────────────────────────────────────

  void createRoom({
    required String roomCode,
    required String hostName,
    required String hostAvatar,
    required String category,
    required String difficulty,
  }) {
    _send({
      'event': 'create_room',
      'room_code': roomCode,
      'host_name': hostName,
      'host_avatar': hostAvatar,
      'category': category,
      'difficulty': difficulty,
    });
    debugPrint('📤 create_room: $roomCode');
  }

  void joinRoom({
    required String roomCode,
    required String playerName,
    required String playerAvatar,
  }) {
    _send({
      'event': 'join_room',
      'room_code': roomCode,
      'player_name': playerName,
      'player_avatar': playerAvatar,
    });
    debugPrint('📤 join_room: $roomCode');
  }

  void startGame(String roomCode) {
    _send({'event': 'start_game', 'room_code': roomCode});
    debugPrint('📤 start_game: $roomCode');
  }

  void submitAnswer({
    required String roomCode,
    required bool isCorrect,
    required int points,
    required int questionIndex,
  }) {
    _send({
      'event': 'submit_answer',
      'room_code': roomCode,
      'is_correct': isCorrect,
      'points': points,
      'question_index': questionIndex,
    });
    debugPrint('📤 submit_answer: ${isCorrect ? "✅" : "❌"} $points pts');
  }

  void leaveRoom(String roomCode) {
    _send({'event': 'leave_room', 'room_code': roomCode});
    debugPrint('📤 leave_room: $roomCode');
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  /// Disconnect the socket. The service can still be reconnected after this.
  void disconnect() {
    debugPrint('🔌 Disconnecting');
    try { _channel?.sink.close(); } catch (_) {}
    _isConnected = false;
    _connectedUserId = null;
  }

  /// Fully dispose — call when this service instance will never be reused.
  Future<void> dispose() async {
    disconnect();
    if (!_messageController.isClosed) {
      await _messageController.close();
    }
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  void _send(Map<String, dynamic> message) {
    if (!_isConnected) {
      debugPrint('❌ _send called while not connected');
      return;
    }
    try {
      _channel?.sink.add(json.encode(message));
    } catch (e) {
      debugPrint('❌ Send failed: $e');
    }
  }

  /// Close old channel and recreate the broadcast controller for a fresh session.
  Future<void> _cleanUp() async {
    try { _channel?.sink.close(); } catch (_) {}
    _channel = null;
    _isConnected = false;
    _connectedUserId = null;

    if (!_messageController.isClosed) {
      await _messageController.close();
    }
    _messageController = StreamController<Map<String, dynamic>>.broadcast();
  }
}