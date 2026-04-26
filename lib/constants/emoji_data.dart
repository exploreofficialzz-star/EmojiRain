// ─── Emoji Categories ─────────────────────────────────────────────────────────
class EmojiCategory {
  static const String happy   = 'happy';
  static const String sad     = 'sad';
  static const String angry   = 'angry';
  static const String scared  = 'scared';
  static const String love    = 'love';
  static const String cool    = 'cool';
  static const String silly   = 'silly';
  static const String danger  = 'danger';
  static const String nature  = 'nature';
  static const String food    = 'food';
}

// ─── Emoji Pool ───────────────────────────────────────────────────────────────
class EmojiPool {
  static const Map<String, List<String>> byCategory = {
    EmojiCategory.happy:  ['😊', '😄', '😁', '🤩', '😃', '😀', '🥳', '🤗'],
    EmojiCategory.sad:    ['😢', '😭', '💔', '😞', '😥', '🥺', '😿', '😔'],
    EmojiCategory.angry:  ['😡', '🤬', '😤', '👿', '🔥', '💢', '😠'],
    EmojiCategory.scared: ['😱', '😨', '😰', '🙀', '😬', '🫣', '😳'],
    EmojiCategory.love:   ['❤️', '🥰', '😍', '💕', '💖', '🫶', '💗', '😘'],
    EmojiCategory.cool:   ['😎', '🤙', '🕶️', '🤘', '💪', '🦸', '🧊'],
    EmojiCategory.silly:  ['🤪', '😜', '😝', '🤡', '🎭', '🙃', '🤓'],
    EmojiCategory.danger: ['💀', '☠️', '👻', '🕷️', '🦂', '⚡', '🧨'],
    EmojiCategory.nature: ['🌈', '⭐', '🌙', '☀️', '🌺', '🍀', '🌊'],
    EmojiCategory.food:   ['🍕', '🍔', '🍦', '🍩', '🎂', '🍭', '🍓'],
  };

  static const List<String> allEmojis = [
    '😊', '😄', '😁', '🤩', '😃', '😀', '🥳', '🤗',
    '😢', '😭', '💔', '😞', '😥', '🥺', '😔',
    '😡', '🤬', '😤', '👿', '💢', '😠',
    '😱', '😨', '😰', '😬', '😳',
    '❤️', '🥰', '😍', '💕', '💖', '🫶', '💗', '😘',
    '😎', '🤙', '💪',
    '🤪', '😜', '😝', '🤡', '🙃',
    '💀', '☠️', '👻',
    '🌈', '⭐', '🌙', '☀️',
    '🍕', '🍔', '🍦', '🍩', '🎂',
    '💩', '🎉', '🦄', '🐸', '🤖',
  ];

  static List<String> get distractors => allEmojis;
}

// ─── Level Configuration ──────────────────────────────────────────────────────
enum RuleType {
  tapSpecific,    // "Tap only X"
  avoidSpecific,  // "Avoid X" (tap everything else)
  tapCategory,    // "Tap only [emotion] emojis"
  avoidCategory,  // "Avoid [emotion] emojis"
}

class LevelConfig {
  final int level;
  final String title;
  final String ruleText;
  final String instructionText;
  final RuleType ruleType;
  final String? targetEmoji;
  final String? targetCategory;
  final double baseSpeed;
  final double spawnInterval;
  final int targetScore;
  final int emojiMix;          // how many wrong emojis per correct
  final double emojiSizeMultiplier;

  const LevelConfig({
    required this.level,
    required this.title,
    required this.ruleText,
    required this.instructionText,
    required this.ruleType,
    this.targetEmoji,
    this.targetCategory,
    required this.baseSpeed,
    required this.spawnInterval,
    required this.targetScore,
    this.emojiMix = 2,
    this.emojiSizeMultiplier = 1.0,
  });

  bool isCorrectEmoji(String emoji) {
    switch (ruleType) {
      case RuleType.tapSpecific:
        return emoji == targetEmoji;
      case RuleType.avoidSpecific:
        return emoji != targetEmoji;
      case RuleType.tapCategory:
        final list = EmojiPool.byCategory[targetCategory] ?? [];
        return list.contains(emoji);
      case RuleType.avoidCategory:
        final list = EmojiPool.byCategory[targetCategory] ?? [];
        return !list.contains(emoji);
    }
  }
}

class LevelData {
  static const List<LevelConfig> levels = [
    LevelConfig(
      level: 1,
      title: 'Warm Up',
      ruleText: 'Tap only ❤️',
      instructionText: 'TAP ONLY ❤️',
      ruleType: RuleType.tapSpecific,
      targetEmoji: '❤️',
      baseSpeed: 160,
      spawnInterval: 1.2,
      targetScore: 100,
      emojiMix: 2,
    ),
    LevelConfig(
      level: 2,
      title: 'Getting Real',
      ruleText: 'Tap only 😊',
      instructionText: 'TAP ONLY 😊',
      ruleType: RuleType.tapSpecific,
      targetEmoji: '😊',
      baseSpeed: 190,
      spawnInterval: 1.0,
      targetScore: 150,
      emojiMix: 3,
    ),
    LevelConfig(
      level: 3,
      title: 'Danger Zone',
      ruleText: 'AVOID 💀 — Tap the rest!',
      instructionText: 'AVOID 💀',
      ruleType: RuleType.avoidSpecific,
      targetEmoji: '💀',
      baseSpeed: 210,
      spawnInterval: 0.9,
      targetScore: 200,
      emojiMix: 3,
    ),
    LevelConfig(
      level: 4,
      title: 'Feels Heavy',
      ruleText: 'Tap only SAD emojis 😭',
      instructionText: 'ONLY SAD 😭💔',
      ruleType: RuleType.tapCategory,
      targetCategory: EmojiCategory.sad,
      baseSpeed: 240,
      spawnInterval: 0.85,
      targetScore: 220,
      emojiMix: 3,
    ),
    LevelConfig(
      level: 5,
      title: 'Good Vibes',
      ruleText: 'Tap only HAPPY emojis 😄',
      instructionText: 'ONLY HAPPY 😄🤩',
      ruleType: RuleType.tapCategory,
      targetCategory: EmojiCategory.happy,
      baseSpeed: 260,
      spawnInterval: 0.8,
      targetScore: 250,
      emojiMix: 4,
    ),
    LevelConfig(
      level: 6,
      title: 'Love Only',
      ruleText: 'Tap only LOVE emojis ❤️',
      instructionText: 'LOVE ONLY 💕🥰',
      ruleType: RuleType.tapCategory,
      targetCategory: EmojiCategory.love,
      baseSpeed: 280,
      spawnInterval: 0.75,
      targetScore: 280,
      emojiMix: 4,
    ),
    LevelConfig(
      level: 7,
      title: 'No Anger',
      ruleText: 'AVOID angry emojis 😡',
      instructionText: 'NO ANGER 😡🤬',
      ruleType: RuleType.avoidCategory,
      targetCategory: EmojiCategory.angry,
      baseSpeed: 310,
      spawnInterval: 0.7,
      targetScore: 300,
      emojiMix: 4,
    ),
    LevelConfig(
      level: 8,
      title: 'Star Power',
      ruleText: 'Tap only ⭐',
      instructionText: 'ONLY ⭐',
      ruleType: RuleType.tapSpecific,
      targetEmoji: '⭐',
      baseSpeed: 340,
      spawnInterval: 0.65,
      targetScore: 350,
      emojiMix: 5,
      emojiSizeMultiplier: 0.9,
    ),
    LevelConfig(
      level: 9,
      title: 'Ghost Hunt',
      ruleText: 'Tap only 👻',
      instructionText: 'GHOST ONLY 👻',
      ruleType: RuleType.tapSpecific,
      targetEmoji: '👻',
      baseSpeed: 370,
      spawnInterval: 0.6,
      targetScore: 400,
      emojiMix: 5,
      emojiSizeMultiplier: 0.85,
    ),
    LevelConfig(
      level: 10,
      title: 'CHAOS MODE',
      ruleText: 'No DANGER emojis! 💀☠️',
      instructionText: 'AVOID DANGER 💀☠️👻',
      ruleType: RuleType.avoidCategory,
      targetCategory: EmojiCategory.danger,
      baseSpeed: 420,
      spawnInterval: 0.45,
      targetScore: 500,
      emojiMix: 6,
      emojiSizeMultiplier: 0.8,
    ),
  ];

  static LevelConfig getLevel(int level) {
    if (level <= 0) return levels.first;
    if (level > levels.length) {
      // Beyond defined levels: remix last level, harder
      final last = levels.last;
      return LevelConfig(
        level: level,
        title: 'INSANE LVL $level',
        ruleText: last.ruleText,
        instructionText: last.instructionText,
        ruleType: last.ruleType,
        targetEmoji: last.targetEmoji,
        targetCategory: last.targetCategory,
        baseSpeed: (last.baseSpeed + (level - levels.length) * 25).clamp(0, 600),
        spawnInterval: (last.spawnInterval - (level - levels.length) * 0.03).clamp(0.25, 1.5),
        targetScore: last.targetScore + (level - levels.length) * 80,
        emojiMix: last.emojiMix + 1,
        emojiSizeMultiplier: 0.75,
      );
    }
    return levels[level - 1];
  }
}

// ─── Fail Messages ────────────────────────────────────────────────────────────
class FailMessages {
  static const List<String> messages = [
    "You had ONE job 💀",
    "Bro... that was clearly wrong 😭",
    "Your ancestors are disappointed 👴",
    "Even my grandma plays better 👵",
    "Focus mode: FAILED 🤦",
    "Your eyes were open though... right? 👁️",
    "You picked the WRONG one lmao 💀",
    "404: Focus not found 🧠",
    "The emojis are bullying you now 😂",
    "Sir, that was literally 💀 💀",
    "Skill issue detected 🚨",
    "Try again... and maybe pay attention? 😅",
    "Bruh 😐",
    "Your thumbs have betrayed you 👎",
    "That... was not it chief 💀",
    "Congratulations on being wrong 🏆",
    "You absolute legend of failure 😂",
    "The emoji was literally GLOWING and you still missed 🙄",
    "This is why we can't have nice things 😩",
    "I believe in you! (I don't) 💀",
    "Speed: fast. Accuracy: zero 😭",
    "You chose chaos 🌪️",
    "Even the 💩 emoji is judging you",
    "New achievement: Epic Fail 🏅",
    "Blink twice if you need help 👀",
  ];

  static String getRandom() {
    messages.shuffle();
    return messages.first;
  }

  static String getForWrongTap(String tapped) {
    if (tapped == '💀' || tapped == '☠️') {
      return "You literally tapped 💀... tragic 😭";
    }
    if (tapped == '💩') {
      return "You tapped the 💩. No further questions.";
    }
    if (tapped == '😡' || tapped == '🤬') {
      return "Touch the angry emoji once more, I dare you 😡";
    }
    if (tapped == '💔') {
      return "You picked 💔... love no be your thing 😭";
    }
    return getRandom();
  }
}

// ─── Share Messages ────────────────────────────────────────────────────────────
class ShareMessages {
  static String get(int score, int level) {
    if (score > 500) {
      return "I scored $score in Emoji Rain! 🔥 Can you beat me? Level $level reached! Download now 🎮";
    }
    if (score > 200) {
      return "I'm getting good at Emoji Rain! $score points 🎯 Try to beat level $level!";
    }
    return "Just started playing Emoji Rain 😂 I only got $score but I'm improving! 🎮";
  }
}
