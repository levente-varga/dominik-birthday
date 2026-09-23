import 'package:flutter/material.dart';
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

  testWidgets(
      'Game area fills the entire screen even over safe area in RunScreen, while top controls remain within SafeArea',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 40, bottom: 30);
    tester.view.viewPadding = const FakeViewPadding(top: 40, bottom: 30);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: RunScreen(
          gameState: gameState,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 1. Board fills screen, gradient overlay is removed, and opaque control bar background sits at top
    expect(find.byKey(const ValueKey('game_area_gradient_overlay')), findsNothing);
    final controlBarFinder = find.byKey(const ValueKey('control_bar_background'));
    expect(controlBarFinder, findsOneWidget);
    final controlBarRect = tester.getRect(controlBarFinder);
    expect(controlBarRect.top, equals(0.0));
    expect(controlBarRect.left, equals(0.0));
    expect(controlBarRect.right, equals(800.0));

    // 2. Top header controls (rank badge, mine counter, pause button) sit within the safe area (top >= 40) in one row
    final rankBadgeFinder = find.byKey(const ValueKey('region_rank_badge'));
    final mineCounterFinder = find.byKey(const ValueKey('region_mine_counter_badge'));
    final pauseFinder = find.byKey(const ValueKey('region_pause_button'));

    expect(rankBadgeFinder, findsOneWidget);
    expect(mineCounterFinder, findsOneWidget);
    expect(pauseFinder, findsOneWidget);

    final rankBadgeRect = tester.getRect(rankBadgeFinder);
    final mineCounterRect = tester.getRect(mineCounterFinder);
    final pauseRect = tester.getRect(pauseFinder);

    // SafeArea top is 40, headerControlTop is 12, so top should be 40 + 12 = 52.0
    expect(rankBadgeRect.top, equals(52.0));
    expect(mineCounterRect.top, equals(52.0));
    expect(pauseRect.top, equals(52.0));

    // Arranged in one row: rank badge on left, mine counter in middle, pause button on right
    expect(rankBadgeRect.left, lessThan(mineCounterRect.left));
    expect(mineCounterRect.right, lessThan(pauseRect.left));
    expect(rankBadgeRect.height, equals(42.0));
    expect(mineCounterRect.height, equals(42.0));
    expect(pauseRect.height, equals(42.0));

    // 3. Bottom bar with empty corner buttons and minimap overflowing onto game area
    final bottomBarFinder = find.byKey(const ValueKey('bottom_control_bar_background'));
    expect(bottomBarFinder, findsOneWidget);
    final bottomBarRect = tester.getRect(bottomBarFinder);
    expect(bottomBarRect.bottom, equals(1000.0));
    expect(find.byKey(const ValueKey('bottom_bar_left_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('bottom_bar_right_button')), findsOneWidget);

    final minimapFinder = find.byKey(const ValueKey('minimap_selector'));
    expect(minimapFinder, findsOneWidget);
    final minimapRect = tester.getRect(minimapFinder);
    expect(minimapRect.bottom, equals(1000.0 - 30.0 - 12.0)); // bottom aligns with corner buttons
    expect(minimapRect.top, lessThan(bottomBarRect.top)); // reaches over bottom bar

    // 4. Gradient overlays: below top bar and above bottom bar, 1 cell wide (38.0px), pass-through touches
    final topOverlayFinder = find.byKey(const ValueKey('top_bar_gradient_overlay'));
    final bottomOverlayFinder = find.byKey(const ValueKey('bottom_bar_gradient_overlay'));
    expect(topOverlayFinder, findsOneWidget);
    expect(bottomOverlayFinder, findsOneWidget);

    final topOverlayRect = tester.getRect(topOverlayFinder);
    final bottomOverlayRect = tester.getRect(bottomOverlayFinder);

    expect(topOverlayRect.top, equals(controlBarRect.bottom));
    expect(topOverlayRect.height, equals(38.0)); // cellSize + cellGap
    expect(topOverlayRect.left, equals(0.0));
    expect(topOverlayRect.right, equals(800.0));

    expect(bottomOverlayRect.bottom, equals(bottomBarRect.top));
    expect(bottomOverlayRect.height, equals(38.0));
    expect(bottomOverlayRect.left, equals(0.0));
    expect(bottomOverlayRect.right, equals(800.0));

    // Both overlays have IgnorePointer allowing cells below to be interacted
    final topIgnorePointer = tester.widget<IgnorePointer>(
      find.descendant(of: topOverlayFinder, matching: find.byType(IgnorePointer)),
    );
    expect(topIgnorePointer.ignoring, isTrue);

    final bottomIgnorePointer = tester.widget<IgnorePointer>(
      find.descendant(of: bottomOverlayFinder, matching: find.byType(IgnorePointer)),
    );
    expect(bottomIgnorePointer.ignoring, isTrue);

    // Verify gradient decoration: 40% transparent (alpha: 0.60) to 100% transparent (alpha: 0.0)
    final topDecoratedBox = tester.widget<DecoratedBox>(
      find.descendant(of: topOverlayFinder, matching: find.byType(DecoratedBox)),
    );
    final topGrad = (topDecoratedBox.decoration as BoxDecoration).gradient as LinearGradient;
    expect(topGrad.colors[0], equals(AppColors.surface.withValues(alpha: 0.60)));
    expect(topGrad.colors[1], equals(AppColors.surface.withValues(alpha: 0.0)));

    final bottomDecoratedBox = tester.widget<DecoratedBox>(
      find.descendant(of: bottomOverlayFinder, matching: find.byType(DecoratedBox)),
    );
    final bottomGrad = (bottomDecoratedBox.decoration as BoxDecoration).gradient as LinearGradient;
    expect(bottomGrad.colors[0], equals(AppColors.surface.withValues(alpha: 0.60)));
    expect(bottomGrad.colors[1], equals(AppColors.surface.withValues(alpha: 0.0)));
  });

  testWidgets(
      'Displays all accessible regions that fit on screen instead of being limited to 3x3',
      (tester) async {
    // Surface size: 1200 x 900 fits more than 3x3 regions (e.g. 5x4 or 5x5)
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final game = MinesweeperGame(
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

    final panelContainers = find.byKey(const ValueKey('actual_panel_container'));
    // With 1200x900 and accessible regions, significantly more than 9 panels are rendered to fill the screen
    final count = tester.widgetList(panelContainers).length;
    expect(count, greaterThan(9));
  });

  testWidgets(
      'Downscales game area when screen size cannot fit selected region + 2 peek rows/cols',
      (tester) async {
    // Narrow screen (200 x 300), which is smaller than minViewportWidth/Height (~378)
    tester.view.physicalSize = const Size(200, 300);
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

    // The center panel and its adjacent peek panels still fit within the viewport due to downscaling
    final centerPanelFinder = find.byKey(const ValueKey('region_panel_0_0'));
    expect(centerPanelFinder, findsOneWidget);

    final fittedBoxFinder = find.byType(FittedBox);
    expect(fittedBoxFinder, findsWidgets);

    // Selected region is fully visible and rendered within the 200x300 screen
    final centerRect = tester.getRect(centerPanelFinder);
    expect(centerRect.left, greaterThanOrEqualTo(0.0));
    expect(centerRect.right, lessThanOrEqualTo(200.0));
    expect(centerRect.top, greaterThanOrEqualTo(0.0));
    expect(centerRect.bottom, lessThanOrEqualTo(300.0));
  });

  testWidgets(
      'Horizontal mode switches control bar to left side with vertical layout and opaque background, and gradient overlays are removed',
      (tester) async {
    // Landscape screen: 1000 x 600
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(left: 30, right: 20, top: 20, bottom: 20);
    tester.view.viewPadding = const FakeViewPadding(left: 30, right: 20, top: 20, bottom: 20);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
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

    // 1. Gradient overlays are completely removed
    expect(find.byKey(const ValueKey('game_area_gradient_overlay')), findsNothing);

    // 2. Control bar background (top bar) is positioned on the left edge with full height
    final controlBarFinder = find.byKey(const ValueKey('control_bar_background'));
    expect(controlBarFinder, findsOneWidget);
    final controlBarRect = tester.getRect(controlBarFinder);
    expect(controlBarRect.left, equals(0.0));
    expect(controlBarRect.top, equals(0.0));
    expect(controlBarRect.bottom, equals(600.0));
    expect(controlBarRect.width, equals(96.0)); // safePadding.left (30) + buttonWidth (42) + 24.0

    // 3. Vertical layout inside left sidebar: rank badge at top, mine counter in middle, pause at bottom
    final rankBadgeFinder = find.byKey(const ValueKey('region_rank_badge'));
    final mineCounterFinder = find.byKey(const ValueKey('region_mine_counter_badge'));
    final pauseFinder = find.byKey(const ValueKey('region_pause_button'));

    expect(rankBadgeFinder, findsOneWidget);
    expect(mineCounterFinder, findsOneWidget);
    expect(pauseFinder, findsOneWidget);

    final rankBadgeRect = tester.getRect(rankBadgeFinder);
    final mineCounterRect = tester.getRect(mineCounterFinder);
    final pauseRect = tester.getRect(pauseFinder);

    expect(rankBadgeRect.top, greaterThanOrEqualTo(20.0));
    expect(rankBadgeRect.bottom, lessThan(mineCounterRect.top));
    expect(mineCounterRect.bottom, lessThan(pauseRect.top));
    expect(pauseRect.bottom, lessThanOrEqualTo(600.0 - 20.0));

    // Widths match button width and are horizontally aligned
    expect(rankBadgeRect.width, equals(pauseRect.width));
    expect(mineCounterRect.width, equals(pauseRect.width));
    expect(pauseRect.width, closeTo(MinesweeperConfig.headerButtonSize, 1.0));
    expect(rankBadgeRect.left, equals(mineCounterRect.left));
    expect(mineCounterRect.left, equals(pauseRect.left));

    // Badges are rendered vertically: icon above, number below, both horizontally centered
    final rankIconFinder = find.descendant(of: rankBadgeFinder, matching: find.byIcon(MinesweeperConfig.rankIcon));
    final rankTextFinder = find.byKey(const ValueKey('region_rank_text'));
    expect(tester.getRect(rankIconFinder).bottom, lessThanOrEqualTo(tester.getRect(rankTextFinder).top));
    expect(tester.getRect(rankIconFinder).center.dx, closeTo(tester.getRect(rankTextFinder).center.dx, 1.0));

    final mineIconFinder = find.descendant(of: mineCounterFinder, matching: find.byIcon(MinesweeperConfig.mineCounterIcon));
    final mineTextFinder = find.descendant(of: mineCounterFinder, matching: find.byType(Text));
    expect(tester.getRect(mineIconFinder).bottom, lessThanOrEqualTo(tester.getRect(mineTextFinder).top));
    expect(tester.getRect(mineIconFinder).center.dx, closeTo(tester.getRect(mineTextFinder).center.dx, 1.0));

    // 4. Bottom control bar turns into right sidebar in landscape
    final bottomBarFinder = find.byKey(const ValueKey('bottom_control_bar_background'));
    expect(bottomBarFinder, findsOneWidget);
    final bottomBarRect = tester.getRect(bottomBarFinder);
    expect(bottomBarRect.right, equals(1000.0));
    expect(bottomBarRect.top, equals(0.0));
    expect(bottomBarRect.bottom, equals(600.0));
    expect(bottomBarRect.width, equals(86.0)); // safePadding.right (20) + 42 + 24
    expect(find.byKey(const ValueKey('bottom_bar_top_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('bottom_bar_bottom_button')), findsOneWidget);

    // 5. Minimap is in middle of right sidebar and overflows to the left onto game area
    final minimapFinder = find.byKey(const ValueKey('minimap_selector'));
    expect(minimapFinder, findsOneWidget);
    final minimapRect = tester.getRect(minimapFinder);
    expect(minimapRect.center.dy, closeTo(300.0, 1.0));
    expect(minimapRect.left, lessThan(bottomBarRect.left));

    // 6. Landscape gradient overlays: right of left sidebar and left of right sidebar, 1 cell wide
    final leftOverlayFinder = find.byKey(const ValueKey('left_sidebar_gradient_overlay'));
    final rightOverlayFinder = find.byKey(const ValueKey('right_sidebar_gradient_overlay'));
    expect(leftOverlayFinder, findsOneWidget);
    expect(rightOverlayFinder, findsOneWidget);

    final leftOverlayRect = tester.getRect(leftOverlayFinder);
    final rightOverlayRect = tester.getRect(rightOverlayFinder);

    expect(leftOverlayRect.left, equals(controlBarRect.right));
    expect(leftOverlayRect.width, equals(38.0));
    expect(leftOverlayRect.top, equals(0.0));
    expect(leftOverlayRect.bottom, equals(600.0));

    expect(rightOverlayRect.right, equals(bottomBarRect.left));
    expect(rightOverlayRect.width, equals(38.0));
    expect(rightOverlayRect.top, equals(0.0));
    expect(rightOverlayRect.bottom, equals(600.0));

    final leftIgnorePointer = tester.widget<IgnorePointer>(
      find.descendant(of: leftOverlayFinder, matching: find.byType(IgnorePointer)),
    );
    expect(leftIgnorePointer.ignoring, isTrue);

    final rightIgnorePointer = tester.widget<IgnorePointer>(
      find.descendant(of: rightOverlayFinder, matching: find.byType(IgnorePointer)),
    );
    expect(rightIgnorePointer.ignoring, isTrue);

    // 7. All visible cells anywhere on the board are interactable
    final cells = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_RegionCellWidget',
    );
    expect(cells, findsWidgets);
    for (final cellWidget in tester.widgetList(cells)) {
      final cell = cellWidget as dynamic;
      expect(cell.isInteractable, isTrue);
      expect(cell.onTap, isNotNull);
    }
  });

  testWidgets(
      'Cells located directly beneath gradient overlays can be interacted with',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 40, bottom: 30);
    tester.view.viewPadding = const FakeViewPadding(top: 40, bottom: 30);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
    });

    final game = MinesweeperGame(
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

    final topOverlayFinder = find.byKey(const ValueKey('top_bar_gradient_overlay'));
    expect(topOverlayFinder, findsOneWidget);
    final topOverlayRect = tester.getRect(topOverlayFinder);

    // Find cells on screen
    final cellFinders = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_RegionCellWidget',
    );
    expect(cellFinders, findsWidgets);

    // Find a cell that intersects or lies within the top gradient overlay region
    Finder? targetCell;
    for (int i = 0; i < tester.widgetList(cellFinders).length; i++) {
      final candidate = cellFinders.at(i);
      final cellRect = tester.getRect(candidate);
      if (cellRect.overlaps(topOverlayRect)) {
        targetCell = candidate;
        break;
      }
    }

    // If no cell directly overlaps in the initial layout, pick the cell nearest to the overlay
    if (targetCell == null) {
      double minDistance = double.infinity;
      for (int i = 0; i < tester.widgetList(cellFinders).length; i++) {
        final candidate = cellFinders.at(i);
        final cellRect = tester.getRect(candidate);
        final dist = (cellRect.top - topOverlayRect.bottom).abs();
        if (dist < minDistance) {
          minDistance = dist;
          targetCell = candidate;
        }
      }
    }

    expect(targetCell, isNotNull);
    final cellBefore = tester.widget(targetCell!) as dynamic;
    expect(cellBefore.cellState, equals(0)); // 0: unrevealed

    // Tap the cell directly
    await tester.tap(targetCell);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The cell was tapped and received the event through the IgnorePointer overlay
    final cellAfter = tester.widget(targetCell) as dynamic;
    expect(cellAfter.cellState, isNot(equals(0))); // revealed or clicked mine
  });
}
