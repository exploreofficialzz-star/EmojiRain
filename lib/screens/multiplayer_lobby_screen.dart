import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../constants/backend_config.dart';
import '../models/game_room.dart';
import '../providers/room_provider.dart';
import 'multiplayer_game_screen.dart';

class MultiplayerLobbyScreen extends StatefulWidget {
  const MultiplayerLobbyScreen({super.key});

  @override
  State<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends State<MultiplayerLobbyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _nicknameCtrl  = TextEditingController();
  final _roomCodeCtrl  = TextEditingController();
  bool _inLobby        = false;
  bool _codeCopied     = false;

  // Countdown before game starts
  int? _countdown;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nicknameCtrl.dispose();
    _roomCodeCtrl.dispose();
    _countdownTimer?.cancel();
    RoomProvider.instance.stopPolling();
    super.dispose();
  }

  // ── Create room ───────────────────────────────────────────────────────────

  Future<void> _createRoom() async {
    final nick = _nicknameCtrl.text.trim();
    if (nick.isEmpty) { _showSnack('Enter your nickname first'); return; }

    final room = await RoomProvider.instance.createRoom(nick);
    if (!mounted) return;
    if (room != null) {
      setState(() => _inLobby = true);
      RoomProvider.instance.startPolling();
    } else {
      _showSnack(RoomProvider.instance.error ?? 'Failed to create room');
    }
  }

  // ── Join room ─────────────────────────────────────────────────────────────

  Future<void> _joinRoom() async {
    final nick = _nicknameCtrl.text.trim();
    final code = _roomCodeCtrl.text.trim().toUpperCase();
    if (nick.isEmpty) { _showSnack('Enter your nickname first'); return; }
    if (code.length != 6) { _showSnack('Enter a valid 6-digit room code'); return; }

    final room = await RoomProvider.instance.joinRoom(code, nick);
    if (!mounted) return;
    if (room != null) {
      setState(() => _inLobby = true);
      RoomProvider.instance.startPolling();
    } else {
      _showSnack(RoomProvider.instance.error ?? 'Room not found or full');
    }
  }

  // ── Share invite ──────────────────────────────────────────────────────────

  Future<void> _copyInvite() async {
    final code = RoomProvider.instance.currentRoom?.roomCode ?? '';
    final text =
        'Play Emoji Rain with me! Room: $code\n${BackendConfig.playStoreUrl}';
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      setState(() => _codeCopied = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _codeCopied = false);
      });
    }
  }

  void _shareWhatsApp() {
    final code = RoomProvider.instance.currentRoom?.roomCode ?? '';
    final msg  = Uri.encodeComponent(
      'Play Emoji Rain with me! Room: $code\n${BackendConfig.playStoreUrl}',
    );
    // On Android, this opens WhatsApp directly if installed
    // ignore: avoid_print
    print('whatsapp://send?text=$msg'); // Real app would use url_launcher
  }

  // ── Mark ready / start game ───────────────────────────────────────────────

  Future<void> _toggleReady() async {
    await RoomProvider.instance.markReady();
  }

  Future<void> _startGame() async {
    if (!(RoomProvider.instance.currentRoom?.canStart ?? false)) return;
    await RoomProvider.instance.startRoom();
    _beginCountdown();
  }

  void _beginCountdown() {
    setState(() => _countdown = 5);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_countdown != null && _countdown! > 1) {
          _countdown = _countdown! - 1;
        } else {
          t.cancel();
          _countdown = null;
          _navigateToGame();
        }
      });
    });
  }

  void _navigateToGame() {
    final room = RoomProvider.instance.currentRoom;
    if (room == null || !mounted) return;
    RoomProvider.instance.stopPolling();
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder:        (_, anim, __) =>
          MultiplayerGameScreen(room: room),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 350),
    ));
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: AppColors.textPrimary)),
      backgroundColor: AppColors.surfaceCard,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RoomProvider.instance,
      builder: (context, _) {
        if (_countdown != null) return _buildCountdownOverlay();
        if (_inLobby) return _buildWaitingRoom();
        return _buildEntryScreen();
      },
    );
  }

  // ── Entry screen (tabs: Create / Join) ────────────────────────────────────

  Widget _buildEntryScreen() {
    final room = RoomProvider.instance;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
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
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('👥  CHALLENGE FRIENDS', style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900,
                          color: Color(0xFFB39DDB), letterSpacing: 1,
                        )),
                        Text('Up to 4 players, same rain, live scores',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),

              // Nickname field (shared by both tabs)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _NicknameField(controller: _nicknameCtrl),
              ),
              const SizedBox(height: 16),

              // Tab bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  indicator: BoxDecoration(
                    gradient: AppColors.primaryBtnGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor:      Colors.black,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 13),
                  tabs: const [
                    Tab(text: 'CREATE ROOM'),
                    Tab(text: 'JOIN ROOM'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildCreateTab(room),
                    _buildJoinTab(room),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateTab(RoomProvider room) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              children: [
                const Text('🎮', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text('Create a private room and invite\nyour friends to join!',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary,
                      height: 1.5),
                  textAlign: TextAlign.center),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: room.isLoading ? null : _createRoom,
            child: Container(
              width: double.infinity, height: 58,
              decoration: BoxDecoration(
                gradient: AppColors.primaryBtnGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 16, offset: const Offset(0, 6),
                )],
              ),
              child: Center(
                child: room.isLoading
                    ? const CircularProgressIndicator(color: Colors.black, strokeWidth: 2)
                    : const Text('Create Room', style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900,
                        color: Colors.black, letterSpacing: 0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinTab(RoomProvider room) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        children: [
          // Room code input
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: TextField(
              controller: _roomCodeCtrl,
              maxLength:  6,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w900,
                color: AppColors.primary, letterSpacing: 6,
              ),
              decoration: const InputDecoration(
                hintText:    'ROOM CODE',
                hintStyle:   TextStyle(fontSize: 16, color: AppColors.textSecondary,
                    letterSpacing: 3),
                border:      InputBorder.none,
                counterText: '',
                contentPadding: EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: room.isLoading ? null : _joinRoom,
            child: Container(
              width: double.infinity, height: 58,
              decoration: BoxDecoration(
                gradient: AppColors.primaryBtnGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 16, offset: const Offset(0, 6),
                )],
              ),
              child: Center(
                child: room.isLoading
                    ? const CircularProgressIndicator(color: Colors.black, strokeWidth: 2)
                    : const Text('Join Room', style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900,
                        color: Colors.black, letterSpacing: 0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Waiting room ──────────────────────────────────────────────────────────

  Widget _buildWaitingRoom() {
    final room   = RoomProvider.instance.currentRoom;
    final isHost = RoomProvider.instance.isHost;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        RoomProvider.instance.leaveRoom();
                        setState(() => _inLobby = false);
                      },
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const Spacer(),
                    const Text('WAITING ROOM', style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary, letterSpacing: 1.5,
                    )),
                    const Spacer(),
                    const SizedBox(width: 38),
                  ],
                ),
              ),

              // Room code display
              if (room != null)
                _buildRoomCodeCard(room.roomCode),

              const SizedBox(height: 20),

              // Players list
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${room?.players.length ?? 0}/4 PLAYERS',
                        style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary, letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...?room?.players.map((p) => _PlayerLobbyCard(
                        player: p,
                        isMe: p.playerId == RoomProvider.instance.myPlayerId,
                      )),

                      // Empty slots
                      if (room != null)
                        ...List.generate(4 - room.players.length, (_) =>
                            _EmptySlotCard()),
                    ],
                  ),
                ),
              ),

              // Bottom buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  children: [
                    if (!isHost)
                      _buildReadyButton(),

                    if (isHost) ...[
                      _buildStartButton(room),
                      const SizedBox(height: 10),
                    ],

                    const SizedBox(height: 10),
                    _buildShareRow(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomCodeCard(String code) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        children: [
          const Text('ROOM CODE', style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: AppColors.textSecondary, letterSpacing: 2,
          )),
          const SizedBox(height: 6),
          Text(code, style: const TextStyle(
            fontSize: 38, fontWeight: FontWeight.w900,
            color: AppColors.primary, letterSpacing: 8,
          )),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms)
        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
  }

  Widget _buildReadyButton() {
    final me = RoomProvider.instance.myPlayer;
    final ready = me?.isReady ?? false;
    return GestureDetector(
      onTap: _toggleReady,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity, height: 54,
        decoration: BoxDecoration(
          gradient: ready ? null : AppColors.primaryBtnGradient,
          color:    ready ? AppColors.success.withOpacity(0.15) : null,
          borderRadius: BorderRadius.circular(16),
          border: ready
              ? Border.all(color: AppColors.success.withOpacity(0.5), width: 1.5)
              : null,
          boxShadow: ready ? null : [BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 14, offset: const Offset(0, 5),
          )],
        ),
        child: Center(child: Text(
          ready ? '✅  I\'m Ready!' : '👍  Mark Ready',
          style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w900,
            color: ready ? AppColors.success : Colors.black,
            letterSpacing: 0.5,
          ),
        )),
      ),
    );
  }

  Widget _buildStartButton(GameRoom? room) {
    final canStart = room?.canStart ?? false;
    return GestureDetector(
      onTap: canStart ? _startGame : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity, height: 54,
        decoration: BoxDecoration(
          gradient: canStart ? AppColors.primaryBtnGradient : null,
          color:    canStart ? null : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: canStart ? null : Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Center(child: Text(
          canStart ? '🚀  Start Game!' : '⏳  Waiting for ready players...',
          style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w900,
            color: canStart ? Colors.black : AppColors.textSecondary,
          ),
        )),
      ),
    );
  }

  Widget _buildShareRow() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _copyInvite,
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(_codeCopied ? '✅' : '🔗', style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(_codeCopied ? 'Copied!' : 'Copy link',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: _codeCopied ? AppColors.success : AppColors.textSecondary,
                  )),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _shareWhatsApp,
          child: Container(
            height: 46, width: 90,
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF25D366).withOpacity(0.4)),
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('💬', style: TextStyle(fontSize: 18)),
              SizedBox(width: 4),
              Text('WA', style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w900,
                color: Color(0xFF25D366),
              )),
            ]),
          ),
        ),
      ],
    );
  }

  // ── Countdown overlay ─────────────────────────────────────────────────────

  Widget _buildCountdownOverlay() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${_countdown ?? 0}', style: const TextStyle(
                fontSize: 120, fontWeight: FontWeight.w900,
                color: AppColors.primary,
              )).animate(key: ValueKey(_countdown)).scale(
                begin: const Offset(1.5, 1.5), end: const Offset(1.0, 1.0),
                duration: 400.ms, curve: Curves.easeOut),
              const Text('GET READY', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900,
                color: AppColors.accent, letterSpacing: 4,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Subwidgets ────────────────────────────────────────────────────────────────

class _NicknameField extends StatelessWidget {
  final TextEditingController controller;
  const _NicknameField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        maxLength:  16,
        style: const TextStyle(
          color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600,
        ),
        decoration: const InputDecoration(
          hintText:      'Your nickname',
          hintStyle:     TextStyle(color: AppColors.textSecondary),
          prefixIcon:    Icon(Icons.person_rounded, color: AppColors.textSecondary, size: 20),
          border:        InputBorder.none,
          counterText:   '',
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

class _PlayerLobbyCard extends StatelessWidget {
  final RoomPlayer player;
  final bool       isMe;
  const _PlayerLobbyCard({required this.player, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.primary.withOpacity(0.08)
            : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe
              ? AppColors.primary.withOpacity(0.35)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          // Avatar circle
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMe
                  ? AppColors.primary.withOpacity(0.2)
                  : AppColors.surface,
              border: Border.all(
                color: isMe ? AppColors.primary.withOpacity(0.5) : Colors.white12,
              ),
            ),
            child: Center(child: Text(player.initials, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w900,
              color: isMe ? AppColors.primary : AppColors.textSecondary,
            ))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Text(player.nickname, style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: isMe ? AppColors.textPrimary : AppColors.textSecondary,
                )),
                if (isMe) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('YOU', style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    )),
                  ),
                ],
              ],
            ),
          ),
          if (player.isReady)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.success.withOpacity(0.4)),
              ),
              child: const Text('READY', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w900,
                color: AppColors.success,
              )),
            )
          else
            const Text('waiting...', style: TextStyle(
              fontSize: 11, color: AppColors.textSecondary,
            )),
        ],
      ),
    );
  }
}

class _EmptySlotCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white10,
            child: Icon(Icons.add_rounded, color: Colors.white24, size: 18),
          ),
          SizedBox(width: 12),
          Text('Waiting for player...', style: TextStyle(
            fontSize: 13, color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          )),
        ],
      ),
    );
  }
}
