import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/providers.dart';
import '../widgets/game_ui.dart';
import 'game_screen.dart';
import 'home_screen.dart';

class LobbyScreen extends ConsumerWidget {
  final String roomId;
  const LobbyScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final roomAsync = ref.watch(roomStreamProvider(roomId));

    return roomAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (room) {
        if (room == null) return const Scaffold(body: Center(child: Text('Room not found')));

        // Both players auto-navigate when status becomes playing
        if (room.isPlaying) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameScreen(roomId: roomId)));
            }
          });
        }

        final isHost = room.hostId == uid;
        final hasGuest = room.guestId != null && room.guestId!.isNotEmpty;
        final isChallengePending = room.isChallenge && !room.challengeAccepted;
        final canStart = isHost && hasGuest && !isChallengePending && room.isWaiting;

        return GameShell(
          appBar: AppBar(
            title: const Text('Lobby'),
            actions: [
              TextButton(
                onPressed: () => _leave(context, ref, room.roomId, uid),
                child: const Text('Leave', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
          child: Column(
              children: [
                GamePanel(
                  child: Column(
                    children: [
                      const SectionLabel('Room Code'),
                      const SizedBox(height: 8),
                      Text(room.roomCode, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 6, color: GameColors.violet)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _PlayerTile(uid: room.playerX, label: 'Player X (Host)', symbol: 'X'),
                const SizedBox(height: 16),
                hasGuest
                    ? _PlayerTile(uid: room.playerO, label: 'Player O', symbol: 'O')
                    : const _WaitingTile(),
                const Spacer(),
                if (!hasGuest)
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2),
                      SizedBox(width: 12),
                      Text('Waiting for opponent...', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                if (isChallengePending)
                  Text(
                    isHost ? 'Waiting for friend to accept...' : 'Challenge pending...',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                if (room.isFinished)
                  Text(
                    room.result == 'declined' ? 'Challenge declined' : 'Room closed',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                if (canStart)
                  GameButton(
                    icon: Icons.play_arrow,
                    label: 'Start Game',
                    onPressed: () => _startGame(context, ref, roomId),
                  ),
                const SizedBox(height: 24),
              ],
            ),
        );
      },
    );
  }

  Future<void> _startGame(BuildContext context, WidgetRef ref, String roomId) async {
    await ref.read(roomServiceProvider).startGame(roomId);
    // navigation handled by stream listener above
  }

  Future<void> _leave(BuildContext context, WidgetRef ref, String roomId, String uid) async {
    await ref.read(roomServiceProvider).abandonRoom(roomId, uid);
    if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
  }
}

class _PlayerTile extends ConsumerWidget {
  final String uid;
  final String label;
  final String symbol;

  const _PlayerTile({required this.uid, required this.label, required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider(uid));
    return GamePanel(
      padding: const EdgeInsets.all(16),
      color: (symbol == 'X' ? GameColors.violet : GameColors.cyan).withOpacity(0.10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: symbol == 'X' ? GameColors.violet : GameColors.cyan,
            child: Text(symbol, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              userAsync.when(
                data: (u) => Text(u?.name ?? 'Player', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                loading: () => const Text('Loading...'),
                error: (_, __) => const Text('Player'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaitingTile extends StatelessWidget {
  const _WaitingTile();

  @override
  Widget build(BuildContext context) {
    return const GamePanel(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: Colors.grey, child: Text('O', style: TextStyle(color: Colors.white))),
          SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Player O', style: TextStyle(fontSize: 12, color: Colors.grey)),
            Text('Waiting...', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ]),
        ],
      ),
    );
  }
}
