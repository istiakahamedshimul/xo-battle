import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/providers.dart';
import '../widgets/game_ui.dart';
import 'home_screen.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _controller = TextEditingController();
  String _avatar = 'avatar_1';
  bool _loading = false;

  final _avatars = ['avatar_1', 'avatar_2', 'avatar_3', 'avatar_4', 'avatar_5', 'avatar_6'];
  final _avatarEmojis = ['A1', 'A2', 'A3', 'A4', 'A5', 'A6'];

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await ref.read(authServiceProvider).setupProfile(uid, name, _avatar);
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
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
      appBar: AppBar(title: const Text('Set Up Profile')),
      scrollable: true,
      child: GamePanel(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: XoLogo(size: 72, compact: true)),
              const SizedBox(height: 20),
              const Text('Create your player', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('Pick a profile and enter the arena.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62))),
              const SizedBox(height: 24),
              const SectionLabel('Choose Avatar'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(_avatars.length, (i) {
                  final selected = _avatar == _avatars[i];
                  return GestureDetector(
                    onTap: () => setState(() => _avatar = _avatars[i]),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 54,
                      width: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: selected ? GameColors.violet.withOpacity(0.16) : Theme.of(context).colorScheme.surface,
                        border: Border.all(color: selected ? GameColors.violet : Colors.black12, width: selected ? 2 : 1),
                      ),
                      child: Text(_avatarEmojis[i], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: GameColors.violet)),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 26),
              const SectionLabel('Your Name'),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                maxLength: 20,
                decoration: InputDecoration(
                  hintText: 'Enter your name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 24),
              GameButton(
                icon: Icons.check_circle_outline,
                label: 'Save & Continue',
                onPressed: _loading ? null : _save,
                trailing: _loading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
