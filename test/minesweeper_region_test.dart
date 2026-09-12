import 'dart:ui' as ui;
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

  testWidgets('Clicking on the minimap opens empty popup dialog matching main menu popups', (tester) async {
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

    // Find the minimap selector in top right corner
    final minimapFinder = find.byKey(const ValueKey('minimap_selector'));
    expect(minimapFinder, findsOneWidget);

    // Tap on the minimap
    await tester.tap(minimapFinder);
    await tester.pumpAndSettle();

    // Verify empty popup is shown matching main menu popup structure
    expect(find.byKey(const ValueKey('minimap_popup_container')), findsOneWidget);
    final closeBtn = find.byIcon(Icons.close_rounded);
    expect(closeBtn, findsOneWidget);

    // Close popup
    await tester.tap(closeBtn);
    await tester.pumpAndSettle();

    // Verify popup is dismissed
    expect(find.byKey(const ValueKey('minimap_popup_container')), findsNothing);
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

  testWidgets('Neighbor cells are wrapped in IgnorePointer and are not interactable', (tester) async {
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

    // Verify neighbor cells have null callbacks and cannot be interacted with
    for (final neighbor in tester.widgetList(neighborWidgets)) {
      expect((neighbor as dynamic).onTap, isNull);
      expect((neighbor as dynamic).onLongPress, isNull);
    }
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
    await tester.pumpAndSettle();

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

  testWidgets('Game area gradient overlay is rendered on top of the entire board area, leaving centered active region unaffected', (tester) async {
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

    // Exactly 1 game_area_gradient_overlay exists on top of the board
    final overlayFinder = find.byKey(const ValueKey('game_area_gradient_overlay'));
    expect(overlayFinder, findsOneWidget);

    // Overlays per region panel are removed
    expect(find.byKey(const ValueKey('panel_gradient_overlay')), findsNothing);

    // Verify CustomPaint with GameAreaGradientPainter
    final customPaint = tester.widget<CustomPaint>(overlayFinder);
    expect(customPaint.painter, isA<GameAreaGradientPainter>());
    final painter = customPaint.painter! as GameAreaGradientPainter;

    expect(painter.nearAlpha, equals(0.0));
    expect(painter.farAlpha, equals(1.0));
    expect(painter.style, equals(OverlayGradientStyle.splitLinear));

    // Center cutout width and height match panelWidth and panelHeight
    final activeGridWidth = MinesweeperConfig.regionCols *
        (MinesweeperConfig.cellSize + MinesweeperConfig.cellGap);
    final activeGridHeight = MinesweeperConfig.regionRows *
        (MinesweeperConfig.cellSize + MinesweeperConfig.cellGap);
    final expectedPanelWidth =
        activeGridWidth + (MinesweeperConfig.boardPadding * 2) + 3.0; // borderWidth * 2
    final expectedPanelHeight =
        activeGridHeight + (MinesweeperConfig.boardPadding * 2) + 3.0;

    expect(painter.centerRect.width, closeTo(expectedPanelWidth, 0.01));
    expect(painter.centerRect.height, closeTo(expectedPanelHeight, 0.01));

    // Center panel remains fully interactable and unaffected while centered
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
      'Entire neighbor panels are rendered underneath game area gradient overlay with diagonally split corners',
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

    // Old per-panel overlays are removed
    expect(find.byKey(const ValueKey('panel_gradient_overlay')), findsNothing);

    // The single game area gradient overlay sits atop all panels
    expect(find.byKey(const ValueKey('game_area_gradient_overlay')), findsOneWidget);

    // Verify painter draws split linear gradients without throwing
    final customPaint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('game_area_gradient_overlay')),
    );
    final painter = customPaint.painter! as GameAreaGradientPainter;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, const Size(557, 557));
    final picture = recorder.endRecording();
    expect(picture, isNotNull);

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

    // In the newly active region: 9 actual containers, game area overlay persists
    expect(find.byKey(const ValueKey('actual_panel_container')), findsNWidgets(9));
    expect(find.byKey(const ValueKey('game_area_gradient_overlay')), findsOneWidget);
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
      'Neighbor regions are faded to 50% opacity, and swipe cross-fades current (0% to 50% transparency) and incoming (50% to 0% transparency)',
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
    // 1. Current selected region has opacity 1.0 (0% transparency)
    final currentPanelOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('region_panel_0_0')),
        matching: find.byType(Opacity),
      ).first,
    );
    expect(currentPanelOpacity.opacity, equals(1.0));

    // 2. Neighbor regions are faded to 50% opacity (50% transparency)
    final eastNeighborOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('region_panel_0_1')),
        matching: find.byType(Opacity),
      ).first,
    );
    expect(eastNeighborOpacity.opacity, equals(0.50));

    final northNeighborOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('region_panel_-1_0')),
        matching: find.byType(Opacity),
      ).first,
    );
    expect(northNeighborOpacity.opacity, equals(0.50));

    // 3. While dragging below threshold (e.g. -30px, where swipeThreshold is 50.0):
    final gesture = await tester.startGesture(const Offset(250, 250));
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();

    // No proportional fade occurs while dragging under threshold:
    // Current region stays at 1.0 opacity (0% transparency)
    // Incoming region stays at 0.50 opacity (50% transparency)
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
    expect(underThresholdIncomingOpacity.opacity, equals(0.50));
    expect(activeSector(3, 3), findsOneWidget);

    // 4. Drag reaches and goes over threshold (move -40px further to -70px total, threshold is 64):
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    // Mid-animation:
    await tester.pump(const Duration(milliseconds: 100));
    final midFadeCurrentOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('region_panel_0_0')),
        matching: find.byType(Opacity),
      ).first,
    );
    expect(midFadeCurrentOpacity.opacity, lessThan(1.0));
    expect(midFadeCurrentOpacity.opacity, greaterThan(0.50));

    // Full animation completes while user's finger is still down!
    await tester.pump(const Duration(milliseconds: 150));
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
    expect(flippedCurrentOpacity.opacity, equals(0.50));
    expect(flippedIncomingOpacity.opacity, equals(1.0));
    // Minimap selected region flipped to Sector [4, 3]!
    expect(activeSector(4, 3), findsOneWidget);

    // Other neighbors stay at 50% opacity
    final draggingOtherNeighborOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('region_panel_-1_0')),
        matching: find.byType(Opacity),
      ).first,
    );
    expect(draggingOtherNeighborOpacity.opacity, equals(0.50));

    // 5. Cancel traversal by dragging back below threshold (drag +50px, delta is now -20px):
    await gesture.moveBy(const Offset(50, 0));
    await tester.pump();
    // Mid-reverse:
    await tester.pump(const Duration(milliseconds: 100));
    // Reverse animation completes:
    await tester.pump(const Duration(milliseconds: 150));
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
    expect(reversedIncomingOpacity.opacity, equals(0.50));
    // Minimap selected region flipped back to Sector [3, 3]!
    expect(activeSector(3, 3), findsOneWidget);

    // 6. Drag over threshold again (move -60px, delta is now -80px) and complete traversal:
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pumpAndSettle();
    expect(activeSector(4, 3), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    // In newly active region:
    // New center region (0, 0) is at 1.0 opacity
    final newCenterOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('region_panel_0_0')),
        matching: find.byType(Opacity),
      ).first,
    );
    expect(newCenterOpacity.opacity, equals(1.0));

    // Old center region (now west neighbor (0, -1)) is at 0.50 opacity
    final oldCenterOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('region_panel_0_-1')),
        matching: find.byType(Opacity),
      ).first,
    );
    expect(oldCenterOpacity.opacity, equals(0.50));
    expect(activeSector(4, 3), findsOneWidget);
  });

  testWidgets(
      'Cells cannot be revealed or flagged while panel is animating, and neighbor cells cannot be interacted with',
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

    // 1. Neighbor cells cannot be interacted with when board is at rest
    final neighborFinder = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == true,
    );
    expect(neighborFinder, findsWidgets);
    final firstNeighbor = tester.widget(neighborFinder.first);
    expect((firstNeighbor as dynamic).isInteractable, isFalse);

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
      'OverlayGradientStyle.radial alternative renders radial gradient without throwing and handles region navigation',
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

    final overlayFinder = find.byKey(const ValueKey('game_area_gradient_overlay'));
    expect(overlayFinder, findsOneWidget);

    final customPaint = tester.widget<CustomPaint>(overlayFinder);
    final painter = customPaint.painter! as GameAreaGradientPainter;
    expect(painter.style, equals(OverlayGradientStyle.radial));

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, const Size(557, 557));
    final picture = recorder.endRecording();
    expect(picture, isNotNull);

    // Verify directional swipe works under radial overlay
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
      'Newly unlocked neighbor region fades in smoothly from 0.0 opacity to neighbor base opacity',
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
    expect(midOpacity, lessThan(0.50));

    // Complete the animation
    await tester.pumpAndSettle();
    expect(getEastPanelOpacity(), equals(0.50));
  });

  testWidgets(
      'Minimap is centered, mine counter left-aligned, and pause button right-aligned with resting region, remaining stationary during swipe',
      (tester) async {
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
    final mineCounterFinder =
        find.byKey(const ValueKey('region_mine_counter_badge'));
    final minimapFinder = find.byKey(const ValueKey('minimap_selector'));
    final pauseButtonFinder = find.byKey(const ValueKey('region_pause_button'));

    expect(centerPanelFinder, findsOneWidget);
    expect(mineCounterFinder, findsOneWidget);
    expect(minimapFinder, findsOneWidget);
    expect(pauseButtonFinder, findsOneWidget);

    final panelRect = tester.getRect(centerPanelFinder);
    final mineCounterRect = tester.getRect(mineCounterFinder);
    final minimapRect = tester.getRect(minimapFinder);
    final pauseButtonRect = tester.getRect(pauseButtonFinder);

    // Left edge of mine counter aligns with left edge of resting selected region
    expect(mineCounterRect.left, equals(panelRect.left));

    // Minimap is centered with resting selected region
    expect(minimapRect.center.dx, closeTo(panelRect.center.dx, 0.5));

    // Right edge of pause button aligns with right edge of resting selected region
    expect(pauseButtonRect.right, equals(panelRect.right));

    // All sit aligned at the same top position
    expect(mineCounterRect.top, equals(minimapRect.top));
    expect(pauseButtonRect.top, equals(minimapRect.top));

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
    expect(pauseDecoration.border, equals(mineCounterDecoration.border));
    expect(pauseDecoration.color, equals(mineCounterDecoration.color));
    expect(
      pauseDecoration.borderRadius,
      equals(mineCounterDecoration.borderRadius),
    );

    // Pause button and mine counter button have the same height, and pause button is square
    final mineCounterSize = tester.getSize(mineCounterFinder);
    final pauseButtonSize = tester.getSize(pauseButtonFinder);
    expect(pauseButtonSize.height, equals(mineCounterSize.height));
    expect(pauseButtonSize.width, equals(pauseButtonSize.height));
    // Mine counter badge fits its content rather than stretching across the entire available half-width
    expect(mineCounterSize.width, lessThan((panelRect.width - minimapRect.width) / 2));

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
    expect(mineCounterDuringDrag.left, equals(panelRect.left));
    expect(minimapDuringDrag.center.dx, closeTo(panelRect.center.dx, 0.5));
    expect(pauseButtonDuringDrag.right, equals(panelRect.right));

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

    // Back layer does NOT show white for selected region (shows greenMedium for revealed cell, panelHigh for neighbor)
    expect(backLayerColor(3, 3), equals(AppColors.greenMedium));
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
    expect(currentOp.opacity, equals(0.50));
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
    expect(incomingOp.opacity, equals(0.50));

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
    expect(currentOp.opacity, equals(0.50));
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
    expect(incomingOp.opacity, equals(0.50));

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
    expect(defaultDecoration.borderRadius, equals(BorderRadius.circular(14.0)));

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

  testWidgets('Clearing a region completes stage in infinite world when regionsToWin is 1', (tester) async {
    bool stageCompleted = false;

    final game = MinesweeperGame(
      regionsToWin: 1,
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

    // With all safe cells revealed and 0 mines to flag, region is cleared and onComplete triggers
    expect(stageCompleted, isTrue);
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

  testWidgets('All regions have the exact same amount of mines', (tester) async {
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

    // Trigger initial click to generate starting region and its 8 neighbors
    final mainCells = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_RegionCellWidget' &&
          (widget as dynamic).isNeighbor == false,
    );
    await tester.tap(mainCells.at(24));
    await tester.pumpAndSettle();

    // Verify all generated regions have exactly targetMines
    expect(regions.length, greaterThanOrEqualTo(9));
    for (final entry in regions.entries) {
      if (entry.value.isGenerated as bool) {
        final mineList = entry.value.mines as List<int>;
        final count = mineList.where((m) => m == 1).length;
        expect(count, equals(targetMines),
            reason: 'Region at ${entry.key} should have exactly $targetMines mines');
        expect(entry.value.mineCount, equals(targetMines));
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
    await tester.pumpAndSettle();

    // 4. Verify that chording affected and revealed the cell in the neighboring region!
    expect(
      eastRegion.cellStates[eastRegion.localIndex(3, 0)],
      equals(CellState.revealed),
      reason: 'Cell (3, 0) in neighboring East region should be revealed by chording',
    );
  });
}




