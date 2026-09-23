import 'package:flutter/material.dart';

import 'game_state.dart';
import 'save_system.dart';
import 'screens/main_menu_screen.dart';
import 'screens/run_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/test_stage_screen.dart';

import 'widgets/global_achievement_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise persistence layer.
  final saveSystem = SaveSystem();
  await saveSystem.init();

  // Initialise game state.
  final gameState = GameStateManager(saveSystem);
  await gameState.loadState();

  runApp(BirthdayGauntletApp(gameState: gameState));
}

class BirthdayGauntletApp extends StatelessWidget {
  final GameStateManager gameState;

  const BirthdayGauntletApp({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dominik',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ).copyWith(
              error: const Color(0xFFC62828), // Deep rich crimson red
              onError: Colors.white,
              errorContainer: const Color(
                0xFF4A1010,
              ), // Deep dark red container
              onErrorContainer: const Color(0xFFFFCDD2),
            ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: GlobalAchievementOverlay(
            gameState: gameState,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      // ── Named routes ─────────────────────────────────────────────────
      initialRoute: '/splash',
      onGenerateRoute: (settings) {
        final Widget? page = switch (settings.name) {
          '/splash' => SplashScreen(
            gameState: gameState,
            pages: const [
              SplashPageConfig(
                duration: Duration(milliseconds: 3500),
                widget: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'LaCIGames',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'presents',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SplashPageConfig(
                duration: Duration(milliseconds: 3500),
                widget: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'A game by',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Levi A Tán',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Hominik',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
          '/menu' => MainMenuScreen(gameState: gameState),
          '/run' => RunScreen(gameState: gameState),
          '/statistics' => StatisticsScreen(gameState: gameState),
          '/practice' => TestStageScreen(
            stageNumber:
                (settings.arguments as Map<String, dynamic>?)?['stageNumber']
                    as int? ??
                1,
            gameState: gameState,
            isDevMode:
                (settings.arguments as Map<String, dynamic>?)?['isDevMode']
                    as bool? ??
                false,
          ),
          _ => null,
        };
        if (page == null) return null;

        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (_, _, _) => page,
          transitionDuration: const Duration(milliseconds: 500),
          reverseTransitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // First half of transition (0.0 -> 0.5): Outgoing screen fades out to background color.
            final fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
              CurvedAnimation(
                parent: secondaryAnimation,
                curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
              ),
            );

            // Second half of transition (0.5 -> 1.0): Incoming screen fades in from background color.
            final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
              ),
            );

            return FadeTransition(
              opacity: fadeOut,
              child: FadeTransition(
                opacity: fadeIn,
                child: child,
              ),
            );
          },
        );
      },
    );
  }
}
