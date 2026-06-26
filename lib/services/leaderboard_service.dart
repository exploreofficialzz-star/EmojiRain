import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/fake_leaderboard_names.dart';

class LeaderboardEntry {
  final int    rank;
  final String name;
  final String flag;
  final int    score;
  final bool   isRealPlayer;

  const LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.flag,
    required this.score,
    required this.isRealPlayer,
  });
}

class LeaderboardService extends ChangeNotifier {
  LeaderboardService._();
  static final LeaderboardService instance = LeaderboardService._();

  // ── Toggle this to true in a future update to enable real winners ──────────
  static const bool winnersEnabled = false;

  // ── Bot score multipliers per rank (rank 1 = index 0) ─────────────────────
  static const List<double> _multipliers = [
    1.18, 1.14, 1.11, 1.09, 1.07,
    1.05, 1.04, 1.03, 1.02, 1.01,
  ];

  // ── Minimum believable floor scores per rank ───────────────────────────────
  static const List<int> _floors = [
    850, 780, 720, 670, 620,
    570, 520, 470, 420, 350,
  ];

  // ── Prize display amounts per rank (shown in UI, paid when winnersEnabled) ─
  static const List<String> prizes = [
    '\$50', '\$40', '\$30', '\$20', '\$10',
    '\$5',  '\$5',  '\$5',  '\$5',  '\$5',
  ];

  static const String _resetDateKey    = 'lb_reset_date';
  static const String _bestTodayKey    = 'lb_best_today';

  List<LeaderboardEntry> _entries           = [];
  int                    _bestRealToday     = 0;
  String                 _storedResetDate   = '';

  List<LeaderboardEntry> get entries       => List.unmodifiable(_entries);
  int                    get bestRealToday => _bestRealToday;

  // ── Countdown to next midnight UTC ────────────────────────────────────────
  Duration get timeUntilReset {
    final now         = DateTime.now().toUtc();
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

  // ── Gap between player and 10th place ────────────────────────────────────
  String get playerGapText {
    if (_bestRealToday == 0) return 'Play a game to enter the race!';
    final lowestBot = _entries.isNotEmpty ? _entries.last.score : 0;
    final gap       = lowestBot - _bestRealToday;
    if (gap <= 0)   return 'You\'re in range — keep grinding! 🔥';
    return 'You need $gap more points to enter top 10!';
  }

  Future<void> init() async {
    final prefs      = await SharedPreferences.getInstance();
    _storedResetDate = prefs.getString(_resetDateKey) ?? '';
    _bestRealToday   = prefs.getInt(_bestTodayKey)    ?? 0;
    _checkAndReset();
  }

  // ── Called after every game over to update bot targets ───────────────────
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

  // ── Called every time leaderboard screen is opened ────────────────────────
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
    final dayKey = _dayKey(_storedResetDate.isNotEmpty
        ? _storedResetDate
        : _utcDateString(DateTime.now().toUtc()));

    final names = _selectDailyNames(dayKey);

    _entries = List.generate(10, (i) {
      final botScore = _botScore(i, _bestRealToday);
      return LeaderboardEntry(
        rank:         i + 1,
        name:         names[i].name,
        flag:         names[i].flag,
        score:        botScore,
        isRealPlayer: false,
      );
    });

    notifyListeners();
  }

  int _botScore(int rankIndex, int realScore) {
    final fromReal = (realScore * _multipliers[rankIndex]).round();
    final floor    = _floors[rankIndex];
    return fromReal > floor ? fromReal : floor;
  }

  /// Deterministic selection — same names for the same UTC date on every device
  List<BotName> _selectDailyNames(int dayKey) {
    final all    = FakeLeaderboardNames.allNames;
    final total  = all.length;
    final picked = <BotName>[];
    final used   = <int>{};

    for (int i = 0; i < 10; i++) {
      int idx = ((dayKey * 31) + (i * 137) + (i * i * 7)) % total;
      // Avoid duplicates with linear probing
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
