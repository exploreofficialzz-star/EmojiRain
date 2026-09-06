import 'dart:math';

enum EmojiState { falling, tapped, missed }

class EmojiItem {
  // Monotonic counter — guarantees a unique id for every spawned emoji,
  // regardless of how many spawn within the same clock tick. The previous
  // id was '${DateTime.now().microsecondsSinceEpoch}_${rand.nextInt(9999)}':
  // _maybeSpawn() in GameProvider can call spawn() up to 6 times in a single
  // synchronous burst at level 12+, and on real Android hardware
  // DateTime.now() resolution is often coarser than true microseconds — so
  // two emojis from the same burst could land on the same timestamp and
  // then collide on the bounded random suffix (1 in 9999 per pair, not
  // negligible over a long session). A duplicate id means two entries in
  // _EmojiLayer's Stack share the same ValueKey, which Flutter's
  // reconciliation doesn't support — the wrong element can be reused,
  // showing an emoji at a stale position or eating a tap meant for a
  // different one. A simple incrementing counter can never collide.
  static int _nextId = 0;

  final String id;
  final String emoji;
  final String category;
  final bool isTarget;       // Should the player tap this?
  final double size;
  double speed;              // px/sec — mutable so it syncs with _currentSpeed

  double x;                  // centre x in pixels
  double y;                  // centre y in pixels
  EmojiState state;

  // Visual feedback
  double opacity;
  double scale;
  double rotation;           // slight tilt for visual variety

  EmojiItem({
    required this.id,
    required this.emoji,
    required this.category,
    required this.isTarget,
    required this.size,
    required this.speed,
    required this.x,
    required this.y,
    this.state    = EmojiState.falling,
    this.opacity  = 1.0,
    this.scale    = 1.0,
    this.rotation = 0.0,
  });

  bool get isFalling => state == EmojiState.falling;
  bool get isTapped  => state == EmojiState.tapped;
  bool get isMissed  => state == EmojiState.missed;

  bool hitTest(double tapX, double tapY, {double r = 40}) {
    final dx = tapX - x;
    final dy = tapY - y;
    return (dx * dx + dy * dy) <= r * r;
  }

  static EmojiItem spawn({
    required String emoji,
    required String category,
    required bool isTarget,
    required double screenWidth,
    required double emojiSize,
    required double speed,
    Random? rng,
  }) {
    final rand     = rng ?? Random();
    final halfSize = emojiSize / 2 + 10;
    return EmojiItem(
      id:       '${_nextId++}',
      emoji:    emoji,
      category: category,
      isTarget: isTarget,
      size:     emojiSize,
      speed:    speed + rand.nextDouble() * 30 - 15,
      x:        halfSize + rand.nextDouble() * (screenWidth - halfSize * 2),
      y:        -emojiSize,
      rotation: (rand.nextDouble() - 0.5) * 0.4,
    );
  }
}
