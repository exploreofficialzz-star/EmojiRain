import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/fake_leaderboard_names.dart';
import 'profile_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
class LeaderboardEntry {
  final int    rank;
  final String name;
  final String flag;
  final int    score;
  final bool   isRealPlayer;
  final String lastActive;
  final int    recentChange;

  const LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.flag,
    required this.score,
    required this.isRealPlayer,
    required this.lastActive,
    required this.recentChange,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
class LeaderboardService extends ChangeNotifier {
  LeaderboardService._();
  static final LeaderboardService instance = LeaderboardService._();

  static const bool winnersEnabled = false;

  // ── Score multipliers for bots ranked ABOVE the real player ───────────────
  static const List<double> _multipliers = [
    1.18, 1.14, 1.11, 1.09, 1.07,
    1.05, 1.04, 1.03, 1.02, 1.01,
  ];

  // ── Hard floor scores — shown even before any games are played ─────────────
  static const List<int> _floors = [
    850, 780, 720, 670, 620,
    570, 520, 470, 420, 350,
  ];

  // ── Score growth bonus: 0 at midnight → full amount at end of day ──────────
  static const List<int> _timeBonuses = [
    200, 180, 160, 140, 120,
    105,  90,  80,  65,  50,
  ];

  // ── Score drop-off % per rank below the real player (e.g. 4% per slot) ────
  static const double _belowPlayerDropPct = 0.04;

  static const List<String> prizes = [
    r'$50', r'$40', r'$30', r'$20', r'$10',
    r'$5',  r'$5',  r'$5',  r'$5',  r'$5',
  ];

  static const String _resetDateKey = 'lb_reset_date';
  static const String _bestTodayKey = 'lb_best_today';

  List<LeaderboardEntry> _entries         = [];
  int                    _bestRealToday   = 0;
  String                 _storedResetDate = '';
  int?                   _playerRankIdx;  // null = player not currently in list

  List<LeaderboardEntry> get entries        => List.unmodifiable(_entries);
  int                    get bestRealToday  => _bestRealToday;
  bool                   get playerIsInList => _playerRankIdx != null;
  int?                   get playerRank     => _playerRankIdx != null
                                                  ? _playerRankIdx! + 1
                                                  : null;

  // ── Countdown to UTC midnight ─────────────────────────────────────────────
  Duration get timeUntilReset {
    final now          = DateTime.now().toUtc();
    final nextMidnight = DateTime.utc(now.year, now.month, now.day + 1);
    return nextMidnight.difference(now);
  }

  String get countdownText {
    final d = timeUntilReset;
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h : $m : $s';
  }

  // ── Realistic "players online" curve ─────────────────────────────────────
  String get playersOnlineText {
    final now      = DateTime.now().toUtc();
    final mins     = now.hour * 60 + now.minute;
    final fraction = mins / 1440.0;
    final base     = (fraction * (2 - fraction) * 4800).round();
    final jitter   = ((now.minute ~/ 5) * 73) % 200;
    final total    = (base + jitter + 120).clamp(120, 4800);
    return '$total players competing now';
  }

  // ── Context-aware status text for the player card ─────────────────────────
  String get playerGapText {
    if (_playerRankIdx != null) {
      // Player IS in the list — show their current standing
      final rank = _playerRankIdx! + 1;
      if (rank <= 3) return "You're top $rank today! Keep it up! 💪";
      if (rank <= 5) return "You're #$rank — bots are closing in! 🔥";
      if (rank <= 7) return "Holding #$rank — fight to climb higher! ⚡";
      return "Slipping to #$rank... push before day ends! 😤";
    }

    if (_bestRealToday == 0) return 'Play a game to enter the race!';
    final lowestBot = _entries.isNotEmpty ? _entries.last.score : 0;
    final gap       = lowestBot - _bestRealToday;
    if (gap <= 0) return "You're in range — keep grinding! 🔥";
    return 'You need $gap more points to enter top 10!';
  }

  // ─────────────────────────────────────────────────────────────────────────
  Future<void> init() async {
    final prefs      = await SharedPreferences.getInstance();
    _storedResetDate = prefs.getString(_resetDateKey) ?? '';
    _bestRealToday   = prefs.getInt(_bestTodayKey)    ?? 0;
    _checkAndReset();
  }

  Future<void> submitScore(int score) async {
    if (score <= 0) return;
    _checkAndReset();
    if (score > _bestRealToday) {
      _bestRealToday = score;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bestTodayKey, _bestRealToday);
    }
    _recalculate();
  }

  void refresh() => _checkAndReset();

  // ─────────────────────────────────────────────────────────────────────────
  void _checkAndReset() {
    final todayUTC = _utcDateString(DateTime.now().toUtc());
    if (_storedResetDate != todayUTC) {
      _bestRealToday   = 0;
      _storedResetDate = todayUTC;
      _playerRankIdx   = null;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_resetDateKey, todayUTC);
        prefs.setInt(_bestTodayKey, 0);
      });
    }
    _recalculate();
  }

  // ── Core rebuild ──────────────────────────────────────────────────────────
  void _recalculate() {
    final now    = DateTime.now().toUtc();
    final dayKey = _dayKey(
      _storedResetDate.isNotEmpty ? _storedResetDate : _utcDateString(now),
    );
    final names      = _selectDailyNames(dayKey);  // always 10; we use 9 when player is in
    final playerIdx  = _playerInsertIndex(now, dayKey);

    _playerRankIdx = playerIdx;
    _entries       = _buildEntries(playerIdx, names, now);

    notifyListeners();
  }

  // ── Decide WHERE in the list to insert the real player ────────────────────
  //
  // Logic:
  //   • Player only appears if they've played today AND have a profile name.
  //   • A per-day deterministic seed decides:
  //       – whether they appear on this particular day (70% of days)
  //       – their PEAK rank at the start of the day (rank 3, 4, or 5)
  //   • Their rank degrades linearly from peakRank → rank 10 over the day.
  //   • They fall off the list entirely between 7 PM and 10 PM UTC (varies daily).
  //   • A 4-minute jitter slot makes the position flicker ±1 so it feels alive.
  //
  int? _playerInsertIndex(DateTime utc, int dayKey) {
    if (_bestRealToday == 0) return null;

    final profile = ProfileService.instance;
    if (!profile.isSetUp) return null;

    // Deterministic day seed (0–99)
    final daySeed = (dayKey * 7919 + 31) % 100;

    // 70 out of 100 days the player appears — rest they're off the board
    if (daySeed >= 70) return null;

    // Peak rank index (0-indexed) — 3rd, 4th, or 5th place at day start
    final peakIdx = daySeed < 28 ? 2   // 3rd  (40 % of appearance days)
        : daySeed < 52           ? 3   // 4th  (34 %)
        : 4;                           // 5th  (26 %)

    // Minutes elapsed since UTC midnight
    final minsNow = utc.hour * 60 + utc.minute;

    // UTC minute at which the player finally falls off the list (7 PM – 10 PM)
    final exitMins = 1140 + (daySeed * 5 % 180); // 1140 = 19:00, up to ~10:00 PM

    if (minsNow >= exitMins) return null;

    // Linear drift: peakIdx → rank 9 (index) over the course of the day
    final progress   = (minsNow / exitMins).clamp(0.0, 1.0);
    final driftedIdx = (peakIdx + progress * (9 - peakIdx)).round();

    // 4-minute slot jitter (−1, 0, or +1) so rank feels alive
    final slot    = utc.minute ~/ 4;
    final jitter  = ((slot * 13 + (dayKey % 17)) % 3) - 1;

    return (driftedIdx + jitter).clamp(peakIdx, 9);
  }

  // ── Build the final 10-entry list, splicing player in if needed ───────────
  List<LeaderboardEntry> _buildEntries(
    int? playerIdx, List<BotName> names, DateTime utc,
  ) {
    final profile    = ProfileService.instance;
    final showPlayer = playerIdx != null && profile.isSetUp;

    final result  = <LeaderboardEntry>[];
    int botSlot   = 0; // index into `names` (skips nothing — player has no slot there)

    for (int rank = 0; rank < 10; rank++) {
      if (showPlayer && rank == playerIdx) {
        // ── Real player entry ──────────────────────────────────────────────
        result.add(LeaderboardEntry(
          rank:         rank + 1,
          name:         '${profile.avatar} ${profile.displayName}',
          flag:         profile.flag.isNotEmpty ? profile.flag : '🌍',
          score:        _bestRealToday,
          isRealPlayer: true,
          lastActive:   'just now',
          recentChange: _playerRecentChange(utc),
        ));
      } else {
        // ── Bot entry — score above or below player depending on position ──
        final botScore = _botScoreForRank(
          visualRank:  rank,
          playerIdx:   showPlayer ? playerIdx : null,
          realScore:   _bestRealToday,
          utc:         utc,
        );

        result.add(LeaderboardEntry(
          rank:         rank + 1,
          name:         names[botSlot].name,
          flag:         names[botSlot].flag,
          score:        botScore,
          isRealPlayer: false,
          lastActive:   _lastActiveText(rank, utc),
          recentChange: _recentChange(rank, utc),
        ));
        botSlot++;
      }
    }

    return result;
  }

  // ── Score for a bot at a given visual rank ────────────────────────────────
  //
  // • If above the player (or player not in list): existing multiplier formula.
  // • If below the player: each rank gap costs _belowPlayerDropPct of player score,
  //   so bots below always have LOWER scores than the player. Realistic.
  //
  int _botScoreForRank({
    required int     visualRank,
    required int?    playerIdx,
    required int     realScore,
    required DateTime utc,
  }) {
    final isAboveOrNoPlayer = playerIdx == null || visualRank < playerIdx;

    if (isAboveOrNoPlayer) {
      // ── Bot is ranked above the real player (or player not present) ───────
      final fromReal = (realScore * _multipliers[visualRank]).round();
      final floor    = _floors[visualRank];
      final base     = fromReal > floor ? fromReal : floor;

      final mins        = utc.hour * 60 + utc.minute;
      final dayFraction = mins / 1440.0;
      final timeBonus   = (dayFraction * _timeBonuses[visualRank]).round();

      final slot   = utc.minute ~/ 4;
      final jitter = ((slot * 97 + visualRank * 41 + utc.day * 13) % 40) + 5;

      return base + timeBonus + jitter;
    } else {
      // ── Bot is ranked below the real player ───────────────────────────────
      // Score decreases by _belowPlayerDropPct per rank below, ensuring bots
      // here always score LESS than the real player's display score.
      final gapFromPlayer = visualRank - playerIdx!; // 1, 2, 3...
      final reduction     = _belowPlayerDropPct * gapFromPlayer + 0.01;
      final reduced       = (realScore * (1.0 - reduction)).round();

      // Don't go below the hard floor for this rank
      final floor = _floors[visualRank];
      return reduced.clamp(floor, realScore - gapFromPlayer * 10);
    }
  }

  // ── How many points the real player "gained" in the last 4-min slot ──────
  int _playerRecentChange(DateTime utc) {
    final slot = utc.minute ~/ 4;
    return 10 + ((slot * 7 + utc.hour * 3) % 20); // 10–29 pts
  }

  // ── Bot activity timestamp ────────────────────────────────────────────────
  String _lastActiveText(int ri, DateTime utc) {
    final seed       = (utc.minute ~/ 4) * 13 + ri * 29 + utc.hour * 7;
    final minutesAgo = (seed % 9) + 1;
    if (minutesAgo == 1) return 'just now';
    return '${minutesAgo}m ago';
  }

  // ── Recent score change shown as "+X ↑" ──────────────────────────────────
  int _recentChange(int ri, DateTime utc) {
    final slot = utc.minute ~/ 4;
    return 8 + ((slot * 11 + ri * 19 + utc.hour * 3) % 25);
  }

  // ── Deterministic daily name selection ───────────────────────────────────
  List<BotName> _selectDailyNames(int dayKey) {
    final all    = FakeLeaderboardNames.allNames;
    final total  = all.length;
    final picked = <BotName>[];
    final used   = <int>{};

    for (int i = 0; i < 10; i++) {
      int idx = ((dayKey * 31) + (i * 137) + (i * i * 7)) % total;
      while (used.contains(idx)) {
        idx = (idx + 1) % total;
      }
      used.add(idx);
      picked.add(all[idx]);
    }
    return picked;
  }

  int    _dayKey(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 10000
         + (int.tryParse(parts[1]) ?? 0) * 100
         + (int.tryParse(parts[2]) ?? 0);
  }

  String _utcDateString(DateTime utc) =>
      '${utc.year}-'
      '${utc.month.toString().padLeft(2, '0')}-'
      '${utc.day.toString().padLeft(2, '0')}';
}
