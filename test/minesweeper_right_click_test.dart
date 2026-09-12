import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dominik/config/config.dart';
import 'package:dominik/game_state.dart';
import 'package:dominik/save_system.dart';
import 'package:dominik/games/minesweeper.dart';

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

  Finder activeCellFinder() => find.byWidgetPredicate(
        (widget) =>
            widget.runtimeType.toString() == '_RegionCellWidget' &&
            (widget as dynamic).isNeighbor == false,
      );

  testWidgets('Long-pressing on an unrevealed Minesweeper tile toggles flag and updates HUD counter', (tester) async {
    final game = MinesweeperGame();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => game.buildGame(
              context: context,
              onComplete: () {},
              onFail: () {},
              gameState: gameState,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sectorMines = (MinesweeperConfig.regionRows *
            MinesweeperConfig.regionCols *
            MinesweeperConfig.mineDensity)
        .round();

    // Initially top-left badge displays sector mine count
    expect(find.byKey(const ValueKey('region_mine_counter_badge')), findsOneWidget);
    expect(find.text('$sectorMines'), findsOneWidget);
    expect(find.byIcon(Icons.flag_rounded), findsNothing);

    // Find first active cell
    final cell = activeCellFinder().first;

    // Long press on cell to place flag
    await tester.longPress(cell);
    await tester.pumpAndSettle();

    // Flag should be rendered and sector mine count decreased by 1
    expect(find.byIcon(Icons.flag_rounded), findsOneWidget);
    expect(find.text('${sectorMines - 1}'), findsOneWidget);

    // Long press again at same cell to unflag
    await tester.longPress(cell);
    await tester.pumpAndSettle();

    // Remaining mine display reverts to sectorMines and flag is removed
    expect(find.byIcon(Icons.flag_rounded), findsNothing);
    expect(find.text('$sectorMines'), findsOneWidget);
  });

  testWidgets('Right-clicking on tile does not toggle flag (mouse support removed)', (tester) async {
    final game = MinesweeperGame();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => game.buildGame(
              context: context,
              onComplete: () {},
              onFail: () {},
              gameState: gameState,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cell = activeCellFinder().first;
    final center = tester.getCenter(cell);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);

    // Right click on tile
    await tester.sendEventToBinding(
      pointer.down(center, buttons: kSecondaryMouseButton),
    );
    await tester.pump();
    await tester.sendEventToBinding(
      pointer.up(),
    );
    await tester.pumpAndSettle();

    // No flag should be placed
    expect(find.byIcon(Icons.flag_rounded), findsNothing);
  });

  testWidgets('Short tap on an unrevealed Minesweeper tile reveals safe clearing on first click', (tester) async {
    final game = MinesweeperGame();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => game.buildGame(
              context: context,
              onComplete: () {},
              onFail: () {},
              gameState: gameState,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final centerIndex =
        MinesweeperConfig.regionRows * MinesweeperConfig.regionCols ~/ 2;
    final cell = activeCellFinder().at(centerIndex); // Center tile of region
    await tester.tap(cell);
    await tester.pumpAndSettle();

    // Tapping reveals the tile (it's no longer unrevealed state 0)
    final firstWidget = tester.widget(cell) as dynamic;
    expect(firstWidget.cellState, isNot(equals(0)));
  });

  testWidgets('Tapping on a revealed number triggers chording', (tester) async {
    final game = MinesweeperGame();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => game.buildGame(
              context: context,
              onComplete: () {},
              onFail: () {},
              gameState: gameState,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Reveal center cell
    final centerIndex =
        MinesweeperConfig.regionRows * MinesweeperConfig.regionCols ~/ 2;
    await tester.tap(activeCellFinder().at(centerIndex));
    await tester.pumpAndSettle();

    // Find any revealed cell with adjacentMines > 0
    final cells = activeCellFinder();
    Finder? numberCellFinder;
    for (int i = 0; i < tester.widgetList(cells).length; i++) {
      final w = tester.widget(cells.at(i)) as dynamic;
      if (w.cellState == 1 && w.adjacentMines > 0) {
        numberCellFinder = cells.at(i);
        break;
      }
    }

    if (numberCellFinder != null) {
      // Tap on the number tile to trigger chording (should not throw and runs chord logic)
      await tester.tap(numberCellFinder);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Reduced long tap duration (250ms) triggers flag placement faster than default 500ms', (tester) async {
    final game = MinesweeperGame();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => game.buildGame(
              context: context,
              onComplete: () {},
              onFail: () {},
              gameState: gameState,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cell = activeCellFinder().first;
    final center = tester.getCenter(cell);

    final touch = TestPointer(1, PointerDeviceKind.touch);
    await tester.sendEventToBinding(touch.down(center));
    // Pump 260ms (more than longTapDuration 250ms, but well below default 500ms)
    await tester.pump(const Duration(milliseconds: 260));
    await tester.sendEventToBinding(touch.up());
    await tester.pumpAndSettle();

    // Flag should be placed at 260ms
    expect(find.byIcon(Icons.flag_rounded), findsOneWidget);
  });

  testWidgets('A touch release shorter than 250ms does not trigger long tap / flag', (tester) async {
    final game = MinesweeperGame();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => game.buildGame(
              context: context,
              onComplete: () {},
              onFail: () {},
              gameState: gameState,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final centerIndex =
        MinesweeperConfig.regionRows * MinesweeperConfig.regionCols ~/ 2;
    final cell = activeCellFinder().at(centerIndex);
    final center = tester.getCenter(cell);

    final touch = TestPointer(1, PointerDeviceKind.touch);
    await tester.sendEventToBinding(touch.down(center));
    // Hold for 120ms (standard tap)
    await tester.pump(const Duration(milliseconds: 120));
    await tester.sendEventToBinding(touch.up());
    await tester.pumpAndSettle();

    // Flag should NOT be placed
    expect(find.byIcon(Icons.flag_rounded), findsNothing);
    // Instead it was a tap (reveals tile)
    final widget = tester.widget(cell) as dynamic;
    expect(widget.cellState, isNot(equals(0)));
  });
}
