import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dominik/game_state.dart';
import 'package:dominik/save_system.dart';
import 'package:dominik/screens/main_menu_screen.dart';
import 'package:dominik/widgets/menu_button.dart';

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

  testWidgets(
      'MainMenuScreen displays Options button instead of Quit button, and tapping it opens options popup',
      (tester) async {
    tester.view.physicalSize = const Size(560, 680);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MainMenuScreen(gameState: gameState),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Quit button is no longer present
    expect(find.text('Quit'), findsNothing);
    expect(find.byIcon(Icons.exit_to_app_rounded), findsNothing);

    // 2. Verify Options button is present
    final optionsButtonFinder = find.byWidgetPredicate(
      (widget) =>
          widget is MenuButton &&
          widget.label == 'Options' &&
          widget.icon == Icons.settings_rounded,
    );
    expect(optionsButtonFinder, findsOneWidget);

    // 3. Tap Options button to open the popup
    await tester.tap(optionsButtonFinder);
    await tester.pumpAndSettle();

    // 4. Verify Options popup is displayed matching minimap popup styling
    final optionsPopupFinder =
        find.byKey(const ValueKey('options_popup_container'));
    expect(optionsPopupFinder, findsOneWidget);

    // 5. Close the popup
    final closeButtonFinder = find.byIcon(Icons.close_rounded);
    expect(closeButtonFinder, findsOneWidget);
    await tester.tap(closeButtonFinder);
    await tester.pumpAndSettle();

    // 6. Verify popup is dismissed
    expect(optionsPopupFinder, findsNothing);
  });
}
