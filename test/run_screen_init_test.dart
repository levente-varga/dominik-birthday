import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dominik/game_state.dart';
import 'package:dominik/save_system.dart';
import 'package:dominik/screens/main_menu_screen.dart';
import 'package:dominik/screens/run_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SaveSystem saveSystem;
  late GameStateManager gameState;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    saveSystem = SaveSystem();
    await saveSystem.init();
    gameState = GameStateManager(saveSystem);
    await gameState.loadState();
  });

  testWidgets('Navigating from MainMenuScreen to RunScreen initializes run without build exception', (tester) async {
    tester.view.physicalSize = const Size(560, 680);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      gameState.resetRunState();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/': (context) => MainMenuScreen(gameState: gameState),
          '/run': (context) => RunScreen(gameState: gameState),
        },
      ),
    );
    await tester.pumpAndSettle();

    // Tap Start Run button (Play icon)
    final startRunBtn = find.byIcon(Icons.play_arrow_rounded);
    expect(startRunBtn, findsOneWidget);
    await tester.tap(startRunBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify RunScreen mounted and run is active
    expect(find.byType(RunScreen), findsOneWidget);
    expect(gameState.isRunActive, isTrue);

    // Pump time forward past old timer limit (70 seconds) - run should still remain active
    await tester.pump(const Duration(seconds: 70));
    expect(gameState.isRunActive, isTrue);

    gameState.resetRunState();
  });
}

