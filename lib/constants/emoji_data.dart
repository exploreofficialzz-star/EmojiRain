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
    EmojiCategory.happy:   ['😊','😄','😁','🤩','😃','😀','🥳','🤗','😸','🙌','😺'],
    EmojiCategory.sad:     ['😢','😭','💔','😞','😥','🥺','😔','😩','😿','😓','🙁'],
    EmojiCategory.angry:   ['😡','🤬','😤','👿','💢','😠','🤯','😾','💥','👊'],
    EmojiCategory.scared:  ['😱','😨','😰','🙀','😬','🫣','😳','😧','😦','😲'],
    EmojiCategory.love:    ['❤️','🥰','😍','💕','💖','🫶','💗','😘','💝','💞','♥️','🩷','🩶'],
    EmojiCategory.cool:    ['😎','🤙','💪','👑','✌️','🦸','🕶️','🧊','🤘'],
    EmojiCategory.silly:   ['🤪','😜','😝','🤡','🙃','🫠','👅','🤓','🎭','😛'],
    EmojiCategory.danger:  ['💀','☠️','👻','💣','🔪','🕷️','🦂','🧨','⚡','🪓'],
    EmojiCategory.nature:  ['🌈','⭐','🌙','☀️','🌸','🌟','❄️','🌊','🍀','🌺','💫','✨'],
    EmojiCategory.food:    ['🍕','🍔','🍦','🍩','🎂','🍭','🌮','🍜','🧁','🍓','🍣','🥐'],
    EmojiCategory.money:   ['💰','💵','🤑','💎','🏆','💸','🪙','💳','🎰','🏅'],
    EmojiCategory.animals: ['🐶','🐱','🦊','🐸','🦄','🐼','🦁','🐬','🦋','🐨','🐯','🦅'],
  };

  // ── Visually confusing distractors for specific targets ───────────────────
  // Key = target emoji, Value = list of look-alike distractors to mix in
  static const Map<String, List<String>> confusingLookalikes = {
    '❤️':  ['🧡','💛','💚','💙','💜','🖤','🤍','💔','♥️','🩷','💗','💕'],
    '😊':  ['😀','😃','😄','😁','🙂','☺️','😸','😺','🤗','😏'],
    '⭐':  ['🌟','✨','💫','⚡','🌠','🌙','☀️','🌞','💥','🔆'],
    '👻':  ['💀','☠️','🕷️','🦴','🫥','🌫️','👁️','🤡','🎭','👤'],
    '💎':  ['🔷','🔹','💠','🪩','🧊','💍','💿','🔵','🫧','🩵'],
    '💀':  ['☠️','👻','🦴','🖤','⬛','🕷️','🌑','🪲','🦇','👁️'],
    '🔥':  ['💥','⚡','✨','🌟','💫','🌋','☄️','💛','🟠','🧨'],
    '💰':  ['💵','💸','🪙','💳','💶','💷','🏦','💴','🤑','🏧'],
    '😡':  ['🤬','😤','😠','👿','💢','😾','😑','😒','🫠','💥'],
  };

  // ── Full flat pool for generic distractors ────────────────────────────────
  static const List<String> allEmojis = [
    '😊','😄','😁','🤩','😃','😀','🥳','🤗',
    '😢','😭','💔','😞','😥','🥺','😔','😩',
    '😡','🤬','😤','👿','💢','😠','🤯',
    '😱','😨','😰','😬','😳','😧',
    '❤️','🥰','😍','💕','💖','🫶','💗','😘','💝',
    '😎','🤙','💪','👑','✌️',
    '🤪','😜','😝','🤡','🙃','🫠',
    '💀','☠️','👻','💣','🔪',
    '🌈','⭐','🌙','☀️','🌸','🌟','❄️',
    '🍕','🍔','🍦','🍩','🎂','🍭','🌮',
    '💰','💵','🤑','💎','🏆','💸',
    '🐶','🐱','🦊','🐸','🦄','🐼','🦁',
    '💩','🎉','🔮','🎯','🪄','🎪','🌋','☄️',
    '🧡','💛','💚','💙','💜','🖤','🤍',
    '🌟','✨','💫','💥','⚡','🔆',
  ];
}

// ─── Level Configuration ──────────────────────────────────────────────────────
enum RuleType { tapSpecific, avoidSpecific, tapCategory, avoidCategory }

class LevelConfig {
  final int      level;
  final String   title;
  final String   ruleText;
  final String   instructionText;
  final RuleType ruleType;
  final String?  targetEmoji;
  final String?  targetCategory;

  // Base speed for this level (speed ramp multiplier applied on top)
  final double baseSpeed;

  // Distractor ratio: how many wrong emojis per correct one spawned
  // Higher = harder to spot the target
  final int distractorRatio;

  // Whether to use confusingLookalikes for distractors (much harder)
  final bool useLookalikes;

  // Emoji size scale for this level
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
    this.distractorRatio = 3,
    this.useLookalikes = false,
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

// ─── 15 Levels — 1 minute each, progressively brutal ─────────────────────────
class LevelData {
  static const List<LevelConfig> levels = [
    LevelConfig(
      level: 1, title: 'First Drop',
      ruleText: 'Tap only ❤️',
      instructionText: 'TAP ONLY ❤️',
      ruleType: RuleType.tapSpecific, targetEmoji: '❤️',
      baseSpeed: 120, distractorRatio: 2, useLookalikes: false,
    ),
    LevelConfig(
      level: 2, title: 'Getting Warmer',
      ruleText: 'Tap only 😊',
      instructionText: 'TAP ONLY 😊',
      ruleType: RuleType.tapSpecific, targetEmoji: '😊',
      baseSpeed: 135, distractorRatio: 3, useLookalikes: false,
    ),
    LevelConfig(
      level: 3, title: 'Danger Lurks',
      ruleText: 'AVOID 💀 — tap everything else!',
      instructionText: 'AVOID 💀',
      ruleType: RuleType.avoidSpecific, targetEmoji: '💀',
      baseSpeed: 148, distractorRatio: 3, useLookalikes: true,
    ),
    LevelConfig(
      level: 4, title: 'Heavy Feels',
      ruleText: 'Tap only SAD emojis 😭',
      instructionText: 'ONLY SAD 😭💔',
      ruleType: RuleType.tapCategory, targetCategory: EmojiCategory.sad,
      baseSpeed: 160, distractorRatio: 3,
    ),
    LevelConfig(
      level: 5, title: 'Good Vibes Only',
      ruleText: 'Tap only HAPPY emojis 😄',
      instructionText: 'ONLY HAPPY 😄🤩',
      ruleType: RuleType.tapCategory, targetCategory: EmojiCategory.happy,
      baseSpeed: 175, distractorRatio: 4, useLookalikes: true,
    ),
    LevelConfig(
      level: 6, title: 'Heart Season',
      ruleText: 'Tap only ❤️ — watch the fakes!',
      instructionText: 'ONLY ❤️ (BEWARE FAKES)',
      ruleType: RuleType.tapSpecific, targetEmoji: '❤️',
      baseSpeed: 188, distractorRatio: 4, useLookalikes: true,
    ),
    LevelConfig(
      level: 7, title: 'No Anger',
      ruleText: 'AVOID all ANGRY emojis 😡',
      instructionText: 'NO ANGER 😡🤬',
      ruleType: RuleType.avoidCategory, targetCategory: EmojiCategory.angry,
      baseSpeed: 200, distractorRatio: 4, useLookalikes: true,
    ),
    LevelConfig(
      level: 8, title: 'Star Hunter',
      ruleText: 'Tap only ⭐ — not ✨🌟!',
      instructionText: 'ONLY ⭐ (NOT ✨🌟)',
      ruleType: RuleType.tapSpecific, targetEmoji: '⭐',
      baseSpeed: 215, distractorRatio: 5, useLookalikes: true,
      emojiSizeMultiplier: 0.90,
    ),
    LevelConfig(
      level: 9, title: 'Ghost Protocol',
      ruleText: 'Tap only 👻 — not 💀☠️!',
      instructionText: 'ONLY 👻 (NOT 💀☠️)',
      ruleType: RuleType.tapSpecific, targetEmoji: '👻',
      baseSpeed: 230, distractorRatio: 5, useLookalikes: true,
      emojiSizeMultiplier: 0.88,
    ),
    LevelConfig(
      level: 10, title: 'Money Moves',
      ruleText: 'Tap only MONEY emojis 💰',
      instructionText: 'MONEY ONLY 💰💎🤑',
      ruleType: RuleType.tapCategory, targetCategory: EmojiCategory.money,
      baseSpeed: 248, distractorRatio: 5, useLookalikes: true,
      emojiSizeMultiplier: 0.86,
    ),
    LevelConfig(
      level: 11, title: 'No Danger',
      ruleText: 'AVOID all DANGER emojis 💀☠️',
      instructionText: 'AVOID DANGER 💀☠️👻',
      ruleType: RuleType.avoidCategory, targetCategory: EmojiCategory.danger,
      baseSpeed: 265, distractorRatio: 5, useLookalikes: true,
      emojiSizeMultiplier: 0.84,
    ),
    LevelConfig(
      level: 12, title: 'Diamond Hunt',
      ruleText: 'Tap only 💎 — fakes everywhere!',
      instructionText: 'ONLY 💎 (BEWARE FAKES)',
      ruleType: RuleType.tapSpecific, targetEmoji: '💎',
      baseSpeed: 282, distractorRatio: 6, useLookalikes: true,
      emojiSizeMultiplier: 0.82,
    ),
    LevelConfig(
      level: 13, title: 'Animal Kingdom',
      ruleText: 'Tap only ANIMAL emojis 🦁',
      instructionText: 'ANIMALS ONLY 🐶🦁🐬',
      ruleType: RuleType.tapCategory, targetCategory: EmojiCategory.animals,
      baseSpeed: 300, distractorRatio: 6, useLookalikes: true,
      emojiSizeMultiplier: 0.80,
    ),
    LevelConfig(
      level: 14, title: 'No Food Allowed',
      ruleText: 'AVOID all FOOD emojis 🍕🍔',
      instructionText: 'NO FOOD 🍕🍔🎂',
      ruleType: RuleType.avoidCategory, targetCategory: EmojiCategory.food,
      baseSpeed: 320, distractorRatio: 6, useLookalikes: true,
      emojiSizeMultiplier: 0.78,
    ),
    LevelConfig(
      level: 15, title: '🔥 CHAOS MODE 🔥',
      ruleText: 'AVOID DANGER — everything falling looks the same!',
      instructionText: 'SURVIVE 💀☠️👻',
      ruleType: RuleType.avoidCategory, targetCategory: EmojiCategory.danger,
      baseSpeed: 345, distractorRatio: 7, useLookalikes: true,
      emojiSizeMultiplier: 0.76,
    ),
  ];

  static LevelConfig getLevel(int level) {
    if (level <= 0) return levels.first;
    if (level <= levels.length) return levels[level - 1];
    final last  = levels.last;
    final extra = level - levels.length;
    return LevelConfig(
      level: level, title: '💀 INSANE LVL $level',
      ruleText: last.ruleText, instructionText: last.instructionText,
      ruleType: last.ruleType, targetEmoji: last.targetEmoji,
      targetCategory: last.targetCategory,
      baseSpeed: (last.baseSpeed + extra * 20).clamp(0, 520),
      distractorRatio: (last.distractorRatio + extra ~/ 2).clamp(0, 14),
      useLookalikes: true,
      emojiSizeMultiplier: 0.74,
    );
  }
}

// ─── Fail Messages ────────────────────────────────────────────────────────────
class FailMessages {
  static const List<String> _generic = [
    "You had ONE job 💀",
    "Bro... that was clearly wrong 😭",
    "Your ancestors are disappointed 👴",
    "Even my grandma plays better 👵",
    "Focus mode: FAILED 🤦",
    "404: Focus not found 🧠",
    "The emojis are bullying you now 😂",
    "Skill issue detected 🚨",
    "Bruh 😐",
    "Your thumbs have betrayed you 👎",
    "That... was not it chief 💀",
    "Congratulations on being wrong 🏆",
    "You absolute legend of failure 😂",
    "Speed: fast. Accuracy: zero 😭",
    "New achievement: Epic Fail 🏅",
    "Attention span of a goldfish 🐟",
    "It was RIGHT THERE 😱",
    "You chose chaos 🌪️",
    "Time ran out... and so did your dignity ⌛",
    "60 seconds. That's all we asked. 💀",
  ];

  static String getRandom() {
    final copy = List<String>.from(_generic)..shuffle();
    return copy.first;
  }

  static String getForWrongTap(String tapped) {
    if (tapped == '💀' || tapped == '☠️') return "You literally tapped 💀... tragic 😭";
    if (tapped == '💩') return "You tapped the 💩. No further questions.";
    if (tapped == '😡' || tapped == '🤬') return "Touch the angry emoji one more time 😡";
    if (tapped == '💔') return "You picked 💔... love no be your thing 😭";
    if (tapped == '👻') return "BOO! Wrong ghost 👻 Game over.";
    return getRandom();
  }

  static String getForMissedTarget(String missed) {
    return [
      "You let $missed escape... unacceptable 😤",
      "$missed fell off the screen. You froze. Why? 💀",
      "It was RIGHT THERE 👇 You missed $missed",
      "The $missed emoji is living its best life on the floor now 😂",
      "Attention span of a goldfish 🐟 You missed $missed",
    ][DateTime.now().millisecond % 5];
  }

  static String getForTimeout() {
    return [
      "TIME'S UP ⌛ Too slow!",
      "60 seconds. That's all we asked 💀",
      "The clock beat you... embarrassing ⏰",
      "You survived but your score didn't 😭",
    ][DateTime.now().millisecond % 4];
  }
}
