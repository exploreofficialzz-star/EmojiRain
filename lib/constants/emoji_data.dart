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
  static const String money   = 'money';
  static const String animals = 'animals';
}

// ─── Emoji Pool ───────────────────────────────────────────────────────────────
class EmojiPool {
  static const Map<String, List<String>> byCategory = {
    EmojiCategory.happy:   ['😊', '😄', '😁', '🤩', '😃', '😀', '🥳', '🤗', '😎', '🙌'],
    EmojiCategory.sad:     ['😢', '😭', '💔', '😞', '😥', '🥺', '😿', '😔', '😩', '😓'],
    EmojiCategory.angry:   ['😡', '🤬', '😤', '👿', '🔥', '💢', '😠', '🤯', '👊'],
    EmojiCategory.scared:  ['😱', '😨', '😰', '🙀', '😬', '🫣', '😳', '😧', '😦'],
    EmojiCategory.love:    ['❤️', '🥰', '😍', '💕', '💖', '🫶', '💗', '😘', '💝', '💞'],
    EmojiCategory.cool:    ['😎', '🤙', '🕶️', '🤘', '💪', '🦸', '🧊', '👑', '✌️'],
    EmojiCategory.silly:   ['🤪', '😜', '😝', '🤡', '🎭', '🙃', '🤓', '🫠', '👅'],
    EmojiCategory.danger:  ['💀', '☠️', '👻', '🕷️', '🦂', '⚡', '🧨', '💣', '🔪'],
    EmojiCategory.nature:  ['🌈', '⭐', '🌙', '☀️', '🌺', '🍀', '🌊', '🌸', '🌟', '❄️'],
    EmojiCategory.food:    ['🍕', '🍔', '🍦', '🍩', '🎂', '🍭', '🍓', '🍜', '🧁', '🌮'],
    EmojiCategory.money:   ['💰', '💵', '🤑', '💎', '🏆', '🎰', '💸', '🪙'],
    EmojiCategory.animals: ['🐶', '🐱', '🦊', '🐸', '🦄', '🐼', '🐨', '🦋', '🐬', '🦁'],
  };

  static const List<String> allEmojis = [
    // happy
    '😊', '😄', '😁', '🤩', '😃', '😀', '🥳', '🤗',
    // sad
    '😢', '😭', '💔', '😞', '😥', '🥺', '😔', '😩',
    // angry
    '😡', '🤬', '😤', '👿', '💢', '😠', '🤯',
    // scared
    '😱', '😨', '😰', '😬', '😳', '😧',
    // love
    '❤️', '🥰', '😍', '💕', '💖', '🫶', '💗', '😘', '💝',
    // cool
    '😎', '🤙', '💪', '👑', '✌️',
    // silly
    '🤪', '😜', '😝', '🤡', '🙃', '🫠',
    // danger
    '💀', '☠️', '👻', '💣', '🔪',
    // nature
    '🌈', '⭐', '🌙', '☀️', '🌸', '🌟', '❄️',
    // food
    '🍕', '🍔', '🍦', '🍩', '🎂', '🍭', '🌮',
    // money
    '💰', '💵', '🤑', '💎', '🏆', '💸',
    // animals
    '🐶', '🐱', '🦊', '🐸', '🦄', '🐼', '🦁',
    // misc
    '💩', '🎉', '🔮', '🎯', '🧲', '🪄', '🎪',
  ];
}

// ─── Level Configuration ──────────────────────────────────────────────────────
enum RuleType {
  tapSpecific,
  avoidSpecific,
  tapCategory,
  avoidCategory,
}

class LevelConfig {
  final int    level;
  final String title;
  final String ruleText;
  final String instructionText;
  final RuleType ruleType;
  final String?  targetEmoji;
  final String?  targetCategory;
  final double   baseSpeed;
  final double   spawnInterval;
  final int      targetScore;       // score to clear this level
  final int      emojiMix;          // distractors per 1 target
  final double   emojiSizeMultiplier;

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
    this.emojiMix = 3,
    this.emojiSizeMultiplier = 1.0,
  });

  bool isCorrectEmoji(String emoji) {
    switch (ruleType) {
      case RuleType.tapSpecific:
        return emoji == targetEmoji;
      case RuleType.avoidSpecific:
        return emoji != targetEmoji;
      case RuleType.tapCategory:
        return (EmojiPool.byCategory[targetCategory] ?? []).contains(emoji);
      case RuleType.avoidCategory:
        return !(EmojiPool.byCategory[targetCategory] ?? []).contains(emoji);
    }
  }
}

// ─── 15 hand-crafted levels — long and progressively brutal ──────────────────
class LevelData {
  static const List<LevelConfig> levels = [
    // ── Level 1: Easy intro ──────────────────────────────────────────────────
    LevelConfig(
      level: 1,
      title: 'First Drop',
      ruleText: 'Tap only ❤️',
      instructionText: 'TAP ONLY ❤️',
      ruleType: RuleType.tapSpecific,
      targetEmoji: '❤️',
      baseSpeed: 130,
      spawnInterval: 0.45,
      targetScore: 300,
      emojiMix: 2,
    ),
    // ── Level 2 ─────────────────────────────────────────────────────────────
    LevelConfig(
      level: 2,
      title: 'Getting Real',
      ruleText: 'Tap only 😊',
      instructionText: 'TAP ONLY 😊',
      ruleType: RuleType.tapSpecific,
      targetEmoji: '😊',
      baseSpeed: 150,
      spawnInterval: 0.4,
      targetScore: 400,
      emojiMix: 3,
    ),
    // ── Level 3 ─────────────────────────────────────────────────────────────
    LevelConfig(
      level: 3,
      title: 'Danger Lurks',
      ruleText: 'AVOID 💀 — tap everything else!',
      instructionText: 'AVOID 💀',
      ruleType: RuleType.avoidSpecific,
      targetEmoji: '💀',
      baseSpeed: 170,
      spawnInterval: 0.36,
      targetScore: 500,
      emojiMix: 3,
    ),
    // ── Level 4 ─────────────────────────────────────────────────────────────
    LevelConfig(
      level: 4,
      title: 'Feels Heavy',
      ruleText: 'Tap only SAD emojis 😭',
      instructionText: 'ONLY SAD 😭💔',
      ruleType: RuleType.tapCategory,
      targetCategory: EmojiCategory.sad,
      baseSpeed: 185,
      spawnInterval: 0.34,
      targetScore: 600,
      emojiMix: 3,
    ),
    // ── Level 5 ─────────────────────────────────────────────────────────────
    LevelConfig(
      level: 5,
      title: 'Good Vibes Only',
      ruleText: 'Tap only HAPPY emojis 😄',
      instructionText: 'ONLY HAPPY 😄🤩',
      ruleType: RuleType.tapCategory,
      targetCategory: EmojiCategory.happy,
      baseSpeed: 200,
      spawnInterval: 0.32,
      targetScore: 700,
      emojiMix: 4,
    ),
    // ── Level 6 ─────────────────────────────────────────────────────────────
    LevelConfig(
      level: 6,
      title: 'Love Season',
      ruleText: 'Tap only LOVE emojis ❤️',
      instructionText: 'LOVE ONLY 💕🥰',
      ruleType: RuleType.tapCategory,
      targetCategory: EmojiCategory.love,
      baseSpeed: 215,
      spawnInterval: 0.3,
      targetScore: 800,
      emojiMix: 4,
    ),
    // ── Level 7 ─────────────────────────────────────────────────────────────
    LevelConfig(
      level: 7,
      title: 'Anger Issues',
      ruleText: 'AVOID all ANGRY emojis 😡',
      instructionText: 'NO ANGER 😡🤬',
      ruleType: RuleType.avoidCategory,
      targetCategory: EmojiCategory.angry,
      baseSpeed: 230,
      spawnInterval: 0.28,
      targetScore: 900,
      emojiMix: 4,
    ),
    // ── Level 8 ─────────────────────────────────────────────────────────────
    LevelConfig(
      level: 8,
      title: 'Star Hunter',
      ruleText: 'Tap only ⭐',
      instructionText: 'ONLY ⭐',
      ruleType: RuleType.tapSpecific,
      targetEmoji: '⭐',
      baseSpeed: 248,
      spawnInterval: 0.26,
      targetScore: 1000,
      emojiMix: 5,
      emojiSizeMultiplier: 0.9,
    ),
    // ── Level 9 ─────────────────────────────────────────────────────────────
    LevelConfig(
      level: 9,
      title: 'Ghost Protocol',
      ruleText: 'Tap only 👻',
      instructionText: 'GHOST ONLY 👻',
      ruleType: RuleType.tapSpecific,
      targetEmoji: '👻',
      baseSpeed: 265,
      spawnInterval: 0.24,
      targetScore: 1100,
      emojiMix: 5,
      emojiSizeMultiplier: 0.88,
    ),
    // ── Level 10 ────────────────────────────────────────────────────────────
    LevelConfig(
      level: 10,
      title: 'Money Mode',
      ruleText: 'Tap only MONEY emojis 💰',
      instructionText: 'MONEY ONLY 💰💵🤑',
      ruleType: RuleType.tapCategory,
      targetCategory: EmojiCategory.money,
      baseSpeed: 280,
      spawnInterval: 0.22,
      targetScore: 1200,
      emojiMix: 5,
      emojiSizeMultiplier: 0.86,
    ),
    // ── Level 11 ────────────────────────────────────────────────────────────
    LevelConfig(
      level: 11,
      title: 'No Danger Zone',
      ruleText: 'AVOID all DANGER emojis 💀☠️',
      instructionText: 'AVOID DANGER 💀☠️👻',
      ruleType: RuleType.avoidCategory,
      targetCategory: EmojiCategory.danger,
      baseSpeed: 300,
      spawnInterval: 0.2,
      targetScore: 1400,
      emojiMix: 5,
      emojiSizeMultiplier: 0.84,
    ),
    // ── Level 12 ────────────────────────────────────────────────────────────
    LevelConfig(
      level: 12,
      title: 'Animal Kingdom',
      ruleText: 'Tap only ANIMAL emojis 🦁',
      instructionText: 'ANIMALS ONLY 🐶🦁🐬',
      ruleType: RuleType.tapCategory,
      targetCategory: EmojiCategory.animals,
      baseSpeed: 320,
      spawnInterval: 0.18,
      targetScore: 1600,
      emojiMix: 6,
      emojiSizeMultiplier: 0.82,
    ),
    // ── Level 13 ────────────────────────────────────────────────────────────
    LevelConfig(
      level: 13,
      title: 'Nature Lover',
      ruleText: 'AVOID all FOOD emojis 🍕',
      instructionText: 'NO FOOD 🍕🍔🍦',
      ruleType: RuleType.avoidCategory,
      targetCategory: EmojiCategory.food,
      baseSpeed: 340,
      spawnInterval: 0.16,
      targetScore: 1800,
      emojiMix: 6,
      emojiSizeMultiplier: 0.80,
    ),
    // ── Level 14 ────────────────────────────────────────────────────────────
    LevelConfig(
      level: 14,
      title: 'Diamond Hands',
      ruleText: 'Tap only 💎',
      instructionText: 'ONLY 💎',
      ruleType: RuleType.tapSpecific,
      targetEmoji: '💎',
      baseSpeed: 360,
      spawnInterval: 0.14,
      targetScore: 2000,
      emojiMix: 7,
      emojiSizeMultiplier: 0.78,
    ),
    // ── Level 15 ────────────────────────────────────────────────────────────
    LevelConfig(
      level: 15,
      title: '🔥 CHAOS MODE 🔥',
      ruleText: 'AVOID SCARED & DANGER emojis!',
      instructionText: 'NO FEAR NO DANGER 💀😱',
      ruleType: RuleType.avoidCategory,
      targetCategory: EmojiCategory.danger,
      baseSpeed: 390,
      spawnInterval: 0.12,
      targetScore: 2500,
      emojiMix: 7,
      emojiSizeMultiplier: 0.76,
    ),
  ];

  static LevelConfig getLevel(int level) {
    if (level <= 0) return levels.first;
    if (level <= levels.length) return levels[level - 1];
    // Beyond level 15: procedural insanity
    final last = levels.last;
    final extra = level - levels.length;
    return LevelConfig(
      level: level,
      title: 'INSANE LVL $level',
      ruleText: last.ruleText,
      instructionText: last.instructionText,
      ruleType: last.ruleType,
      targetEmoji: last.targetEmoji,
      targetCategory: last.targetCategory,
      baseSpeed: (last.baseSpeed + extra * 18).clamp(0, 520),
      spawnInterval: (last.spawnInterval - extra * 0.02).clamp(0.12, 1.5),
      targetScore: last.targetScore + extra * 300,
      emojiMix: (last.emojiMix + (extra ~/ 3)).clamp(0, 12),
      emojiSizeMultiplier: 0.74,
    );
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
    "The emoji was literally falling toward you 🙄",
    "This is why we can't have nice things 😩",
    "I believe in you! (I don't) 💀",
    "Speed: fast. Accuracy: zero 😭",
    "You chose chaos 🌪️",
    "Even the 💩 emoji is judging you",
    "New achievement: Epic Fail 🏅",
    "Blink twice if you need help 👀",
    "You let it fall off the screen 🤦‍♂️",
    "It was RIGHT THERE 😱",
    "You watched it fall and did nothing. Why? 😂",
    "The emoji escaped because of you 🏃",
    "Attention span: goldfish 🐟",
  ];

  static String getRandom() {
    final copy = List<String>.from(messages)..shuffle();
    return copy.first;
  }

  static String getForWrongTap(String tapped) {
    if (tapped == '💀' || tapped == '☠️') return "You literally tapped 💀... tragic 😭";
    if (tapped == '💩') return "You tapped the 💩. No further questions.";
    if (tapped == '😡' || tapped == '🤬') return "Touch the angry emoji again I dare you 😡";
    if (tapped == '💔') return "You picked 💔... love no be your thing 😭";
    if (tapped == '👻') return "BOO! Wrong ghost 👻 Game over.";
    return getRandom();
  }

  static String getForMissedTarget(String missed) {
    return [
      "You let $missed escape... unacceptable 😤",
      "$missed fell off the screen. You froze. Why? 💀",
      "It was RIGHT THERE 👇 You missed $missed",
      "The $missed emoji is now living its best life on the floor 😂",
      "Attention span of a goldfish 🐟 You missed $missed",
    ][DateTime.now().millisecond % 5];
  }
}
