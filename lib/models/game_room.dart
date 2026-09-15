/// Multiplayer room status lifecycle.
enum RoomStatus { waiting, countdown, playing, finished }

/// A single player inside a multiplayer room.
class RoomPlayer {
  final String playerId;
  final String nickname;
  int score;
  int level;
  bool isReady;
  bool isAlive;

  RoomPlayer({
    required this.playerId,
    required this.nickname,
    this.score   = 0,
    this.level   = 1,
    this.isReady = false,
    this.isAlive = true,
  });

  factory RoomPlayer.fromJson(Map<String, dynamic> json) => RoomPlayer(
    playerId: json['player_id'] as String,
    nickname: json['nickname']  as String,
    score:    (json['score']    as num?)?.toInt() ?? 0,
    level:    (json['level']    as num?)?.toInt() ?? 1,
    isReady:  json['is_ready']  as bool? ?? false,
    isAlive:  json['is_alive']  as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'player_id': playerId,
    'nickname':  nickname,
    'score':     score,
    'level':     level,
    'is_ready':  isReady,
    'is_alive':  isAlive,
  };

  /// Initials shown in avatar circles (max 2 characters).
  String get initials {
    final parts = nickname.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return nickname.substring(0, nickname.length.clamp(1, 2)).toUpperCase();
  }
}

/// A live multiplayer game room (max 4 players).
class GameRoom {
  final String       roomCode;  // 6-char alphanumeric, e.g. "XK92MQ"
  final String       hostId;
  final List<RoomPlayer> players;
  final int          seedValue; // shared Random seed — same emoji sequence on all clients
  final RoomStatus   status;
  final DateTime     createdAt;

  const GameRoom({
    required this.roomCode,
    required this.hostId,
    required this.players,
    required this.seedValue,
    required this.status,
    required this.createdAt,
  });

  factory GameRoom.fromJson(Map<String, dynamic> json) => GameRoom(
    roomCode:  json['room_code']  as String,
    hostId:    json['host_id']    as String,
    seedValue: (json['seed_value'] as num).toInt(),
    status: RoomStatus.values.firstWhere(
      (s) => s.name == (json['status'] as String),
      orElse: () => RoomStatus.waiting,
    ),
    createdAt: DateTime.parse(json['created_at'] as String),
    players: (json['players'] as List<dynamic>? ?? [])
        .map((p) => RoomPlayer.fromJson(p as Map<String, dynamic>))
        .toList(),
  );

  bool get canStart  => players.where((p) => p.isReady).length >= 2;
  bool get isFull    => players.length >= 4;
}
