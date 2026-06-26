import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_constants.dart';
import '../services/coin_service.dart';
import '../services/streak_service.dart';

class DailyRewardModal extends StatefulWidget {
  const DailyRewardModal({super.key});

  @override
  State<DailyRewardModal> createState() => _DailyRewardModalState();
}

class _DailyRewardModalState extends State<DailyRewardModal> {
  bool _claimed = false;
  int  _reward  = 0;

  @override
  Widget build(BuildContext context) {
    final streak = StreakService.instance;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.45),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color:      AppColors.primary.withOpacity(0.22),
              blurRadius: 36,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            if (!_claimed) ...[
              const Text('🔥', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 8),
              Text(
                'DAY ${(streak.streak + 1).clamp(1, 7)} STREAK!',
                style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900,
                  color: AppColors.primary, letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Log in daily for bigger coin rewards',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const Text('🎉', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 8),
              const Text(
                'REWARD CLAIMED!',
                style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900,
                  color: AppColors.success, letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Come back tomorrow to keep your streak',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 22),

            // ── 7-Day Grid ──────────────────────────────────────────────────
            _buildStreakGrid(streak.streak),

            const SizedBox(height: 20),

            // ── Coin Reward Display ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.11),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.35)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Text(
                    _claimed
                        ? '+$_reward Coins Added!'
                        : '+${streak.pendingReward} Coins',
                    style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Action Button ───────────────────────────────────────────────
            if (!_claimed)
              _PrimaryBtn(label: '🎁  CLAIM REWARD', onTap: _claimReward)
            else
              _SecondaryBtn(
                label: 'LET\'S PLAY! 🎮',
                onTap: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      )
          .animate()
          .scale(
            begin: const Offset(0.85, 0.85),
            end:   const Offset(1.0,  1.0),
            duration: 380.ms,
            curve: Curves.elasticOut,
          ),
    );
  }

  Widget _buildStreakGrid(int currentStreak) {
    final rewards = StreakService.rewardSchedule;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final dayNum   = i + 1;
        final isPast   = dayNum <= currentStreak;
        final isToday  = dayNum == currentStreak + 1;
        final isFuture = dayNum > currentStreak + 1;
        final reward   = rewards[i];

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: Column(
              children: [
                // Day circle
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPast
                        ? AppColors.primary
                        : isToday
                            ? AppColors.primary.withOpacity(0.18)
                            : AppColors.surfaceCard,
                    border: Border.all(
                      color: isToday
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: isPast
                        ? [BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 8,
                          )]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      isPast ? '✓' : '$dayNum',
                      style: TextStyle(
                        fontSize: isPast ? 13 : 12,
                        fontWeight: FontWeight.w900,
                        color: isPast
                            ? Colors.black
                            : isToday
                                ? AppColors.primary
                                : AppColors.textSecondary.withOpacity(0.35),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                // Reward label
                Text(
                  i == 6 ? '🏆' : '${reward}c',
                  style: TextStyle(
                    fontSize: i == 6 ? 12 : 9,
                    fontWeight: FontWeight.w800,
                    color: isFuture
                        ? AppColors.textSecondary.withOpacity(0.25)
                        : isToday
                            ? AppColors.primary
                            : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Future<void> _claimReward() async {
    final amount = await StreakService.instance.claimDailyReward();
    if (amount > 0) await CoinService.instance.addCoins(amount);
    if (mounted) {
      setState(() {
        _claimed = true;
        _reward  = amount;
      });
    }
  }
}

// ── Reusable buttons ──────────────────────────────────────────────────────────
class _PrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity, height: 52,
          decoration: BoxDecoration(
            gradient: AppColors.primaryBtnGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color:      AppColors.primary.withOpacity(0.4),
                blurRadius: 14,
                offset:     const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(label, style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w900,
              color: Colors.black, letterSpacing: 1,
            )),
          ),
        ),
      );
}

class _SecondaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SecondaryBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity, height: 52,
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          child: Center(
            child: Text(label, style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w900,
              color: AppColors.textPrimary, letterSpacing: 1,
            )),
          ),
        ),
      );
}

// ── Helper to show the modal ──────────────────────────────────────────────────
Future<void> showDailyRewardModal(BuildContext context) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.75),
    builder: (_) => const DailyRewardModal(),
  );
}
