import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../widgets/game_ui.dart';
import 'login_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);

    return GameShell(
      appBar: AppBar(title: const Text('Settings')),
      child: Column(
        children: [
          GamePanel(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Dark Theme', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('Switch the arena lighting'),
                  secondary: const Icon(Icons.dark_mode),
                  value: isDark,
                  onChanged: (v) => ref.read(themeProvider.notifier).state = v,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GameButton(
            icon: Icons.logout,
            label: 'Logout',
            color: GameColors.rose,
            outlined: true,
            onPressed: () async {
            await ref.read(authServiceProvider).signOut();
            if (context.mounted) {
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
            }
          },
          ),
        ],
      ),
    );
  }
}
