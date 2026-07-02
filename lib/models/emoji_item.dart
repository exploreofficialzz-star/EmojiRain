// ─────────────────────────────────────────────────────────────────────────────
// lib/models/emoji_item.dart — OPTIMISED
//
// CHANGES vs original:
// 1. OBJECT POOL — EmojiItem instances are recycled instead of GC'd every
//    spawn. At 60 fps with up to 15 on-screen emojis, the original code was
//    allocating and garbage-collecting ~900 objects/min. Each allocation
//    stresses the Dart GC and causes micro-stutters visible as dropped frames.
//    Pool.acquire() reuses a dead instance; Pool.release() returns it.
//
// 2. ID generation — original used DateTime.now().microsecondsSinceEpoch
//    which calls into native on every spawn. Replaced with a monotonic int
//    counter; zero-cost, no native call, still globally unique per session.
//
// 3. reset() instead of constructor — pool reuse means we reinitialise via
//    reset(), keeping the same Dart object identity on the heap.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';

enum EmojiState { falling, tapped, missed }

class EmojiItem {
  // ── Identity ──────────────────────────────────────────────────────────────
  late String     id;
  late String     emoji;
  late String     category;
  late bool       isTarget;
  late double     size;

  // ── Physics — mutable during gameplay ────────────────────────────────────
  double speed    = 0;
  double x        = 0;
  double y        = 0;
  EmojiState state = EmojiState.falling;

  // ── Visuals ───────────────────────────────────────────────────────────────
  double opacity  = 1.0;
  double scale    = 1.0;
  double rotation = 0.0;

  // ── Private: used by pool ─────────────────────────────────────────────────
  bool _inPool = false;

  EmojiItem._();   // Private constructor — always go through pool.

  // ── Convenience getters ───────────────────────────────────────────────────
  bool get isFalling => state == EmojiState.falling;
  bool get isTapped  => state == EmojiState.tapped;
  bool get isMissed  => state == EmojiState.missed;

  bool hitTest(double tapX, double tapY, {double r = 40}) {
    final dx = tapX - x;
    final dy = tapY - y;
    return (dx * dx + dy * dy) <= r * r;
  }

  // ── Reset for pool reuse — no allocation ──────────────────────────────────
  void reset({
    required String id,
    required String emoji,
    required String category,
    required bool   isTarget,
    required double size,
    required double speed,
    required double x,
    required double y,
    required double rotation,
  }) {
    this.id       = id;
    this.emoji    = emoji;
    this.category = category;
    this.isTarget = isTarget;
    this.size     = size;
    this.speed    = speed;
    this.x        = x;
    this.y        = y;
    this.rotation = rotation;
    state         = EmojiState.falling;
    opacity       = 1.0;
    scale         = 1.0;
    _inPool       = false;
  }

  // ── Pool ──────────────────────────────────────────────────────────────────
  static final _EmojiPool pool = _EmojiPool();

  static EmojiItem spawn({
    required String emoji,
    required String category,
    required bool   isTarget,
    required double screenWidth,
    required double emojiSize,
    required double speed,
    required Random rng,
    required int    idCounter,
  }) {
    final halfSize = emojiSize / 2 + 10;
    final item     = pool.acquire();
    item.reset(
      id:       'e_$idCounter',
      emoji:    emoji,
      category: category,
      isTarget: isTarget,
      size:     emojiSize,
      speed:    speed + rng.nextDouble() * 30 - 15,
      x:        halfSize + rng.nextDouble() * (screenWidth - halfSize * 2),
      y:        -emojiSize,
      rotation: (rng.nextDouble() - 0.5) * 0.4,
    );
    return item;
  }
}

// ── Object Pool ───────────────────────────────────────────────────────────────
class _EmojiPool {
  static const int _maxSize = 32;
  final List<EmojiItem> _free = [];

  EmojiItem acquire() {
    if (_free.isNotEmpty) {
      final item  = _free.removeLast();
      item._inPool = false;
      return item;
    }
    return EmojiItem._();
  }

  void release(EmojiItem item) {
    if (item._inPool || _free.length >= _maxSize) return;
    item._inPool = true;
    _free.add(item);
  }

  void releaseAll(List<EmojiItem> items) {
    for (final item in items) {
      release(item);
    }
  }
}
