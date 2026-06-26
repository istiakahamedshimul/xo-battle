import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart';
import '../services/auth_service.dart';
import '../widgets/game_ui.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const GameShell(
        child: Center(
          child: GamePanel(
            padding: EdgeInsets.symmetric(horizontal: 28, vertical: 34),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                XoLogo(),
                SizedBox(height: 28),
                LinearProgressIndicator(minHeight: 6),
              ],
            ),
          ),
        ),
      ),
      error: (_, __) => const LoginScreen(),
      data: (user) {
        if (user == null) return const LoginScreen();
        return FutureBuilder<bool>(
          future: AuthService().hasProfile(user.uid),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const GameShell(child: Center(child: CircularProgressIndicator()));
            }
            return snap.data! ? const HomeScreen() : const ProfileSetupScreen();
          },
        );
      },
    );
  }
}
