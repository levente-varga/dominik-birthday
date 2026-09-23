import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dominik/config/config.dart';
import 'package:dominik/game_state.dart';
import 'package:dominik/save_system.dart';
import 'package:dominik/constants/colors.dart';
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

  Finder activeSector(int x, int y) =>
      find.byKey(ValueKey('active_minimap_sector_${x}_$y'));

  testWidgets('Minesweeper starts at middle region (2,2) displayed in minimap as Sector [3, 3]', (tester) async {
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

    // Verify initial region in minimap is Sector [3, 3]
    expect(activeSector(3, 3), findsOneWidget);

    // Verify active minimap cell is white and has no border
    final activeSectorWidget =
        tester.widget<AnimatedContainer>(find.byKey(const ValueKey('active_minimap_sector')));
    final sectorDecoration = activeSectorWidget.decoration as BoxDecoration;
    expect(sectorDecoration.color, equals(Colors.white));
    expect(sectorDecoration.border, isNull);

    // Verify minimap container has border matching mine counter badge border
    final minimapContainer = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const ValueKey('minimap_selector')),
        matching: find.byType(Container),
      ).first,
    );
    final minimapDecoration = minimapContainer.decoration as BoxDecoration;
    final mineCounterContainer = tester.widget<Container>(
      find.byKey(const ValueKey('region_mine_counter_badge')),
    );
    final mineCounterDecoration =
        mineCounterContainer.decoration as BoxDecoration;
    expect(minimapDecoration.border, equals(mineCounterDecoration.border));
    expect(
      minimapDecoration.borderRadius,
      equals(mineCounterDecoration.borderRadius),
    );

    // Verify 5x5 minimap sector cells exist (from [1,1] to [5,5])
    expect(find.byKey(const ValueKey('minimap_sector_1_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('minimap_sector_5_5')), findsOneWidget);

    // Verify sector mine counter badge is present in top left
    expect(find.byKey(const ValueKey('region_mine_counter_badge')), findsOneWidget);
    final sectorMines = (MinesweeperConfig.regionRows *
            MinesweeperConfig.regionCols *
            MinesweeperConfig.mineDensity)
        .round();
    expect(find.text('$sectorMines'), findsOneWidget);
  });

  testWidgets('Directional swipes navigate between regions in 5x5 world with threshold', (tester) async {
    final game = MinesweeperGame(lockInaccessibleRegions: false, swipeThreshold: 64.0);

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

    final centerCell = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    ).at(MinesweeperConfig.regionRows * MinesweeperConfig.regionCols ~/ 2);

    // Initial state: Sector [3, 3]
    expect(activeSector(3, 3), findsOneWidget);

    // Swipe under threshold (< 64pt, e.g. -40pt) does NOT navigate
    await tester.drag(centerCell, const Offset(-40, 0));
    await tester.pumpAndSettle();
    expect(activeSector(3, 3), findsOneWidget);

    // Swipe Up (dy = -80pt, > 64pt) -> moves South -> Sector [3, 4]
    await tester.drag(centerCell, const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(activeSector(3, 4), findsOneWidget);

    // Swipe Down (dy = 80pt, > 64pt) -> moves North -> Sector [3, 3]
    await tester.drag(centerCell, const Offset(0, 80));
    await tester.pumpAndSettle();
    expect(activeSector(3, 3), findsOneWidget);

    // Swipe Left (dx = -80pt, > 64pt) -> moves East -> Sector [4, 3]
    await tester.drag(centerCell, const Offset(-80, 0));
    await tester.pumpAndSettle();
    expect(activeSector(4, 3), findsOneWidget);

    // Swipe Right (dx = 80pt, > 64pt) -> moves West -> Sector [3, 3]
    await tester.drag(centerCell, const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(activeSector(3, 3), findsOneWidget);
  });

  testWidgets('Clicking on minimap expands it to center with unified padding and closes on tap anywhere', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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

    final scaffoldSize = tester.getSize(find.byType(Scaffold));

    // Find the minimap selector in top header
    final minimapFinder = find.byKey(const ValueKey('minimap_selector'));
    expect(minimapFinder, findsOneWidget);

    final initialRect = tester.getRect(minimapFinder);
    expect(initialRect.bottom, equals(scaffoldSize.height - MinesweeperConfig.headerControlTop));

    // Verify AnimatedPositioned curve uses Curves.easeOutCirc
    final animatedPositioned = tester.widget<AnimatedPositioned>(
      find.ancestor(
        of: minimapFinder,
        matching: find.byType(AnimatedPositioned),
      ),
    );
    expect(animatedPositioned.curve, equals(Curves.easeOutCirc));
    expect(MinesweeperConfig.minimapExpandCurve, equals(Curves.easeOutCirc));

    // Tap on the minimap
    await tester.tap(minimapFinder);
    await tester.pumpAndSettle();

    // Verify popup dialog is NOT shown
    expect(find.byKey(const ValueKey('minimap_popup_container')), findsNothing);

    // Verify minimap expanded: retains square shape and is centered
    final expandedRect = tester.getRect(minimapFinder);
    expect(expandedRect.width, equals(expandedRect.height));
    final expectedSize = scaffoldSize.width < scaffoldSize.height
        ? (scaffoldSize.width - (2 * MinesweeperConfig.minimapExpandedPadding))
        : (scaffoldSize.height - (2 * MinesweeperConfig.minimapExpandedPadding));
    expect(expandedRect.width, closeTo(expectedSize, 1.0));
    expect(
      expandedRect.top,
      closeTo((scaffoldSize.height - expandedRect.height) / 2.0, 1.0),
    );

    // Verify active minimap sector is centered inside expanded minimap
    final overlayFinder = find.byKey(const ValueKey('active_minimap_sector'));
    expect(overlayFinder, findsOneWidget);
    final overlayRect = tester.getRect(overlayFinder);
    expect(overlayRect.center.dx, closeTo(expandedRect.center.dx, 1.0));
    expect(overlayRect.center.dy, closeTo(expandedRect.center.dy, 1.0));

    // Verify corner radius increased proportionally with expanded/collapsed size ratio
    final expandedContainer = tester.widget<Container>(
      find.descendant(
        of: minimapFinder,
        matching: find.byType(Container),
      ).first,
    );
    final expandedDecoration = expandedContainer.decoration as BoxDecoration;
    final expectedSizeRatio = expandedRect.width / initialRect.width;
    final expectedRadius = MinesweeperConfig.minimapRadius * expectedSizeRatio;
    final expectedInnerRadius = MinesweeperConfig.minimapInnerRadius * expectedSizeRatio;
    expect(
      (expandedDecoration.borderRadius as BorderRadius).topLeft.x,
      closeTo(expectedRadius, 0.01),
    );

    final expandedClip = tester.widget<ClipRRect>(
      find.descendant(
        of: minimapFinder,
        matching: find.byType(ClipRRect),
      ).first,
    );
    expect(
      (expandedClip.borderRadius as BorderRadius).topLeft.x,
      closeTo(expectedInnerRadius, 0.01),
    );

    // Tap anywhere on the expanded minimap to dismiss
    await tester.tap(minimapFinder);
    await tester.pumpAndSettle();

    // Verify minimap returns to resting bottom position and corner radius returns to base
    final dismissedRect = tester.getRect(minimapFinder);
    expect(dismissedRect.bottom, equals(scaffoldSize.height - MinesweeperConfig.headerControlTop));
    expect(dismissedRect.height, equals(initialRect.height));

    final collapsedContainer = tester.widget<Container>(
      find.descendant(
        of: minimapFinder,
        matching: find.byType(Container),
      ).first,
    );
    final collapsedDecoration = collapsedContainer.decoration as BoxDecoration;
    expect(
      (collapsedDecoration.borderRadius as BorderRadius).topLeft.x,
      closeTo(MinesweeperConfig.minimapRadius, 0.01),
    );

    final collapsedClip = tester.widget<ClipRRect>(
      find.descendant(
        of: minimapFinder,
        matching: find.byType(ClipRRect),
      ).first,
    );
    expect(
      (collapsedClip.borderRadius as BorderRadius).topLeft.x,
      closeTo(MinesweeperConfig.minimapInnerRadius, 0.01),
    );

    // Re-expand and test dismiss by tapping outside the minimap on the barrier
    await tester.tap(minimapFinder);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(minimapFinder).top,
      closeTo((scaffoldSize.height - expandedRect.height) / 2.0, 1.0),
    );

    final barrierFinder = find.byKey(const ValueKey('minimap_barrier'));
    expect(barrierFinder, findsOneWidget);
    await tester.tapAt(tester.getTopLeft(barrierFinder) + const Offset(10.0, 10.0));
    await tester.pumpAndSettle();

    expect(tester.getRect(minimapFinder).bottom, equals(scaffoldSize.height - MinesweeperConfig.headerControlTop));
  });

  testWidgets('Extended minimap drag snaps selection with ease-out, clamps bounds, and tapping inside/outside collapses and navigates', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final game = MinesweeperGame(lockInaccessibleRegions: false);

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

    final minimapFinder = find.byKey(const ValueKey('minimap_selector'));
    expect(minimapFinder, findsOneWidget);

    // Initial state: starts at (2, 2) -> sector [3, 3]
    expect(find.byKey(const ValueKey('active_minimap_sector_3_3')), findsOneWidget);

    // 1. Tap to expand minimap
    await tester.tap(minimapFinder);
    await tester.pumpAndSettle();

    // Verify config settings
    expect(MinesweeperConfig.minimapJumpCurve, equals(Curves.easeOut));
    expect(MinesweeperConfig.minimapJumpDuration, equals(const Duration(milliseconds: 180)));

    // While extended, sector [3, 3] is initially selected
    expect(find.byKey(const ValueKey('active_minimap_sector_3_3')), findsOneWidget);

    Future<void> panMinimap(Offset delta) async {
      final gesture = await tester.startGesture(tester.getCenter(minimapFinder));
      final slopOffset = Offset(
        delta.dx != 0 ? (delta.dx > 0 ? 19.0 : -19.0) : 0,
        delta.dy != 0 ? (delta.dy > 0 ? 19.0 : -19.0) : 0,
      );
      await gesture.moveBy(slopOffset);
      await gesture.moveBy(delta);
      await gesture.up();
      await tester.pumpAndSettle();
    }

    // 2. Drag minimap to the left: moving map left pulls column 3 (1-indexed 4) to center
    await panMinimap(const Offset(-15.0, 0));

    // Verify selected region jumped to [4, 3] (col 3, row 2)
    expect(find.byKey(const ValueKey('active_minimap_sector_4_3')), findsOneWidget);

    // 3. Test boundary clamping: drag extremely far left (beyond maxCol = 4, 1-indexed 5)
    await panMinimap(const Offset(-500.0, 0));

    // Should clamp to sector [5, 3] (col 4, row 2) and NOT go out of bounds to [6, 3]
    expect(find.byKey(const ValueKey('active_minimap_sector_5_3')), findsOneWidget);
    expect(find.byKey(const ValueKey('active_minimap_sector_6_3')), findsNothing);

    // Drag extremely far right (beyond minCol = 0, 1-indexed 1)
    await panMinimap(const Offset(1000.0, 0));

    // Should clamp to sector [1, 3] (col 0, row 2) and NOT go out of bounds to [0, 3]
    expect(find.byKey(const ValueKey('active_minimap_sector_1_3')), findsOneWidget);
    expect(find.byKey(const ValueKey('active_minimap_sector_0_3')), findsNothing);

    // Drag extremely far up (beyond maxRow = 4, 1-indexed 5)
    await panMinimap(const Offset(0, -500.0));

    // Should clamp to sector [1, 5] (col 0, row 4)
    expect(find.byKey(const ValueKey('active_minimap_sector_1_5')), findsOneWidget);

    // Drag extremely far down (beyond minRow = 0, 1-indexed 1)
    await panMinimap(const Offset(0, 1000.0));

    // Should clamp to sector [1, 1] (col 0, row 0)
    expect(find.byKey(const ValueKey('active_minimap_sector_1_1')), findsOneWidget);

    // 4. Drag back to sector [4, 3] (from col 0, row 0 to col 3, row 2: deltaX = -45, deltaY = -30)
    await panMinimap(const Offset(-45.0, -30.0));
    expect(find.byKey(const ValueKey('active_minimap_sector_4_3')), findsOneWidget);

    // 5. Tap inside the minimap to collapse and navigate to selected region [4, 3]
    await tester.tap(minimapFinder);
    await tester.pumpAndSettle();

    // Verify minimap collapsed back to bottom bar
    expect(tester.getRect(minimapFinder).bottom, equals(800.0 - MinesweeperConfig.headerControlTop));

    // Verify current region is now [4, 3] (col 3, row 2)
    expect(find.byKey(const ValueKey('active_minimap_sector_4_3')), findsOneWidget);

    // 6. Test tapping outside the minimap on the barrier to collapse and navigate:
    // Expand again
    await tester.tap(minimapFinder);
    await tester.pumpAndSettle();

    // Drag to sector [2, 3] (from col 3, row 2 to col 1, row 2: deltaX = +30)
    await panMinimap(const Offset(30.0, 0));
    expect(find.byKey(const ValueKey('active_minimap_sector_2_3')), findsOneWidget);

    // Tap outside on the barrier (top-left corner of screen, safely outside centered minimap)
    final barrierFinder = find.byKey(const ValueKey('minimap_barrier'));
    expect(barrierFinder, findsOneWidget);
    await tester.tapAt(tester.getTopLeft(barrierFinder) + const Offset(10.0, 10.0));
    await tester.pumpAndSettle();

    // Verify minimap collapsed back to bottom bar
    expect(tester.getRect(minimapFinder).bottom, equals(800.0 - MinesweeperConfig.headerControlTop));

    // Verify current region is now [2, 3] (col 1, row 2)
    expect(find.byKey(const ValueKey('active_minimap_sector_2_3')), findsOneWidget);
  });

  testWidgets('Keyboard arrow keys and WASD navigate regions', (tester) async {
    final game = MinesweeperGame(lockInaccessibleRegions: false);

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

    expect(activeSector(3, 3), findsOneWidget);

    // Press Key W -> North -> Sector [3, 2]
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.pumpAndSettle();
    expect(activeSector(3, 2), findsOneWidget);

    // Press Key D -> East -> Sector [4, 2]
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pumpAndSettle();
    expect(activeSector(4, 2), findsOneWidget);

    // Press Key S -> South -> Sector [4, 3]
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pumpAndSettle();
    expect(activeSector(4, 3), findsOneWidget);

    // Press Key A -> West -> Sector [3, 3]
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pumpAndSettle();
    expect(activeSector(3, 3), findsOneWidget);
  });

  testWidgets('Reveals and flags persist across region navigation', (tester) async {
    final game = MinesweeperGame(lockInaccessibleRegions: false);

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

    // Flag first cell in center region Sector [3, 3] using long press
    final firstActiveCell = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    ).first;

    await tester.longPress(firstActiveCell);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.flag_rounded), findsOneWidget);

    // Navigate to another region (Sector [4, 4]) via S and D keys
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pumpAndSettle();
    expect(activeSector(4, 4), findsOneWidget);

    // In Sector [4, 4], the active center panel has no flag
    final activeFlags = find.descendant(
      of: find.byWidgetPredicate(
        (widget) =>
            widget.runtimeType.toString() == '_RegionCellWidget' &&
            (widget as dynamic).isNeighbor == false,
      ),
      matching: find.byIcon(Icons.flag_rounded),
    );
    expect(activeFlags, findsNothing);

    // Return to Sector [3, 3] via W and A keys
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pumpAndSettle();
    expect(activeSector(3, 3), findsOneWidget);

    // Flag is preserved!
    expect(find.byIcon(Icons.flag_rounded), findsOneWidget);
  });

  testWidgets('Adjacent rows of neighboring regions are rendered and D-Pad below board is removed', (tester) async {
    final game = MinesweeperGame(lockInaccessibleRegions: false);

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

    // At middle sector [2, 2], all 8 surrounding neighbor panels are fully rendered (8 * 7x7 cells)
    final expectedNeighborCount =
        8 * (MinesweeperConfig.regionRows * MinesweeperConfig.regionCols);
    final neighborCellsFinder = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == true,
    );
    expect(neighborCellsFinder, findsNWidgets(expectedNeighborCount));

    // Verify D-Pad buttons are completely removed from below the board
    expect(find.byTooltip('Move North (Up / W)'), findsNothing);
    expect(find.byTooltip('Move South (Down / S)'), findsNothing);
    expect(find.byTooltip('Move West (Left / A)'), findsNothing);
    expect(find.byTooltip('Move East (Right / D)'), findsNothing);
  });

  testWidgets('Auto exploration stops strictly at region edges', (tester) async {
    final game = MinesweeperGame(lockInaccessibleRegions: false);

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

    // Locate the cells in the active region (7x7 = 49 cells)
    final expectedMainCellsCount =
        MinesweeperConfig.regionRows * MinesweeperConfig.regionCols;
    final mainPanelCells = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    );
    expect(mainPanelCells, findsNWidgets(expectedMainCellsCount));

    // Tap first cell to trigger placement safe zone and auto-exploration flood fill
    await tester.tap(mainPanelCells.first);
    await tester.pumpAndSettle();

    // External neighbor cells from adjacent regions must remain completely unrevealed (state 0)
    final neighborCells = tester.widgetList(find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == true,
    ));

    for (final neighbor in neighborCells) {
      final state = (neighbor as dynamic).cellState;
      expect(state, equals(0));
    }

    // Move to adjacent Sector [2, 2] via W and A keys and verify all cells in that region are unrevealed
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pumpAndSettle();

    final sector22Cells = tester.widgetList(find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    ));
    for (final cell in sector22Cells) {
      final state = (cell as dynamic).cellState;
      expect(state, equals(0));
    }
  });

  testWidgets('All cells across accessible adjacent regions are interactable (non-interactive restriction removed)', (tester) async {
    final game = MinesweeperGame(lockInaccessibleRegions: false);

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

    final expectedNeighborCount =
        8 * (MinesweeperConfig.regionRows * MinesweeperConfig.regionCols);
    final neighborWidgets = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == true,
    );
    expect(neighborWidgets, findsNWidgets(expectedNeighborCount));

    int interactableCount = 0;
    int nonInteractableCount = 0;
    for (final neighbor in tester.widgetList(neighborWidgets)) {
      if ((neighbor as dynamic).isInteractable == true) {
        interactableCount++;
        expect((neighbor as dynamic).onTap, isNotNull);
        expect((neighbor as dynamic).onLongPress, isNotNull);
      } else {
        nonInteractableCount++;
        expect((neighbor as dynamic).onTap, isNull);
        expect((neighbor as dynamic).onLongPress, isNull);
      }
    }
    expect(interactableCount, equals(expectedNeighborCount));
    expect(nonInteractableCount, equals(0));
  });

  testWidgets('Normal reveals and auto exploration do not reveal or affect cells in other regions', (tester) async {
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

    // Reveal cells in current region
    final mainPanelCells = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    );
    await tester.tap(
      mainPanelCells.at(
        MinesweeperConfig.regionRows * MinesweeperConfig.regionCols ~/ 2,
      ),
    );
    // Ensure cell 0 is safe before tapping border cell
    final dynamic state = tester.state(
      find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MinesweeperGame'),
    );
    final currentRegion = state.regions[(2, 2)];
    if (currentRegion != null && currentRegion.mines[0] == 1) {
      currentRegion.mines[0] = 0;
    }

    // Tap border cell
    await tester.tap(mainPanelCells.first);
    await tester.pumpAndSettle();

    // All external neighbor cells must remain unrevealed
    final neighborCells = tester.widgetList(find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == true,
    ));

    for (final neighbor in neighborCells) {
      final state = (neighbor as dynamic).cellState;
      expect(state, equals(0));
    }
  });

  testWidgets('Game area gradient overlays are completely removed and all panels render without overlay', (tester) async {
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

    // Gradient overlays are completely removed
    expect(find.byKey(const ValueKey('game_area_gradient_overlay')), findsNothing);
    expect(find.byKey(const ValueKey('panel_gradient_overlay')), findsNothing);

    // Center panel remains fully interactable and unaffected
    final centerCell = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    ).at(MinesweeperConfig.regionRows * MinesweeperConfig.regionCols ~/ 2);

    await tester.tap(centerCell);
    await tester.pumpAndSettle();
  });

  testWidgets('Highlight tapped unrevealed cells with modest lightgrey outline during hold, with fade in/out animation', (tester) async {
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

    final unrevealedCells = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    );
    final targetCell = unrevealedCells.first;

    // Initially, cell touch highlight has opacity 0.0
    final initialHighlight = find.descendant(
      of: targetCell,
      matching: find.byKey(const ValueKey('cell_touch_highlight')),
    );
    expect(initialHighlight, findsOneWidget);
    expect(tester.widget<AnimatedOpacity>(initialHighlight).opacity, equals(0.0));

    // Place finger down on target cell
    final gesture = await tester.startGesture(tester.getCenter(targetCell));
    await tester.pump();

    // While finger is held down, highlight opacity is targeted to 1.0
    final activeHighlight = find.descendant(
      of: targetCell,
      matching: find.byKey(const ValueKey('cell_touch_highlight')),
    );
    expect(tester.widget<AnimatedOpacity>(activeHighlight).opacity, equals(1.0));

    // Verify styling matches config: lighter grey fill color without outline/border
    final highlightContainer = tester.widget<Container>(
      find.descendant(
        of: activeHighlight,
        matching: find.byType(Container),
      ),
    );
    final boxDecoration = highlightContainer.decoration as BoxDecoration;
    expect(boxDecoration.color, equals(MinesweeperConfig.touchHighlightColor));
    expect(boxDecoration.border, isNull);

    // Pump halfway through fade duration (e.g. 75ms)
    await tester.pump(const Duration(milliseconds: 75));
    // Pump to complete fade in (150ms total)
    await tester.pump(const Duration(milliseconds: 75));

    // Release finger (< 250ms, so it triggers a tap/reveal)
    await gesture.up();
    await tester.pump();

    // Fade out initiated
    final releasingHighlight = find.descendant(
      of: targetCell,
      matching: find.byKey(const ValueKey('cell_touch_highlight')),
    );
    expect(tester.widget<AnimatedOpacity>(releasingHighlight).opacity, equals(0.0));

    // Settle fade out animation
    await tester.pumpAndSettle();
    final settledHighlight = find.descendant(
      of: targetCell,
      matching: find.byKey(const ValueKey('cell_touch_highlight')),
    );
    expect(tester.widget<AnimatedOpacity>(settledHighlight).opacity, equals(0.0));

    // Find a remaining unrevealed cell after the first tap's safe clearing
    final remainingUnrevealed = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false &&
          (widget as dynamic).cellState == 0,
    );
    final flagCenter = tester.getCenter(remainingUnrevealed.first);
    final flagGesture = await tester.startGesture(flagCenter);
    await tester.pump(const Duration(milliseconds: 300));
    await flagGesture.up();
    await tester.pumpAndSettle();

    // Verify cell is now flagged
    expect(find.byIcon(Icons.flag_rounded), findsOneWidget);

    final flaggedCellFinder = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false &&
          (widget as dynamic).cellState == 2,
    );

    // Place finger down on the flagged cell
    final flaggedGesture = await tester.startGesture(flagCenter);
    await tester.pump();

    // Verify highlight is active on flagged cell too
    final flaggedHighlight = find.descendant(
      of: flaggedCellFinder,
      matching: find.byKey(const ValueKey('cell_touch_highlight')),
    );
    expect(tester.widget<AnimatedOpacity>(flaggedHighlight).opacity, equals(1.0));

    await flaggedGesture.up();
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(flaggedHighlight).opacity, equals(0.0));
  });

  testWidgets('Moving finger beyond slop threshold dismisses cell highlight', (tester) async {
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

    final unrevealedCells = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    );
    final targetCell = unrevealedCells.first;

    final gesture = await tester.startGesture(tester.getCenter(targetCell));
    await tester.pump();

    final activeHighlight = find.descendant(
      of: targetCell,
      matching: find.byKey(const ValueKey('cell_touch_highlight')),
    );
    expect(tester.widget<AnimatedOpacity>(activeHighlight).opacity, equals(1.0));

    // Move finger by > 12pt (drag away)
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();

    // Target opacity drops to 0.0
    final movedHighlight = find.descendant(
      of: targetCell,
      matching: find.byKey(const ValueKey('cell_touch_highlight')),
    );
    expect(tester.widget<AnimatedOpacity>(movedHighlight).opacity, equals(0.0));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'Entire neighbor panels are rendered as actual panels without gradient overlays',
      (tester) async {
    final game = MinesweeperGame(lockInaccessibleRegions: false);

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

    // In idle state at middle region (2,2):
    // All 9 panels render their actual_panel_container (1 center + 8 neighbors)
    expect(find.byKey(const ValueKey('actual_panel_container')), findsNWidgets(9));

    // Adjacent panel outline is completely removed
    expect(find.byKey(const ValueKey('adjacent_panel_outline')), findsNothing);

    // Per-panel and game area gradient overlays are completely removed
    expect(find.byKey(const ValueKey('panel_gradient_overlay')), findsNothing);
    expect(find.byKey(const ValueKey('game_area_gradient_overlay')), findsNothing);

    // Begin a drag to the left (bring in the East adjacent panel)
    final gesture = await tester.startGesture(const Offset(200, 200));
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();

    // The moment dragging starts, neighbors of the potential new region are loaded (9 + 3 = 12 panels)
    expect(find.byKey(const ValueKey('actual_panel_container')), findsNWidgets(12));

    // Complete the swipe and settle
    await gesture.moveBy(const Offset(-40, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    // In the newly active region: 9 actual containers, no gradient overlay
    expect(find.byKey(const ValueKey('actual_panel_container')), findsNWidgets(9));
    expect(find.byKey(const ValueKey('game_area_gradient_overlay')), findsNothing);
  });

  testWidgets(
      'The MOMENT the player starts dragging, load the neighbors of the potential new selected region, and unload them if the player cancels',
      (tester) async {
    final game = MinesweeperGame(lockInaccessibleRegions: false);

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

    // In idle state at middle region (2,2):
    // Exactly 9 panels rendered (the 3x3 of Sector [3, 3])
    expect(find.byKey(const ValueKey('actual_panel_container')), findsNWidgets(9));
    expect(find.byKey(const ValueKey('region_panel_0_2')), findsNothing);
    expect(find.byKey(const ValueKey('region_panel_-1_2')), findsNothing);
    expect(find.byKey(const ValueKey('region_panel_1_2')), findsNothing);

    // The MOMENT the player starts dragging left (e.g. 20pt towards East):
    final gesture = await tester.startGesture(const Offset(250, 250));
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();

    // Potential new selected region (2, 3) has its neighbors loaded immediately!
    // Original 9 panels + 3 new neighbors of East = 12 panels
    expect(find.byKey(const ValueKey('actual_panel_container')), findsNWidgets(12));
    expect(find.byKey(const ValueKey('region_panel_0_2')), findsOneWidget);
    expect(find.byKey(const ValueKey('region_panel_-1_2')), findsOneWidget);
    expect(find.byKey(const ValueKey('region_panel_1_2')), findsOneWidget);

    // If player drags back to center while finger is still held down:
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();

    // The extra neighbors are unloaded! Only the 9 neighbors of the selected region remain shown
    expect(find.byKey(const ValueKey('actual_panel_container')), findsNWidgets(9));
    expect(find.byKey(const ValueKey('region_panel_0_2')), findsNothing);

    // Drag again to -20pt (re-load potential new region neighbors)
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    expect(find.byKey(const ValueKey('actual_panel_container')), findsNWidgets(12));
    expect(find.byKey(const ValueKey('region_panel_0_2')), findsOneWidget);

    // If the player cancels (releases gesture under threshold < 64pt):
    await gesture.up();
    await tester.pump();

    // Snapback immediately unloads the extra neighbors!
    expect(find.byKey(const ValueKey('actual_panel_container')), findsNWidgets(9));
    expect(find.byKey(const ValueKey('region_panel_0_2')), findsNothing);

    await tester.pumpAndSettle();
    expect(activeSector(3, 3), findsOneWidget);
  });

  testWidgets(
      'Visible regions remain fully opaque (1.0 opacity) without fading during idle and swipe traversal',
      (tester) async {
    final game = MinesweeperGame(lockInaccessibleRegions: false, swipeThreshold: 64.0);

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

    // In idle state at middle region (2,2):
    // 1. Current selected region has opacity 1.0
    final currentPanelOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('region_panel_0_0')),
        matching: find.byType(Opacity),
      ).first,
    );
    expect(currentPanelOpacity.opacity, equals(1.0));

    // 2. Neighbor regions are fully opaque 1.0 (no dimming/fading)
    final eastNeighborOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('region_panel_0_1')),
        matching: find.byType(Opacity),
      ).first,
    );
    expect(eastNeighborOpacity.opacity, equals(1.0));

    final northNeighborOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('region_panel_-1_0')),
        matching: find.byType(Opacity),
      ).first,
    );
    expect(northNeighborOpacity.opacity, equals(1.0));

    // 3. While dragging below threshold (-30px, where swipeThreshold is 64.0):
    final gesture = await tester.startGesture(const Offset(250, 250));
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();

    // Both remain 1.0 opacity
    final underThresholdCurrentOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('region_panel_0_0')),
        matching: find.byType(Opacity),
      ).first,
    );
    final underThresholdIncomingOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('region_panel_0_1')),
        matching: find.byType(Opacity),
      ).first,
    );
    expect(underThresholdCurrentOpacity.opacity, equals(1.0));
    expect(underThresholdIncomingOpacity.opacity, equals(1.0));
    expect(activeSector(3, 3), findsOneWidget);

    // 4. Drag reaches and goes over threshold (move -40px further to -70px total):
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // Minimap selected region flipped to Sector [4, 3]!
    expect(activeSector(4, 3), findsOneWidget);

    // Regions remain 1.0 opacity
    final flippedCurrentOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('region_panel_0_0')),
        matching: find.byType(Opacity),
      ).first,
    );
    final flippedIncomingOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('region_panel_0_1')),
        matching: find.byType(Opacity),
      ).first,
    );
    expect(flippedCurrentOpacity.opacity, equals(1.0));
    expect(flippedIncomingOpacity.opacity, equals(1.0));

    // 5. Cancel traversal by dragging back below threshold (drag +50px, delta is now -20px):
    await gesture.moveBy(const Offset(50, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final reversedCurrentOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('region_panel_0_0')),
        matching: find.byType(Opacity),
      ).first,
    );
    final reversedIncomingOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('region_panel_0_1')),
        matching: find.byType(Opacity),
      ).first,
    );
    expect(reversedCurrentOpacity.opacity, equals(1.0));
    expect(reversedIncomingOpacity.opacity, equals(1.0));
    // Minimap selected region flipped back to Sector [3, 3]!
    expect(activeSector(3, 3), findsOneWidget);

    // 6. Drag over threshold again (move -60px, delta is now -80px) and complete traversal:
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pumpAndSettle();
    expect(activeSector(4, 3), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    // In newly active region:
    final newCenterOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('region_panel_0_0')),
        matching: find.byType(Opacity),
      ).first,
    );
    expect(newCenterOpacity.opacity, equals(1.0));

    final oldCenterOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('region_panel_0_-1')),
        matching: find.byType(Opacity),
      ).first,
    );
    expect(oldCenterOpacity.opacity, equals(1.0));
    expect(activeSector(4, 3), findsOneWidget);
  });

  testWidgets(
      'Cells cannot be revealed or flagged while panel is animating, but all visible cells are interactable at rest',
      (tester) async {
    final game = MinesweeperGame(lockInaccessibleRegions: false);
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

    // 1. Neighbor cells are interactable when board is at rest
    final neighborFinder = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == true,
    );
    expect(neighborFinder, findsWidgets);
    final firstNeighbor = tester.widget(neighborFinder.first);
    expect((firstNeighbor as dynamic).isInteractable, isTrue);

    // 2. Main panel cells are interactable when not animating
    final mainFinder = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    );
    expect(mainFinder, findsWidgets);
    final firstMain = tester.widget(mainFinder.first);
    expect((firstMain as dynamic).isInteractable, isTrue);

    // 3. Initiate a swipe and pause mid-flight during the slide transition
    final gesture = await tester.startGesture(const Offset(250, 250));
    await gesture.moveBy(const Offset(-80, 0));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 50)); // Animation is in-flight

    // During animation, all cells must have isInteractable == false
    final animatingCells = tester.widgetList(find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_RegionCellWidget',
    ));
    for (final cell in animatingCells) {
      expect((cell as dynamic).isInteractable, isFalse);
    }

    // Attempt to tap a cell while animation is in flight
    await tester.tap(mainFinder.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 10));

    // Wait for the transition to finish
    await tester.pumpAndSettle();

    // The cell that was tapped while animating must NOT have triggered any reveals
    // (All cells in the newly arrived panel remain unrevealed state 0)
    final newPanelCells = tester.widgetList(find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    ));
    for (final cell in newPanelCells) {
      expect((cell as dynamic).cellState, equals(0));
    }
  });

  testWidgets('Swiping can be initiated while the panel is animating',
      (tester) async {
    final game = MinesweeperGame(lockInaccessibleRegions: false, swipeThreshold: 64.0);
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

    // Starts at middle region Sector [3, 3]
    expect(activeSector(3, 3), findsOneWidget);

    // Swipe 1: Swipe Left towards Sector [4, 3]
    final g1 = await tester.startGesture(const Offset(250, 250));
    await g1.moveBy(const Offset(-80, 0));
    await g1.up();

    // Pump partially (60ms of the 220ms animation) so the transition is actively in flight
    await tester.pump(const Duration(milliseconds: 60));

    // While animating, initiate a second swipe: Swipe Left towards Sector [5, 3]
    final g2 = await tester.startGesture(const Offset(250, 250));
    await g2.moveBy(const Offset(-80, 0));
    await g2.up();

    // Settle both animations completely
    await tester.pumpAndSettle();

    // Active region must now be Sector [5, 3]!
    expect(activeSector(5, 3), findsOneWidget);
  });

  testWidgets(
      'Passing overlayGradientStyle does not throw and game navigation works without gradient overlay',
      (tester) async {
    final game = MinesweeperGame(
      overlayGradientStyle: OverlayGradientStyle.radial,
      lockInaccessibleRegions: false,
      swipeThreshold: 64.0,
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

    // Gradient overlay is completely removed
    expect(find.byKey(const ValueKey('game_area_gradient_overlay')), findsNothing);

    // Verify directional swipe works smoothly
    final centerCell = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    ).at(MinesweeperConfig.regionRows * MinesweeperConfig.regionCols ~/ 2);

    await tester.drag(centerCell, const Offset(-80, 0));
    await tester.pumpAndSettle();
    expect(activeSector(4, 3), findsOneWidget);
  });

  testWidgets(
      'When flag is toggled on a cell, highlight immediately fades out without waiting for tap release',
      (tester) async {
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

    final mainCells = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    );
    final cell = mainCells.first;

    final cellHighlight = find.descendant(
      of: cell,
      matching: find.byKey(const ValueKey('cell_touch_highlight')),
    );

    // Initial highlight opacity is 0.0
    expect(tester.widget<AnimatedOpacity>(cellHighlight).opacity, equals(0.0));

    // Start gesture (hold finger down)
    final gesture = await tester.startGesture(tester.getCenter(cell));
    await tester.pump();

    // Finger is down: highlight targets 1.0
    expect(tester.widget<AnimatedOpacity>(cellHighlight).opacity, equals(1.0));

    // Advance by longTapDuration to trigger the flag toggle
    // Do NOT release gesture (do NOT call gesture.up())
    await tester.pump(MinesweeperConfig.longTapDuration);

    // Verify flag was toggled
    expect(find.byIcon(Icons.flag_rounded), findsOneWidget);

    // The highlight target opacity must immediately become 0.0, even though finger is still down!
    expect(tester.widget<AnimatedOpacity>(cellHighlight).opacity, equals(0.0));

    // Pump halfway through fade duration (75ms): highlight is actively fading out
    await tester.pump(const Duration(milliseconds: 75));
    // Settle the fade-out
    await tester.pumpAndSettle();

    // Clean up gesture
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'Initially, inaccessible neighbor regions are hidden and minimap sectors are transparent',
      (tester) async {
    final game = MinesweeperGame(); // lockInaccessibleRegions: true by default

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

    // Only 1 panel is rendered (the active center region)
    expect(find.byKey(const ValueKey('actual_panel_container')), findsOneWidget);
    expect(find.byKey(const ValueKey('region_panel_0_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('region_panel_0_1')), findsNothing);
    expect(find.byKey(const ValueKey('region_panel_0_-1')), findsNothing);
    expect(find.byKey(const ValueKey('region_panel_1_0')), findsNothing);
    expect(find.byKey(const ValueKey('region_panel_-1_0')), findsNothing);

    // Initial center sector [3, 3] is visible
    expect(activeSector(3, 3), findsOneWidget);

    Color sectorColor(int x, int y) {
      final sectorFinder = find.descendant(
        of: find.byKey(ValueKey('minimap_sector_${x}_$y')),
        matching: find.byType(Container),
      ).last;
      return (tester.widget<Container>(sectorFinder).decoration as BoxDecoration).color!;
    }

    // Neighbor sectors in minimap are transparent
    expect(sectorColor(4, 3), equals(Colors.transparent));
    expect(sectorColor(3, 2), equals(Colors.transparent));
    expect(sectorColor(1, 1), equals(Colors.transparent));
  });

  testWidgets(
      'Player is blocked from swiping or using keyboard into locked regions, with rubber band snapback',
      (tester) async {
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

    // Start at Sector [3, 3]
    expect(activeSector(3, 3), findsOneWidget);

    // 1. Try swiping Left towards East locked Sector [4, 3]
    final centerCell = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    ).at(MinesweeperConfig.regionRows * MinesweeperConfig.regionCols ~/ 2);

    await tester.drag(centerCell, const Offset(-80, 0));
    await tester.pumpAndSettle();

    // Snapped back to Sector [3, 3]
    expect(activeSector(3, 3), findsOneWidget);

    // 2. Try swiping Up towards South locked Sector [3, 4]
    await tester.drag(centerCell, const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(activeSector(3, 3), findsOneWidget);

    // 3. Try keyboard navigation W, A, S, D
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.pumpAndSettle();
    expect(activeSector(3, 3), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pumpAndSettle();
    expect(activeSector(3, 3), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pumpAndSettle();
    expect(activeSector(3, 3), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pumpAndSettle();
    expect(activeSector(3, 3), findsOneWidget);
  });

  testWidgets(
      'Revealing a cell directly adjacent to an orthogonal border unlocks the neighbor region, makes it visible and accessible',
      (tester) async {
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

    // Initially 1 panel
    expect(find.byKey(const ValueKey('actual_panel_container')), findsOneWidget);
    expect(find.byKey(const ValueKey('region_panel_0_1')), findsNothing);

    // Find main panel cells:
    final mainCells = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    );

    // Cell at index 27 (row 3, col 6) is strictly an East border cell (not a corner)
    final eastBorderCell = mainCells.at(27);
    await tester.tap(eastBorderCell);
    await tester.pumpAndSettle();

    // Now East neighbor region (2, 3) is unlocked!
    // East neighbor panel (0, 1) is now rendered!
    expect(find.byKey(const ValueKey('region_panel_0_1')), findsOneWidget);

    Color sectorColor(int x, int y) {
      final sectorFinder = find.descendant(
        of: find.byKey(ValueKey('minimap_sector_${x}_$y')),
        matching: find.byType(Container),
      ).last;
      return (tester.widget<Container>(sectorFinder).decoration as BoxDecoration).color!;
    }

    // Minimap sector [4, 3] is now visible (not transparent)
    expect(sectorColor(4, 3), isNot(equals(Colors.transparent)));

    // Far-away sectors (like [5, 3] and [1, 1]) remain inaccessible & transparent
    expect(sectorColor(5, 3), equals(Colors.transparent));
    expect(sectorColor(1, 1), equals(Colors.transparent));

    // Player can now navigate East!
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pumpAndSettle();
    expect(activeSector(4, 3), findsOneWidget);

    // But from Sector [4, 3], moving further East (Sector [5, 3]) is still locked
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pumpAndSettle();
    expect(activeSector(4, 3), findsOneWidget);
  });

  testWidgets(
      'Newly unlocked neighbor region fades in smoothly from 0.0 opacity to 1.0 opacity',
      (tester) async {
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

    // East neighbor panel (0, 1) is initially hidden
    expect(find.byKey(const ValueKey('region_panel_0_1')), findsNothing);

    // Tap cell 27 on East border to trigger reveal and unlock East neighbor
    final mainCells = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    );
    await tester.tap(mainCells.at(27));
    // Pump first frame (animation just started)
    await tester.pump();

    // The newly unlocked panel is mounted in the tree
    expect(find.byKey(const ValueKey('region_panel_0_1')), findsOneWidget);

    double getEastPanelOpacity() {
      final opacityWidget = tester.widget<Opacity>(
        find.descendant(
          of: find.byKey(const ValueKey('region_panel_0_1')),
          matching: find.byType(Opacity),
        ).first,
      );
      return opacityWidget.opacity;
    }

    // Immediately at start, opacity is 0.0
    expect(getEastPanelOpacity(), equals(0.0));

    // Advance 175ms (halfway through the 350ms fade-in)
    await tester.pump(const Duration(milliseconds: 175));
    final midOpacity = getEastPanelOpacity();
    expect(midOpacity, greaterThan(0.0));
    expect(midOpacity, lessThan(1.0));

    // Complete the animation
    await tester.pumpAndSettle();
    expect(getEastPanelOpacity(), equals(1.0));
  });

  testWidgets(
      'Minimap is centered, mine counter left-aligned, and pause button right-aligned with resting control bar, remaining stationary during swipe',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    bool pauseTapped = false;
    final game = MinesweeperGame(
      lockInaccessibleRegions: false,
      onPause: () {
        pauseTapped = true;
      },
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

    final centerPanelFinder = find.byKey(const ValueKey('region_panel_0_0'));
    final controlBarFinder =
        find.byKey(const ValueKey('control_bar_background'));
    final mineCounterFinder =
        find.byKey(const ValueKey('region_mine_counter_badge'));
    final minimapFinder = find.byKey(const ValueKey('minimap_selector'));
    final pauseButtonFinder = find.byKey(const ValueKey('region_pause_button'));
    final rankBadgeFinder = find.byKey(const ValueKey('region_rank_badge'));

    expect(centerPanelFinder, findsOneWidget);
    expect(find.byKey(const ValueKey('game_area_gradient_overlay')), findsNothing);
    expect(controlBarFinder, findsOneWidget);
    expect(mineCounterFinder, findsOneWidget);
    expect(rankBadgeFinder, findsOneWidget);
    expect(minimapFinder, findsOneWidget);
    expect(pauseButtonFinder, findsOneWidget);

    final panelRect = tester.getRect(centerPanelFinder);
    final controlBarRect = tester.getRect(controlBarFinder);
    final mineCounterRect = tester.getRect(mineCounterFinder);
    final rankBadgeRect = tester.getRect(rankBadgeFinder);
    final minimapRect = tester.getRect(minimapFinder);
    final pauseButtonRect = tester.getRect(pauseButtonFinder);

    // Control bar background sits at top across available width
    expect(controlBarRect.topLeft, equals(Offset.zero));
    expect(controlBarRect.size.width, equals(400.0));

    // Bottom control bar sits at bottom across available width
    final bottomControlBarFinder =
        find.byKey(const ValueKey('bottom_control_bar_background'));
    expect(bottomControlBarFinder, findsOneWidget);
    final bottomBarRect = tester.getRect(bottomControlBarFinder);
    expect(bottomBarRect.bottom, equals(800.0));

    // Bottom bar has two empty corner buttons
    expect(find.byKey(const ValueKey('bottom_bar_left_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('bottom_bar_right_button')), findsOneWidget);

    // Header controls are arranged in a single row: rank badge left, mine count middle, pause button right
    expect(rankBadgeRect.left, lessThan(mineCounterRect.left));
    expect(mineCounterRect.right, lessThan(pauseButtonRect.left));
    expect(mineCounterRect.center.dx, closeTo(panelRect.center.dx, 0.5));
    expect(rankBadgeRect.top, equals(mineCounterRect.top));
    expect(pauseButtonRect.top, equals(mineCounterRect.top));

    // Minimap is at the bottom, centered with resting selected region, overflowing top of bottom bar
    expect(minimapRect.center.dx, closeTo(panelRect.center.dx, 0.5));
    expect(minimapRect.bottom, equals(800.0 - MinesweeperConfig.headerControlTop));
    expect(minimapRect.top, lessThan(bottomBarRect.top));

    // Pause button has pause icon and matches mine counter badge decoration
    expect(
      find.descendant(
        of: pauseButtonFinder,
        matching: find.byIcon(Icons.pause_rounded),
      ),
      findsOneWidget,
    );
    final pauseContainer = tester.widget<Container>(
      find.descendant(
        of: pauseButtonFinder,
        matching: find.byType(Container),
      ).first,
    );
    final pauseDecoration = pauseContainer.decoration as BoxDecoration;
    final mineCounterDecoration =
        tester.widget<Container>(mineCounterFinder).decoration as BoxDecoration;
    final rankDecoration =
        tester.widget<Container>(rankBadgeFinder).decoration as BoxDecoration;
    expect(pauseDecoration.border, equals(mineCounterDecoration.border));
    expect(pauseDecoration.color, equals(mineCounterDecoration.color));
    expect(
      pauseDecoration.borderRadius,
      equals(mineCounterDecoration.borderRadius),
    );
    expect(rankDecoration.border, equals(mineCounterDecoration.border));
    expect(rankDecoration.color, equals(mineCounterDecoration.color));
    expect(
      rankDecoration.borderRadius,
      equals(mineCounterDecoration.borderRadius),
    );

    // Rank badge has rank icon and displays rank 0 for starting region
    expect(
      find.descendant(
        of: rankBadgeFinder,
        matching: find.byIcon(MinesweeperConfig.rankIcon),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: rankBadgeFinder,
        matching: find.text('0'),
      ),
      findsOneWidget,
    );

    // Pause button size is 42.0 square, and banner badges match button height
    final mineCounterSize = tester.getSize(mineCounterFinder);
    final pauseButtonSize = tester.getSize(pauseButtonFinder);
    final rankBadgeSize = tester.getSize(rankBadgeFinder);
    expect(pauseButtonSize.height, equals(mineCounterSize.height));
    expect(pauseButtonSize.height, equals(rankBadgeSize.height));
    expect(pauseButtonSize.height, equals(42.0));
    expect(pauseButtonSize.width, equals(42.0));
    expect(mineCounterSize.height, equals(MinesweeperConfig.headerBadgeHeight));

    // Badges use flag icon size (18.0) and number text size (15.0)
    final flagIcon = tester.widget<Icon>(
      find.descendant(
        of: mineCounterFinder,
        matching: find.byIcon(MinesweeperConfig.mineCounterIcon),
      ),
    );
    expect(flagIcon.size, equals(MinesweeperConfig.cellFlagIconSize));
    expect(flagIcon.size, equals(18.0));

    final rankIcon = tester.widget<Icon>(
      find.descendant(
        of: rankBadgeFinder,
        matching: find.byIcon(MinesweeperConfig.rankIcon),
      ),
    );
    expect(rankIcon.size, equals(MinesweeperConfig.cellFlagIconSize));
    expect(rankIcon.size, equals(18.0));

    final mineText = tester.widget<Text>(
      find.descendant(
        of: mineCounterFinder,
        matching: find.byType(Text),
      ),
    );
    expect(mineText.style?.fontSize, equals(MinesweeperConfig.cellNumberFontSize));
    expect(mineText.style?.fontSize, equals(15.0));

    final rankText = tester.widget<Text>(
      find.byKey(const ValueKey('region_rank_text')),
    );
    expect(rankText.style?.fontSize, equals(MinesweeperConfig.cellNumberFontSize));
    expect(rankText.style?.fontSize, equals(15.0));

    // Mine counter badge fits its content rather than stretching across the entire available half-width
    expect(mineCounterSize.width, lessThan((controlBarRect.width - minimapRect.width) / 2));

    // Tapping pause button triggers callback
    await tester.tap(pauseButtonFinder);
    expect(pauseTapped, isTrue);

    // Begin dragging to the left by -40px
    final gesture = await tester.startGesture(const Offset(250, 250));
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();

    // Center panel has moved during drag
    final panelRectDuringDrag = tester.getRect(centerPanelFinder);
    expect(panelRectDuringDrag.left, lessThan(panelRect.left));

    // Mine counter, minimap, and pause button did NOT move (they sit in one place and do not follow swiping)
    final mineCounterDuringDrag = tester.getRect(mineCounterFinder);
    final minimapDuringDrag = tester.getRect(minimapFinder);
    final pauseButtonDuringDrag = tester.getRect(pauseButtonFinder);
    expect(
      mineCounterDuringDrag.left,
      equals(mineCounterRect.left),
    );
    expect(minimapDuringDrag.center.dx, closeTo(panelRect.center.dx, 0.5));
    expect(
      pauseButtonDuringDrag.right,
      equals(pauseButtonRect.right),
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'Minimap keeps white current region overlay centered, and moves back layer map mimicking board movement',
      (tester) async {
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

    // Unlock East neighbor region by tapping border cell
    final mainCells = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    );
    final eastBorderCell = mainCells.at(27);
    await tester.tap(eastBorderCell);
    await tester.pumpAndSettle();

    final minimapFinder = find.byKey(const ValueKey('minimap_selector'));
    final overlayFinder = find.byKey(const ValueKey('active_minimap_sector'));
    final sector33Finder = find.byKey(const ValueKey('minimap_sector_3_3'));
    final sector43Finder = find.byKey(const ValueKey('minimap_sector_4_3'));

    expect(minimapFinder, findsOneWidget);
    expect(overlayFinder, findsOneWidget);
    expect(sector33Finder, findsOneWidget);
    expect(sector43Finder, findsOneWidget);

    final minimapRect = tester.getRect(minimapFinder);
    final overlayRect = tester.getRect(overlayFinder);
    final sector33Rect = tester.getRect(sector33Finder);

    // 1. White current region overlay is centered inside the minimap
    expect(overlayRect.center.dx, closeTo(minimapRect.center.dx, 0.5));
    expect(overlayRect.center.dy, closeTo(minimapRect.center.dy, 0.5));

    // 2. Initial region [3, 3] in back layer is centered directly under the overlay
    expect(sector33Rect.center.dx, closeTo(overlayRect.center.dx, 0.5));
    expect(sector33Rect.center.dy, closeTo(overlayRect.center.dy, 0.5));

    // 3. Begin dragging left by -60px
    final gesture = await tester.startGesture(const Offset(250, 250));
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();

    // Front layer overlay tracks sector [3, 3] in the moving back layer
    final overlayDuringDrag = tester.getRect(overlayFinder);
    final sector33DuringDrag = tester.getRect(sector33Finder);
    expect(overlayDuringDrag.center.dx, closeTo(sector33DuringDrag.center.dx, 0.5));
    expect(overlayDuringDrag.center.dy, closeTo(sector33DuringDrag.center.dy, 0.5));
    expect(sector33DuringDrag.center.dx, lessThan(sector33Rect.center.dx));

    // Complete the swipe to East region [4, 3]
    await gesture.moveBy(const Offset(-400, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    // Player navigated to Sector [4, 3]
    expect(activeSector(4, 3), findsOneWidget);

    // Front layer overlay now tracks new sector [4, 3], which is centered after swipe completion
    final overlayAfterSwipe = tester.getRect(overlayFinder);
    final sector43AfterSwipe = tester.getRect(sector43Finder);
    expect(overlayAfterSwipe.center.dx, closeTo(minimapRect.center.dx, 0.5));
    expect(overlayAfterSwipe.center.dy, closeTo(minimapRect.center.dy, 0.5));
    expect(sector43AfterSwipe.center.dx, closeTo(overlayAfterSwipe.center.dx, 0.5));
    expect(sector43AfterSwipe.center.dy, closeTo(overlayAfterSwipe.center.dy, 0.5));

    // Previous sector [3, 3] has shifted leftwards
    final sector33AfterSwipe = tester.getRect(sector33Finder);
    expect(sector33AfterSwipe.center.dx, lessThan(overlayAfterSwipe.center.dx));
  });

  testWidgets(
      'Dragging back and forth across threshold plays flip animation forward and reverse repeatedly and updates minimap selected region each time',
      (tester) async {
    final game = MinesweeperGame(swipeThreshold: 64.0);

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

    // Unlock East neighbor region by tapping border cell
    final mainCells = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    );
    final eastBorderCell = mainCells.at(27);
    await tester.tap(eastBorderCell);
    await tester.pumpAndSettle();

    Color backLayerColor(int x, int y) {
      final sectorFinder = find.descendant(
        of: find.byKey(ValueKey('minimap_sector_${x}_$y')),
        matching: find.byType(Container),
      ).last;
      return (tester.widget<Container>(sectorFinder).decoration as BoxDecoration).color!;
    }

    final overlayFinder = find.byKey(const ValueKey('active_minimap_sector'));
    final sector33Finder = find.byKey(const ValueKey('minimap_sector_3_3'));
    final sector43Finder = find.byKey(const ValueKey('minimap_sector_4_3'));

    // Back layer does NOT show white for selected region (shows minimapStartedColor for revealed cell, panelHigh for neighbor)
    expect(backLayerColor(3, 3), equals(MinesweeperConfig.minimapStartedColor));
    expect(backLayerColor(4, 3), equals(AppColors.panelHigh));
    expect(tester.getRect(overlayFinder).center.dx, closeTo(tester.getRect(sector33Finder).center.dx, 0.5));

    final gesture = await tester.startGesture(const Offset(250, 250));

    // Drag below threshold (-40px): overlay tracks sector [3, 3] in back layer
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    expect(activeSector(3, 3), findsOneWidget);
    expect(tester.getRect(overlayFinder).center.dx, closeTo(tester.getRect(sector33Finder).center.dx, 0.5));
    expect(backLayerColor(3, 3), isNot(equals(Colors.white)));
    expect(backLayerColor(4, 3), isNot(equals(Colors.white)));

    // Iteration 1: Drag over threshold (-70px total -> moveBy -30px)
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(activeSector(4, 3), findsOneWidget);
    expect(tester.getRect(overlayFinder).center.dx, closeTo(tester.getRect(sector43Finder).center.dx, 0.5));
    expect(backLayerColor(3, 3), isNot(equals(Colors.white)));
    expect(backLayerColor(4, 3), isNot(equals(Colors.white)));
    var currentOp = tester.widget<Opacity>(
      find.descendant(of: find.byKey(const ValueKey('region_panel_0_0')), matching: find.byType(Opacity)).first,
    );
    var incomingOp = tester.widget<Opacity>(
      find.descendant(of: find.byKey(const ValueKey('region_panel_0_1')), matching: find.byType(Opacity)).first,
    );
    expect(currentOp.opacity, equals(1.0));
    expect(incomingOp.opacity, equals(1.0));

    // Iteration 1 reverse: Drag back below threshold (move +50px -> total -20px)
    await gesture.moveBy(const Offset(50, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(activeSector(3, 3), findsOneWidget);
    expect(tester.getRect(overlayFinder).center.dx, closeTo(tester.getRect(sector33Finder).center.dx, 0.5));
    currentOp = tester.widget<Opacity>(
      find.descendant(of: find.byKey(const ValueKey('region_panel_0_0')), matching: find.byType(Opacity)).first,
    );
    incomingOp = tester.widget<Opacity>(
      find.descendant(of: find.byKey(const ValueKey('region_panel_0_1')), matching: find.byType(Opacity)).first,
    );
    expect(currentOp.opacity, equals(1.0));
    expect(incomingOp.opacity, equals(1.0));

    // Iteration 2: Drag over threshold again (move -60px -> total -80px)
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(activeSector(4, 3), findsOneWidget);
    expect(tester.getRect(overlayFinder).center.dx, closeTo(tester.getRect(sector43Finder).center.dx, 0.5));
    currentOp = tester.widget<Opacity>(
      find.descendant(of: find.byKey(const ValueKey('region_panel_0_0')), matching: find.byType(Opacity)).first,
    );
    incomingOp = tester.widget<Opacity>(
      find.descendant(of: find.byKey(const ValueKey('region_panel_0_1')), matching: find.byType(Opacity)).first,
    );
    expect(currentOp.opacity, equals(1.0));
    expect(incomingOp.opacity, equals(1.0));

    // Iteration 2 reverse: Drag back below threshold again (move +70px -> total -10px)
    await gesture.moveBy(const Offset(70, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(activeSector(3, 3), findsOneWidget);
    expect(tester.getRect(overlayFinder).center.dx, closeTo(tester.getRect(sector33Finder).center.dx, 0.5));
    currentOp = tester.widget<Opacity>(
      find.descendant(of: find.byKey(const ValueKey('region_panel_0_0')), matching: find.byType(Opacity)).first,
    );
    incomingOp = tester.widget<Opacity>(
      find.descendant(of: find.byKey(const ValueKey('region_panel_0_1')), matching: find.byType(Opacity)).first,
    );
    expect(currentOp.opacity, equals(1.0));
    expect(incomingOp.opacity, equals(1.0));

    // Release below threshold -> snapback maintains Sector [3, 3]
    await gesture.up();
    await tester.pumpAndSettle();
    expect(activeSector(3, 3), findsOneWidget);
    expect(tester.getRect(overlayFinder).center.dx, closeTo(tester.getRect(sector33Finder).center.dx, 0.5));
    expect(backLayerColor(3, 3), isNot(equals(Colors.white)));
    expect(backLayerColor(4, 3), isNot(equals(Colors.white)));
  });

  testWidgets(
      'Minimap front layer selection tracks selected region in back layer, animates to new one with ease out on threshold, and continues tracking',
      (tester) async {
    final game = MinesweeperGame(swipeThreshold: 64.0);

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

    // Unlock East neighbor
    final mainCells = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    );
    await tester.tap(mainCells.at(27));
    await tester.pumpAndSettle();

    final overlayFinder = find.byKey(const ValueKey('active_minimap_sector'));
    final sector33Finder = find.byKey(const ValueKey('minimap_sector_3_3'));
    final sector43Finder = find.byKey(const ValueKey('minimap_sector_4_3'));
    expect(sector43Finder, findsOneWidget);

    Color backLayerColor(int x, int y) {
      final sectorFinder = find.descendant(
        of: find.byKey(ValueKey('minimap_sector_${x}_$y')),
        matching: find.byType(Container),
      ).last;
      return (tester.widget<Container>(sectorFinder).decoration as BoxDecoration).color!;
    }

    // Front layer overlay is white; back layer cells are NOT white
    final overlayDecoration = tester.widget<AnimatedContainer>(overlayFinder).decoration as BoxDecoration;
    expect(overlayDecoration.color, equals(Colors.white));
    expect(backLayerColor(3, 3), isNot(equals(Colors.white)));
    expect(backLayerColor(4, 3), isNot(equals(Colors.white)));

    // 1. Initial rest: overlay is directly over sector [3, 3]
    final initialSector33Rect = tester.getRect(sector33Finder);
    expect(tester.getRect(overlayFinder).center.dx, closeTo(initialSector33Rect.center.dx, 0.5));

    // 2. Drag under threshold (-30px): overlay tracks sector [3, 3] in moving back layer
    final gesture = await tester.startGesture(const Offset(250, 250));
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();

    final sector33At30 = tester.getRect(sector33Finder);
    expect(sector33At30.center.dx, lessThan(initialSector33Rect.center.dx));
    expect(tester.getRect(overlayFinder).center.dx, closeTo(sector33At30.center.dx, 0.5));

    // 3. Drag over threshold (-70px total -> additional -40px)
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();

    // Pump halfway through the 200ms ease out animation (e.g. 80ms):
    // Overlay is in flight between sector [3, 3] and sector [4, 3]!
    await tester.pump(const Duration(milliseconds: 80));
    final inFlightOverlay = tester.getRect(overlayFinder);
    final currentSector33 = tester.getRect(sector33Finder);
    final currentSector43 = tester.getRect(sector43Finder);
    expect(inFlightOverlay.center.dx, greaterThan(currentSector33.center.dx));
    expect(inFlightOverlay.center.dx, lessThan(currentSector43.center.dx));

    // Complete the ease out animation (remaining 150ms):
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.getRect(overlayFinder).center.dx, closeTo(tester.getRect(sector43Finder).center.dx, 0.5));
    expect(activeSector(4, 3), findsOneWidget);

    // 4. Continue dragging further (-90px total -> additional -20px):
    // Overlay continues tracking sector [4, 3] as it moves!
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    expect(tester.getRect(overlayFinder).center.dx, closeTo(tester.getRect(sector43Finder).center.dx, 0.5));

    // 5. Drag back below threshold (+70px -> total -20px):
    await gesture.moveBy(const Offset(70, 0));
    await tester.pump();
    // Ease out animates back to sector [3, 3]
    await tester.pump(const Duration(milliseconds: 250));
    expect(activeSector(3, 3), findsOneWidget);
    expect(tester.getRect(overlayFinder).center.dx, closeTo(tester.getRect(sector33Finder).center.dx, 0.5));

    // 6. Release below threshold -> snapback
    await gesture.up();
    await tester.pumpAndSettle();
    expect(activeSector(3, 3), findsOneWidget);
    expect(tester.getRect(overlayFinder).center.dx, closeTo(tester.getRect(sector33Finder).center.dx, 0.5));
    expect(backLayerColor(3, 3), isNot(equals(Colors.white)));
    expect(backLayerColor(4, 3), isNot(equals(Colors.white)));
  });

  testWidgets(
      'Corner radius of region panels is configurable via panelCornerRadius config param',
      (tester) async {
    // 1. Test default value (14.0)
    final defaultGame = MinesweeperGame();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => defaultGame.buildGame(
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

    final defaultContainer = tester.widget<Container>(
      find.byKey(const ValueKey('actual_panel_container')).first,
    );
    final defaultDecoration = defaultContainer.decoration as BoxDecoration;
    expect(
      defaultDecoration.borderRadius,
      equals(BorderRadius.circular(MinesweeperConfig.panelCornerRadius)),
    );

    // 2. Test custom value (e.g. 24.0)
    final customGame = MinesweeperGame(panelCornerRadius: 24.0);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => customGame.buildGame(
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

    final customContainer = tester.widget<Container>(
      find.byKey(const ValueKey('actual_panel_container')).first,
    );
    final customDecoration = customContainer.decoration as BoxDecoration;
    expect(
      customDecoration.borderRadius,
      equals(BorderRadius.circular(24.0)),
    );

    // 3. Test alias regionPanelCornerRadius (e.g. 30.0)
    final aliasGame = MinesweeperGame(regionPanelCornerRadius: 30.0);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => aliasGame.buildGame(
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

    final aliasContainer = tester.widget<Container>(
      find.byKey(const ValueKey('actual_panel_container')).first,
    );
    final aliasDecoration = aliasContainer.decoration as BoxDecoration;
    expect(
      aliasDecoration.borderRadius,
      equals(BorderRadius.circular(30.0)),
    );
  });

  testWidgets('Infinite world allows navigation beyond 5x5 bounds in all directions', (tester) async {
    final game = MinesweeperGame(lockInaccessibleRegions: false);

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

    // Start at Sector [3, 3]
    expect(activeSector(3, 3), findsOneWidget);

    // Navigate East 4 times -> reaches Sector [7, 3] (beyond old 5x5 bounds)
    for (int i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.pumpAndSettle();
    }
    expect(activeSector(7, 3), findsOneWidget);

    // Navigate North 4 times -> reaches Sector [7, -1] (negative row coordinate)
    for (int i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.pumpAndSettle();
    }
    expect(activeSector(7, -1), findsOneWidget);

    // Navigate West 8 times -> reaches Sector [-1, -1] (negative col coordinate)
    for (int i = 0; i < 8; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pumpAndSettle();
    }
    expect(activeSector(-1, -1), findsOneWidget);
  });

  testWidgets('Revealing a border cell dynamically discovers and unlocks regions beyond old 5x5 bounds', (tester) async {
    final game = MinesweeperGame(
      lockInaccessibleRegions: true,
      initialRegionX: 4, // Col 4 (Sector [5, 3] - eastern edge of old 5x5 world)
      initialRegionY: 2,
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

    expect(activeSector(5, 3), findsOneWidget);

    // Sector [6, 3] (Col 5) is outside old bounds and initially locked
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pumpAndSettle();
    // Cannot move into locked Sector [6, 3]
    expect(activeSector(5, 3), findsOneWidget);

    // Reveal an eastern border cell in Sector [5, 3] (localCol = 6, e.g. center row localRow = 3)
    final activeCells = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    );
    final eastBorderCell = activeCells.at(3 * MinesweeperConfig.regionCols + (MinesweeperConfig.regionCols - 1));
    await tester.tap(eastBorderCell);
    await tester.pumpAndSettle();

    // Now Sector [6, 3] is discovered and unlocked!
    // We can navigate into Sector [6, 3]!
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pumpAndSettle();
    expect(activeSector(6, 3), findsOneWidget);
  });

  testWidgets('Clearing a region marks it cleared but does not complete stage in infinite world', (tester) async {
    bool stageCompleted = false;

    final game = MinesweeperGame(
      mineDensity: 0.0, // Zero mines for deterministic instant clear
      lockInaccessibleRegions: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => game.buildGame(
              context: context,
              onComplete: () {
                stageCompleted = true;
              },
              onFail: () {},
              gameState: gameState,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap first cell in region (with 0 mines, flood fill reveals all 49 cells)
    final firstActiveCell = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    ).first;

    await tester.tap(firstActiveCell);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 700));

    // In infinite world, clearing a region never ends the stage; onComplete is NOT triggered
    expect(stageCompleted, isFalse);
  });

  testWidgets(
      'When a region is unlocked, its 8 neighbors are generated immediately and all its edge numbers are precalculated',
      (tester) async {
    final game = MinesweeperGame(); // lockInaccessibleRegions: true by default

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

    // Initially, starting region is (2, 2)
    // Find active cells:
    final mainCells = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    );

    // Cell at index 27 (row 3, col 6 in a 7-column region) is on East border
    final eastBorderCell = mainCells.at(27);
    await tester.tap(eastBorderCell);
    await tester.pumpAndSettle();

    // Tapping eastBorderCell unlocked East region (2, 3)
    final eastRegion = regions[(2, 3)];
    expect(eastRegion, isNotNull);
    expect(eastRegion!.isGenerated, isTrue);

    // All 8 neighbors of East region (2, 3) must be generated immediately
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final neighbor = regions[(2 + dr, 3 + dc)];
        expect(neighbor, isNotNull, reason: 'Neighbor at (${2 + dr}, ${3 + dc}) should exist');
        expect(neighbor!.isGenerated, isTrue, reason: 'Neighbor at (${2 + dr}, ${3 + dc}) should be generated');
      }
    }

    // All cells (especially edges) of East region (2, 3) must have their numbers precalculated (!= 255)
    final adjacentList = eastRegion.adjacent as List<int>;
    for (int i = 0; i < adjacentList.length; i++) {
      expect(
        adjacentList[i],
        isNot(equals(255)),
        reason: 'Cell $i in unlocked region should have precalculated adjacent count',
      );
      expect(adjacentList[i], inInclusiveRange(0, 8));
    }
  });

  testWidgets(
      'Starting region generates with default mines, and other regions scale linearly with distance',
      (tester) async {
    const targetMines = 8;
    final game = MinesweeperGame(
      minesPerRegion: targetMines,
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

    // Verify starting region is marked on the minimap, and NOT on the board map
    expect(find.byKey(const ValueKey('minimap_starting_region_marker')), findsOneWidget);
    expect(find.byKey(const ValueKey('starting_region_marker')), findsNothing);

    // Trigger initial click to generate starting region (2, 2) and its 8 neighbors
    final mainCells = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    );
    await tester.tap(mainCells.at(24));
    await tester.pumpAndSettle();

    // Verify starting region has exactly targetMines (distance 0) and is marked
    final startRegion = regions[(2, 2)];
    expect(startRegion, isNotNull);
    expect(startRegion.isStartingRegion, isTrue);
    expect(startRegion.mineCount, equals(targetMines));
    final startMineList = startRegion.mines as List<int>;
    expect(startMineList.where((m) => m == 1).length, equals(targetMines));

    // Verify all 8 neighbors have expected mines based on distance (targetMines + dist)
    expect(regions.length, greaterThanOrEqualTo(9));
    for (final entry in regions.entries) {
      if (entry.key == (2, 2)) continue;
      if (entry.value.isGenerated as bool) {
        final rank = entry.value.rank as int;
        final expectedMines =
            MinesweeperConfig.rankToMineCountFunction(rank, baseMines: targetMines);
        final mineList = entry.value.mines as List<int>;
        final count = mineList.where((m) => m == 1).length;
        expect(count, equals(expectedMines),
            reason:
                'Region at ${entry.key} (rank $rank) should have exactly $expectedMines mines');
        expect(entry.value.mineCount, equals(expectedMines));
        expect(entry.value.isStartingRegion, isFalse);
      }
    }
  });

  testWidgets('Chording affects and reveals cells in neighboring regions', (tester) async {
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

    final dynamic state = tester.state(
      find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MinesweeperGame'),
    );
    final Map<(int, int), dynamic> regions = state.regions;

    // 1. Initial click at center of starting region (2, 2)
    final mainCells = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    );
    await tester.tap(mainCells.at(24));
    await tester.pumpAndSettle();

    // 2. Set up deterministic board configuration around East border cell (3, 6) in region (2, 2):
    final currentRegion = regions[(2, 2)];
    final eastRegion = regions[(2, 3)];

    // Clear mines in surrounding cells of (3, 6) in (2, 2) and (2, 3)
    for (int r = 0; r < 7; r++) {
      for (int c = 0; c < 7; c++) {
        currentRegion.mines[currentRegion.localIndex(r, c)] = 0;
        eastRegion.mines[eastRegion.localIndex(r, c)] = 0;
      }
    }
    // Place 1 mine at (3, 5) in (2, 2)
    currentRegion.mines[currentRegion.localIndex(3, 5)] = 1;
    // Invalidate cached adjacent numbers
    (currentRegion.adjacent as List<int>).fillRange(0, 49, 255);
    (eastRegion.adjacent as List<int>).fillRange(0, 49, 255);

    // Flag the mine at (3, 5) and reveal cell (3, 6)
    currentRegion.cellStates[currentRegion.localIndex(3, 5)] = CellState.flagged;
    currentRegion.cellStates[currentRegion.localIndex(3, 6)] = CellState.revealed;
    // Ensure east neighbor cell (3, 0) is unrevealed
    eastRegion.cellStates[eastRegion.localIndex(3, 0)] = CellState.unrevealed;

    await tester.pump();

    // Verify cell (3, 0) in east neighbor region is currently unrevealed
    expect(eastRegion.cellStates[eastRegion.localIndex(3, 0)], equals(CellState.unrevealed));

    // 3. Tap on revealed cell (3, 6) in current region to trigger chord
    final chordCellFinder = mainCells.at(currentRegion.localIndex(3, 6) as int);
    await tester.tap(chordCellFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 4. Verify that chording affected and revealed the cell in the neighboring region!
    expect(
      eastRegion.cellStates[eastRegion.localIndex(3, 0)],
      equals(CellState.revealed),
      reason: 'Cell (3, 0) in neighboring East region should be revealed by chording',
    );
  });

  testWidgets(
      'Revealing a corner tile unlocks the diagonal neighbor region and makes it visible and accessible',
      (tester) async {
    final game = MinesweeperGame(); // lockInaccessibleRegions: true by default

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

    // Initially, diagonal panels are hidden
    expect(find.byKey(const ValueKey('region_panel_-1_-1')), findsNothing);
    expect(find.byKey(const ValueKey('region_panel_1_1')), findsNothing);

    Color sectorColor(int x, int y) {
      final sectorFinder = find.descendant(
        of: find.byKey(ValueKey('minimap_sector_${x}_$y')),
        matching: find.byType(Container),
      ).last;
      return (tester.widget<Container>(sectorFinder).decoration as BoxDecoration).color!;
    }

    // Diagonal sectors [2, 2] (NW) and [4, 4] (SE) are initially transparent
    expect(sectorColor(2, 2), equals(Colors.transparent));
    expect(sectorColor(4, 4), equals(Colors.transparent));

    final mainCells = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    );

    final state = tester.state(
      find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MinesweeperGame'),
    ) as dynamic;
    final region = state.regions[(2, 2)];
    // Ensure cell 0 is safe and has an adjacent mine so it reveals without flood fill cascade
    region.mines[0] = 0;
    region.mines[1] = 1;
    if (region.mines[48] == 1) {
      region.mines[48] = 0;
      region.mines[24] = 1;
    }

    // 1. Reveal Top-Left corner tile (index 0, row 0, col 0)
    final topLeftCell = mainCells.at(0);
    await tester.tap(topLeftCell);
    await tester.pumpAndSettle();

    // North-West diagonal neighbor panel (-1, -1) is now rendered!
    expect(find.byKey(const ValueKey('region_panel_-1_-1')), findsOneWidget);
    // NW diagonal minimap sector [2, 2] is now visible (not transparent)
    expect(sectorColor(2, 2), isNot(equals(Colors.transparent)));

    // Opposite diagonal SE neighbor panel (1, 1) and sector [4, 4] remain locked
    expect(find.byKey(const ValueKey('region_panel_1_1')), findsNothing);
    expect(sectorColor(4, 4), equals(Colors.transparent));

    // Ensure cell 48 is safe after first-click mine placement so tapping it reveals rather than triggers game over
    if (region.mines[48] == 1) {
      region.mines[48] = 0;
      region.mines[24] = 1;
    }

    // 2. Reveal Bottom-Right corner tile (index 48, row 6, col 6)
    final bottomRightCell = mainCells.at(48);
    await tester.tap(bottomRightCell);
    await tester.pumpAndSettle();

    // South-East diagonal neighbor panel (1, 1) is now unlocked and rendered!
    expect(find.byKey(const ValueKey('region_panel_1_1')), findsOneWidget);
    // SE diagonal minimap sector [4, 4] is now visible (not transparent)
    expect(sectorColor(4, 4), isNot(equals(Colors.transparent)));
  });

  testWidgets(
      'Diagonal swipe navigates into unlocked diagonal region',
      (tester) async {
    final game = MinesweeperGame(
      lockInaccessibleRegions: false,
      swipeThreshold: 64.0,
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

    // Initial state: Sector [3, 3]
    expect(activeSector(3, 3), findsOneWidget);

    final centerCell = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    ).first;

    // Diagonal drag up-left (dx = -80, dy = -80, distance ~113 > 64) -> pulls in South-East -> Sector [4, 4]
    await tester.drag(centerCell, const Offset(-80, -80));
    await tester.pumpAndSettle();
    expect(activeSector(4, 4), findsOneWidget);

    // Diagonal drag down-right (dx = 80, dy = 80) -> pulls in North-West -> back to Sector [3, 3]
    await tester.drag(centerCell, const Offset(80, 80));
    await tester.pumpAndSettle();
    expect(activeSector(3, 3), findsOneWidget);
  });

  testWidgets(
      'User can switch drag directions mid-drag and the active incoming region updates accordingly',
      (tester) async {
    final game = MinesweeperGame(
      lockInaccessibleRegions: false,
      swipeThreshold: 50.0,
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

    final centerCell = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    ).first;

    // 1. Start gesture: drag left (East)
    final gesture = await tester.startGesture(tester.getCenter(centerCell));
    await gesture.moveBy(const Offset(-60, 0)); // East (dx = -60, dist = 60 > 50)
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // fade in completed

    // East neighbor panel (0, 1) should be at full opacity 1.0
    final eastPanelOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('region_panel_0_1')),
        matching: find.byType(Opacity),
      ).first,
    );
    expect(eastPanelOpacity.opacity, equals(1.0));

    // 2. Switch direction mid-drag without releasing: move to South-East (dx = -60, dy = -60)
    await gesture.moveBy(const Offset(0, -60)); // total delta (-60, -60), South-East
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Now South-East panel (1, 1) should be at full opacity 1.0
    final sePanelOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('region_panel_1_1')),
        matching: find.byType(Opacity),
      ).first,
    );
    expect(sePanelOpacity.opacity, equals(1.0));

    // And East panel (0, 1) also remains at 1.0 opacity
    final eastPanelAfterSwitch = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('region_panel_0_1')),
        matching: find.byType(Opacity),
      ).first,
    );
    expect(eastPanelAfterSwitch.opacity, equals(1.0));

    // 3. Release: should navigate into South-East (Sector [4, 4])
    await gesture.up();
    await tester.pumpAndSettle();
    expect(activeSector(4, 4), findsOneWidget);
  });

  testWidgets('Minimap displays 7x7 sector viewport (105x105px)', (tester) async {
    final game = MinesweeperGame(lockInaccessibleRegions: false);
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

    // Verify 105x105px viewport in RegionMiniMapSelector
    final minimapSizedBoxFinder = find.descendant(
      of: find.byKey(const ValueKey('minimap_selector')),
      matching: find.byType(SizedBox),
    ).first;
    final minimapSizedBox = tester.widget<SizedBox>(minimapSizedBoxFinder);
    expect(minimapSizedBox.width, equals(105.0));
    expect(minimapSizedBox.height, equals(105.0));

    // Verify 7x7 sector window cells exist centered around [3, 3]
    expect(find.byKey(const ValueKey('minimap_sector_0_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('minimap_sector_3_3')), findsOneWidget);
    expect(find.byKey(const ValueKey('minimap_sector_6_6')), findsOneWidget);
  });

  testWidgets('Dragging does not move map until dragMinThreshold is exceeded', (tester) async {
    final game = MinesweeperGame(
      lockInaccessibleRegions: false,
      swipeThreshold: 64.0,
      dragMinThreshold: 10.0,
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

    final centerPanelFinder = find.byKey(const ValueKey('region_panel_0_0'));
    final initialPanelRect = tester.getRect(centerPanelFinder);

    // 1. Drag under dragMinThreshold (distance = 5.0px < 10.0px)
    final gesture = await tester.startGesture(const Offset(250, 250));
    await gesture.moveBy(const Offset(-5, 0));
    await tester.pump();

    // Panel must NOT have moved at all
    final underThresholdRect = tester.getRect(centerPanelFinder);
    expect(underThresholdRect.left, equals(initialPanelRect.left));

    // Move slightly more to 9.0px total (< 10.0px)
    await gesture.moveBy(const Offset(-4, 0));
    await tester.pump();
    final at9pxRect = tester.getRect(centerPanelFinder);
    expect(at9pxRect.left, equals(initialPanelRect.left));

    // 2. Drag exceeds dragMinThreshold (move -6px further, total distance 15.0px > 10.0px)
    await gesture.moveBy(const Offset(-6, 0));
    await tester.pump();
    final pastThresholdRect = tester.getRect(centerPanelFinder);
    expect(pastThresholdRect.left, lessThan(initialPanelRect.left));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('Mid-drag traversal target switching updates candidate and minimap without fading', (tester) async {
    final game = MinesweeperGame(
      lockInaccessibleRegions: false,
      swipeThreshold: 64.0,
      dragMinThreshold: 10.0,
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

    // 1. Drag past swipeThreshold towards East (Offset(-70, 0))
    final gesture = await tester.startGesture(const Offset(250, 250));
    await gesture.moveBy(const Offset(-70, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final eastPanelFinder = find.byKey(const ValueKey('region_panel_0_1'));
    final sePanelFinder = find.byKey(const ValueKey('region_panel_1_1'));

    double getOpacity(Finder f) => tester.widget<Opacity>(
      find.descendant(of: f, matching: find.byType(Opacity)).first,
    ).opacity;

    expect(getOpacity(eastPanelFinder), equals(1.0));
    expect(getOpacity(sePanelFinder), equals(1.0));
    expect(activeSector(4, 3), findsOneWidget);

    // 2. Switch mid-drag to South-East without lifting pointer (dx = -50, dy = -50, dist ~70.7 > 64)
    await gesture.moveBy(const Offset(20, -50));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(getOpacity(eastPanelFinder), equals(1.0));
    expect(getOpacity(sePanelFinder), equals(1.0));
    expect(activeSector(4, 4), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('Mid-drag traversal target switching does not blink or flicker center region opacity', (tester) async {
    final game = MinesweeperGame(
      lockInaccessibleRegions: false,
      swipeThreshold: 64.0,
      dragMinThreshold: 10.0,
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

    final centerPanelFinder = find.byKey(const ValueKey('region_panel_0_0'));
    final eastPanelFinder = find.byKey(const ValueKey('region_panel_0_1'));
    final sePanelFinder = find.byKey(const ValueKey('region_panel_1_1'));

    double getOpacity(Finder f) => tester.widget<Opacity>(
      find.descendant(of: f, matching: find.byType(Opacity)).first,
    ).opacity;

    expect(getOpacity(centerPanelFinder), equals(1.0));

    // 1. Drag past swipeThreshold towards East (Offset(-70, 0))
    final gesture = await tester.startGesture(const Offset(250, 250));
    await gesture.moveBy(const Offset(-70, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(getOpacity(centerPanelFinder), equals(1.0));
    expect(getOpacity(eastPanelFinder), equals(1.0));
    expect(getOpacity(sePanelFinder), equals(1.0));

    // 2. Switch mid-drag to South-East without lifting pointer (Offset(-50, -50))
    await gesture.moveBy(const Offset(20, -50));
    await tester.pump();

    // At each frame during candidate switch, center panel remains steady at 1.0 opacity
    for (int ms = 0; ms <= 200; ms += 25) {
      await tester.pump(const Duration(milliseconds: 25));
      expect(
        getOpacity(centerPanelFinder),
        equals(1.0),
        reason: 'Center panel blinked or changed opacity at ms=$ms during candidate switch',
      );
    }

    // Verify final states of candidate targets
    expect(getOpacity(eastPanelFinder), equals(1.0));
    expect(getOpacity(sePanelFinder), equals(1.0));
    expect(getOpacity(centerPanelFinder), equals(1.0));

    // 3. Pull back towards center below swipeThreshold (distance ~28.3 < 64)
    // From (-50, -50) move by (30, 30) -> new delta (-20, -20)
    await gesture.moveBy(const Offset(30, 30));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(getOpacity(centerPanelFinder), equals(1.0));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('Drag extension limit smoothly interpolates between discovered and undiscovered directions without jumping', (tester) async {
    final game = MinesweeperGame(
      lockInaccessibleRegions: true,
      swipeThreshold: 64.0,
      dragMinThreshold: 10.0,
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
    // Explicitly unlock East region (2, 3) only (SE remains locked)
    state.unlockedRegions.add(const (2, 3));
    await tester.pumpAndSettle();

    final centerPanelFinder = find.byKey(const ValueKey('region_panel_0_0'));
    final initialPos = tester.getTopLeft(centerPanelFinder);

    const startPoint = Offset(300, 300);
    final gesture = await tester.startGesture(startPoint);

    // Sample visual displacements as angle rotates from 0 deg (East, unlocked)
    // to 45 deg (SE, locked) at constant radius R = 100
    const double radius = 100.0;
    final displacements = <double>[];

    for (double deg = 0; deg <= 45; deg += 5) {
      final rad = deg * math.pi / 180.0;
      final dx = -radius * math.cos(rad);
      final dy = -radius * math.sin(rad);
      await gesture.moveTo(startPoint + Offset(dx, dy));
      await tester.pump();

      final currentPos = tester.getTopLeft(centerPanelFinder);
      final offset = currentPos - initialPos;
      displacements.add(offset.distance);
    }

    // Unlocked displacement (deg = 0) is ~45px, locked displacement (deg = 45) is ~28.7px
    expect(displacements.first, greaterThan(40.0));
    expect(displacements.last, lessThan(32.0));

    // Every step must decrease smoothly and monotonically without any jump > 4.0px
    for (int i = 1; i < displacements.length; i++) {
      final prev = displacements[i - 1];
      final curr = displacements[i];
      expect(curr, lessThanOrEqualTo(prev + 0.001),
          reason: 'Displacement must decrease monotonically towards locked direction');
      final stepChange = (prev - curr).abs();
      expect(stepChange, lessThan(4.0),
          reason: 'Displacement jumped abruptly ($stepChange px) at step $i');
    }

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('Switching drag from discovered region to non-discovered area resets traversal target without fading', (tester) async {
    final game = MinesweeperGame(
      lockInaccessibleRegions: true,
      swipeThreshold: 64.0,
      dragMinThreshold: 10.0,
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
    // Explicitly unlock East region (2, 3) only (SE (3, 3) remains non-discovered)
    state.unlockedRegions.add(const (2, 3));
    (state as dynamic).setState(() {});
    await tester.pumpAndSettle();

    final centerPanelFinder = find.byKey(const ValueKey('region_panel_0_0'));
    final eastPanelFinder = find.byKey(const ValueKey('region_panel_0_1'));

    double getOpacity(Finder f) => tester.widget<Opacity>(
      find.descendant(of: f, matching: find.byType(Opacity)).first,
    ).opacity;

    // Initially at Sector [3, 3] with full opacity
    expect(activeSector(3, 3), findsOneWidget);
    expect(getOpacity(centerPanelFinder), equals(1.0));
    expect(getOpacity(eastPanelFinder), equals(1.0));

    // 1. Drag past swipeThreshold towards East (discovered region)
    final gesture = await tester.startGesture(const Offset(250, 250));
    await gesture.moveBy(const Offset(-70, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // Traversal target set to East: minimap highlights Sector [4, 3], opacities stay 1.0
    expect(getOpacity(centerPanelFinder), equals(1.0));
    expect(getOpacity(eastPanelFinder), equals(1.0));
    expect(activeSector(4, 3), findsOneWidget);

    // 2. Switch drag towards South-East (non-discovered area) while staying past swipeThreshold (dist ~70.7 > 64)
    // Move from (-70, 0) to (-50, -50): moveBy(Offset(20, -50))
    await gesture.moveBy(const Offset(20, -50));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // Traversal target must immediately reset to original region:
    // Minimap selected sector resets to original Sector [3, 3]
    expect(activeSector(3, 3), findsOneWidget);
    expect(getOpacity(centerPanelFinder), equals(1.0));
    expect(getOpacity(eastPanelFinder), equals(1.0));

    // 3. Switch back to East (discovered region) while still dragging past threshold
    // From (-50, -50) to (-70, 0): moveBy(Offset(-20, 50))
    await gesture.moveBy(const Offset(-20, 50));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // Traversal target is restored to East: minimap at Sector [4, 3], opacities stay 1.0
    expect(getOpacity(centerPanelFinder), equals(1.0));
    expect(getOpacity(eastPanelFinder), equals(1.0));
    expect(activeSector(4, 3), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'Region panels are wrapped in RepaintBoundary for smooth subpixel movement',
      (tester) async {
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

    final centerPanelFinder = find.byKey(const ValueKey('region_panel_0_0'));
    expect(centerPanelFinder, findsOneWidget);

    // Verify RepaintBoundary is present on region panel
    final repaintBoundaryFinder = find.descendant(
      of: centerPanelFinder,
      matching: find.byType(RepaintBoundary),
    );
    expect(repaintBoundaryFinder, findsOneWidget);

    final renderObj = tester.renderObject(repaintBoundaryFinder);
    expect(renderObj.isRepaintBoundary, isTrue);

    // Verify subpixel movement during drag
    final gesture = await tester.startGesture(tester.getCenter(centerPanelFinder));
    await gesture.moveBy(const Offset(-15.4, -8.7));
    await tester.pump();

    final panelPos = tester.getTopLeft(centerPanelFinder);
    expect(panelPos.dx % 1.0, isNot(equals(0.0))); // Has fractional subpixel component
    expect(renderObj.isRepaintBoundary, isTrue);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  test('MinesweeperConfig distance and linear mine scaling functions', () {
    // 1. Distance calculations (Manhattan default)
    expect(MinesweeperConfig.calculateRegionDistance(2, 2, startR: 2, startC: 2), equals(0));
    expect(MinesweeperConfig.calculateRegionDistance(1, 2, startR: 2, startC: 2), equals(1)); // North
    expect(MinesweeperConfig.calculateRegionDistance(1, 3, startR: 2, startC: 2), equals(2)); // North-East (diagonal)
    expect(MinesweeperConfig.calculateRegionDistance(0, 4, startR: 2, startC: 2), equals(4));
    expect(MinesweeperConfig.calculateRegionDistance(-1, 5, startR: 2, startC: 2), equals(6));

    // 2. Chebyshev distance option
    expect(
      MinesweeperConfig.calculateRegionDistance(
        1,
        3,
        startR: 2,
        startC: 2,
        metric: RegionDistanceMetric.chebyshev,
      ),
      equals(1),
    );

    // 3. Linear mine calculation (base + distance)
    const base = 7;
    expect(MinesweeperConfig.calculateMinesForDistance(0, baseMines: base), equals(7));
    expect(MinesweeperConfig.calculateMinesForDistance(1, baseMines: base), equals(8));
    expect(MinesweeperConfig.calculateMinesForDistance(2, baseMines: base), equals(9));
    expect(MinesweeperConfig.calculateMinesForDistance(5, baseMines: base), equals(12));

    // 4. minesForRegion helper
    expect(
      MinesweeperConfig.minesForRegion(2, 2, startR: 2, startC: 2, baseMines: base),
      equals(7),
    );
    expect(
      MinesweeperConfig.minesForRegion(3, 3, startR: 2, startC: 2, baseMines: base),
      equals(8),
    );
    expect(
      MinesweeperConfig.minesForRegion(4, 2, startR: 2, startC: 2, baseMines: base),
      equals(8),
    );

    // 5. Rank calculations and rank-to-mine count
    expect(MinesweeperConfig.calculateRegionRank(2, 2, startR: 2, startC: 2), equals(0));
    expect(MinesweeperConfig.calculateRegionRank(2, 3, startR: 2, startC: 2), equals(1));
    expect(MinesweeperConfig.calculateRegionRank(0, 4, startR: 2, startC: 2), equals(1));
    expect(MinesweeperConfig.rankForRegion(2, 2, startR: 2, startC: 2), equals(0));
    expect(MinesweeperConfig.rankForRegion(3, 3, startR: 2, startC: 2), equals(1));
    expect(MinesweeperConfig.rankToMineCount(0, baseMines: base), equals(7));
    expect(MinesweeperConfig.rankToMineCount(1, baseMines: base), equals(8));
    expect(MinesweeperConfig.rankToMineCount(3, baseMines: base), equals(10));
  });

  testWidgets(
      'Region rank badge displays rank 0 for initial region and updates to rank 1 when navigating to adjacent region',
      (tester) async {
    final game = MinesweeperGame(lockInaccessibleRegions: false);

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

    final rankBadgeFinder = find.byKey(const ValueKey('region_rank_badge'));
    expect(rankBadgeFinder, findsOneWidget);
    expect(
      find.descendant(
        of: rankBadgeFinder,
        matching: find.text('0'),
      ),
      findsOneWidget,
    );

    // Navigate to East adjacent region via keyboard arrow
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    final dynamic state = tester.state(
      find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MinesweeperGame'),
    );
    final int currentRegionRank = state.currentRegionRank as int;

    // Rank badge now displays current region rank
    expect(
      find.descendant(
        of: rankBadgeFinder,
        matching: find.text('$currentRegionRank'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Starting region minimap cell has no border and displays masked black dot on active selection', (tester) async {
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

    // 1. Verify starting region minimap cell (Sector [3, 3]) has NO border
    final startSectorCellFinder = find.byKey(const ValueKey('minimap_sector_3_3'));
    expect(startSectorCellFinder, findsOneWidget);
    final innerAnimContainer = tester.widget<AnimatedContainer>(
      find.descendant(
        of: startSectorCellFinder,
        matching: find.byType(AnimatedContainer),
      ),
    );
    final sectorBoxDec = innerAnimContainer.decoration as BoxDecoration;
    expect(sectorBoxDec.border, isNull);

    // Verify back layer has starting region marker
    expect(find.byKey(const ValueKey('minimap_starting_region_marker')), findsOneWidget);

    // 2. Verify active minimap sector displays masked black dot over starting region
    final activeDotFinder = find.byKey(const ValueKey('active_minimap_starting_dot'));
    expect(activeDotFinder, findsOneWidget);

    final activeDotBox = tester.widget<DecoratedBox>(activeDotFinder);
    final dotDec = activeDotBox.decoration as BoxDecoration;
    expect(dotDec.color, equals(Colors.black));
    expect(dotDec.shape, equals(BoxShape.circle));

    // Verify dot is centered inside the active minimap sector
    final activeSectorFinder = find.byKey(const ValueKey('active_minimap_sector'));
    expect(activeSectorFinder, findsOneWidget);
    final sectorRect = tester.getRect(activeSectorFinder);
    final dotRect = tester.getRect(activeDotFinder);
    expect(dotRect.center.dx, closeTo(sectorRect.center.dx, 0.5));
    expect(dotRect.center.dy, closeTo(sectorRect.center.dy, 0.5));
  });

  testWidgets('Minimap only allows selecting discovered regions and prevents selecting undiscovered ones', (tester) async {
    final game = MinesweeperGame(lockInaccessibleRegions: true);

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

    final minimapFinder = find.byKey(const ValueKey('minimap_selector'));
    expect(minimapFinder, findsOneWidget);

    // Expand minimap
    await tester.tap(minimapFinder);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('active_minimap_sector_3_3')), findsOneWidget);

    // Drag helper
    Future<void> panMinimap(Offset delta) async {
      final gesture = await tester.startGesture(tester.getCenter(minimapFinder));
      final slopOffset = Offset(
        delta.dx != 0 ? (delta.dx > 0 ? 19.0 : -19.0) : 0,
        delta.dy != 0 ? (delta.dy > 0 ? 19.0 : -19.0) : 0,
      );
      await gesture.moveBy(slopOffset);
      await gesture.moveBy(delta);
      await gesture.up();
      await tester.pumpAndSettle();
    }

    // Try dragging towards undiscovered regions in all directions
    await panMinimap(const Offset(-100.0, 0));
    // Should NOT jump to undiscovered sectors (e.g. col 3 or col 4)
    expect(find.byKey(const ValueKey('active_minimap_sector_4_3')), findsNothing);
    expect(find.byKey(const ValueKey('active_minimap_sector_5_3')), findsNothing);
    expect(find.byKey(const ValueKey('active_minimap_sector_3_3')), findsOneWidget);

    await panMinimap(const Offset(100.0, 0));
    expect(find.byKey(const ValueKey('active_minimap_sector_2_3')), findsNothing);
    expect(find.byKey(const ValueKey('active_minimap_sector_1_3')), findsNothing);
    expect(find.byKey(const ValueKey('active_minimap_sector_3_3')), findsOneWidget);

    // Tap to collapse
    await tester.tap(minimapFinder);
    await tester.pumpAndSettle();

    // Still in starting region [3, 3]
    expect(find.byKey(const ValueKey('active_minimap_sector_3_3')), findsOneWidget);
  });

  testWidgets('Minimap displays and allows selecting discovered regions more than 2 and 3 distance away in infinite world', (tester) async {
    final game = MinesweeperGame(
      isInfiniteWorld: true,
      lockInaccessibleRegions: false,
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

    // Start at (2, 2) -> Sector [3, 3]
    expect(find.byKey(const ValueKey('active_minimap_sector_3_3')), findsOneWidget);

    // Navigate East 4 times -> reaches Sector [7, 3] (Col 6, Row 2: distance 4 from start Col 2)
    for (int i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const ValueKey('active_minimap_sector_7_3')), findsOneWidget);

    // 1. Expand minimap while at Sector [7, 3] (distance 4 away from start)
    final minimapFinder = find.byKey(const ValueKey('minimap_selector'));
    await tester.tap(minimapFinder);
    await tester.pumpAndSettle();

    // Sector [7, 3] (distance 4 from start) MUST be rendered and selected in minimap
    expect(find.byKey(const ValueKey('minimap_sector_7_3')), findsOneWidget);
    expect(find.byKey(const ValueKey('active_minimap_sector_7_3')), findsOneWidget);

    // Sector [6, 3] (distance 3 from start) MUST also be rendered in minimap
    expect(find.byKey(const ValueKey('minimap_sector_6_3')), findsOneWidget);

    // 2. Drag minimap to the right to move selection back towards Sector [3, 3] (distance 4 away)
    Future<void> panMinimap(Offset delta) async {
      final gesture = await tester.startGesture(tester.getCenter(minimapFinder));
      final slopOffset = Offset(
        delta.dx != 0 ? (delta.dx > 0 ? 19.0 : -19.0) : 0,
        delta.dy != 0 ? (delta.dy > 0 ? 19.0 : -19.0) : 0,
      );
      await gesture.moveBy(slopOffset);
      await gesture.moveBy(delta);
      await gesture.up();
      await tester.pumpAndSettle();
    }

    // Drag right by 4 sectors (4 * 15 = 60px) to pull starting region [3, 3] back to center
    await panMinimap(const Offset(60.0, 0));
    expect(find.byKey(const ValueKey('active_minimap_sector_3_3')), findsOneWidget);

    // 3. Tap to collapse and navigate back to starting region [3, 3] from distance 4
    await tester.tap(minimapFinder);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('active_minimap_sector_3_3')), findsOneWidget);
  });
}




