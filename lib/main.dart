import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'navigation.dart';
import 'providers/providers.dart';
import 'screens/splash_screen.dart';
import 'services/bot_service.dart';
import 'widgets/challenge_listener.dart';
import 'widgets/game_ui.dart';

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
        colorSchemeSeed: GameColors.violet,
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FBFF),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: GameColors.ink,
          titleTextStyle: TextStyle(color: GameColors.ink, fontSize: 20, fontWeight: FontWeight.w900),
        ),
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: GameColors.violet,
        brightness: Brightness.dark,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
      ),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => ChallengeListener(child: child ?? const SizedBox()),
      home: const SplashScreen(),
    );
  }
}
