import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dominik/game_state.dart';
import 'package:dominik/save_system.dart';
import 'package:dominik/widgets/confirm_popup.dart';

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

  testWidgets('showAddDevTokensPopup allows entering and adding custom tokens', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showAddDevTokensPopup(context, gameState: gameState),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    // Open popup
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Add Dev Tokens'), findsOneWidget);
    expect(find.text('Current Balance: '), findsOneWidget);

    // Default pre-fill is 100
    expect(find.text('100'), findsOneWidget);

    // Tap +1,000 preset button
    await tester.tap(find.text('+1,000'));
    await tester.pumpAndSettle();

    // Verify text changed to 1000
    expect(find.text('1000'), findsOneWidget);

    // Clear and enter custom 750
    final textField = find.byType(TextField);
    await tester.enterText(textField, '750');
    await tester.pumpAndSettle();

    // Tap 'Add Tokens' button
    await tester.tap(find.text('Add Tokens'));
    await tester.pumpAndSettle();

    // Dialog dismissed
    expect(find.text('Add Dev Tokens'), findsNothing);

    // Verify tokens and stats updated
    expect(gameState.tokens, 750);
    expect(gameState.statistics.totalTokensEarned, 750);
  });
}
