import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

class ProfileScreen extends ConsumerWidget {
  final String uid;
  /// Pass the logged-in user's uid when viewing someone else's profile.
  final String? viewerUid;

  const ProfileScreen({super.key, required this.uid, this.viewerUid});

  static const _avatarEmojis = {
    'avatar_1': '🐶', 'avatar_2': '🐱', 'avatar_3': '🦊',
    'avatar_4': '🐸', 'avatar_5': '🐼', 'avatar_6': '🦁',
  };

  bool get _isOwnProfile => viewerUid == null || viewerUid == uid;

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
                const SizedBox(height: 16),
                if (!_isOwnProfile) _ActionButtons(viewerUid: viewerUid!, targetUid: uid),
                const SizedBox(height: 16),
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

class _ActionButtons extends ConsumerWidget {
  final String viewerUid;
  final String targetUid;

  const _ActionButtons({required this.viewerUid, required this.targetUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFriendAsync = ref.watch(isFriendProvider((viewer: viewerUid, target: targetUid)));
    final hasPendingAsync = ref.watch(hasPendingRequestProvider((viewer: viewerUid, target: targetUid)));

    return isFriendAsync.when(
      loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, __) => const SizedBox(),
      data: (isFriend) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isFriend)
            ElevatedButton.icon(
              onPressed: () => _challenge(context, ref),
              icon: const Icon(Icons.sports_esports, size: 16),
              label: const Text('Challenge'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )
          else
            hasPendingAsync.when(
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
              data: (hasPending) => hasPending
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.hourglass_top, size: 16),
                      label: const Text('Request Sent'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: () => _sendRequest(context, ref),
                      icon: const Icon(Icons.person_add, size: 16),
                      label: const Text('Add Friend'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  Future<void> _sendRequest(BuildContext context, WidgetRef ref) async {
    await ref.read(roomServiceProvider).sendFriendRequest(viewerUid, targetUid);
    ref.invalidate(hasPendingRequestProvider((viewer: viewerUid, target: targetUid)));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend request sent!')));
    }
  }

  Future<void> _challenge(BuildContext context, WidgetRef ref) async {
    await ref.read(roomServiceProvider).challengeFriend(viewerUid, targetUid);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Challenge sent!')));
    }
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
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
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
