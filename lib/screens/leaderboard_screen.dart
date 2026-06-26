import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_constants.dart';
import '../services/leaderboard_service.dart';
import '../services/profile_service.dart';
import 'profile_setup_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  Timer? _countdownTimer;
  String _countdown = '';

  @override
  void initState() {
    super.initState();
    LeaderboardService.instance.refresh();
    _updateCountdown();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateCountdown(),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    if (!mounted) return;
    setState(() => _countdown = LeaderboardService.instance.countdownText);
  }

  void _goToProfileOrSubmit() {
    if (!ProfileService.instance.isSetUp) {
      Navigator.of(context).push(PageRouteBuilder(
        pageBuilder:        (_, anim, __) => const ProfileSetupScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: ListenableBuilder(
                  listenable: LeaderboardService.instance,
                  builder: (_, __) {
                    final entries = LeaderboardService.instance.entries;
                    if (entries.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Column(
                        children: [
                          _buildCountdownCard(),
                          const SizedBox(height: 16),
                          _buildPrizeHeader(),
                          const SizedBox(height: 12),
                          ...entries.asMap().entries.map(
                            (e) => _buildEntryTile(e.key, e.value),
                          ),
                          const SizedBox(height: 16),
                          _buildPlayerCard(),
                          const SizedBox(height: 20),
                          _buildSubmitBtn(),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 16,
              ),
            ),
          ),
          const Spacer(),
          const Text(
            '🏆  LEADERBOARD',
            style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w900,
              color: AppColors.primary, letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 38), // balance header
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  // ── Countdown Card ─────────────────────────────────────────────────────────
  Widget _buildCountdownCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DAILY RESET',
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary, letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Fresh start at midnight UTC',
                style: TextStyle(
                  fontSize: 11, color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Text('⏱', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  _countdown,
                  style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900,
                    color: AppColors.primary, letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Prize Header ───────────────────────────────────────────────────────────
  Widget _buildPrizeHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.15),
            AppColors.primaryGlow.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.35)),
      ),
      child: const Row(
        children: [
          Text('💰', style: TextStyle(fontSize: 20)),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DAILY PRIZE POOL',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w900,
                    color: AppColors.primary, letterSpacing: 1,
                  ),
                ),
                Text(
                  'Top 10 earn real cash rewards',
                  style: TextStyle(
                    fontSize: 10, color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Leaderboard Entry Tile ─────────────────────────────────────────────────
  Widget _buildEntryTile(int index, LeaderboardEntry entry) {
    final isTop3   = entry.rank <= 3;
    final rankEmoji = switch (entry.rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => '#${entry.rank}',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isTop3
            ? AppColors.primary.withOpacity(0.08)
            : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isTop3
              ? AppColors.primary.withOpacity(0.3)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 36,
            child: Text(
              rankEmoji,
              style: TextStyle(
                fontSize: isTop3 ? 20 : 13,
                fontWeight: FontWeight.w900,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),

          // Flag
          Text(entry.flag, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),

          // Name
          Expanded(
            child: Text(
              entry.name,
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: isTop3 ? AppColors.textPrimary : AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Score
          Text(
            '${entry.score}',
            style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w900,
              color: isTop3 ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 10),

          // Prize
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.success.withOpacity(0.3),
              ),
            ),
            child: Text(
              LeaderboardService.prizes[index],
              style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w900,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: 60 * index))
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.15, end: 0);
  }

  // ── Player Card ────────────────────────────────────────────────────────────
  Widget _buildPlayerCard() {
    final lb      = LeaderboardService.instance;
    final profile = ProfileService.instance;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accent.withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                profile.isSetUp ? profile.avatar : '🎮',
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.isSetUp ? profile.username : 'You',
                      style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Best today: ${lb.bestRealToday} pts',
                      style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'YOUR RANK',
                style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary, letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              lb.playerGapText,
              style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit Button ──────────────────────────────────────────────────────────
  Widget _buildSubmitBtn() {
    final isSetUp = ProfileService.instance.isSetUp;
    return GestureDetector(
      onTap: _goToProfileOrSubmit,
      child: Container(
        width: double.infinity, height: 52,
        decoration: BoxDecoration(
          gradient: isSetUp ? null : AppColors.primaryBtnGradient,
          color:    isSetUp ? AppColors.surfaceCard : null,
          borderRadius: BorderRadius.circular(16),
          border: isSetUp
              ? Border.all(color: Colors.white.withOpacity(0.1))
              : null,
          boxShadow: isSetUp
              ? null
              : [BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 14, offset: const Offset(0, 4),
                )],
        ),
        child: Center(
          child: Text(
            isSetUp ? '✅  Profile Set Up' : '👤  Set Up Profile to Compete',
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w900,
              color: isSetUp ? AppColors.textSecondary : Colors.black,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

}
