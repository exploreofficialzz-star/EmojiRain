import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_constants.dart';
import '../providers/game_provider.dart';
import '../services/coin_service.dart';

class PowerupHUD extends StatelessWidget {
  final GameProvider game;
  const PowerupHUD({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CoinService.instance,
      builder: (context, _) {
        final coins = CoinService.instance.balance;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PowerupBtn(
              icon:     '⏰',
              label:    'Slow',
              cost:     GameConstants.slowMoCost,
              coins:    coins,
              active:   game.slowMoActive,
              disabled: game.slowMoActive,
              onTap:    () => _activate(context, () => game.activateSlowMo()),
            ),
            const SizedBox(width: 14),
            _PowerupBtn(
              icon:     '🛡️',
              label:    'Shield',
              cost:     GameConstants.shieldCost,
              coins:    coins,
              active:   game.shieldActive,
              disabled: game.shieldActive,
              onTap:    () => _activate(context, () => game.activateShield()),
            ),
            const SizedBox(width: 14),
            _PowerupBtn(
              icon:     '💣',
              label:    'Clear',
              cost:     GameConstants.clearWaveCost,
              coins:    coins,
              disabled: false,
              active:   false,
              onTap:    () => _activate(context, () => game.activateClearWave()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _activate(
    BuildContext context,
    Future<bool> Function() activator,
  ) async {
    final success = await activator();
    if (!success && context.mounted) {
      _showNotEnoughCoinsSnack(context);
    }
  }

  void _showNotEnoughCoinsSnack(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceCard,
        behavior:        SnackBarBehavior.floating,
        margin:  const EdgeInsets.fromLTRB(20, 0, 20, 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape:   RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
        ),
        duration: const Duration(seconds: 2),
        content: const Row(
          children: [
            Text('🪙', style: TextStyle(fontSize: 18)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Not enough coins — keep tapping to earn more!',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13, fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PowerupBtn extends StatelessWidget {
  final String       icon;
  final String       label;
  final int          cost;
  final int          coins;
  final bool         active;
  final bool         disabled;
  final VoidCallback onTap;

  const _PowerupBtn({
    required this.icon,
    required this.label,
    required this.cost,
    required this.coins,
    required this.active,
    required this.disabled,
    required this.onTap,
  });

  bool get _canAfford => coins >= cost;

  @override
  Widget build(BuildContext context) {
    final isActive = active;
    final canBuy   = _canAfford && !disabled;

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width:  64, height: 68,
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withOpacity(0.18)
              : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? AppColors.primary
                : canBuy
                    ? AppColors.primary.withOpacity(0.35)
                    : Colors.white.withOpacity(0.08),
            width: isActive ? 1.8 : 1.2,
          ),
          boxShadow: isActive
              ? [BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 12,
                )]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isActive ? _activeEmoji : icon,
              style: const TextStyle(fontSize: 22),
            )
                .animate(target: isActive ? 1 : 0)
                .scaleXY(end: 1.15, duration: 500.ms)
                .then()
                .scaleXY(end: 1.0, duration: 500.ms),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize:   9,
                fontWeight: FontWeight.w800,
                color: isActive
                    ? AppColors.primary
                    : AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isActive ? 'ACTIVE' : '🪙$cost',
              style: TextStyle(
                fontSize:   8,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? AppColors.success
                    : canBuy
                        ? AppColors.primary.withOpacity(0.8)
                        : AppColors.textSecondary.withOpacity(0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _activeEmoji {
    switch (icon) {
      case '⏰': return '⏳';
      case '🛡️': return '✨';
      default:    return icon;
    }
  }
}
