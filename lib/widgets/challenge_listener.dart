import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../navigation.dart';
import '../providers/providers.dart';
import '../models/room_model.dart';
import '../screens/lobby_screen.dart';

class ChallengeListener extends ConsumerStatefulWidget {
  final Widget child;
  const ChallengeListener({super.key, required this.child});

  @override
  ConsumerState<ChallengeListener> createState() => _ChallengeListenerState();
}

class _ChallengeListenerState extends ConsumerState<ChallengeListener> {
  final Set<String> _shown = {};

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return widget.child;

    ref.listen(incomingChallengesProvider(user.uid), (_, next) {
      next.whenData((list) {
        for (final challenge in list) {
          if (!_shown.contains(challenge.roomId)) {
            _shown.add(challenge.roomId);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showDialog(challenge, user.uid);
            });
          }
        }
      });
    });

    return widget.child;
  }

  Future<void> _showDialog(RoomModel challenge, String uid) async {
    final navigator = rootNavigatorKey.currentState;
    final dialogContext = navigator?.context;
    if (dialogContext == null) return;

    final accepted = await showDialog<bool>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('⚔️ Challenge Received!'),
        content: FutureBuilder<String>(
          future: ref.read(roomServiceProvider).getUserName(challenge.hostId),
          builder: (_, snap) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${snap.data ?? '...'} challenged you!',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Do you accept?'),
            ],
          ),
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

    if (!mounted) return;
    if (accepted == true) {
      await ref.read(roomServiceProvider).acceptChallenge(challenge.roomId);
      rootNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => LobbyScreen(roomId: challenge.roomId)));
    } else {
      await ref.read(roomServiceProvider).declineChallenge(challenge.roomId);
    }
  }
}
