import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/fake_leaderboard_names.dart';

// ─────────────────────────────────────────────────────────────────────────────
class LeaderboardEntry {
  final int    rank;
  final String name;
  final String flag;
  final int    score;
  final bool   isRealPlayer;
  final String lastActive;   // "just now", "2m ago" etc.
  final int    recentChange; // points gained this slot — shown as "+X ↑"

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

  // Flip to true in a future update to enable real prize payouts
  static const bool winnersEnabled = false;

  // Bot score multipliers per rank (rank 1 = index 0)
  static const List<double> _multipliers = [
    1.18, 1.14, 1.11, 1.09, 1.07,
    1.05, 1.04, 1.03, 1.02, 1.01,
  ];

  // Hard floor scores per rank — shown even if no one has played yet
  static const List<int> _floors = [
    850, 780, 720, 670, 620,
    570, 520, 470, 420, 350,
  ];

  // How much scores grow from midnight to end-of-day (time progression bonus)
  static const List<int> _timeBonuses = [
    200, 180, 160, 140, 120,
    105,  90,  80,  65,  50,
  ];

  // Prize amounts per rank (displayed in UI)
  static const List<String> prizes = [
    r'$50', r'$40', r'$30', r'$20', r'$10',
    r'$5',  r'$5',  r'$5',  r'$5',  r'$5',
  ];

  static const String _resetDateKey = 'lb_reset_date';
  static const String _bestTodayKey = 'lb_best_today';

  List<LeaderboardEntry> _entries         = [];
  int                    _bestRealToday   = 0;
  String                 _storedResetDate = '';

  List<LeaderboardEntry> get entries       => List.unmodifiable(_entries);
  int                    get bestRealToday => _bestRealToday;

  // ── Countdown to midnight UTC ────────────────────────────────────────────
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

  // ── Fake "players online now" — realistic daily curve ────────────────────
  String get playersOnlineText {
    final now          = DateTime.now().toUtc();
    final mins         = now.hour * 60 + now.minute;
    final fraction     = mins / 1440.0;
    final base         = (fraction * (2 - fraction) * 4800).round();
    final jitter       = ((now.minute ~/ 5) * 73) % 200;
    final total        = (base + jitter + 120).clamp(120, 4800);
    return '$total players competing now';
  }

  // ── Gap text shown on player card ────────────────────────────────────────
  String get playerGapText {
    if (_bestRealToday == 0) return 'Play a game to enter the race!';
    final lowestBot = _entries.isNotEmpty ? _entries.last.score : 0;
    final gap       = lowestBot - _bestRealToday;
    if (gap <= 0) return "You\'re in range — keep grinding! 🔥";
    return 'You need $gap more points to enter top 10!';
  }

  Future<void> init() async {
    final prefs      = await SharedPreferences.getInstance();
    _storedResetDate = prefs.getString(_resetDateKey) ?? '';
    _bestRealToday   = prefs.getInt(_bestTodayKey)    ?? 0;
    _checkAndReset();
  }

  // Called after every game over
  Future<void> submitScore(int score) async {
    if (score <= 0) return;
    _checkAndReset();
    if (score > _bestRealToday) {
      _bestRealToday = score;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bestTodayKey, score);
    }
    _recalculate();
  }

  // Called every time the leaderboard screen opens or auto-refreshes
  void refresh() => _checkAndReset();

  // ─────────────────────────────────────────────────────────────────────────
  void _checkAndReset() {
    final todayUTC = _utcDateString(DateTime.now().toUtc());
    if (_storedResetDate != todayUTC) {
      _bestRealToday   = 0;
      _storedResetDate = todayUTC;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_resetDateKey, todayUTC);
        prefs.setInt(_bestTodayKey, 0);
      });
    }
    _recalculate();
  }

  void _recalculate() {
    final now    = DateTime.now().toUtc();
    final dayKey = _dayKey(
      _storedResetDate.isNotEmpty ? _storedResetDate : _utcDateString(now),
    );
    final names  = _selectDailyNames(dayKey);

    _entries = List.generate(10, (i) {
      return LeaderboardEntry(
        rank:         i + 1,
        name:         names[i].name,
        flag:         names[i].flag,
        score:        _botScore(i, _bestRealToday, now),
        isRealPlayer: false,
        lastActive:   _lastActiveText(i, now),
        recentChange: _recentChange(i, now),
      );
    });

    notifyListeners();
  }

  // ── Bot score: base + time-of-day progression + per-slot jitter ──────────
  int _botScore(int ri, int realScore, DateTime utc) {
    // Floor from real player's score
    final fromReal = (realScore * _multipliers[ri]).round();
    final floor    = _floors[ri];
    final base     = fromReal > floor ? fromReal : floor;

    // Time-of-day bonus: 0 at midnight → full _timeBonuses[ri] by end of day
    final mins        = utc.hour * 60 + utc.minute;
    final dayFraction = mins / 1440.0;
    final timeBonus   = (dayFraction * _timeBonuses[ri]).round();

    // Micro-jitter: each 4-minute slot gives a different bump (5–44 pts)
    final slot   = utc.minute ~/ 4;
    final jitter = ((slot * 97 + ri * 41 + utc.day * 13) % 40) + 5;

    return base + timeBonus + jitter;
  }

  // ── How many points this entry "gained" in the last slot ─────────────────
  int _recentChange(int ri, DateTime utc) {
    final slot = utc.minute ~/ 4;
    // Always positive (8–32 pts) — scores only go up in a live competition
    return 8 + ((slot * 11 + ri * 19 + utc.hour * 3) % 25);
  }

  // ── Activity timestamp per entry ──────────────────────────────────────────
  String _lastActiveText(int ri, DateTime utc) {
    final seed       = (utc.minute ~/ 4) * 13 + ri * 29 + utc.hour * 7;
    final minutesAgo = (seed % 9) + 1; // 1–9 minutes ago
    if (minutesAgo == 1) return 'just now';
    return '${minutesAgo}m ago';
  }

  // ── Deterministic name selection: same per UTC day, all devices ───────────
  List<BotName> _selectDailyNames(int dayKey) {
    final all   = FakeLeaderboardNames.allNames;
    final total = all.length;
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

  int _dayKey(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return 0;
    final y = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final d = int.tryParse(parts[2]) ?? 0;
    return y * 10000 + m * 100 + d;
  }

  String _utcDateString(DateTime utc) =>
      '${utc.year}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}';
}
