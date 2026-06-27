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

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  Timer?  _countdownTimer;
  Timer?  _refreshTimer;
  String  _countdown       = '';
  int     _secondsSinceLast = 0;
  late AnimationController _livePulse;

  @override
  void initState() {
    super.initState();

    _livePulse = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    LeaderboardService.instance.refresh();
    _updateCountdown();

    // Tick every second — countdown + "updated X s ago" counter
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _countdown        = LeaderboardService.instance.countdownText;
        _secondsSinceLast = (_secondsSinceLast + 1).clamp(0, 999);
      });
    });

    // Auto-refresh leaderboard data every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      LeaderboardService.instance.refresh();
      setState(() => _secondsSinceLast = 0);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _refreshTimer?.cancel();
    _livePulse.dispose();
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

  String get _lastUpdatedText {
    if (_secondsSinceLast < 5)  return 'just updated';
    if (_secondsSinceLast < 60) return 'updated ${_secondsSinceLast}s ago';
    return 'updated ${_secondsSinceLast ~/ 60}m ago';
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
                        child: CircularProgressIndicator(color: AppColors.primary),
                      );
                    }
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      child: Column(
                        children: [
                          _buildLiveBar(),
                          const SizedBox(height: 10),
                          _buildCountdownCard(),
                          const SizedBox(height: 12),
                          _buildPrizeHeader(),
                          const SizedBox(height: 12),
                          ...entries.asMap().entries.map(
                            (e) => _buildEntryTile(e.key, e.value),
                          ),
                          const SizedBox(height: 14),
                          _buildPlayerCard(),
                          const SizedBox(height: 18),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
          Column(
            children: [
              const Text(
                '🏆  LEADERBOARD',
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900,
                  color: AppColors.primary, letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              // 🔴 LIVE badge
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _livePulse,
                    builder: (_, __) => Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color.lerp(
                          const Color(0xFFFF1744),
                          const Color(0xFFFF6D00),
                          _livePulse.value,
                        )!,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.6 * _livePulse.value),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w900,
                      color: Color(0xFFFF1744), letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(width: 38),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  // ── Live Activity Bar ──────────────────────────────────────────────────────
  Widget _buildLiveBar() {
    final lb = LeaderboardService.instance;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Player count
          Row(
            children: [
              Container(
                width: 7, height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success,
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true))
               .scaleXY(begin: 1.0, end: 1.5, duration: 700.ms),
              const SizedBox(width: 7),
              Text(
                '🎮  ${lb.playersOnlineText}',
                style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          // Last updated
          Text(
            _lastUpdatedText,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }

  // ── Countdown Card ─────────────────────────────────────────────────────────
  Widget _buildCountdownCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.22)),
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
                'New competition starts at midnight',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.11),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppColors.primary.withOpacity(0.38)),
            ),
            child: Row(
              children: [
                const Text('⏱', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 5),
                Text(
                  _countdown,
                  style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.primary.withOpacity(0.13),
          AppColors.primaryGlow.withOpacity(0.07),
        ]),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.primary.withOpacity(0.32)),
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
                  'Top 10 earn real cash — updated live',
                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Entry Tile — scores animate in on each refresh ────────────────────────
  Widget _buildEntryTile(int index, LeaderboardEntry entry) {
    final isTop3     = entry.rank <= 3;
    final rankEmoji  = switch (entry.rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => '#${entry.rank}',
    };

    return Container(
      key:    ValueKey('entry_${entry.rank}_${entry.score}'),
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: isTop3
            ? AppColors.primary.withOpacity(0.07)
            : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isTop3
              ? AppColors.primary.withOpacity(0.28)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          // Rank badge
          SizedBox(
            width: 34,
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
          const SizedBox(width: 7),

          // Flag
          Text(entry.flag, style: const TextStyle(fontSize: 17)),
          const SizedBox(width: 9),

          // Name + "X min ago"
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: isTop3
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  entry.lastActive,
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),

          // Score — animates in on each refresh
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.score}',
                key: ValueKey(entry.score),
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900,
                  color: isTop3 ? AppColors.primary : AppColors.textSecondary,
                ),
              )
                  .animate(key: ValueKey(entry.score))
                  .slideY(begin: -0.4, end: 0, duration: 300.ms, curve: Curves.easeOut)
                  .fadeIn(duration: 250.ms),

              // "+X ↑" recent change badge
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '+${entry.recentChange} ↑',
                    style: const TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 9),

          // Prize
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.09),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: AppColors.success.withOpacity(0.28)),
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
        .animate(delay: Duration(milliseconds: 55 * index))
        .fadeIn(duration: 280.ms)
        .slideX(begin: 0.12, end: 0);
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
        border: Border.all(color: AppColors.accent.withOpacity(0.32), width: 1.5),
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

  // ── Submit / Profile Button ────────────────────────────────────────────────
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
