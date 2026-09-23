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

  group('Minesweeper Inventory & Item System', () {
    testWidgets('Starts game with Shield in slot 0 and Flag Obvious in slot 1 in bottom left corner', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final game = MinesweeperGame(
        initialRegionX: 2,
        initialRegionY: 2,
        isInfiniteWorld: false,
      );

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

      final dynamic state = tester.state(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MinesweeperGame'),
      );

      // Verify inventory has 2 items initially
      expect(state.inventory.length, equals(2));
      expect(state.inventory[0], equals(InventoryItemType.shield));
      expect(state.inventory[1], equals(InventoryItemType.flagObvious));
      expect(state.hasShield, isTrue);

      // Check slot buttons are present
      final slot0Finder = find.byKey(const ValueKey('bottom_bar_left_button'));
      final slot1Finder = find.byKey(const ValueKey('bottom_bar_right_button'));
      expect(slot0Finder, findsOneWidget);
      expect(slot1Finder, findsOneWidget);

      // Check icons
      expect(
        find.descendant(of: slot0Finder, matching: find.byIcon(Icons.shield_rounded)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: slot1Finder, matching: find.byIcon(Icons.flag_outlined)),
        findsOneWidget,
      );

      // Check layout: both buttons positioned in bottom-left corner
      final slot0Rect = tester.getRect(slot0Finder);
      final slot1Rect = tester.getRect(slot1Finder);

      expect(slot0Rect.left, equals(MinesweeperConfig.headerCornerPadding));
      expect(slot1Rect.left, equals(slot0Rect.right + 8.0));
      expect(slot0Rect.top, equals(slot1Rect.top));
    });

    testWidgets('Passive Shield: direct click on mine defuses it, flags cell, prevents game over, and breaks shield', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool failed = false;
      final game = MinesweeperGame(
        initialRegionX: 2,
        initialRegionY: 2,
        isInfiniteWorld: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => game.buildGame(
                context: context,
                onComplete: () {},
                onFail: () {
                  failed = true;
                },
                gameState: gameState,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dynamic state = tester.state(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MinesweeperGame'),
      );
      final Map<(int, int), dynamic> regions = state.regions;
      final region = regions[(2, 2)];
      state.ensureRegionGenerated(2, 2);
      state.minesPlaced = true;

      // Clear mines and cellStates for our custom test
      region.mines.fillRange(0, region.mines.length, 0);
      region.adjacent.fillRange(0, region.adjacent.length, 255);
      region.cellStates.fillRange(0, region.cellStates.length, CellState.unrevealed);

      final mineIdx = region.localIndex(3, 3);
      region.mines[mineIdx] = 1;

      expect(state.hasShield, isTrue);
      expect(state.inventory[0], equals(InventoryItemType.shield));

      // Click directly on the mine at (3, 3)
      state.reveal(2, 2, 3, 3);
      await tester.pumpAndSettle();

      // Shield should have defused the mine: game over prevented, cell flagged, shield broken
      expect(failed, isFalse);
      expect(region.cellStates[mineIdx], equals(CellState.flagged));
      expect(region.flagCount, equals(1));
      expect(state.hasShield, isFalse);
      expect(state.inventory[0], isNull);

      // Shield icon should no longer be in slot 0 (empty slot)
      final slot0Finder = find.byKey(const ValueKey('bottom_bar_left_button'));
      expect(
        find.descendant(of: slot0Finder, matching: find.byIcon(Icons.shield_rounded)),
        findsNothing,
      );

      // Subsequent click on another mine WITHOUT shield causes game over
      region.mines[region.localIndex(4, 4)] = 1;
      region.cellStates[region.localIndex(4, 4)] = CellState.unrevealed;

      state.reveal(2, 2, 4, 4);
      await tester.pumpAndSettle();

      expect(failed, isTrue);
      expect(region.cellStates[region.localIndex(4, 4)], equals(CellState.activatedMine));
    });

    testWidgets('Passive Shield: chording into 1 mine defuses it, reveals safe neighbors, and prevents game over', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool failed = false;
      final game = MinesweeperGame(
        initialRegionX: 2,
        initialRegionY: 2,
        isInfiniteWorld: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => game.buildGame(
                context: context,
                onComplete: () {},
                onFail: () {
                  failed = true;
                },
                gameState: gameState,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dynamic state = tester.state(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MinesweeperGame'),
      );
      final Map<(int, int), dynamic> regions = state.regions;
      final region = regions[(2, 2)];
      state.ensureRegionGenerated(2, 2);
      state.minesPlaced = true;

      // Clear mines in region and reset cell states around (2, 2)
      region.mines.fillRange(0, region.mines.length, 0);
      region.adjacent.fillRange(0, region.adjacent.length, 255);
      region.cellStates.fillRange(0, region.cellStates.length, CellState.unrevealed);

      // Place 1 mine at (1, 2) and 1 mine at (1, 3)
      region.mines[region.localIndex(1, 2)] = 1;
      region.mines[region.localIndex(1, 3)] = 1;

      // Cell (2, 2) sees 2 mines: (1, 2) and (1, 3)
      state.reveal(2, 2, 2, 2);
      await tester.pumpAndSettle();

      expect(region.adjacent[region.localIndex(2, 2)], equals(2));

      // Player correctly flags (1, 2), but incorrectly leaves (1, 3) unflagged,
      // and falsely flags (2, 1) which is safe!
      state.toggleFlag(2, 2, 1, 2);
      state.toggleFlag(2, 2, 2, 1);
      await tester.pumpAndSettle();

      // Now flaggedCount == 2 == adjCount.
      // Chording cell (2, 2) will reveal the unflagged neighbors: (1, 1), (1, 3)[MINE!], (2, 3), (3, 1), (3, 2), (3, 3)
      // Exactly 1 mine is in the unflagged neighbors: (1, 3)!
      state.handleCellTap(2, 2, 2, 2);
      await tester.pumpAndSettle();

      // With shield, that 1 mine is defused! Game does not fail
      expect(failed, isFalse);
      expect(region.cellStates[region.localIndex(1, 3)], equals(CellState.flagged));
      expect(state.hasShield, isFalse);
      expect(state.inventory[0], isNull);

      // And the safe unflagged neighbors were revealed
      expect(region.cellStates[region.localIndex(1, 1)], equals(CellState.revealed));
      expect(region.cellStates[region.localIndex(2, 3)], equals(CellState.revealed));
    });

    testWidgets('Passive Shield: chording into 2+ mines is NOT prevented; causes game over', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool failed = false;
      final game = MinesweeperGame(
        initialRegionX: 2,
        initialRegionY: 2,
        isInfiniteWorld: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => game.buildGame(
                context: context,
                onComplete: () {},
                onFail: () {
                  failed = true;
                },
                gameState: gameState,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dynamic state = tester.state(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MinesweeperGame'),
      );
      final Map<(int, int), dynamic> regions = state.regions;
      final region = regions[(2, 2)];
      state.ensureRegionGenerated(2, 2);
      state.minesPlaced = true;

      // Clear mines in region and reset cell states around (2, 2)
      region.mines.fillRange(0, region.mines.length, 0);
      region.adjacent.fillRange(0, region.adjacent.length, 255);
      region.cellStates.fillRange(0, region.cellStates.length, CellState.unrevealed);

      // Place 2 actual mines around (2, 2): (1, 2) and (1, 3)
      region.mines[region.localIndex(1, 2)] = 1;
      region.mines[region.localIndex(1, 3)] = 1;

      // Cell (2, 2) sees 2 mines
      state.reveal(2, 2, 2, 2);
      await tester.pumpAndSettle();

      // Player falsely flags two safe neighbors (2, 1) and (2, 3)
      state.toggleFlag(2, 2, 2, 1);
      state.toggleFlag(2, 2, 2, 3);
      await tester.pumpAndSettle();

      // Chording cell (2, 2) attempts to reveal all remaining unflagged neighbors,
      // which includes BOTH mines: (1, 2) and (1, 3) simultaneously!
      state.handleCellTap(2, 2, 2, 2);
      await tester.pumpAndSettle();

      // Shield is not enough to defend against 2+ mines revealed at once!
      expect(failed, isTrue);
      expect(region.cellStates[region.localIndex(1, 2)], equals(CellState.activatedMine));
      expect(region.cellStates[region.localIndex(1, 3)], equals(CellState.activatedMine));
    });

    testWidgets('Active Flag Obvious Mines: flags obvious mines on board and breaks upon use', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final game = MinesweeperGame(
        initialRegionX: 2,
        initialRegionY: 2,
        isInfiniteWorld: false,
      );

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

      final dynamic state = tester.state(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MinesweeperGame'),
      );
      final Map<(int, int), dynamic> regions = state.regions;
      final region = regions[(2, 2)];
      state.ensureRegionGenerated(2, 2);
      state.minesPlaced = true;

      // Set up a clear corner mine scenario at top-left:
      // (0, 0) is a mine
      // All other cells are revealed safe cells.
      region.mines.fillRange(0, region.mines.length, 0);
      region.adjacent.fillRange(0, region.adjacent.length, 255);
      region.mines[region.localIndex(0, 0)] = 1;

      // Mark all cells revealed except (0, 0)
      for (int i = 0; i < region.cellStates.length; i++) {
        region.cellStates[i] = CellState.revealed;
      }
      region.cellStates[region.localIndex(0, 0)] = CellState.unrevealed;

      expect(region.cellStates[region.localIndex(0, 0)], equals(CellState.unrevealed));
      expect(state.inventory[1], equals(InventoryItemType.flagObvious));

      // Tap the active item slot button
      await tester.tap(find.byKey(const ValueKey('bottom_bar_right_button')));
      await tester.pumpAndSettle();

      // Obvious mine at (0, 0) should now be flagged!
      expect(region.cellStates[region.localIndex(0, 0)], equals(CellState.flagged));
      expect(region.flagCount, equals(1));

      // Item should have broken and disappeared from slot 1
      expect(state.inventory[1], isNull);
      final slot1Finder = find.byKey(const ValueKey('bottom_bar_right_button'));
      expect(
        find.descendant(of: slot1Finder, matching: find.byIcon(Icons.flag_outlined)),
        findsNothing,
      );
    });
  });
}
