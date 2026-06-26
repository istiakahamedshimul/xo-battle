import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/providers.dart';
import '../widgets/game_ui.dart';
import 'lobby_screen.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  String? _roomId;
  String? _roomCode;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _createRoom();
  }

  Future<void> _createRoom() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final room = await ref.read(roomServiceProvider).createRoom(uid);
    if (mounted) {
      setState(() {
        _roomId = room.roomId;
        _roomCode = room.roomCode;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameShell(
      appBar: AppBar(title: const Text('Create Room')),
      child: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : GamePanel(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const XoLogo(size: 64, compact: true),
                    const SizedBox(height: 20),
                    const SectionLabel('Room Code'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                      decoration: BoxDecoration(
                        color: GameColors.violet.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: GameColors.violet, width: 2),
                      ),
                      child: Text(
                        _roomCode ?? '',
                        style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: 7, color: GameColors.violet),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GameButton(
                      icon: Icons.copy,
                      label: 'Copy Code',
                      color: GameColors.cyan,
                      outlined: true,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _roomCode ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied!')));
                      },
                    ),
                    const SizedBox(height: 12),
                    Text('Share this code with a friend', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62))),
                    const SizedBox(height: 32),
                    GameButton(
                      icon: Icons.sports_esports,
                      label: 'Go to Lobby',
                      onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LobbyScreen(roomId: _roomId!))),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
