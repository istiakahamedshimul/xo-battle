import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/providers.dart';
import '../models/room_model.dart';
import '../screens/game_screen.dart';

/// Wraps the entire app and listens for incoming challenges globally.
/// Shows the challenge dialog instantly no matter what screen the user is on.
class ChallengeListener extends ConsumerStatefulWidget {
  final Widget child;
  const ChallengeListener({super.key, required this.child});

  @override
  ConsumerState<ChallengeListener> createState() => _ChallengeListenerState();
}

class _ChallengeListenerState extends ConsumerState<ChallengeListener> {
  final Set<String> _shownChallenges = {};
  bool _dialogVisible = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return widget.child;

    final challenges = ref.watch(incomingChallengesProvider(user.uid));

    challenges.whenData((list) {
      for (final challenge in list) {
        if (!_shownChallenges.contains(challenge.roomId)) {
          _shownChallenges.add(challenge.roomId);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_dialogVisible) {
              _showDialog(challenge, user.uid);
            }
          });
        }
      }
    });

    return widget.child;
  }

  Future<void> _showDialog(RoomModel challenge, String uid) async {
    _dialogVisible = true;

    final challengerName = await ref.read(roomServiceProvider).getUserName(challenge.hostId);
    if (!mounted) {
      _dialogVisible = false;
      return;
    }

    final ctx = context;
    final accepted = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('⚔️ Challenge Received!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$challengerName challenged you!',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Do you accept?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Decline', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    _dialogVisible = false;
    if (!mounted) return;

    if (accepted == true) {
      await ref.read(roomServiceProvider).startGame(challenge.roomId);
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(roomId: challenge.roomId)));
      }
    } else {
      await ref.read(roomServiceProvider).abandonRoom(challenge.roomId, uid);
    }
  }
}
