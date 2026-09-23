import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dominik/config/config.dart';
import 'package:dominik/constants/colors.dart';
import 'package:dominik/game_state.dart';
import 'package:dominik/games/minesweeper.dart';
import 'package:dominik/save_system.dart';
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

  testWidgets('On lose: screen does not return to menu, pause changes to home button, cell clicks blocked', (tester) async {
    bool onFailCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => MinesweeperGame(
              lockInaccessibleRegions: false,
              initialInventory: const [],
            ).buildGame(
              context: context,
              onComplete: () {},
              onFail: () {
                onFailCalled = true;
              },
              gameState: gameState,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initially: pause button is present
    expect(find.byKey(const ValueKey('region_pause_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('region_home_button')), findsNothing);

    final state = tester.state(
      find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MinesweeperGame'),
    ) as dynamic;

    // First click to place mines
    final centerCells = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_RegionCellWidget' && (w as dynamic).isNeighbor == false,
    );
    await tester.tap(centerCells.first);
    await tester.pumpAndSettle();

    // Find a mine cell in current region
    final currentRegion = state.regions[(2, 2)];
    int mineLocalIndex = -1;
    for (int i = 0; i < currentRegion.rows * currentRegion.cols; i++) {
      if (currentRegion.mines[i] == 1) {
        mineLocalIndex = i;
        break;
      }
    }
    expect(mineLocalIndex, isNot(-1));

    // Tap the mine
    final mineCellFinder = centerCells.at(mineLocalIndex);
    await tester.tap(mineCellFinder);
    await tester.pumpAndSettle();

    // onFail should have been invoked immediately
    expect(onFailCalled, isTrue);

    // Pause button changed to Home button!
    expect(find.byKey(const ValueKey('region_home_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('region_pause_button')), findsNothing);

    // Verify cell interactions are blocked after defeat (cells are non-interactable / IgnorePointer)
    final previousState = currentRegion.cellStates[0];
    await tester.tap(centerCells.at(0), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(currentRegion.cellStates[0], equals(previousState));

    // Long press (flagging) is also blocked
    await tester.longPress(centerCells.at(0), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(currentRegion.cellStates[0], equals(previousState));
  });

  testWidgets('On loss: correctly placed flags turn golden with black flag, unflagged mines turn red with black mine, incorrectly placed flags remain orange', (tester) async {
    bool onFailCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => MinesweeperGame(
              lockInaccessibleRegions: false,
              initialInventory: const [],
            ).buildGame(
              context: context,
              onComplete: () {},
              onFail: () {
                onFailCalled = true;
              },
              gameState: gameState,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(
      find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MinesweeperGame'),
    ) as dynamic;

    // First click to place mines safely
    final centerCells = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_RegionCellWidget' && (w as dynamic).isNeighbor == false,
    );
    await tester.tap(centerCells.first);
    await tester.pumpAndSettle();

    final currentRegion = state.regions[(2, 2)];
    // Find two distinct mine cells and one safe cell
    int mineIndex1 = -1;
    int mineIndex2 = -1;
    int safeIndex = -1;
    for (int i = 0; i < currentRegion.rows * currentRegion.cols; i++) {
      if (currentRegion.mines[i] == 1) {
        if (mineIndex1 == -1) {
          mineIndex1 = i;
        } else if (mineIndex2 == -1) {
          mineIndex2 = i;
        }
      } else if (currentRegion.cellStates[i] == CellState.unrevealed && safeIndex == -1) {
        safeIndex = i;
      }
    }
    expect(mineIndex1, isNot(-1));
    expect(mineIndex2, isNot(-1));
    expect(safeIndex, isNot(-1));

    // Place a flag on mineIndex1 (correctly placed flag)
    currentRegion.cellStates[mineIndex1] = CellState.flagged;
    currentRegion.flagCount++;

    // Place a flag on safeIndex (incorrectly placed flag)
    currentRegion.cellStates[safeIndex] = CellState.flagged;
    currentRegion.flagCount++;

    // Refresh UI with flags
    (tester.state(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MinesweeperGame')) as dynamic).setState(() {});
    await tester.pumpAndSettle();

    // Now tap mineIndex2 to trigger loss!
    await tester.tap(centerCells.at(mineIndex2));
    await tester.pumpAndSettle();

    expect(onFailCalled, isTrue);

    // Helper to get Container decoration color and Icon color of a cell
    Color getTileBgColor(int cellIndex) {
      final cellFinder = centerCells.at(cellIndex);
      final containerFinder = find.descendant(of: cellFinder, matching: find.byType(Container)).first;
      final decoration = tester.widget<Container>(containerFinder).decoration as BoxDecoration;
      return decoration.color!;
    }

    Color getTileIconColor(int cellIndex) {
      final cellFinder = centerCells.at(cellIndex);
      final iconFinder = find.descendant(of: cellFinder, matching: find.byType(Icon)).first;
      return tester.widget<Icon>(iconFinder).color!;
    }

    // 1. Correctly placed flag (mineIndex1) turns golden background with black flag icon
    expect(getTileBgColor(mineIndex1), equals(MinesweeperConfig.correctFlagLossBackgroundColor));
    expect(getTileIconColor(mineIndex1), equals(MinesweeperConfig.correctFlagLossIconColor));

    // 2. Clicked mine (mineIndex2) turns red background with black mine icon
    expect(getTileBgColor(mineIndex2), equals(Colors.red.shade900));
    expect(getTileIconColor(mineIndex2), equals(Colors.black));

    // 3. Incorrectly placed flag (safeIndex) does NOT turn golden/black (remains orange flag)
    expect(getTileBgColor(safeIndex), isNot(equals(MinesweeperConfig.correctFlagLossBackgroundColor)));
    expect(getTileIconColor(safeIndex), equals(Colors.orange.shade400));
  });

  testWidgets('Completed region (all mines flagged, all safe revealed) turns pale green on minimap only', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => MinesweeperGame(
              lockInaccessibleRegions: false,
            ).buildGame(
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

    final state = tester.state(
      find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MinesweeperGame'),
    ) as dynamic;

    // First click to place mines
    final centerCells = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_RegionCellWidget' && (w as dynamic).isNeighbor == false,
    );
    await tester.tap(centerCells.first);
    await tester.pumpAndSettle();

    final currentRegion = state.regions[(2, 2)];
    // Flag all mines and reveal all safe cells
    final total = currentRegion.rows * currentRegion.cols;
    for (int i = 0; i < total; i++) {
      if (currentRegion.mines[i] == 1) {
        currentRegion.cellStates[i] = CellState.flagged;
        currentRegion.flagCount++;
      } else {
        currentRegion.cellStates[i] = CellState.revealed;
        currentRegion.revealedCount++;
      }
    }

    // Trigger UI update
    (tester.state(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MinesweeperGame')) as dynamic).setState(() {});
    await tester.pumpAndSettle();

    // Verify the minimap sector is pale gold (MinesweeperConfig.minimapFinishedColor = AppColors.amberMedium)
    final sectorFinder = find.descendant(
      of: find.byKey(const ValueKey('minimap_sector_3_3')),
      matching: find.byType(Container),
    ).last;
    final decoration = tester.widget<Container>(sectorFinder).decoration as BoxDecoration;
    expect(decoration.color, equals(MinesweeperConfig.minimapFinishedColor));
    expect(MinesweeperConfig.minimapFinishedColor, equals(AppColors.amberMedium));
  });

  testWidgets('On loss: completed regions in the minimap remain completed (pale gold) and do NOT turn blue', (tester) async {
    bool onFailCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => MinesweeperGame(
              lockInaccessibleRegions: false,
              initialInventory: const [],
            ).buildGame(
              context: context,
              onComplete: () {},
              onFail: () {
                onFailCalled = true;
              },
              gameState: gameState,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(
      find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MinesweeperGame'),
    ) as dynamic;

    // First click in center region [2, 2] to initialize mines
    final centerCells = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_RegionCellWidget' && (w as dynamic).isNeighbor == false,
    );
    await tester.tap(centerCells.first);
    await tester.pumpAndSettle();

    final region22 = state.regions[(2, 2)];
    // Complete region (2, 2)
    final total = region22.rows * region22.cols;
    for (int i = 0; i < total; i++) {
      if (region22.mines[i] == 1) {
        region22.cellStates[i] = CellState.flagged;
        region22.flagCount++;
      } else {
        region22.cellStates[i] = CellState.revealed;
        region22.revealedCount++;
      }
    }
    region22.isCleared = true;

    // Trigger state update
    (tester.state(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MinesweeperGame')) as dynamic).setState(() {});
    await tester.pumpAndSettle();

    // Verify region (2, 2) [minimap sector 3, 3] is pale gold
    final sectorFinder = find.descendant(
      of: find.byKey(const ValueKey('minimap_sector_3_3')),
      matching: find.byType(Container),
    ).last;
    final decorationBeforeLoss = tester.widget<Container>(sectorFinder).decoration as BoxDecoration;
    expect(decorationBeforeLoss.color, equals(MinesweeperConfig.minimapFinishedColor));
    expect(decorationBeforeLoss.color, equals(AppColors.amberMedium));

    // Now cause defeat: navigate to region (2, 3) and hit a mine
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pumpAndSettle();

    final eastCells = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_RegionCellWidget' && (w as dynamic).isNeighbor == false,
    );
    // Tap first cell in region (2, 3) to place mines
    await tester.tap(eastCells.first);
    await tester.pumpAndSettle();

    final region23 = state.regions[(2, 3)];
    int mineLocalIndex = -1;
    for (int i = 0; i < region23.rows * region23.cols; i++) {
      if (region23.mines[i] == 1) {
        mineLocalIndex = i;
        break;
      }
    }
    expect(mineLocalIndex, isNot(-1));

    // Tap the mine in region (2, 3) to cause defeat
    await tester.tap(eastCells.at(mineLocalIndex), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(onFailCalled, isTrue);

    // Verify that on loss, region (2, 2) [minimap sector 3, 3] REMAINS pale gold, NOT blue
    final decorationAfterLoss = tester.widget<Container>(sectorFinder).decoration as BoxDecoration;
    expect(decorationAfterLoss.color, equals(MinesweeperConfig.minimapFinishedColor));
    expect(decorationAfterLoss.color, equals(AppColors.amberMedium));
    expect(decorationAfterLoss.color, isNot(equals(MinesweeperConfig.minimapStartedColor)));
  });

  testWidgets('Interaction allowed anywhere on adjacent regions (not blocked for 2nd row/column)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => MinesweeperGame(
              lockInaccessibleRegions: false,
            ).buildGame(
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

    // Check cells in North neighbor panel (dr = -1, dc = 0)
    final northPanel = find.byKey(const ValueKey('region_panel_-1_0'));
    expect(northPanel, findsOneWidget);

    final northCells = find.descendant(
      of: northPanel,
      matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_RegionCellWidget'),
    );

    // Region is 7x7 (indices 0..48).
    // Nearest row of North region to center is row 6 (indices 42..48).
    // Second row is row 5 (indices 35..41).
    // All rows are now interactable anywhere on the game area!
    for (int i = 42; i <= 48; i++) {
      final cell = tester.widget(northCells.at(i)) as dynamic;
      expect(cell.isInteractable, isTrue, reason: 'Nearest row cell index $i should be interactable');
      expect(cell.onTap, isNotNull);
      expect(cell.onLongPress, isNotNull);
    }

    for (int i = 35; i <= 41; i++) {
      final cell = tester.widget(northCells.at(i)) as dynamic;
      expect(cell.isInteractable, isTrue, reason: 'Second row cell index $i should also be interactable');
      expect(cell.onTap, isNotNull);
      expect(cell.onLongPress, isNotNull);
    }
  });

  testWidgets('RunScreen does not exit on lose; tapping home button returns to main menu', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Text('Main Menu Placeholder'),
        ),
        routes: {
          '/run': (context) => RunScreen(gameState: gameState),
        },
      ),
    );
    await tester.pumpAndSettle();

    // Navigate to /run
    final context = tester.element(find.text('Main Menu Placeholder'));
    Navigator.of(context).pushNamed('/run');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(RunScreen), findsOneWidget);

    // First click to place mines
    final centerCells = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_RegionCellWidget' && (w as dynamic).isNeighbor == false,
    );
    await tester.tap(centerCells.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final state = tester.state(
      find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MinesweeperGame'),
    ) as dynamic;
    final currentRegion = state.regions[(2, 2)];
    int mineLocalIndex = -1;
    int secondMineIndex = -1;
    for (int i = 0; i < currentRegion.rows * currentRegion.cols; i++) {
      if (currentRegion.mines[i] == 1) {
        if (mineLocalIndex == -1) {
          mineLocalIndex = i;
        } else if (secondMineIndex == -1) {
          secondMineIndex = i;
          break;
        }
      }
    }
    expect(mineLocalIndex, isNot(-1));
    expect(secondMineIndex, isNot(-1));

    // Tap first mine (defused by starting shield item, breaks shield)
    await tester.tap(centerCells.at(mineLocalIndex));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap second mine without shield (triggers defeat)
    await tester.tap(centerCells.at(secondMineIndex));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // RunScreen is STILL mounted and visible!
    expect(find.byType(RunScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('region_home_button')), findsOneWidget);

    // Now tap the Home button!
    await tester.tap(find.byKey(const ValueKey('region_home_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // We have navigated back to the Main Menu!
    expect(find.byType(RunScreen), findsNothing);
    expect(find.text('Main Menu Placeholder'), findsOneWidget);
  });
}
