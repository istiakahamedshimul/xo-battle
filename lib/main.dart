import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'navigation.dart';
import 'providers/providers.dart';
import 'screens/splash_screen.dart';
import 'services/bot_service.dart';
import 'widgets/challenge_listener.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await BotService.seedBots();
  runApp(const ProviderScope(child: XOBattleApp()));
}

class XOBattleApp extends ConsumerWidget {
  const XOBattleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'XO Battle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => ChallengeListener(child: child ?? const SizedBox()),
      home: const SplashScreen(),
    );
  }
}
