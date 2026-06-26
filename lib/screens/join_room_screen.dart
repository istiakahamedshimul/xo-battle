import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/providers.dart';
import '../widgets/game_ui.dart';
import 'lobby_screen.dart';

class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _join() async {
    final code = _controller.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter a valid 6-character code');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final room = await ref.read(roomServiceProvider).joinRoomByCode(code, uid);
      if (room == null) {
        setState(() => _error = 'Room not found or already started');
      } else {
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LobbyScreen(roomId: room.roomId)));
      }
    } catch (e) {
      setState(() => _error = 'Failed to join room');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameShell(
      appBar: AppBar(title: const Text('Join Room')),
      child: Center(
        child: GamePanel(
          padding: const EdgeInsets.all(24),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.login, size: 54, color: GameColors.cyan),
            const SizedBox(height: 12),
            const Text('Enter the arena', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Room Code',
                hintText: 'Enter 6-character code',
                errorText: _error,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.tag),
              ),
              style: const TextStyle(fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            GameButton(
              icon: Icons.sports_esports,
              label: 'Join Room',
              color: GameColors.cyan,
              onPressed: _loading ? null : _join,
              trailing: _loading
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : null,
            ),
          ],
        ),
      ),
      ),
    );
  }
}
