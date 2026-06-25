import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/providers.dart';
import 'profile_screen.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final lb = ref.watch(leaderboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: lb.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (players) => ListView.builder(
          itemCount: players.length,
          itemBuilder: (_, i) {
            final p = players[i];
            final rank = i + 1;
            final wins = p['wins'] ?? 0;
            final total = p['totalMatches'] ?? 0;
            final winRate = total == 0 ? 0.0 : wins / total;
            final isMe = p['uid'] == myUid;

            return ListTile(
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
                    ? [Colors.amber, Colors.grey, Colors.brown][rank - 1]
                    : Colors.deepPurple.shade100,
                child: Text(
                  rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '$rank',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              title: Text(
                '${p['name'] ?? 'Player'}${isMe ? ' (You)' : ''}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isMe ? Colors.deepPurple : null,
                ),
              ),
              subtitle: Text('${wins}W · ${(winRate * 100).toStringAsFixed(0)}% win rate · $total matches'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${p['points'] ?? 0} pts',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
