import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/providers.dart';
import '../widgets/game_ui.dart';
import 'profile_screen.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final lb = ref.watch(leaderboardProvider);

    return GameShell(
      appBar: AppBar(title: const Text('Leaderboard')),
      child: lb.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (players) => ListView.separated(
          itemCount: players.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final p = players[i];
            final rank = i + 1;
            final wins = p['wins'] ?? 0;
            final total = p['totalMatches'] ?? 0;
            final winRate = total == 0 ? 0.0 : wins / total;
            final isMe = p['uid'] == myUid;

            return GamePanel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: isMe ? GameColors.violet.withOpacity(0.12) : null,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                      uid: p['uid'],
                      viewerUid: isMe ? null : myUid,
                    ),
                  ),
                ),
                leading: CircleAvatar(
                  backgroundColor: rank <= 3
                      ? [GameColors.amber, Colors.blueGrey, Colors.brown][rank - 1]
                      : GameColors.violet.withOpacity(0.14),
                  child: Text(
                    '$rank',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: rank <= 3 ? Colors.white : GameColors.violet),
                  ),
                ),
                title: Text(
                  '${p['name'] ?? 'Player'}${isMe ? ' (You)' : ''}',
                  style: TextStyle(fontWeight: FontWeight.w900, color: isMe ? GameColors.violet : null),
                ),
                subtitle: Text('${wins}W | ${(winRate * 100).toStringAsFixed(0)}% win rate | $total matches'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${p['points'] ?? 0} pts', style: const TextStyle(fontWeight: FontWeight.w900, color: GameColors.violet)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
