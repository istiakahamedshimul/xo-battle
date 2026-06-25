import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

class ProfileScreen extends ConsumerWidget {
  final String uid;
  const ProfileScreen({super.key, required this.uid});

  static const _avatarEmojis = {
    'avatar_1': '🐶', 'avatar_2': '🐱', 'avatar_3': '🦊',
    'avatar_4': '🐸', 'avatar_5': '🐼', 'avatar_6': '🦁',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider(uid));

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          if (user == null) return const Center(child: Text('User not found'));
          final winRate = (user.winRate * 100).toStringAsFixed(1);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.deepPurple.shade100,
                  child: Text(_avatarEmojis[user.avatar] ?? '🐶', style: const TextStyle(fontSize: 48)),
                ),
                const SizedBox(height: 12),
                Text(user.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text('${user.points} points', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 32),
                _StatsGrid(user: user, winRate: winRate),
                const SizedBox(height: 24),
                _StatRow(label: 'Current Streak', value: '${user.currentStreak} 🔥'),
                _StatRow(label: 'Best Streak', value: '${user.bestStreak} ⚡'),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final dynamic user;
  final String winRate;

  const _StatsGrid({required this.user, required this.winRate});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2,
      children: [
        _StatCard(label: 'Matches', value: '${user.totalMatches}', color: Colors.blue),
        _StatCard(label: 'Wins', value: '${user.wins}', color: Colors.green),
        _StatCard(label: 'Losses', value: '${user.losses}', color: Colors.red),
        _StatCard(label: 'Win Rate', value: '$winRate%', color: Colors.deepPurple),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
