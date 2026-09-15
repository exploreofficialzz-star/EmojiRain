
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/game_room.dart';
import '../providers/game_provider.dart';
import '../providers/room_provider.dart';
import '../widgets/share_card_widget.dart';

/// Multiplayer game screen.
///
/// Wraps the existing [GameProvider] (initialized with the shared [seedValue]
/// so all clients produce the same emoji fall sequence) and overlays a live
/// leaderboard bar showing all players' scores, updated via SSE.
class MultiplayerGameScreen extends StatelessWidget {
  final GameRoom room;
  const MultiplayerGameScreen({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    // Fresh GameProvider with the shared seed for identical emoji sequences
    return ChangeNotifierProvider(
      create: (_) => GameProvider()..setSeed(room.seedValue),
      child: _MultiplayerGameBody(room: room),
    );
  }
}

class _MultiplayerGameBody extends StatefulWidget {
  final GameRoom room;
  const _MultiplayerGameBody({required this.room});

  @override
  State<_MultiplayerGameBody> createState() => _MultiplayerGameBodyState();
}

class _MultiplayerGameBodyState extends State<_MultiplayerGameBody> {
  bool _gameOver = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final game = context.read<GameProvider>();
      final size = MediaQuery.of(context).size;
      game.startGame(screenWidth: size.width, screenHeight: size.height);
      game.addListener(_onGameState);

      // Push score to server every 2 seconds
      RoomProvider.instance.startScorePush(() => game.score);
    });
  }

  @override
  void dispose() {
    context.read<GameProvider>().removeListener(_onGameState);
    RoomProvider.instance.stopScorePush();
    super.dispose();
  }

  void _onGameState() {
    final game = context.read<GameProvider>();
    if (game.isGameOver && !_gameOver) {
      setState(() => _gameOver = true);
      RoomProvider.instance.signalDead();
      RoomProvider.instance.stopScorePush();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_gameOver) return _buildGameOver(context);
    return _buildGameplay(context);
  }

  // ── Gameplay ───────────────────────────────────────────────────────────────

  Widget _buildGameplay(BuildContext context) {
    final game = context.watch<GameProvider>();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Game canvas (full screen) ──────────────────────────────────
          AnimatedBuilder(
            animation: game,
            builder: (_, __) => Stack(
              children: [
                Container(decoration: const BoxDecoration(
                    gradient: AppColors.bgGradient)),
                // Hearts
                Positioned(
                  bottom: 16, left: 0, right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(game.maxHearts, (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Text(i < game.hearts ? '❤️' : '🖤',
                          style: const TextStyle(fontSize: 20)),
                    )),
                  ),
                ),
                // Emojis
                ...game.emojis.where((e) => e.isFalling).map((emoji) =>
                  Positioned(
                    left: emoji.x - emoji.size / 2,
                    top:  emoji.y - emoji.size / 2,
                    child: GestureDetector(
                      onTap: () => game.onEmojiTapped(emoji),
                      child: Transform.rotate(
                        angle: emoji.rotation,
                        child: Text(emoji.emoji,
                            style: TextStyle(fontSize: emoji.size * 0.5)),
                      ),
                    ),
                  )),
              ],
            ),
          ),

          // ── Live leaderboard bar (top) ─────────────────────────────────
          SafeArea(
            child: ListenableBuilder(
              listenable: RoomProvider.instance,
              builder: (_, __) => _buildLeaderboardBar(game),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardBar(GameProvider game) {
    final board = RoomProvider.instance.liveLeaderboard;
    final myId  = RoomProvider.instance.myPlayerId;

    // Update my score in the leaderboard display immediately from local state
    final displayBoard = board.map((p) {
      if (p.playerId == myId) {
        return RoomPlayer(
          playerId: p.playerId, nickname: p.nickname,
          score: game.score, level: game.level,
          isReady: p.isReady, isAlive: p.isAlive,
        );
      }
      return p;
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final leader = displayBoard.isNotEmpty ? displayBoard.first : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: displayBoard.map((p) {
          final isLeader = p.playerId == leader?.playerId;
          final isMe     = p.playerId == myId;
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isLeader
                            ? const Color(0xFFFFB300).withOpacity(0.25)
                            : isMe
                                ? AppColors.accent.withOpacity(0.2)
                                : AppColors.surface,
                        border: Border.all(
                          color: isLeader
                              ? const Color(0xFFFFB300)
                              : isMe
                                  ? AppColors.accent
                                  : Colors.white12,
                          width: isLeader || isMe ? 1.5 : 1,
                        ),
                      ),
                      child: Center(child: Text(p.initials, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w900,
                        color: isLeader
                            ? const Color(0xFFFFB300)
                            : isMe ? AppColors.accent : AppColors.textSecondary,
                      ))),
                    ),
                    if (isLeader)
                      const Text('👑', style: TextStyle(fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatScore(p.score),
                  key: ValueKey(p.score),
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w900,
                    color: isLeader
                        ? const Color(0xFFFFB300)
                        : AppColors.textSecondary,
                  ),
                ).animate(key: ValueKey(p.score))
                    .slideY(begin: -0.3, end: 0, duration: 200.ms),
                Text(
                  p.isAlive ? '' : '💀',
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Game over / final leaderboard ──────────────────────────────────────────

  Widget _buildGameOver(BuildContext context) {
    final game    = context.read<GameProvider>();
    final board   = RoomProvider.instance.liveLeaderboard;
    final myId    = RoomProvider.instance.myPlayerId;

    // Sort by score descending
    final sorted = List<RoomPlayer>.from(board)
      ..sort((a, b) => b.score.compareTo(a.score));

    final winner  = sorted.isNotEmpty ? sorted.first : null;
    final isWinner = winner?.playerId == myId;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 28),

                Text(isWinner ? '🏆' : '🎮',
                    style: const TextStyle(fontSize: 64))
                    .animate().scale(
                      begin: const Offset(0.3, 0.3), end: const Offset(1, 1),
                      duration: 600.ms, curve: Curves.elasticOut),

                const SizedBox(height: 12),

                ShaderMask(
                  shaderCallback: (b) =>
                      AppColors.goldGradient.createShader(b),
                  child: Text(
                    isWinner ? 'YOU WIN! 🎉' : 'GAME OVER',
                    style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: 1.5,
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 24),

                // Final leaderboard
                _buildFinalLeaderboard(sorted, myId),
                const SizedBox(height: 20),

                // Share card
                ShareCardWidget(
                  score:       game.score,
                  level:       game.level,
                  maxCombo:    game.maxCombo,
                  accuracyPct: 0,
                ),
                const SizedBox(height: 16),

                // Home button
                GestureDetector(
                  onTap: () {
                    RoomProvider.instance.leaveRoom();
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  child: Container(
                    width: double.infinity, height: 54,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryBtnGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 14, offset: const Offset(0, 5),
                      )],
                    ),
                    child: const Center(child: Text('🏠  HOME', style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900,
                      color: Colors.black, letterSpacing: 1,
                    ))),
                  ),
                ).animate().fadeIn(delay: 900.ms),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFinalLeaderboard(List<RoomPlayer> sorted, String? myId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: sorted.asMap().entries.map((entry) {
          final rank   = entry.key + 1;
          final player = entry.value;
          final isMe   = player.playerId == myId;

          final rankEmoji = switch (rank) {
            1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '#$rank',
          };

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: rank == 1
                  ? AppColors.primary.withOpacity(0.08)
                  : isMe
                      ? AppColors.accent.withOpacity(0.06)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: rank == 1
                    ? AppColors.primary.withOpacity(0.3)
                    : isMe
                        ? AppColors.accent.withOpacity(0.3)
                        : Colors.white.withOpacity(0.05),
              ),
            ),
            child: Row(
              children: [
                Text(rankEmoji, style: TextStyle(
                  fontSize: rank <= 3 ? 22 : 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w900,
                )),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isMe ? '${player.nickname} (you)' : player.nickname,
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: rank == 1
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(_formatScore(player.score), style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w900,
                  color: rank == 1 ? AppColors.primary : AppColors.textSecondary,
                )),
                if (!player.isAlive) ...[
                  const SizedBox(width: 6),
                  const Text('💀', style: TextStyle(fontSize: 14)),
                ],
              ],
            ),
          ).animate(delay: Duration(milliseconds: 100 * rank))
              .fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0);
        }).toList(),
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  String _formatScore(int score) {
    if (score >= 10000) return '${(score / 1000).toStringAsFixed(1)}k';
    return '$score';
  }
}

