import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/game_provider.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/coin_service.dart';
import '../services/notification_service.dart';
import '../services/purchase_service.dart';
import '../services/streak_service.dart';
import '../widgets/background_picker_sheet.dart';
import '../widgets/daily_reward_modal.dart';
import 'beat_mode_screen.dart';
import 'game_screen.dart';
import 'leaderboard_screen.dart';
import 'multiplayer_lobby_screen.dart';
import 'profile_setup_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Rank system — computed from lifetime high score
// ─────────────────────────────────────────────────────────────────────────────
class RankInfo {
  final String name;
  final String emoji;
  final int    minScore;
  final int    maxScore;
  const RankInfo({required this.name, required this.emoji,
      required this.minScore, required this.maxScore});
}

const List<RankInfo> kRanks = [
  RankInfo(name: 'Rookie',     emoji: '🌱', minScore: 0,      maxScore: 999),
  RankInfo(name: 'Focused',    emoji: '🎯', minScore: 1000,   maxScore: 4999),
  RankInfo(name: 'Sharp',      emoji: '⚡', minScore: 5000,   maxScore: 14999),
  RankInfo(name: 'Elite',      emoji: '🔥', minScore: 15000,  maxScore: 39999),
  RankInfo(name: 'Untappable', emoji: '💎', minScore: 40000,  maxScore: 99999),
  RankInfo(name: 'Legend',     emoji: '👑', minScore: 100000, maxScore: 999999999),
];

RankInfo rankFor(int score) =>
    kRanks.lastWhere((r) => score >= r.minScore, orElse: () => kRanks.first);

// ─────────────────────────────────────────────────────────────────────────────
// Root HomeScreen — hosts bottom navigation
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.cancelComeback();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkStreak());
  }

  Future<void> _checkStreak() async {
    if (!mounted) return;
    if (StreakService.instance.canClaimToday) await showDailyRewardModal(context);
  }

  void _onNavTap(int idx) {
    if (idx == _navIndex) return;
    AudioService.instance.play(SoundEffect.tap);
    setState(() => _navIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    final purchase = context.watch<PurchaseService>();
    // Tabs 1–3 push new routes; tab 0 is the main home content
    final body = switch (_navIndex) {
      0 => _HomeTab(onNavTap: _onNavTap),
      1 => const BeatModeScreen(),
      2 => const LeaderboardScreen(),
      3 => const ProfileSetupScreen(),
      _ => _HomeTab(onNavTap: _onNavTap),
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body:            body,
      bottomNavigationBar: _BottomNav(current: _navIndex, onTap: _onNavTap),
    );
  }
}

// ── Bottom navigation bar ─────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int current;
  final void Function(int) onTap;
  const _BottomNav({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(children: [
            _NavItem(icon: '🏠', label: 'Home',    idx: 0, current: current, onTap: onTap),
            _NavItem(icon: '🎵', label: 'Beat',    idx: 1, current: current, onTap: onTap),
            _NavItem(icon: '🏆', label: 'Ranks',   idx: 2, current: current, onTap: onTap),
            _NavItem(icon: '👤', label: 'Profile', idx: 3, current: current, onTap: onTap),
          ]),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String icon, label;
  final int idx, current;
  final void Function(int) onTap;
  const _NavItem({required this.icon, required this.label,
      required this.idx, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = idx == current;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(idx),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(icon, style: TextStyle(fontSize: active ? 24 : 20)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: active ? AppColors.primary : AppColors.textSecondary,
          )),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Home tab
// ─────────────────────────────────────────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  final void Function(int) onNavTap;
  const _HomeTab({required this.onNavTap});
  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with SingleTickerProviderStateMixin {
  late AnimationController _beatVisCtrl;
  bool   _bannerLoaded = false;
  Timer? _statsTimer;

  @override
  void initState() {
    super.initState();
    _beatVisCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    AdService.instance.loadBanner(
      onLoaded: () => mounted ? setState(() => _bannerLoaded = true) : null,
    );

    _statsTimer = Timer.periodic(const Duration(seconds: 90), (_) {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) setState(() {});
    });
  }

  @override
  void dispose() {
    _beatVisCtrl.dispose();
    _statsTimer?.cancel();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _openClassic() {
    AudioService.instance.play(SoundEffect.tap);
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder:        (_, a, __) => const GameScreen(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 350),
    ));
  }

  void _openBeat()        => widget.onNavTap(1);
  void _openMultiplayer() {
    AudioService.instance.play(SoundEffect.tap);
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder:        (_, a, __) => const MultiplayerLobbyScreen(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 350),
    ));
  }

  // ── Computed fake stats ────────────────────────────────────────────────────
  String get _avgReaction {
    final s = DateTime.now().toUtc().minute ~/ 5;
    return '${220 + (s * 13) % 80} ms';
  }
  String get _accuracy {
    final s = DateTime.now().toUtc().minute ~/ 3;
    return '${72 + (s * 7) % 20}%';
  }
  String get _focusScore {
    final s = DateTime.now().toUtc().minute ~/ 7;
    return '${55 + (s * 11) % 40}';
  }
  String get _survivalStat {
    final s = DateTime.now().toUtc().minute ~/ 7;
    return 'Only ${3 + (s * 7) % 7}% reach level ${5 + s % 2}';
  }

  @override
  Widget build(BuildContext context) {
    final game     = context.watch<GameProvider>();
    final purchase = context.watch<PurchaseService>();
    final rank     = rankFor(game.highScore);

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.bgGradient),
      child: Column(children: [
        Expanded(
          child: SafeArea(
            child: LayoutBuilder(builder: (ctx, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      _buildTopBar(ctx),
                      const SizedBox(height: 16),
                      _buildLogo(),
                      const SizedBox(height: 18),
                      _buildStatsRow(),
                      const SizedBox(height: 12),
                      _buildRankBadge(rank, game.highScore),
                      const SizedBox(height: 18),
                      _buildModeCards(game),
                      const SizedBox(height: 14),
                      _buildUtilityRow(ctx),
                      const SizedBox(height: 10),
                      _buildSurvivalBadge(),
                      const SizedBox(height: 14),
                      _buildByChAs(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        if (_bannerLoaded &&
            AdService.instance.bannerAd != null &&
            !purchase.adsRemoved)
          Container(
            color: AppColors.background,
            alignment: Alignment.center,
            width:  AdService.instance.bannerAd!.size.width.toDouble(),
            height: AdService.instance.bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: AdService.instance.bannerAd!),
          ),
      ]),
    );
  }

  // ── Top bar: coins pill + streak pill ─────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ListenableBuilder(
            listenable: CoinService.instance,
            builder: (_, __) => _Pill(
              children: [
                const Text('🪙', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 5),
                Text(CoinService.instance.formattedBalance,
                  style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w900,
                    color: AppColors.primary)),
              ],
              borderColor: AppColors.primary.withOpacity(0.3),
            ),
          ),
          ListenableBuilder(
            listenable: StreakService.instance,
            builder: (_, __) {
              final streak = StreakService.instance.streak;
              final can    = StreakService.instance.canClaimToday;
              return GestureDetector(
                onTap: can ? () => showDailyRewardModal(context) : null,
                child: _Pill(
                  color: can
                      ? AppColors.primary.withOpacity(0.15) : AppColors.surfaceCard,
                  borderColor: can
                      ? AppColors.primary.withOpacity(0.5)
                      : Colors.white.withOpacity(0.1),
                  children: [
                    Text(can ? '🎁' : '🔥', style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 5),
                    Text(
                      can ? 'Claim!'
                          : streak > 0 ? '${streak}d streak' : 'Daily',
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800,
                        color: can ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ).animate(target: can ? 1 : 0).shimmer(
                duration: 1200.ms, color: AppColors.primary.withOpacity(0.6));
            },
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  // ── Logo ───────────────────────────────────────────────────────────────────
  Widget _buildLogo() {
    return Column(children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
            color: AppColors.primary.withOpacity(0.18),
            blurRadius: 16, spreadRadius: 2)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset('assets/images/icon.png', fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: AppColors.surfaceCard,
              child: const Center(child: Text('🎮', style: TextStyle(fontSize: 44))),
            )),
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 1.0, end: 1.04, duration: 1600.ms, curve: Curves.easeInOut),

      const SizedBox(height: 14),
      ShaderMask(
        shaderCallback: (b) => AppColors.goldGradient.createShader(b),
        child: const Text('EMOJI RAIN', style: TextStyle(
          fontSize: 34, fontWeight: FontWeight.w900,
          color: Colors.white, letterSpacing: 2)),
      ).animate().fadeIn(duration: 600.ms, delay: 200.ms),

      const SizedBox(height: 4),
      Text('FOCUS  OR  FAIL', style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700,
        color: AppColors.accent.withOpacity(0.9), letterSpacing: 5),
      ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
    ]);
  }

  // ── Stats row — 3 mini cards ───────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        _StatMini(label: 'Avg reaction', value: _avgReaction, emoji: '⚡'),
        const SizedBox(width: 8),
        _StatMini(label: 'Accuracy',     value: _accuracy,    emoji: '🎯'),
        const SizedBox(width: 8),
        _StatMini(label: 'Focus score',  value: _focusScore,  emoji: '🧠'),
      ]).animate().fadeIn(delay: 500.ms, duration: 500.ms),
    );
  }

  // ── Rank badge ─────────────────────────────────────────────────────────────
  Widget _buildRankBadge(RankInfo rank, int score) {
    final isMax  = rank.name == 'Legend';
    final prog   = isMax ? 1.0
        : (score - rank.minScore) / (rank.maxScore - rank.minScore + 1).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withOpacity(0.25))),
        child: Row(children: [
          Text(rank.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(rank.name, style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900,
                  color: AppColors.primary)),
                const SizedBox(width: 8),
                Text('$score pts', style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
              ]),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: prog.clamp(0.0, 1.0),
                  backgroundColor: AppColors.surface,
                  color: AppColors.primary,
                  minHeight: 5,
                ),
              ),
              if (!isMax) ...[
                const SizedBox(height: 2),
                Text('${rank.maxScore - score + 1} pts to next rank',
                  style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
              ],
            ]),
          ),
        ]),
      ),
    ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.2, end: 0);
  }

  // ── Mode cards ─────────────────────────────────────────────────────────────
  Widget _buildModeCards(GameProvider game) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        // 1 — Classic solo
        _ModeCard(
          accentColor: const Color(0xFF00C853),
          icon: '⚡', title: 'Classic solo',
          desc: 'Tap targets, build combos, beat your best',
          badge: game.highScore > 0 ? 'Best: ${game.highScore}' : null,
          badgeColor: AppColors.success,
          ctaLabel: 'Play', ctaColors: [const Color(0xFF00C853), const Color(0xFF007B33)],
          ctaTextColor: Colors.black,
          onTap: _openClassic,
        ).animate().fadeIn(delay: 650.ms).slideY(begin: 0.1, end: 0),

        const SizedBox(height: 10),

        // 2 — Beat mode (featured)
        _BeatModeCard(ctrl: _beatVisCtrl, onTap: _openBeat)
            .animate().fadeIn(delay: 750.ms).slideY(begin: 0.1, end: 0),

        const SizedBox(height: 10),

        // 3 — Challenge friends
        _MultiCard(onTap: _openMultiplayer)
            .animate().fadeIn(delay: 850.ms).slideY(begin: 0.1, end: 0),
      ]),
    );
  }

  // ── Utility row ───────────────────────────────────────────────────────────
  Widget _buildUtilityRow(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _SoundToggle(),
      const SizedBox(width: 20),
      Container(width: 1, height: 16, color: Colors.white.withOpacity(0.15)),
      const SizedBox(width: 20),
      GestureDetector(
        onTap: () => showBackgroundPickerSheet(context),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wallpaper_rounded, color: AppColors.accent, size: 16),
          const SizedBox(width: 6),
          Text('Background', style: TextStyle(
            fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w600)),
        ]),
      ),
    ]).animate().fadeIn(delay: 900.ms, duration: 500.ms);
  }

  Widget _buildSurvivalBadge() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.07))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('🔥', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 7),
          Flexible(child: Text(_survivalStat,
            style: AppTextStyles.bodyMedium,
            overflow: TextOverflow.ellipsis, maxLines: 1)),
        ]),
      ),
    ).animate().fadeIn(delay: 1000.ms);
  }

  Widget _buildByChAs() {
    return Column(children: [
      Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 60),
          color: Colors.white.withOpacity(0.07)),
      const SizedBox(height: 12),
      RichText(text: TextSpan(children: [
        TextSpan(text: 'by ', style: TextStyle(
          fontSize: 13, color: AppColors.textSecondary.withOpacity(0.7), letterSpacing: 1)),
        const TextSpan(text: 'ChAs', style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w900,
          color: AppColors.primary, letterSpacing: 2)),
      ])).animate()
          .fadeIn(delay: 1200.ms, duration: 800.ms)
          .shimmer(delay: 2000.ms, duration: 2000.ms, color: AppColors.primaryGlow),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final List<Widget> children;
  final Color? color;
  final Color? borderColor;
  const _Pill({required this.children, this.color, this.borderColor});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color ?? AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: borderColor ?? Colors.white.withOpacity(0.1))),
    child: Row(mainAxisSize: MainAxisSize.min, children: children),
  );
}

class _StatMini extends StatelessWidget {
  final String label, value, emoji;
  const _StatMini({required this.label, required this.value, required this.emoji});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        Text(label, style: const TextStyle(
          fontSize: 9, color: AppColors.textSecondary, letterSpacing: 0.3),
          textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}

// Generic mode card
class _ModeCard extends StatelessWidget {
  final Color        accentColor;
  final String       icon, title, desc, ctaLabel;
  final Color        ctaTextColor;
  final List<Color>  ctaColors;
  final String?      badge;
  final Color        badgeColor;
  final VoidCallback onTap;

  const _ModeCard({
    required this.accentColor, required this.icon,
    required this.title, required this.desc,
    required this.ctaLabel, required this.ctaColors,
    required this.ctaTextColor, required this.onTap,
    this.badge, this.badgeColor = AppColors.success,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07))),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withOpacity(0.35))),
          child: Center(child: Text(icon, style: const TextStyle(fontSize: 24)))),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(title, style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              if (badge != null) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor.withOpacity(0.4))),
                  child: Text(badge!, style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w800, color: badgeColor))),
              ],
            ]),
            const SizedBox(height: 3),
            Text(desc, style: const TextStyle(
              fontSize: 11, color: AppColors.textSecondary, height: 1.4),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: ctaColors),
            borderRadius: BorderRadius.circular(10)),
          child: Text(ctaLabel, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w900, color: ctaTextColor))),
      ]),
    ),
  );
}

// Beat mode card with visualiser
class _BeatModeCard extends StatelessWidget {
  final AnimationController ctrl;
  final VoidCallback onTap;
  const _BeatModeCard({required this.ctrl, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.45), width: 1.5),
        boxShadow: [BoxShadow(
          color: AppColors.accent.withOpacity(0.06), blurRadius: 10, spreadRadius: 2)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withOpacity(0.35))),
            child: const Center(child: Text('🎵', style: TextStyle(fontSize: 24)))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('Beat mode', style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.accent.withOpacity(0.5))),
                  child: const Text('New', style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.accent))),
              ]),
              const SizedBox(height: 3),
              const Text('Emojis fall on the beat — tap in rhythm to multiply',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF00B8D4), Color(0xFF006064)]),
              borderRadius: BorderRadius.circular(10)),
            child: const Text('Play', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white))),
        ]),
        const SizedBox(height: 12),
        // Beat visualiser bars
        Row(mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) => AnimatedBuilder(
            animation: ctrl,
            builder: (_, __) {
              final phase = (ctrl.value + i * 0.2) % 1.0;
              return Container(
                width: 5, height: 6.0 + 18.0 * phase,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.5 + 0.5 * phase),
                  borderRadius: BorderRadius.circular(3)));
            },
          ))),
      ]),
    ),
  );
}

// Multiplayer card with friend avatars
class _MultiCard extends StatelessWidget {
  final VoidCallback onTap;
  const _MultiCard({required this.onTap});
  static const _initials = ['AJ', 'NK', 'TF'];

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF7B1FA2).withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF7B1FA2).withOpacity(0.35))),
            child: const Center(child: Text('👥', style: TextStyle(fontSize: 24)))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('Challenge friends', style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B1FA2).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF7B1FA2).withOpacity(0.5))),
                  child: const Text('New', style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w900,
                    color: Color(0xFFCE93D8)))),
              ]),
              const SizedBox(height: 3),
              const Text('Invite up to 4 players — same rain, live scores',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFAB47BC), Color(0xFF6A1B9A)]),
              borderRadius: BorderRadius.circular(10)),
            child: const Text('Invite', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          ..._initials.map((init) => Container(
            width: 28, height: 28,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: AppColors.surface,
              border: Border.all(color: const Color(0xFF7B1FA2).withOpacity(0.4))),
            child: Center(child: Text(init, style: const TextStyle(
              fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFCE93D8)))))),
          const SizedBox(width: 6),
          const Text('playing now', style: TextStyle(
            fontSize: 10, color: AppColors.textSecondary)),
        ]),
      ]),
    ),
  );
}

class _SoundToggle extends StatefulWidget {
  @override
  State<_SoundToggle> createState() => _SoundToggleState();
}
class _SoundToggleState extends State<_SoundToggle> {
  @override
  Widget build(BuildContext context) {
    final on = AudioService.instance.soundEnabled;
    return GestureDetector(
      onTap: () async { await AudioService.instance.toggleSound(); setState(() {}); },
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            color: on ? AppColors.accent : AppColors.textSecondary, size: 16),
        const SizedBox(width: 6),
        Text(on ? 'Sound ON' : 'Sound OFF', style: TextStyle(
          fontSize: 13, color: on ? AppColors.accent : AppColors.textSecondary,
          fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
