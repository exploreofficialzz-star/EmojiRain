import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/backend_config.dart';
import '../models/game_room.dart';

/// Manages a multiplayer room session: creation, join, ready, live scoring,
/// and SSE-based live leaderboard updates.
class RoomProvider extends ChangeNotifier {
  RoomProvider._();
  static final RoomProvider instance = RoomProvider._();

  // ── State ─────────────────────────────────────────────────────────────────
  GameRoom?  _currentRoom;
  String?    _myPlayerId;
  String?    _myNickname;
  bool       _isLoading    = false;
  String?    _error;

  // Live leaderboard (sorted by score descending, updated from SSE)
  List<RoomPlayer> _leaderboard = [];

  // SSE subscription
  http.Client?           _sseClient;
  StreamSubscription<List<int>>? _sseSub;
  Timer?                 _scorePushTimer;
  int                    _pendingScore = 0;

  // ── Getters ───────────────────────────────────────────────────────────────
  GameRoom?        get currentRoom   => _currentRoom;
  String?          get myPlayerId    => _myPlayerId;
  bool             get isHost        => _currentRoom?.hostId == _myPlayerId;
  bool             get isLoading     => _isLoading;
  String?          get error         => _error;
  List<RoomPlayer> get liveLeaderboard => List.unmodifiable(_leaderboard);

  RoomPlayer? get myPlayer => _currentRoom?.players
      .where((p) => p.playerId == _myPlayerId)
      .firstOrNull;

  // ── Create / Join ─────────────────────────────────────────────────────────

  Future<GameRoom?> createRoom(String nickname) async {
    _setLoading(true);
    _myNickname = nickname;
    try {
      final playerId = _generatePlayerId();
      _myPlayerId    = playerId;

      final resp = await http.post(
        Uri.parse('${BackendConfig.apiBaseUrl}/rooms/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'host_id':  playerId,
          'nickname': nickname,
        }),
      );

      if (resp.statusCode == 200) {
        _currentRoom = GameRoom.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
        _leaderboard = List<RoomPlayer>.from(_currentRoom!.players);
        _subscribeToSse(_currentRoom!.roomCode);
        _setLoading(false);
        return _currentRoom;
      } else {
        _setError('Could not create room (${resp.statusCode})');
        return null;
      }
    } catch (e) {
      _setError('Network error: $e');
      return null;
    }
  }

  Future<GameRoom?> joinRoom(String code, String nickname) async {
    _setLoading(true);
    _myNickname = nickname;
    try {
      final playerId = _generatePlayerId();
      _myPlayerId    = playerId;

      final resp = await http.post(
        Uri.parse('${BackendConfig.apiBaseUrl}/rooms/${code.toUpperCase()}/join'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'player_id': playerId,
          'nickname':  nickname,
        }),
      );

      if (resp.statusCode == 200) {
        _currentRoom = GameRoom.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
        _leaderboard = List<RoomPlayer>.from(_currentRoom!.players);
        _subscribeToSse(code.toUpperCase());
        _setLoading(false);
        return _currentRoom;
      } else {
        _setError('Room not found or full (${resp.statusCode})');
        return null;
      }
    } catch (e) {
      _setError('Network error: $e');
      return null;
    }
  }

  Future<void> markReady() async {
    final room = _currentRoom;
    final pid  = _myPlayerId;
    if (room == null || pid == null) return;
    try {
      await http.post(
        Uri.parse('${BackendConfig.apiBaseUrl}/rooms/${room.roomCode}/ready'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'player_id': pid}),
      );
    } catch (_) {}
  }

  Future<void> startRoom() async {
    final room = _currentRoom;
    final pid  = _myPlayerId;
    if (room == null || pid == null || !isHost) return;
    try {
      await http.post(
        Uri.parse('${BackendConfig.apiBaseUrl}/rooms/${room.roomCode}/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'player_id': pid}),
      );
    } catch (_) {}
  }

  // ── Live Scoring ──────────────────────────────────────────────────────────

  /// Begin pushing score updates every 2 seconds during gameplay.
  void startScorePush(int Function() scoreGetter) {
    _scorePushTimer?.cancel();
    _scorePushTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pushScore(scoreGetter());
    });
  }

  void stopScorePush() {
    _scorePushTimer?.cancel();
    _scorePushTimer = null;
  }

  Future<void> _pushScore(int score) async {
    final room = _currentRoom;
    final pid  = _myPlayerId;
    if (room == null || pid == null) return;
    _pendingScore = score;
    try {
      await http.post(
        Uri.parse('${BackendConfig.apiBaseUrl}/rooms/${room.roomCode}/score'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'player_id': pid, 'score': score}),
      );
    } catch (_) {}
  }

  Future<void> signalDead() async {
    final room = _currentRoom;
    final pid  = _myPlayerId;
    if (room == null || pid == null) return;
    stopScorePush();
    try {
      await http.post(
        Uri.parse('${BackendConfig.apiBaseUrl}/rooms/${room.roomCode}/dead'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'player_id': pid}),
      );
    } catch (_) {}
  }

  // ── SSE Live Updates ──────────────────────────────────────────────────────

  void _subscribeToSse(String roomCode) {
    _sseSub?.cancel();
    _sseClient?.close();
    _sseClient = http.Client();

    final request = http.Request(
      'GET',
      Uri.parse('${BackendConfig.apiBaseUrl}/rooms/$roomCode/live'),
    )..headers['Accept'] = 'text/event-stream';

    _sseClient!.send(request).then((response) {
      _sseSub = response.stream.listen(
        _onSseData,
        onError: (_) => _reconnectSse(roomCode),
        cancelOnError: false,
      );
    }).catchError((_) => _reconnectSse(roomCode));
  }

  final StringBuffer _sseBuffer = StringBuffer();

  void _onSseData(List<int> data) {
    _sseBuffer.write(utf8.decode(data, allowMalformed: true));
    final raw = _sseBuffer.toString();
    final events = raw.split('\n\n');

    // Keep last incomplete chunk in buffer
    if (!raw.endsWith('\n\n')) {
      _sseBuffer.clear();
      _sseBuffer.write(events.removeLast());
    } else {
      _sseBuffer.clear();
    }

    for (final block in events) {
      if (block.trim().isEmpty) continue;
      for (final line in block.split('\n')) {
        if (line.startsWith('data:')) {
          final payload = line.substring(5).trim();
          _handleSseEvent(payload);
        }
      }
    }
  }

  void _handleSseEvent(String payload) {
    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      final type = json['type'] as String?;

      if (type == 'room_update' || type == 'score_update') {
        final raw = json['players'] as List<dynamic>?;
        if (raw != null) {
          final updated = raw
              .map((p) => RoomPlayer.fromJson(p as Map<String, dynamic>))
              .toList();
          updated.sort((a, b) => b.score.compareTo(a.score));
          _leaderboard = updated;

          // Merge into currentRoom
          if (_currentRoom != null) {
            // Update local player list with server truth
            final mergedPlayers = List<RoomPlayer>.from(updated);
            _currentRoom = GameRoom(
              roomCode:  _currentRoom!.roomCode,
              hostId:    _currentRoom!.hostId,
              seedValue: _currentRoom!.seedValue,
              status:    _parseStatus(json['status'] as String?) ?? _currentRoom!.status,
              createdAt: _currentRoom!.createdAt,
              players:   mergedPlayers,
            );
          }
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  RoomStatus? _parseStatus(String? s) {
    if (s == null) return null;
    return RoomStatus.values.where((v) => v.name == s).firstOrNull;
  }

  Timer? _reconnectTimer;
  void _reconnectSse(String roomCode) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      const Duration(seconds: 3),
      () => _subscribeToSse(roomCode),
    );
  }

  // ── Room polling fallback (used in lobby while waiting) ───────────────────

  Timer? _pollTimer;

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollRoom());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollRoom() async {
    final room = _currentRoom;
    if (room == null) return;
    try {
      final resp = await http.get(
        Uri.parse('${BackendConfig.apiBaseUrl}/rooms/${room.roomCode}'),
      );
      if (resp.statusCode == 200) {
        _currentRoom = GameRoom.fromJson(
            jsonDecode(resp.body) as Map<String, dynamic>);
        _leaderboard = List<RoomPlayer>.from(_currentRoom!.players)
          ..sort((a, b) => b.score.compareTo(a.score));
        notifyListeners();
      }
    } catch (_) {}
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  void leaveRoom() {
    stopPolling();
    stopScorePush();
    _sseSub?.cancel();
    _sseClient?.close();
    _reconnectTimer?.cancel();
    _currentRoom  = null;
    _myPlayerId   = null;
    _leaderboard  = [];
    _error        = null;
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setLoading(bool v) {
    _isLoading = v;
    if (v) _error = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _isLoading = false;
    _error     = msg;
    notifyListeners();
  }

  String _generatePlayerId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng   = Random.secure();
    return List.generate(12, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// Persist player ID across sessions so rankings carry over.
  Future<String> getOrCreatePlayerId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('mp_player_id');
    if (id == null) {
      id = _generatePlayerId();
      await prefs.setString('mp_player_id', id);
    }
    _myPlayerId = id;
    return id;
  }
}
