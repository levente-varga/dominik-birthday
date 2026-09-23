import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dominik/config/achievement_config.dart';
import 'package:dominik/game_state.dart';
import 'package:dominik/save_system.dart';
import 'package:dominik/widgets/global_achievement_overlay.dart';

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

  testWidgets('Achievement toast appears below safe zone on phones with Dynamic Island (top: 59.0)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(top: 59.0),
            size: Size(393, 852),
          ),
          child: GlobalAchievementOverlay(
            gameState: gameState,
            child: const Scaffold(body: SizedBox.expand()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Trigger an achievement unlock toast
    gameState.triggerTestAchievementToast();
    await tester.idle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final toastFinder = find.byKey(const ValueKey('test_achievement_1'));
    expect(toastFinder, findsOneWidget);

    final toastRect = tester.getRect(toastFinder);
    // Must appear strictly below the safe zone (59.0) plus top margin (12.0) = 71.0
    expect(toastRect.top, equals(59.0 + AchievementToastConfig.topMargin));
    expect(toastRect.top, greaterThan(59.0));

    // Wait until display duration finishes and pump animation reverse
    await tester.pump(AchievementToastConfig.displayDuration);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const ValueKey('test_achievement_1')), findsNothing);
  });

  testWidgets('Achievement toast appears below safe zone on phones with notch (top: 47.0)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(top: 47.0),
            size: Size(390, 844),
          ),
          child: GlobalAchievementOverlay(
            gameState: gameState,
            child: const Scaffold(body: SizedBox.expand()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    gameState.triggerTestAchievementToast();
    await tester.idle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final toastFinder = find.byKey(const ValueKey('test_achievement_1'));
    expect(toastFinder, findsOneWidget);

    final toastRect = tester.getRect(toastFinder);
    expect(toastRect.top, equals(47.0 + AchievementToastConfig.topMargin));
    expect(toastRect.top, greaterThan(47.0));
  });

  testWidgets('Achievement toast appears with top margin on devices with zero safe area padding (desktop/web)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.zero,
            size: Size(800, 600),
          ),
          child: GlobalAchievementOverlay(
            gameState: gameState,
            child: const Scaffold(body: SizedBox.expand()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    gameState.triggerTestAchievementToast();
    await tester.idle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final toastFinder = find.byKey(const ValueKey('test_achievement_1'));
    expect(toastFinder, findsOneWidget);

    final toastRect = tester.getRect(toastFinder);
    expect(toastRect.top, equals(AchievementToastConfig.topMargin));
  });
}
