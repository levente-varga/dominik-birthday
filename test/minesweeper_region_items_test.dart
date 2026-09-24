import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dominik/config/config.dart';
import 'package:dominik/game_state.dart';
import 'package:dominik/games/minesweeper.dart';
import 'package:dominik/save_system.dart';

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

  group('MinesweeperConfig Item Spawn & Center-Weighted Scoring', () {
    test('itemSpawnChanceForRank increases as rank increases', () {
      final chance0 = MinesweeperConfig.itemSpawnChanceForRank(0);
      final chance1 = MinesweeperConfig.itemSpawnChanceForRank(1);
      final chance2 = MinesweeperConfig.itemSpawnChanceForRank(2);
      final chance5 = MinesweeperConfig.itemSpawnChanceForRank(5);

      expect(chance0, greaterThanOrEqualTo(0.0));
      expect(chance1, greaterThan(chance0));
      expect(chance2, greaterThan(chance1));
      expect(chance5, greaterThan(chance2));
      expect(MinesweeperConfig.itemSpawnChanceForRank(-1), equals(0.0));
      expect(MinesweeperConfig.itemSpawnChanceForRank(100), lessThanOrEqualTo(1.0));
    });

    test('itemSpawnChanceForRankFunction can be plugged/overridden', () {
      final originalFn = MinesweeperConfig.itemSpawnChanceForRankFunction;
      addTearDown(() {
        MinesweeperConfig.itemSpawnChanceForRankFunction = originalFn;
      });

      MinesweeperConfig.itemSpawnChanceForRankFunction = (rank) => 0.42;
      expect(MinesweeperConfig.itemSpawnChanceForRankFunction(0), equals(0.42));
      expect(MinesweeperConfig.itemSpawnChanceForRankFunction(10), equals(0.42));
    });

    test('centerWeightedCellScore gives higher weight to center cells than outer cells', () {
      const rows = 5;
      const cols = 5;
      // Center cell is (2, 2)
      final centerScore = MinesweeperConfig.centerWeightedCellScore(2, 2, rows, cols);
      // Inner ring cell is (2, 1)
      final ringScore = MinesweeperConfig.centerWeightedCellScore(2, 1, rows, cols);
      // Corner cell is (0, 0)
      final cornerScore = MinesweeperConfig.centerWeightedCellScore(0, 0, rows, cols);

      expect(centerScore, greaterThan(ringScore));
      expect(ringScore, greaterThan(cornerScore));
      // Outermost cell must still have score > 0
      expect(cornerScore, greaterThan(0.0));
    });
  });

  group('Region Item Placement & Center Bias', () {
    test('Item is always placed on an empty cell (never on a mine)', () {
      final rng = Random(42);
      for (int trial = 0; trial < 20; trial++) {
        final region = RegionData(
          r: 2,
          c: 2,
          rows: 5,
          cols: 5,
          itemType: InventoryItemType.shield,
        );
        // Place some mines manually
        region.mines[0] = 1;
        region.mines[1] = 1;
        region.mines[12] = 1; // Center is a mine in this trial
        region.mineCount = 3;

        // Simulate item placement
        final totalCells = region.rows * region.cols;
        final safeIndices = <int>[];
        final weights = <double>[];
        double totalWeight = 0.0;
        for (int i = 0; i < totalCells; i++) {
          if (region.mines[i] == 0) {
            safeIndices.add(i);
            final lr = i ~/ region.cols;
            final lc = i % region.cols;
            final w = MinesweeperConfig.centerWeightedCellScore(lr, lc, region.rows, region.cols);
            weights.add(w);
            totalWeight += w;
          }
        }
        final roll = rng.nextDouble() * totalWeight;
        double cumulative = 0.0;
        int chosen = safeIndices.first;
        for (int j = 0; j < safeIndices.length; j++) {
          cumulative += weights[j];
          if (roll <= cumulative) {
            chosen = safeIndices[j];
            break;
          }
        }
        region.itemCellIndex = chosen;

        expect(region.mines[region.itemCellIndex!], equals(0));
      }
    });

    test('Item placement is more likely towards center than corners over many trials', () {
      const rows = 5;
      const cols = 5;
      const totalCells = rows * cols;
      final rng = Random(999);

      int centerHits = 0; // cell (2, 2)
      int cornerHits = 0; // cell (0, 0)

      for (int i = 0; i < 5000; i++) {
        final safeIndices = List.generate(totalCells, (idx) => idx);
        final weights = <double>[];
        double totalWeight = 0.0;
        for (final idx in safeIndices) {
          final lr = idx ~/ cols;
          final lc = idx % cols;
          final w = MinesweeperConfig.centerWeightedCellScore(lr, lc, rows, cols);
          weights.add(w);
          totalWeight += w;
        }

        final roll = rng.nextDouble() * totalWeight;
        double cumulative = 0.0;
        int chosen = safeIndices.first;
        for (int j = 0; j < safeIndices.length; j++) {
          cumulative += weights[j];
          if (roll <= cumulative) {
            chosen = safeIndices[j];
            break;
          }
        }

        if (chosen == 12) centerHits++; // (2, 2)
        if (chosen == 0) cornerHits++; // (0, 0)
      }

      // Center should have noticeably more hits than a single corner
      expect(centerHits, greaterThan(cornerHits * 2));
    });
  });

  group('Region Sparkling Projectiles', () {
    testWidgets('Spawns sparkles on region containing unfound item and removes them once found', (tester) async {
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
        enableContinuousSparklesInTests: false,
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

      // Explicitly set an item on region (2, 2) at local cell index 0 (0, 0)
      state.setRegionItem(2, 2, InventoryItemType.shield, 0);
      await tester.pump();

      // Sparkles widget must be active for region (2, 2)
      final sparklesFinder = find.byKey(const ValueKey('region_sparkles_2_2'));
      expect(sparklesFinder, findsOneWidget);

      final dynamic sparklesWidget = tester.widget(sparklesFinder);
      expect(sparklesWidget.active, isTrue);

      // Uncover cell (0, 0) containing the chest
      state.handleCellTap(2, 2, 0, 0);
      await tester.pump();

      // Chest is visible on revealed cell, and still unopened
      final region = state.regions[(2, 2)];
      expect(region.chestOpened, isFalse);
      expect(region.hasItem, isTrue);
      expect(find.byKey(const ValueKey('cell_chest_icon')), findsOneWidget);

      // Sparkles are still active while chest is unopened
      expect(find.byKey(const ValueKey('region_sparkles_2_2')), findsOneWidget);

      // Now tap the chest cell to open it!
      state.handleCellTap(2, 2, 0, 0);
      await tester.pumpAndSettle();

      // Chest popup is now shown
      expect(find.byKey(const ValueKey('chest_reward_popup_container')), findsOneWidget);
      expect(region.chestOpened, isTrue);
      expect(region.hasItem, isFalse);

      // Close popup by picking option
      await tester.tap(find.text('CLAIM').first);
      await tester.pumpAndSettle();

      // Sparkles layer is removed / inactive
      expect(find.byKey(const ValueKey('region_sparkles_2_2')), findsNothing);
    });

    testWidgets('Region sparkles and particles do NOT reset during navigation/traversal', (tester) async {
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
        lockInaccessibleRegions: false,
        enableContinuousSparklesInTests: true,
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final dynamic state = tester.state(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MinesweeperGame'),
      );

      // Explicitly set an item on adjacent region (2, 3) at cell (0, 0)
      state.setRegionItem(2, 3, InventoryItemType.shield, 0);
      await tester.pump();

      // Sparkles widget must be active for region (2, 3)
      final sparklesFinder = find.byKey(const ValueKey('region_sparkles_2_3'));
      expect(sparklesFinder, findsOneWidget);

      final region23 = state.regions[(2, 3)];
      expect(region23.sparkleParticles, isNotNull);
      expect(region23.sparkleParticles!.length, equals(14));
      final initialParticlesList = region23.sparkleParticles!;

      // Pick particle with lowest initial life so it does not wrap around (>1.2s lifespan)
      SparkleParticle testParticle = initialParticlesList.first;
      for (final p in initialParticlesList) {
        if (p.life < testParticle.life) {
          testParticle = p;
        }
      }
      final initialLife = testParticle.life;
      final initialX = testParticle.x;
      final initialY = testParticle.y;

      // Pump several frames so particles advance
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 32));
      }

      final midLife = testParticle.life;
      final midX = testParticle.x;
      final midY = testParticle.y;
      expect(midLife, greaterThan(initialLife));
      expect(midX != initialX || midY != initialY, isTrue);

      // Now navigate east into region (2, 3)
      state.navigateRegion(0, 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Region (2, 3) is now active center region; sparkles widget is still rendered
      expect(find.byKey(const ValueKey('region_sparkles_2_3')), findsOneWidget);

      // Particles must NOT have reset to initialLife or initial coordinates!
      expect(identical(region23.sparkleParticles, initialParticlesList), isTrue);
      final postNavLife = testParticle.life;
      expect(postNavLife, greaterThanOrEqualTo(midLife));
      expect(postNavLife, greaterThan(initialLife));
    });
  });

  group('Discovered Item Flight to Free Inventory Slot', () {
    testWidgets('Uncovered item flies into the first free inventory slot', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Start with empty slot 0 and filled slot 1
      final game = MinesweeperGame(
        initialRegionX: 2,
        initialRegionY: 2,
        isInfiniteWorld: false,
        initialInventory: [null, InventoryItemType.flagObvious],
        enableContinuousSparklesInTests: false,
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

      expect(state.inventory[0], isNull);
      expect(state.inventory[1], equals(InventoryItemType.flagObvious));

      // Configure region (2, 2) to have a Shield at (1, 1)
      final targetIdx = state.regions[(2, 2)].localIndex(1, 1);
      state.setRegionItem(2, 2, InventoryItemType.shield, targetIdx);
      await tester.pump();

      // Uncover cell (1, 1) to reveal chest
      state.handleCellTap(2, 2, 1, 1);
      await tester.pump();
      expect(find.byKey(const ValueKey('cell_chest_icon')), findsOneWidget);

      // Open chest and pick Shield item
      state.openChest(2, 2, optionToPick: ChestRewardOption.item(InventoryItemType.shield));
      await tester.pump();

      // An active item flight must be started targeting slot 0
      expect(state.activeItemFlights.length, equals(1));
      expect(state.activeItemFlights[0].targetSlot, equals(0));
      expect(state.activeItemFlights[0].itemType, equals(InventoryItemType.shield));

      // Verify FlyingItemOverlayWidget is in widget tree
      expect(find.byType(FlyingItemOverlayWidget), findsOneWidget);

      // Advance through appearance delay and flight duration
      await tester.pump(MinesweeperConfig.itemAppearanceDelay);
      await tester.pump(MinesweeperConfig.itemFlightDuration + const Duration(milliseconds: 50));

      // After flight completes, slot 0 now has Shield!
      expect(state.inventory[0], equals(InventoryItemType.shield));
      expect(state.activeItemFlights, isEmpty);
      expect(find.byType(FlyingItemOverlayWidget), findsNothing);
    });

    testWidgets('Uncovered item targets slot 1 when slot 0 is already occupied', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Start with Shield in slot 0, empty slot 1
      final game = MinesweeperGame(
        initialRegionX: 2,
        initialRegionY: 2,
        isInfiniteWorld: false,
        initialInventory: [InventoryItemType.shield, null],
        enableContinuousSparklesInTests: false,
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

      expect(state.inventory[0], equals(InventoryItemType.shield));
      expect(state.inventory[1], isNull);

      // Place Flag Obvious item at cell (1, 1)
      final targetIdx = state.regions[(2, 2)].localIndex(1, 1);
      state.setRegionItem(2, 2, InventoryItemType.flagObvious, targetIdx);
      await tester.pump();

      // Uncover cell to reveal chest
      state.handleCellTap(2, 2, 1, 1);
      await tester.pump();
      expect(find.byKey(const ValueKey('cell_chest_icon')), findsOneWidget);

      // Open chest and pick Flag Obvious item
      state.openChest(2, 2, optionToPick: ChestRewardOption.item(InventoryItemType.flagObvious));
      await tester.pump();

      expect(state.activeItemFlights.length, equals(1));
      expect(state.activeItemFlights[0].targetSlot, equals(1));

      await tester.pump(MinesweeperConfig.itemAppearanceDelay);
      await tester.pump(MinesweeperConfig.itemFlightDuration + const Duration(milliseconds: 50));

      // Slot 1 has Flag Obvious now
      expect(state.inventory[1], equals(InventoryItemType.flagObvious));
      expect(state.inventory[0], equals(InventoryItemType.shield));
    });
  });

  group('Full Inventory Item Loss (Scale Up, Fade Out & Vanish)', () {
    testWidgets('When inventory is full, item scales up, fades out, and is lost', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Default inventory: both slots full [shield, flagObvious]
      final game = MinesweeperGame(
        initialRegionX: 2,
        initialRegionY: 2,
        isInfiniteWorld: false,
        initialInventory: [InventoryItemType.shield, InventoryItemType.flagObvious],
        enableContinuousSparklesInTests: false,
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

      expect(state.inventory[0], equals(InventoryItemType.shield));
      expect(state.inventory[1], equals(InventoryItemType.flagObvious));

      // Put an item on cell (1, 1)
      final targetIdx = state.regions[(2, 2)].localIndex(1, 1);
      state.setRegionItem(2, 2, InventoryItemType.shield, targetIdx);
      await tester.pump();

      // Uncover cell to reveal chest
      state.handleCellTap(2, 2, 1, 1);
      await tester.pump();
      expect(find.byKey(const ValueKey('cell_chest_icon')), findsOneWidget);

      // Open chest and pick Shield item
      state.openChest(2, 2, optionToPick: ChestRewardOption.item(InventoryItemType.shield));
      await tester.pump();

      // Target slot must be null because inventory has no free slot!
      expect(state.activeItemFlights.length, equals(1));
      expect(state.activeItemFlights[0].targetSlot, isNull);

      // FlyingItemOverlayWidget is rendered
      expect(find.byType(FlyingItemOverlayWidget), findsOneWidget);

      // Advance through delay and vanish duration
      await tester.pump(MinesweeperConfig.itemAppearanceDelay);
      await tester.pump(MinesweeperConfig.itemVanishDuration + const Duration(milliseconds: 50));

      // Active flight finishes, overlay disappears, inventory unchanged (item lost)
      expect(state.activeItemFlights, isEmpty);
      expect(find.byType(FlyingItemOverlayWidget), findsNothing);
      expect(state.inventory[0], equals(InventoryItemType.shield));

      expect(state.inventory[1], equals(InventoryItemType.flagObvious));
    });
  });

  group('Chest Rewards & 2-Option Picking System', () {
    test('generateTwoUniqueOptions always returns two distinct options', () {
      final rng = Random(12345);
      for (int trial = 0; trial < 100; trial++) {
        final options = ChestRewardOption.generateTwoUniqueOptions(
          rng,
          currentRegion: (0, 0),
          rank: 2,
        );
        expect(options.length, equals(2));
        expect(options[0].title, isNot(equals(options[1].title)));
        expect(options[0].categoryLabel, isNot(equals(options[1].categoryLabel)));
      }
    });

    testWidgets('Tapping revealed chest shows popup with 2 options, and picking Money awards tokens', (tester) async {
      final game = MinesweeperGame(
        initialRegionX: 2,
        initialRegionY: 2,
        isInfiniteWorld: false,
        enableContinuousSparklesInTests: false,
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

      // Place chest at cell (0, 0)
      state.setRegionChest(2, 2, 0);
      await tester.pump();

      // Uncover cell (0, 0) -> chest appears
      state.handleCellTap(2, 2, 0, 0);
      await tester.pump();
      expect(find.byKey(const ValueKey('cell_chest_icon')), findsOneWidget);

      // Tap revealed chest -> open popup
      state.handleCellTap(2, 2, 0, 0);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('chest_reward_popup_container')), findsOneWidget);
      expect(find.text('CLAIM'), findsNWidgets(2));

      // Dismiss popup by claiming first reward option
      await tester.tap(find.text('CLAIM').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chest_reward_popup_container')), findsNothing);

      // Verify picking Money explicitly awards tokens
      final tokensBeforeMoney = gameState.tokens;
      state.setRegionChest(2, 3, 0);
      state.openChest(2, 3, optionToPick: ChestRewardOption.money(25));
      await tester.pump();

      expect(gameState.tokens, equals(tokensBeforeMoney + 25));
    });

    testWidgets('Quest option marks region on map/minimap with "!" and awards tokens on arrival', (tester) async {
      final initialTokens = gameState.tokens;

      final game = MinesweeperGame(
        initialRegionX: 2,
        initialRegionY: 2,
        isInfiniteWorld: false,
        lockInaccessibleRegions: false,
        enableContinuousSparklesInTests: false,
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

      // Pick quest targeting region (2, 3)
      state.setRegionChest(2, 2, 0);
      state.openChest(2, 2, optionToPick: ChestRewardOption.quest(const (2, 3)));
      await tester.pump();

      expect(state.questRegions, contains(const (2, 3)));

      // Quest marker beacon '!' is in widget tree
      expect(find.byKey(const ValueKey('region_quest_marker_2_3')), findsOneWidget);

      // Navigate into region (2, 3)
      state.navigateRegion(0, 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Quest completed upon reaching region!
      expect(state.questRegions, isNot(contains(const (2, 3))));
      expect(gameState.tokens, equals(initialTokens + 50));
    });

    testWidgets('Hint option marks distant region on minimap with "?"', (tester) async {
      final game = MinesweeperGame(
        initialRegionX: 2,
        initialRegionY: 2,
        isInfiniteWorld: false,
        enableContinuousSparklesInTests: false,
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

      // Pick hint targeting region (3, 4)
      state.setRegionChest(2, 2, 0);
      state.openChest(2, 2, optionToPick: ChestRewardOption.hint(const (3, 4)));
      await tester.pump();

      expect(state.hintRegions, contains(const (3, 4)));
    });

    testWidgets('Boon option increments activeBoonRankBonus', (tester) async {
      final game = MinesweeperGame(
        initialRegionX: 2,
        initialRegionY: 2,
        isInfiniteWorld: false,
        enableContinuousSparklesInTests: false,
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

      expect(state.activeBoonRankBonus, equals(0));

      // Pick boon
      state.setRegionChest(2, 2, 0);
      state.openChest(
        2,
        2,
        optionToPick: ChestRewardOption.boon('Ancient Boon', 'Increases difficulty and spoils'),
      );
      await tester.pump();

      expect(state.activeBoonRankBonus, equals(1));
    });
  });
}
