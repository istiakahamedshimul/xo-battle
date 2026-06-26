import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../widgets/game_ui.dart';
import 'lobby_screen.dart';

class ProfileScreen extends ConsumerWidget {
  final String uid;
  final String? viewerUid;

  const ProfileScreen({super.key, required this.uid, this.viewerUid});

  static const _avatarLabels = {
    'avatar_1': 'A1',
    'avatar_2': 'A2',
    'avatar_3': 'A3',
    'avatar_4': 'A4',
    'avatar_5': 'A5',
    'avatar_6': 'A6',
  };

  bool get _isOwnProfile => viewerUid == null || viewerUid == uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider(uid));

    return GameShell(
      appBar: AppBar(title: const Text('Profile')),
      scrollable: true,
      child: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          if (user == null) return const Center(child: Text('User not found'));
          final winRate = (user.winRate * 100).toStringAsFixed(1);

          return Column(
            children: [
              GamePanel(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: GameColors.violet.withOpacity(0.14),
                      child: Text(
                        _avatarLabels[user.avatar] ?? 'P1',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: GameColors.violet),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(user.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                    Text('${user.points} points', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62))),
                    if (!_isOwnProfile) ...[
                      const SizedBox(height: 16),
                      _ActionButtons(viewerUid: viewerUid!, targetUid: uid),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _StatsGrid(user: user, winRate: winRate),
              const SizedBox(height: 16),
              _StatRow(label: 'Current Streak', value: '${user.currentStreak}'),
              _StatRow(label: 'Best Streak', value: '${user.bestStreak}'),
            ],
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
      data: (isFriend) {
        if (isFriend) {
          return GameButton(
            icon: Icons.sports_esports,
            label: 'Challenge',
            onPressed: () => _challenge(context, ref),
          );
        }
        return hasPendingAsync.when(
          loading: () => const SizedBox(),
          error: (_, __) => const SizedBox(),
          data: (hasPending) => hasPending
              ? const GameButton(icon: Icons.hourglass_top, label: 'Request Sent', onPressed: null, outlined: true)
              : GameButton(
                  icon: Icons.person_add,
                  label: 'Add Friend',
                  color: GameColors.cyan,
                  onPressed: () => _sendRequest(context, ref),
                ),
        );
      },
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
    final room = await ref.read(roomServiceProvider).challengeFriend(viewerUid, targetUid);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Challenge sent!')));
      Navigator.push(context, MaterialPageRoute(builder: (_) => LobbyScreen(roomId: room.roomId)));
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
        GameStatTile(label: 'Matches', value: '${user.totalMatches}', color: GameColors.cyan, icon: Icons.grid_3x3),
        GameStatTile(label: 'Wins', value: '${user.wins}', color: GameColors.green, icon: Icons.emoji_events),
        GameStatTile(label: 'Losses', value: '${user.losses}', color: GameColors.rose, icon: Icons.close),
        GameStatTile(label: 'Win Rate', value: '$winRate%', color: GameColors.violet, icon: Icons.trending_up),
      ],
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GamePanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: GameColors.violet)),
          ],
        ),
      ),
    );
  }
}
