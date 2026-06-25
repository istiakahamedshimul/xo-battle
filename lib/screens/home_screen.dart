import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/providers.dart';
import 'create_room_screen.dart';
import 'join_room_screen.dart';
import 'leaderboard_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import '../services/room_service.dart';
import 'lobby_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userAsync = ref.watch(userProfileProvider(uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('XO Battle', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
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
              onTap: () => _randomMatch(context, ref, uid),
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

  Future<void> _randomMatch(BuildContext context, WidgetRef ref, String uid) async {
    final roomService = ref.read(roomServiceProvider);
    final room = await roomService.joinRandomRoom(uid);
    if (room != null) {
      if (context.mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => LobbyScreen(roomId: room.roomId)));
      }
    } else {
      // No room found, create one and wait
      final newRoom = await roomService.createRoom(uid);
      if (context.mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => LobbyScreen(roomId: newRoom.roomId)));
      }
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
  final VoidCallback onTap;

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
