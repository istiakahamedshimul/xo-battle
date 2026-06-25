import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: rank <= 3 ? [Colors.amber, Colors.grey, Colors.brown][rank - 1] : Colors.deepPurple.shade100,
                child: Text(rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '$rank', style: const TextStyle(fontSize: 16)),
              ),
              title: Text(p['name'] ?? 'Player', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${wins}W · ${(winRate * 100).toStringAsFixed(0)}% win rate · $total matches'),
              trailing: Text('${p['points'] ?? 0} pts', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            );
          },
        ),
      ),
    );
  }
}
