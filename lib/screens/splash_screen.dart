import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart';
import '../services/auth_service.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('XO', style: TextStyle(fontSize: 72, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              Text('BATTLE', style: TextStyle(fontSize: 24, letterSpacing: 6, color: Colors.deepPurple)),
              SizedBox(height: 32),
              CircularProgressIndicator(),
            ],
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
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return snap.data! ? const HomeScreen() : const ProfileSetupScreen();
          },
        );
      },
    );
  }
}
