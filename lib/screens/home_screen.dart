import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/providers.dart';
import '../services/bot_service.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('XO Battle', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            userAsync.when(
              data: (user) => user == null
                  ? const SizedBox()
                  : Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.deepPurple.shade100,
                          child: Text(_avatarEmoji(user.avatar), style: const TextStyle(fontSize: 22)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('${user.points} pts · ${user.wins}W ${user.draws}D ${user.losses}L',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.person),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(uid: uid))),
                        ),
                      ],
                    ),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
            const SizedBox(height: 32),
            _MenuButton(
              icon: Icons.add_circle_outline,
              label: 'Create Room',
              color: Colors.deepPurple,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRoomScreen())),
            ),
            const SizedBox(height: 16),
            _MenuButton(
              icon: Icons.login,
              label: 'Join Room',
              color: Colors.teal,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JoinRoomScreen())),
            ),
            const SizedBox(height: 16),
            _MenuButton(
              icon: Icons.shuffle,
              label: 'Random Match',
              color: Colors.orange,
              onTap: _randomMatchBusy ? null : () => _randomMatch(uid),
            ),
            const SizedBox(height: 16),
            _MenuButton(
              icon: Icons.leaderboard,
              label: 'Leaderboard',
              color: Colors.amber.shade700,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _randomMatch(String uid) async {
    if (_randomMatchBusy) return;
    setState(() => _randomMatchBusy = true);

    final roomService = ref.read(roomServiceProvider);

    try {
      // Try joining an existing real-player waiting room first
      final existing = await roomService.joinRandomRoom(uid);
      if (existing != null) {
        if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => LobbyScreen(roomId: existing.roomId)));
        return;
      }

      // No room found — create one and wait up to 20s for a real opponent
      final waitRoom = await roomService.createRoom(uid);
      if (!mounted) return;

      int secondsLeft = 20;
      Timer? countdown;
      bool cancelled = false;
      bool navigated = false;

      // ignore: use_build_context_synchronously
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) {
            countdown ??= Timer.periodic(const Duration(seconds: 1), (_) async {
              if (cancelled || navigated) return;

              // Check if a real player joined via Firestore stream
              final snap = await roomService.watchRoom(waitRoom.roomId).first;
              if (snap != null &&
                  snap.guestId != null &&
                  snap.guestId!.isNotEmpty &&
                  !BotService.isBot(snap.guestId!)) {
                navigated = true;
                countdown?.cancel();
                if (ctx.mounted) Navigator.pop(ctx); // close dialog
                // Both host and guest go to lobby — stream will show Start button
                if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => LobbyScreen(roomId: waitRoom.roomId)));
                return;
              }

              if (secondsLeft <= 1) {
                countdown?.cancel();
                if (ctx.mounted) Navigator.pop(ctx);
                return;
              }
              if (ctx.mounted) setDialogState(() => secondsLeft--);
            });

            return AlertDialog(
              title: const Text('🔍 Finding Opponent...'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Searching for real players...', style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Text(
                    '$secondsLeft s',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                  ),
                  const SizedBox(height: 4),
                  Text('Bot will fill in if no one joins', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    cancelled = true;
                    countdown?.cancel();
                    Navigator.pop(ctx);
                    roomService.abandonRoom(waitRoom.roomId, uid);
                  },
                  child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        ),
      ).then((_) async {
        // Dialog closed — if not navigated and not cancelled, go to bot
        countdown?.cancel();
        if (navigated || cancelled || !mounted) return;
        await roomService.abandonRoom(waitRoom.roomId, uid);
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
      'avatar_1': '🐶', 'avatar_2': '🐱', 'avatar_3': '🦊',
      'avatar_4': '🐸', 'avatar_5': '🐼', 'avatar_6': '🦁',
    };
    return map[avatar] ?? '🐶';
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
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 16)),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
