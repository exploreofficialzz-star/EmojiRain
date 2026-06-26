import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StreakService extends ChangeNotifier {
  StreakService._();
  static final StreakService instance = StreakService._();

  static const String _streakKey    = 'daily_streak_count';
  static const String _lastClaimKey = 'daily_streak_last_claim';

  // Coin rewards: Day 1 → 7+
  static const List<int> rewardSchedule = [50, 75, 100, 150, 200, 250, 500];

  int  _streak        = 0;
  bool _canClaimToday = false;
  int  _pendingReward = 0;

  int  get streak        => _streak;
  bool get canClaimToday => _canClaimToday;
  int  get pendingReward => _pendingReward;

  /// The reward the player will receive on claiming today.
  /// Based on the streak they'll reach after claiming (streak + 1).
  int get rewardForNextClaim {
    final nextStreak = _streak + 1;
    return rewardSchedule[(nextStreak - 1).clamp(0, rewardSchedule.length - 1)];
  }

  Future<void> init() async {
    final prefs      = await SharedPreferences.getInstance();
    _streak          = prefs.getInt(_streakKey) ?? 0;
    final lastClaim  = prefs.getString(_lastClaimKey) ?? '';
    final todayUTC   = _utcDateString(DateTime.now().toUtc());
    final yesterdayUTC = _utcDateString(
      DateTime.now().toUtc().subtract(const Duration(days: 1)),
    );

    if (lastClaim == todayUTC) {
      // Already claimed today
      _canClaimToday = false;
    } else if (lastClaim == yesterdayUTC || lastClaim.isEmpty) {
      // Consecutive day or very first time
      _canClaimToday = true;
    } else {
      // Missed one or more days — reset streak
      _streak = 0;
      await prefs.setInt(_streakKey, 0);
      _canClaimToday = true;
    }

    _pendingReward = _canClaimToday ? rewardForNextClaim : 0;
    notifyListeners();
  }

  /// Claims today's reward. Returns the coin amount awarded.
  /// Caller is responsible for adding coins via CoinService.
  Future<int> claimDailyReward() async {
    if (!_canClaimToday) return 0;

    _streak       += 1;
    _canClaimToday = false;

    final prefs   = await SharedPreferences.getInstance();
    await prefs.setInt(_streakKey, _streak);
    await prefs.setString(_lastClaimKey, _utcDateString(DateTime.now().toUtc()));

    final reward  = rewardSchedule[(_streak - 1).clamp(0, rewardSchedule.length - 1)];
    _pendingReward = reward;
    notifyListeners();
    return reward;
  }

  String _utcDateString(DateTime utc) =>
      '${utc.year}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}';
}
