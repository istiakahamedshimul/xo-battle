import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/providers.dart';
import '../services/bot_service.dart';
import '../widgets/game_ui.dart';
import 'create_room_screen.dart';
import 'join_room_screen.dart';
import 'leaderboard_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'lobby_screen.dart';
import 'friends_screen.dart';
import 'game_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _randomMatchBusy = false;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userAsync = ref.watch(userProfileProvider(uid));
    final incomingRequests = ref.watch(incomingRequestsProvider(uid));
    final pendingCount = incomingRequests.maybeWhen(data: (l) => l.length, orElse: () => 0);

    return GameShell(
      appBar: AppBar(
        title: const Text('XO Battle'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.people),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FriendsScreen(uid: uid))),
              ),
              if (pendingCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: GameColors.rose, shape: BoxShape.circle),
                    child: Text('$pendingCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          userAsync.when(
            data: (user) => user == null
                ? const SizedBox()
                : GamePanel(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: GameColors.violet.withOpacity(0.14),
                          child: Text(_avatarEmoji(user.avatar), style: const TextStyle(fontSize: 22)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              Text(
                                '${user.points} pts | ${user.wins}W ${user.draws}D ${user.losses}L',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.person),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(uid: uid))),
                        ),
                      ],
                    ),
                  ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
          const SizedBox(height: 22),
          const Text('Choose your battle', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            'Create rooms, find players, and climb the leaderboard.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62)),
          ),
          const SizedBox(height: 18),
          _MenuButton(
            icon: Icons.add_circle_outline,
            label: 'Create Room',
            color: GameColors.violet,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRoomScreen())),
          ),
          const SizedBox(height: 14),
          _MenuButton(
            icon: Icons.login,
            label: 'Join Room',
            color: GameColors.cyan,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JoinRoomScreen())),
          ),
          const SizedBox(height: 14),
          _MenuButton(
            icon: Icons.shuffle,
            label: 'Random Match',
            color: GameColors.amber,
            onTap: _randomMatchBusy ? null : () => _randomMatch(uid),
          ),
          const SizedBox(height: 14),
          _MenuButton(
            icon: Icons.leaderboard,
            label: 'Leaderboard',
            color: GameColors.rose,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
          ),
        ],
      ),
    );
  }

  Future<void> _randomMatch(String uid) async {
    if (_randomMatchBusy) return;
    setState(() => _randomMatchBusy = true);

    final roomService = ref.read(roomServiceProvider);

    try {
      final existing = await roomService.joinRandomRoom(uid);
      if (existing != null) {
        if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => LobbyScreen(roomId: existing.roomId)));
        return;
      }

      final waitRoom = await roomService.createRoom(uid);
      if (!mounted) return;

      int searchTicks = 0;
      int cardIndex = 0;
      Timer? countdown;
      StreamSubscription? roomSub;
      bool cancelled = false;
      bool navigated = false;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) {
            roomSub ??= roomService.watchRoom(waitRoom.roomId).listen((snap) {
              if (cancelled || navigated) return;
              if (snap != null && snap.guestId != null && snap.guestId!.isNotEmpty && !BotService.isBot(snap.guestId!)) {
                navigated = true;
                countdown?.cancel();
                roomSub?.cancel();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => LobbyScreen(roomId: waitRoom.roomId)));
                }
              }
            });

            countdown ??= Timer.periodic(const Duration(milliseconds: 450), (_) async {
              if (cancelled || navigated) return;

              if (searchTicks >= 44) {
                countdown?.cancel();
                roomSub?.cancel();
                if (ctx.mounted) Navigator.pop(ctx);
                return;
              }
              if (ctx.mounted) {
                setDialogState(() {
                  searchTicks++;
                  cardIndex++;
                });
              }
            });

            return AlertDialog(
              title: const Text('Finding Rival'),
              content: _MatchmakingCards(activeIndex: cardIndex),
              actions: [
                TextButton(
                  onPressed: () {
                    cancelled = true;
                    countdown?.cancel();
                    roomSub?.cancel();
                    Navigator.pop(ctx);
                    roomService.cancelWaitingRoom(waitRoom.roomId);
                  },
                  child: const Text('Cancel', style: TextStyle(color: GameColors.rose)),
                ),
              ],
            );
          },
        ),
      ).then((_) async {
        countdown?.cancel();
        await roomSub?.cancel();
        if (navigated || cancelled || !mounted) return;
        await roomService.cancelWaitingRoom(waitRoom.roomId);
        if (!mounted) return;
        final botRoom = await roomService.createRoomVsBot(uid);
        if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(roomId: botRoom.roomId)));
      });
    } finally {
      if (mounted) setState(() => _randomMatchBusy = false);
    }
  }

  String _avatarEmoji(String avatar) {
    const map = {
      'avatar_1': 'A1',
      'avatar_2': 'A2',
      'avatar_3': 'A3',
      'avatar_4': 'A4',
      'avatar_5': 'A5',
      'avatar_6': 'A6',
    };
    return map[avatar] ?? 'P1';
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _MenuButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GameButton(icon: icon, label: label, color: color, onPressed: onTap);
  }
}

class _MatchmakingCards extends StatelessWidget {
  final int activeIndex;

  const _MatchmakingCards({required this.activeIndex});

  static const _rivals = [
    ('Blitz X', 'Fast opener', GameColors.violet, Icons.flash_on),
    ('Nova O', 'Corner trapper', GameColors.cyan, Icons.auto_awesome),
    ('Grid Ace', 'Clean striker', GameColors.amber, Icons.grid_3x3),
    ('Shadow XO', 'Late-game closer', GameColors.rose, Icons.visibility),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = activeIndex % _rivals.length;

    return SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: GameColors.violet.withOpacity(0.18)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _ScannerLinesPainter()),
                ),
                for (var i = 0; i < _rivals.length; i++)
                  AnimatedPositioned(
                    key: ValueKey('rival_$i'),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    left: _cardLeft(i, selected),
                    top: i == selected ? 20 : 34,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 260),
                      opacity: i == selected ? 1 : 0.42,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 320),
                        scale: i == selected ? 1 : 0.82,
                        child: _RivalCard(
                          name: _rivals[i].$1,
                          tag: _rivals[i].$2,
                          color: _rivals[i].$3,
                          icon: _rivals[i].$4,
                          selected: i == selected,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text('Scanning live arenas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            'Cards shuffle until a real opponent locks in.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const LinearProgressIndicator(minHeight: 7),
          ),
        ],
      ),
    );
  }

  double _cardLeft(int index, int selected) {
    final offset = (index - selected + _rivals.length) % _rivals.length;
    if (offset == 0) return 86;
    if (offset == 1) return 194;
    if (offset == _rivals.length - 1) return -22;
    return 86;
  }
}

class _RivalCard extends StatelessWidget {
  final String name;
  final String tag;
  final Color color;
  final IconData icon;
  final bool selected;

  const _RivalCard({
    required this.name,
    required this.tag,
    required this.color,
    required this.icon,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      height: 108,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.92), color.withOpacity(0.62)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? Colors.white : Colors.white.withOpacity(0.45), width: selected ? 2 : 1),
        boxShadow: [
          if (selected) BoxShadow(color: color.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const Spacer(),
              const Text('XO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ],
          ),
          const Spacer(),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(tag, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.82), fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ScannerLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = GameColors.violet.withOpacity(0.06)
      ..strokeWidth = 1;
    for (double x = 18; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x + 24, size.height), paint);
    }
    final centerPaint = Paint()
      ..color = GameColors.violet.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(82, 16, 136, 116), const Radius.circular(10)),
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
