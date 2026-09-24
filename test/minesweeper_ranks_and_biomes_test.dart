import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dominik/config/config.dart';
import 'package:dominik/game_state.dart';
import 'package:dominik/save_system.dart';
import 'package:dominik/games/minesweeper.dart';
import 'package:dominik/games/minesweeper/perlin_noise.dart';

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

  group('Randomized Ranks & Distance Scaling', () {
    test('rollRankForDistance returns 0 for distance <= 0', () {
      expect(MinesweeperConfig.rollRankForDistance(0), equals(0));
      expect(MinesweeperConfig.rollRankForDistance(-1), equals(0));
    });

    test('rollRankForDistance shifts probability towards higher ranks as distance increases', () {
      final rng = Random(42);
      const samples = 1000;

      double avgDist1 = 0;
      double avgDist3 = 0;
      double avgDist6 = 0;

      for (int i = 0; i < samples; i++) {
        avgDist1 += MinesweeperConfig.rollRankForDistance(1, random: rng);
        avgDist3 += MinesweeperConfig.rollRankForDistance(3, random: rng);
        avgDist6 += MinesweeperConfig.rollRankForDistance(6, random: rng);
      }

      avgDist1 /= samples;
      avgDist3 /= samples;
      avgDist6 /= samples;

      expect(avgDist1, greaterThanOrEqualTo(0.5));
      expect(avgDist3, greaterThan(avgDist1));
      expect(avgDist6, greaterThan(avgDist3));
    });

    test('biomeSpawnChanceForRank returns 0 for rank <= 0 and increases with rank', () {
      expect(MinesweeperConfig.biomeSpawnChanceForRank(0), equals(0.0));
      expect(MinesweeperConfig.biomeSpawnChanceForRank(-1), equals(0.0));

      final chanceRank1 = MinesweeperConfig.biomeSpawnChanceForRank(1);
      final chanceRank2 = MinesweeperConfig.biomeSpawnChanceForRank(2);
      final chanceRank3 = MinesweeperConfig.biomeSpawnChanceForRank(3);
      final chanceRank4 = MinesweeperConfig.biomeSpawnChanceForRank(4);

      expect(chanceRank1, greaterThan(0.0));
      expect(chanceRank2, greaterThan(chanceRank1));
      expect(chanceRank3, greaterThan(chanceRank2));
      expect(chanceRank4, greaterThan(chanceRank3));
    });
  });

  group('MinesweeperWorldGenerator Blob Invariants', () {
    test('Every region in a finite grid belongs to a rank blob of size >= 2', () {
      for (int seed = 0; seed < 10; seed++) {
        final generator = MinesweeperWorldGenerator(
          initialRegionX: 2,
          initialRegionY: 2,
          regionsX: 5,
          regionsY: 5,
          isInfiniteWorld: false,
          random: Random(seed),
        );
        generator.pregenerateGrid(5, 5);

        for (int r = 0; r < 5; r++) {
          for (int c = 0; c < 5; c++) {
            final rank = generator.assignedRanks[(r, c)]!;
            if (r == 2 && c == 2) {
              expect(rank, equals(0), reason: 'Starting region must be rank 0');
              continue;
            }
            final neighbors = [
              (r - 1, c),
              (r + 1, c),
              (r, c - 1),
              (r, c + 1),
            ].where((n) => n.$1 >= 0 && n.$1 < 5 && n.$2 >= 0 && n.$2 < 5);

            final hasPartner = neighbors.any((n) => generator.assignedRanks[n] == rank);
            expect(
              hasPartner,
              isTrue,
              reason: 'Seed $seed: Region ($r, $c) with rank $rank must have at least one neighbor of same rank',
            );
          }
        }
      }
    });

    test('Every Unknown biome in a finite grid belongs to a biome blob of size >= 2', () {
      for (int seed = 0; seed < 10; seed++) {
        final generator = MinesweeperWorldGenerator(
          initialRegionX: 2,
          initialRegionY: 2,
          regionsX: 5,
          regionsY: 5,
          isInfiniteWorld: false,
          random: Random(seed),
        );
        generator.pregenerateGrid(5, 5);

        for (int r = 0; r < 5; r++) {
          for (int c = 0; c < 5; c++) {
            final biome = generator.assignedBiomes[(r, c)]!;
            if (biome == BiomeType.unknown) {
              final neighbors = [
                (r - 1, c),
                (r + 1, c),
                (r, c - 1),
                (r, c + 1),
              ].where((n) => n.$1 >= 0 && n.$1 < 5 && n.$2 >= 0 && n.$2 < 5);

              final hasPartner = neighbors.any((n) => generator.assignedBiomes[n] == BiomeType.unknown);
              expect(
                hasPartner,
                isTrue,
                reason: 'Seed $seed: Unknown biome region ($r, $c) must have at least one Unknown neighbor',
              );
            }
          }
        }
      }
    });

    test('Infinite world on-demand generation preserves rank blob constraint', () {
      final generator = MinesweeperWorldGenerator(
        initialRegionX: 0,
        initialRegionY: 0,
        isInfiniteWorld: true,
        random: Random(123),
      );

      // Generate in outward spiral / coordinates
      for (int r = -3; r <= 3; r++) {
        for (int c = -3; c <= 3; c++) {
          generator.getOrGenerateRank(r, c);
          generator.getOrGenerateBiome(r, c);
        }
      }

      for (int r = -2; r <= 2; r++) {
        for (int c = -2; c <= 2; c++) {
          final rank = generator.assignedRanks[(r, c)]!;
          if (r == 0 && c == 0) {
            expect(rank, equals(0), reason: 'Starting region must be rank 0');
            continue;
          }
          final neighbors = [
            (r - 1, c),
            (r + 1, c),
            (r, c - 1),
            (r, c + 1),
          ];
          final hasPartner = neighbors.any((n) => generator.assignedRanks[n] == rank);
          expect(hasPartner, isTrue, reason: 'Infinite world region ($r, $c) must share rank with neighbor');
        }
      }
    });
  });

  group('Perlin Noise Rank Generation', () {
    test('Starting region always sits at a point where noise is 0.0 and rank is 0', () {
      expect(MinesweeperConfig.sampleRankNoise(2, 2, startR: 2, startC: 2), equals(0.0));
      expect(MinesweeperConfig.calculateRegionRank(2, 2, startR: 2, startC: 2), equals(0));
      expect(MinesweeperConfig.rankForRegion(2, 2, startR: 2, startC: 2), equals(0));

      expect(MinesweeperConfig.sampleRankNoise(0, 0, startR: 0, startC: 0), equals(0.0));
      expect(MinesweeperConfig.calculateRegionRank(0, 0, startR: 0, startC: 0), equals(0));
      expect(MinesweeperConfig.sampleRankNoise(10, -5, startR: 10, startC: -5), equals(0.0));
      expect(MinesweeperConfig.calculateRegionRank(10, -5, startR: 10, startC: -5), equals(0));
    });

    test('All regions adjacent to starting region evaluate to rank 1', () {
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          final r = MinesweeperConfig.initialRegionY + dr;
          final c = MinesweeperConfig.initialRegionX + dc;
          final rank = MinesweeperConfig.calculateRegionRank(r, c);
          expect(
            rank,
            equals(1),
            reason: 'Adjacent region at ($r, $c) (offset $dr, $dc) must be rank 1',
          );
        }
      }
    });

    test('Where noise is 1.0, it evaluates to highestRank', () {
      expect(MinesweeperConfig.highestRank, equals(8));
      final rankAtMax = MinesweeperConfig.calculateRegionRank(
        100,
        100,
        startR: 0,
        startC: 0,
        generator: _MockMaxNoiseGenerator(),
      );
      expect(rankAtMax, equals(MinesweeperConfig.highestRank));
    });

    test('pow N makes higher rank values exponentially less likely', () {
      int highRankCountPow1 = 0;
      int highRankCountPow2 = 0;
      for (int r = -15; r <= 15; r++) {
        for (int c = -15; c <= 15; c++) {
          final rk1 = MinesweeperConfig.calculateRegionRank(r, c, startR: 0, startC: 0, power: 1.0);
          final rk2 = MinesweeperConfig.calculateRegionRank(r, c, startR: 0, startC: 0, power: 2.0);
          if (rk1 >= 3) highRankCountPow1++;
          if (rk2 >= 3) highRankCountPow2++;
        }
      }
      expect(highRankCountPow2, lessThan(highRankCountPow1));
    });

    test('Config parameters are customizable', () {
      final rankCustom = MinesweeperConfig.calculateRegionRank(
        2,
        3,
        startR: 2,
        startC: 2,
        scale: 1.0,
        maxRank: 15,
      );
      expect(rankCustom, greaterThanOrEqualTo(1));
      expect(rankCustom, lessThanOrEqualTo(15));
    });
  });

  group('BiomeConfig Generation Rules in World Generator', () {
    test('Generated biomes strictly obey BiomeConfig rank ranges and minDistanceFromStart in infinite world', () {
      for (int seed = 0; seed < 5; seed++) {
        final generator = MinesweeperWorldGenerator(
          initialRegionX: 0,
          initialRegionY: 0,
          isInfiniteWorld: true,
          random: Random(seed * 77 + 1),
        );

        for (int r = -6; r <= 6; r++) {
          for (int c = -6; c <= 6; c++) {
            generator.getOrGenerateRank(r, c);
            generator.getOrGenerateBiome(r, c);
          }
        }

        for (int r = -5; r <= 5; r++) {
          for (int c = -5; c <= 5; c++) {
            final biome = generator.assignedBiomes[(r, c)]!;
            final rank = generator.assignedRanks[(r, c)]!;
            final distance = MinesweeperConfig.calculateRegionDistance(
              r,
              c,
              startR: 0,
              startC: 0,
            );

            if (r == 0 && c == 0) {
              expect(biome, equals(BiomeType.regular));
              expect(rank, equals(0));
              continue;
            }

            if (biome != BiomeType.regular) {
              final rule = BiomeConfig.getRule(biome);
              expect(
                rank,
                greaterThanOrEqualTo(rule.minRank),
                reason: 'Seed $seed: $biome at ($r, $c) has rank $rank < minRank ${rule.minRank}',
              );
              expect(
                rank,
                lessThanOrEqualTo(rule.maxRank),
                reason: 'Seed $seed: $biome at ($r, $c) has rank $rank > maxRank ${rule.maxRank}',
              );
              expect(
                distance,
                greaterThanOrEqualTo(rule.minDistanceFromStart),
                reason: 'Seed $seed: $biome at ($r, $c) has distance $distance < minDistance ${rule.minDistanceFromStart}',
              );
            }
          }
        }
      }
    });

    test('Generated biomes strictly obey BiomeConfig rank ranges and minDistanceFromStart in finite grid', () {
      for (int seed = 0; seed < 5; seed++) {
        final generator = MinesweeperWorldGenerator(
          initialRegionX: 2,
          initialRegionY: 2,
          regionsX: 5,
          regionsY: 5,
          isInfiniteWorld: false,
          random: Random(seed * 31 + 7),
        );
        generator.pregenerateGrid(5, 5);

        for (int r = 0; r < 5; r++) {
          for (int c = 0; c < 5; c++) {
            final biome = generator.assignedBiomes[(r, c)]!;
            final rank = generator.assignedRanks[(r, c)]!;
            final distance = MinesweeperConfig.calculateRegionDistance(
              r,
              c,
              startR: 2,
              startC: 2,
            );

            if (r == 2 && c == 2) {
              expect(biome, equals(BiomeType.regular));
              expect(rank, equals(0));
              continue;
            }

            if (biome != BiomeType.regular) {
              final rule = BiomeConfig.getRule(biome);
              expect(
                rank,
                greaterThanOrEqualTo(rule.minRank),
                reason: 'Finite seed $seed: $biome at ($r, $c) has rank $rank < minRank ${rule.minRank}',
              );
              expect(
                rank,
                lessThanOrEqualTo(rule.maxRank),
                reason: 'Finite seed $seed: $biome at ($r, $c) has rank $rank > maxRank ${rule.maxRank}',
              );
              expect(
                distance,
                greaterThanOrEqualTo(rule.minDistanceFromStart),
                reason: 'Finite seed $seed: $biome at ($r, $c) has distance $distance < minDistance ${rule.minDistanceFromStart}',
              );
            }
          }
        }
      }
    });
  });

  group('Unknown Biome In-game & Widget Mechanics', () {
    testWidgets('Biomes only reveal type (colored border) after discovering at least one empty cell', (tester) async {
      final generator = MinesweeperWorldGenerator(
        initialRegionX: 2,
        initialRegionY: 2,
        regionsX: 5,
        regionsY: 5,
        isInfiniteWorld: false,
        random: Random(42),
      );
      // Force (2, 3) and (2, 4) to be Unknown biome
      generator.assignedRanks[(2, 2)] = 0;
      generator.assignedBiomes[(2, 2)] = BiomeType.regular;
      generator.assignedRanks[(2, 3)] = 2;
      generator.assignedBiomes[(2, 3)] = BiomeType.unknown;
      generator.assignedRanks[(2, 4)] = 2;
      generator.assignedBiomes[(2, 4)] = BiomeType.unknown;

      final game = MinesweeperGame(
        initialRegionX: 2,
        initialRegionY: 2,
        lockInaccessibleRegions: false,
        worldGenerator: generator,
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
      await tester.pump(const Duration(milliseconds: 300));

      final dynamic state = tester.state(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MinesweeperGame'),
      );

      // 1. Initially, no cells in (2, 3) have been revealed.
      // Minimap sector for (2, 3) (minimap_sector_4_3) must NOT have a colored border yet!
      final minimapCellFinder = find.byKey(const ValueKey('minimap_sector_4_3'));
      expect(minimapCellFinder, findsOneWidget);

      AnimatedContainer animatedContainer = tester.widget<AnimatedContainer>(
        find.descendant(of: minimapCellFinder, matching: find.byType(AnimatedContainer)),
      );
      BoxDecoration minimapDeco = animatedContainer.decoration as BoxDecoration;
      expect(minimapDeco.border, isNull, reason: 'Unrevealed unknown biome must not show border');

      // Check board panel for (2, 3) (dr=0, dc=1 -> region_panel_0_1)
      final panelFinder = find.descendant(
        of: find.byKey(const ValueKey('region_panel_0_1')),
        matching: find.byKey(const ValueKey('actual_panel_container')),
      );
      expect(panelFinder, findsOneWidget);
      Container panelContainer = tester.widget<Container>(panelFinder);
      BoxDecoration panelDeco = panelContainer.decoration as BoxDecoration;
      expect((panelDeco.border as Border).top.color, isNot(equals(MinesweeperConfig.unknownBiomeBorderColor)));
      expect(panelDeco.color, equals(MinesweeperConfig.regularRegionPanelBackgroundColor));

      // 2. Flagging a cell on (2, 3) does NOT reveal the biome!
      state.toggleFlag(2, 3, 0, 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      animatedContainer = tester.widget<AnimatedContainer>(
        find.descendant(of: minimapCellFinder, matching: find.byType(AnimatedContainer)),
      );
      minimapDeco = animatedContainer.decoration as BoxDecoration;
      expect(minimapDeco.border, isNull, reason: 'Flagging a cell must not reveal biome border');

      panelContainer = tester.widget<Container>(panelFinder);
      panelDeco = panelContainer.decoration as BoxDecoration;
      expect((panelDeco.border as Border).top.color, isNot(equals(MinesweeperConfig.unknownBiomeBorderColor)));

      // Unflag the cell
      state.toggleFlag(2, 3, 0, 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 3. Discovered at least ONE empty cell on (2, 3)!
      // Find an unrevealed safe cell on (2, 3) and reveal it
      state.ensureRegionGenerated(2, 3);
      final unknownRegion = state.regions[(2, 3)];
      int safeIndex = -1;
      for (int i = 0; i < unknownRegion.rows * unknownRegion.cols; i++) {
        if (unknownRegion.mines[i] == 0 && unknownRegion.cellStates[i] == CellState.unrevealed) {
          safeIndex = i;
          break;
        }
      }
      expect(safeIndex, greaterThanOrEqualTo(0));
      final safeR = safeIndex ~/ unknownRegion.cols;
      final safeC = safeIndex % unknownRegion.cols;

      state.reveal(2, 3, safeR, safeC);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // NOW the biome type is revealed! Colored border appears on panel and minimap!
      animatedContainer = tester.widget<AnimatedContainer>(
        find.descendant(of: minimapCellFinder, matching: find.byType(AnimatedContainer)),
      );
      minimapDeco = animatedContainer.decoration as BoxDecoration;
      expect(minimapDeco.border, isNotNull);
      expect(minimapDeco.border!.top.color, equals(MinesweeperConfig.unknownBiomeBorderColor));

      panelContainer = tester.widget<Container>(panelFinder);
      panelDeco = panelContainer.decoration as BoxDecoration;
      expect(
        (panelDeco.border as Border).top.color,
        equals(MinesweeperConfig.unknownBiomeBorderColor.withValues(
          alpha: MinesweeperConfig.nonSelectedBiomeBorderAlpha,
        )),
      );
      expect(
        panelDeco.color,
        equals(Color.alphaBlend(
          MinesweeperConfig.unknownBiomeBorderColor.withValues(
            alpha: MinesweeperConfig.regionPanelTintAlpha,
          ),
          MinesweeperConfig.regionPanelBaseColor,
        )),
      );

      // Neighbor region (2, 4) in the same biome still has 0 empty cells revealed, so it does NOT show border yet
      final neighborMinimapFinder = find.byKey(const ValueKey('minimap_sector_5_3'));
      final neighborAnimContainer = tester.widget<AnimatedContainer>(
        find.descendant(of: neighborMinimapFinder, matching: find.byType(AnimatedContainer)),
      );
      final neighborDeco = neighborAnimContainer.decoration as BoxDecoration;
      expect(neighborDeco.border, isNull, reason: 'Region (2, 4) has not discovered an empty cell yet');
    });

    testWidgets('Unknown biome generates ? cells and tapping them does not chord', (tester) async {
      final generator = MinesweeperWorldGenerator(
        initialRegionX: 2,
        initialRegionY: 2,
        regionsX: 5,
        regionsY: 5,
        isInfiniteWorld: false,
      );
      // Start region (2, 2), neighbor (2, 3) is unknown biome
      generator.assignedRanks[(2, 2)] = 0;
      generator.assignedBiomes[(2, 2)] = BiomeType.regular;
      generator.assignedRanks[(2, 3)] = 1;
      generator.assignedBiomes[(2, 3)] = BiomeType.unknown;

      final game = MinesweeperGame(
        initialRegionX: 2,
        initialRegionY: 2,
        lockInaccessibleRegions: false,
        worldGenerator: generator,
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
      await tester.pump(const Duration(milliseconds: 300));

      final dynamic state = tester.state(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MinesweeperGame'),
      );
      final Map<(int, int), dynamic> regions = state.regions;
      final unknownRegion = regions[(2, 3)];
      expect(unknownRegion, isNotNull);
      expect(unknownRegion.biome, equals(BiomeType.unknown));

      // Trigger generation of unknown region
      state.ensureRegionGenerated(2, 3);
      expect(unknownRegion.hiddenNumberIndices, isNotEmpty);

      // Reveal cell in unknownRegion that is in hiddenNumberIndices
      final hiddenIdx = (unknownRegion.hiddenNumberIndices as Set<int>).first;
      final hr = hiddenIdx ~/ MinesweeperConfig.regionCols;
      final hc = hiddenIdx % MinesweeperConfig.regionCols;

      state.reveal(2, 3, hr, hc);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(unknownRegion.cellStates[hiddenIdx], equals(CellState.hiddenNumber));

      // Attempting to tap on the hiddenNumber cell should NOT chord or reveal neighbors
      final beforeRevealedCount = unknownRegion.revealedCount;
      state.handleCellTap(2, 3, hr, hc);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(unknownRegion.revealedCount, equals(beforeRevealedCount));
    });

    testWidgets('Diagonal biome: numbers only see mines diagonally and chord diagonally', (tester) async {
      final generator = MinesweeperWorldGenerator(
        initialRegionX: 2,
        initialRegionY: 2,
        regionsX: 5,
        regionsY: 5,
        isInfiniteWorld: false,
      );
      generator.assignedRanks[(2, 2)] = 0;
      generator.assignedBiomes[(2, 2)] = BiomeType.regular;
      generator.assignedRanks[(2, 3)] = 1;
      generator.assignedBiomes[(2, 3)] = BiomeType.diagonal;

      final game = MinesweeperGame(
        initialRegionX: 2,
        initialRegionY: 2,
        lockInaccessibleRegions: false,
        worldGenerator: generator,
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
      final diagRegion = regions[(2, 3)];
      state.ensureRegionGenerated(2, 3);

      // Clear all mines in diagRegion, then place 1 cardinal mine at (1, 2) and 1 diagonal mine at (1, 3)
      diagRegion.mines.fillRange(0, diagRegion.mines.length, 0);
      diagRegion.adjacent.fillRange(0, diagRegion.adjacent.length, 255);
      diagRegion.mines[diagRegion.localIndex(1, 2)] = 1; // Cardinal North of (2, 2)
      diagRegion.mines[diagRegion.localIndex(1, 3)] = 1; // Diagonal North-East of (2, 2)

      // In diagonal biome, cell (2, 2) must only see the diagonal mine (count = 1), ignoring cardinal North
      state.reveal(2, 3, 2, 2);
      await tester.pumpAndSettle();

      final cellIdx = diagRegion.localIndex(2, 2);
      expect(diagRegion.cellStates[cellIdx], equals(CellState.revealed));
      expect(diagRegion.adjacent[cellIdx], equals(1));
      expect(diagRegion.getDisplayedNumber(cellIdx), equals(1));

      // Flag the diagonal mine at (1, 3)
      state.toggleFlag(2, 3, 1, 3);
      await tester.pumpAndSettle();

      // Chording cell (2, 2) should reveal remaining diagonal neighbors without revealing cardinal cells
      state.handleCellTap(2, 3, 2, 2);
      await tester.pumpAndSettle();

      // Other diagonal neighbors of (2, 2): (1, 1), (3, 1), (3, 3) should be revealed
      expect(diagRegion.cellStates[diagRegion.localIndex(1, 1)], equals(CellState.revealed));
      expect(diagRegion.cellStates[diagRegion.localIndex(3, 1)], equals(CellState.revealed));
      expect(diagRegion.cellStates[diagRegion.localIndex(3, 3)], equals(CellState.revealed));

      // Cardinal neighbors: (1, 2) is a mine (unrevealed), (2, 1), (2, 3), (3, 2) should remain unrevealed
      expect(diagRegion.cellStates[diagRegion.localIndex(1, 2)], equals(CellState.unrevealed));
      expect(diagRegion.cellStates[diagRegion.localIndex(2, 1)], equals(CellState.unrevealed));
    });

    testWidgets('Orthogonal biome: numbers only see mines orthogonally and chord orthogonally', (tester) async {
      final generator = MinesweeperWorldGenerator(
        initialRegionX: 2,
        initialRegionY: 2,
        regionsX: 5,
        regionsY: 5,
        isInfiniteWorld: false,
      );
      generator.assignedRanks[(2, 2)] = 0;
      generator.assignedBiomes[(2, 2)] = BiomeType.regular;
      generator.assignedRanks[(2, 3)] = 1;
      generator.assignedBiomes[(2, 3)] = BiomeType.orthogonal;

      final game = MinesweeperGame(
        initialRegionX: 2,
        initialRegionY: 2,
        lockInaccessibleRegions: false,
        worldGenerator: generator,
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
      final orthoRegion = regions[(2, 3)];
      state.ensureRegionGenerated(2, 3);

      // Clear all mines in orthoRegion
      orthoRegion.mines.fillRange(0, orthoRegion.mines.length, 0);
      orthoRegion.adjacent.fillRange(0, orthoRegion.adjacent.length, 255);

      // Center cell: (2, 2)
      // Cardinal North mine: (1, 2)
      // Diagonal North-East mine: (1, 3)
      // To prevent cardinal neighbors from flood-filling when chorded, give each a cardinal mine:
      // Cardinal West of (2, 1) is (2, 0) -> place mine
      // Cardinal East of (2, 3) is (2, 4) -> place mine
      // Cardinal South of (3, 2) is (4, 2) -> place mine
      orthoRegion.mines[orthoRegion.localIndex(1, 2)] = 1;
      orthoRegion.mines[orthoRegion.localIndex(1, 3)] = 1;
      orthoRegion.mines[orthoRegion.localIndex(2, 0)] = 1;
      orthoRegion.mines[orthoRegion.localIndex(2, 4)] = 1;
      orthoRegion.mines[orthoRegion.localIndex(4, 2)] = 1;

      // In orthogonal biome, cell (2, 2) must only see the cardinal North mine (count = 1), ignoring diagonal NE (1, 3)
      state.reveal(2, 3, 2, 2);
      await tester.pumpAndSettle();

      final cellIdx = orthoRegion.localIndex(2, 2);
      expect(orthoRegion.cellStates[cellIdx], equals(CellState.revealed));
      expect(orthoRegion.adjacent[cellIdx], equals(1));
      expect(orthoRegion.getDisplayedNumber(cellIdx), equals(1));

      // Flag the cardinal mine at (1, 2)
      state.toggleFlag(2, 3, 1, 2);
      await tester.pumpAndSettle();

      // Chording cell (2, 2) should reveal cardinal neighbors (2, 1), (2, 3), (3, 2)
      state.handleCellTap(2, 3, 2, 2);
      await tester.pumpAndSettle();

      expect(orthoRegion.cellStates[orthoRegion.localIndex(2, 1)], equals(CellState.revealed));
      expect(orthoRegion.cellStates[orthoRegion.localIndex(2, 3)], equals(CellState.revealed));
      expect(orthoRegion.cellStates[orthoRegion.localIndex(3, 2)], equals(CellState.revealed));

      // Diagonal neighbors should remain unrevealed
      expect(orthoRegion.cellStates[orthoRegion.localIndex(1, 1)], equals(CellState.unrevealed));
      expect(orthoRegion.cellStates[orthoRegion.localIndex(1, 3)], equals(CellState.unrevealed));
      expect(orthoRegion.cellStates[orthoRegion.localIndex(3, 1)], equals(CellState.unrevealed));
      expect(orthoRegion.cellStates[orthoRegion.localIndex(3, 3)], equals(CellState.unrevealed));
    });

    testWidgets('Range biome: numbers see mines up to 2 tiles away including adjacent regions', (tester) async {
      final generator = MinesweeperWorldGenerator(
        initialRegionX: 2,
        initialRegionY: 2,
        regionsX: 5,
        regionsY: 5,
        isInfiniteWorld: false,
      );
      generator.assignedRanks[(2, 2)] = 0;
      generator.assignedBiomes[(2, 2)] = BiomeType.regular;
      generator.assignedRanks[(2, 3)] = 1;
      generator.assignedBiomes[(2, 3)] = BiomeType.range;

      final game = MinesweeperGame(
        initialRegionX: 2,
        initialRegionY: 2,
        lockInaccessibleRegions: false,
        worldGenerator: generator,
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
      final rangeRegion = regions[(2, 3)];
      state.ensureRegionGenerated(2, 3);
      state.ensureRegionGenerated(2, 2);

      // Clear mines in (2, 3) and place 1 mine 2 tiles away within the same region: (1, 3) from (3, 3)
      rangeRegion.mines.fillRange(0, rangeRegion.mines.length, 0);
      rangeRegion.adjacent.fillRange(0, rangeRegion.adjacent.length, 255);
      rangeRegion.mines[rangeRegion.localIndex(1, 3)] = 1; // 2 steps North of (3, 3)

      state.reveal(2, 3, 3, 3);
      await tester.pumpAndSettle();

      expect(rangeRegion.adjacent[rangeRegion.localIndex(3, 3)], equals(1));

      // Also test cross-region mine detection:
      // Clear mines in both regions
      rangeRegion.mines.fillRange(0, rangeRegion.mines.length, 0);
      rangeRegion.adjacent.fillRange(0, rangeRegion.adjacent.length, 255);
      final reg22 = regions[(2, 2)];
      reg22.mines.fillRange(0, reg22.mines.length, 0);
      reg22.adjacent.fillRange(0, reg22.adjacent.length, 255);

      // Place a mine in neighbor region (2, 2) at row 3, col 5 (which is 2 tiles West of (2, 3) at row 3, col 0)
      reg22.mines[reg22.localIndex(3, 5)] = 1;

      state.reveal(2, 3, 3, 0);
      await tester.pumpAndSettle();

      // Cell (3, 0) in rangeRegion (2, 3) should see the mine across the border in region (2, 2)
      expect(rangeRegion.adjacent[rangeRegion.localIndex(3, 0)], equals(1));
    });

    testWidgets('Random biome: numbers > 0 are offset by unified randomOffset, 0 is blank and flood-clears', (tester) async {
      final generator = MinesweeperWorldGenerator(
        initialRegionX: 2,
        initialRegionY: 2,
        regionsX: 5,
        regionsY: 5,
        isInfiniteWorld: false,
      );
      generator.assignedRanks[(2, 2)] = 0;
      generator.assignedBiomes[(2, 2)] = BiomeType.regular;
      generator.assignedRanks[(2, 3)] = 1;
      generator.assignedBiomes[(2, 3)] = BiomeType.random;

      final game = MinesweeperGame(
        initialRegionX: 2,
        initialRegionY: 2,
        lockInaccessibleRegions: false,
        worldGenerator: generator,
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
      final randRegion = regions[(2, 3)];
      state.ensureRegionGenerated(2, 3);

      expect(randRegion.randomOffset, greaterThanOrEqualTo(MinesweeperConfig.randomBiomeMinOffset));
      expect(randRegion.randomOffset, lessThanOrEqualTo(MinesweeperConfig.randomBiomeMaxOffset));

      // Clear mines and place 1 mine at (0, 0)
      randRegion.mines.fillRange(0, randRegion.mines.length, 0);
      randRegion.adjacent.fillRange(0, randRegion.adjacent.length, 255);
      randRegion.mines[randRegion.localIndex(0, 0)] = 1;

      // Cell (0, 1) touches 1 mine. Displayed number must be 1 + randomOffset
      state.reveal(2, 3, 0, 1);
      await tester.pumpAndSettle();

      final idx01 = randRegion.localIndex(0, 1);
      expect(randRegion.adjacent[idx01], equals(1));
      expect(randRegion.getDisplayedNumber(idx01), equals(1 + randRegion.randomOffset));

      // Cell (4, 4) has 0 mines around it. Displayed number must be 0 (blank) and trigger flood fill
      state.reveal(2, 3, 4, 4);
      await tester.pumpAndSettle();

      final idx44 = randRegion.localIndex(4, 4);
      expect(randRegion.adjacent[idx44], equals(0));
      expect(randRegion.getDisplayedNumber(idx44), equals(0));
      // Surrounding empty cells should have flood-cleared
      expect(randRegion.cellStates[randRegion.localIndex(3, 4)], equals(CellState.revealed));
      expect(randRegion.cellStates[randRegion.localIndex(4, 3)], equals(CellState.revealed));
    });

    testWidgets('Random biome: chording matches displayed number (actual mines + randomOffset)', (tester) async {
      final generator = MinesweeperWorldGenerator(
        initialRegionX: 2,
        initialRegionY: 2,
        regionsX: 5,
        regionsY: 5,
        isInfiniteWorld: false,
      );
      generator.assignedRanks[(2, 2)] = 0;
      generator.assignedBiomes[(2, 2)] = BiomeType.regular;
      generator.assignedRanks[(2, 3)] = 1;
      generator.assignedBiomes[(2, 3)] = BiomeType.random;

      final game = MinesweeperGame(
        initialRegionX: 2,
        initialRegionY: 2,
        lockInaccessibleRegions: false,
        worldGenerator: generator,
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
      final randRegion = regions[(2, 3)];
      state.ensureRegionGenerated(2, 3);

      // Clear mines and place 1 mine at (1, 1)
      randRegion.mines.fillRange(0, randRegion.mines.length, 0);
      randRegion.adjacent.fillRange(0, randRegion.adjacent.length, 255);
      randRegion.mines[randRegion.localIndex(1, 1)] = 1;

      // Reveal cell (2, 2). It has 1 actual mine adjacent.
      state.reveal(2, 3, 2, 2);
      await tester.pumpAndSettle();

      final idx22 = randRegion.localIndex(2, 2);
      final displayedNumber = randRegion.getDisplayedNumber(idx22);
      final offset = randRegion.randomOffset;
      expect(displayedNumber, equals(1 + offset));

      // In order to chord, player must flag exactly displayedNumber neighbors!
      // Flag the real mine at (1, 1) plus offset safe neighbors
      state.toggleFlag(2, 3, 1, 1);
      final extraNeighbors = [(1, 2), (1, 3), (2, 1), (2, 3), (3, 1), (3, 2), (3, 3)];
      for (int i = 0; i < offset; i++) {
        final (r, c) = extraNeighbors[i];
        state.toggleFlag(2, 3, r, c);
      }
      await tester.pumpAndSettle();

      // Trigger chord on (2, 2)
      state.handleCellTap(2, 3, 2, 2);
      await tester.pumpAndSettle();

      // The remaining unflagged neighbors should now be revealed!
      for (int i = offset; i < extraNeighbors.length; i++) {
        final (r, c) = extraNeighbors[i];
        expect(randRegion.cellStates[randRegion.localIndex(r, c)], equals(CellState.revealed));
      }
    });

    testWidgets('Blind biome: does not display the total number of bombs in it (shows ? in counter)', (tester) async {
      final generator = MinesweeperWorldGenerator(
        initialRegionX: 2,
        initialRegionY: 2,
        regionsX: 5,
        regionsY: 5,
        isInfiniteWorld: false,
      );
      generator.assignedRanks[(2, 2)] = 1;
      generator.assignedBiomes[(2, 2)] = BiomeType.blind;
      generator.assignedRanks[(2, 3)] = 0;
      generator.assignedBiomes[(2, 3)] = BiomeType.regular;

      final game = MinesweeperGame(
        initialRegionX: 2,
        initialRegionY: 2,
        lockInaccessibleRegions: false,
        worldGenerator: generator,
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

      final badgeFinder = find.byKey(const ValueKey('region_mine_counter_badge'));
      expect(badgeFinder, findsOneWidget);

      // In Blind region (2, 2), badge displays '?' instead of numeric count
      expect(find.descendant(of: badgeFinder, matching: find.text('?')), findsOneWidget);

      final dynamic state = tester.state(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MinesweeperGame'),
      );

      final Map<(int, int), dynamic> regions = state.regions;
      final blindRegion = regions[(2, 2)];
      state.ensureRegionGenerated(2, 2);
      expect(blindRegion.biome, equals(BiomeType.blind));

      // Flag a cell in Blind region
      state.toggleFlag(2, 2, 0, 0);
      await tester.pumpAndSettle();

      // After placing a flag, the badge continues to display '?' (count is unknown)
      expect(find.descendant(of: badgeFinder, matching: find.text('?')), findsOneWidget);

      // Unflag the cell
      state.toggleFlag(2, 2, 0, 0);
      await tester.pumpAndSettle();

      // Navigate to regular region (2, 3)
      state.navigateRegion(0, 1);
      await tester.pumpAndSettle();

      // In regular region, badge displays a numeric mine count (not '?')
      expect(find.descendant(of: badgeFinder, matching: find.text('?')), findsNothing);

      // Border color matches blindBiomeBorderColor
      expect(MinesweeperConfig.biomeBorderColor(BiomeType.blind), equals(MinesweeperConfig.blindBiomeBorderColor));
    });

    test('All special biomes satisfy blob size >= 2 constraint in finite grid', () {
      for (int seed = 0; seed < 10; seed++) {
        final generator = MinesweeperWorldGenerator(
          initialRegionX: 2,
          initialRegionY: 2,
          regionsX: 5,
          regionsY: 5,
          isInfiniteWorld: false,
          random: Random(seed),
        );
        generator.pregenerateGrid(5, 5);

        for (int r = 0; r < 5; r++) {
          for (int c = 0; c < 5; c++) {
            final biome = generator.assignedBiomes[(r, c)]!;
            if (biome != BiomeType.regular) {
              final neighbors = [
                (r - 1, c),
                (r + 1, c),
                (r, c - 1),
                (r, c + 1),
              ].where((n) => n.$1 >= 0 && n.$1 < 5 && n.$2 >= 0 && n.$2 < 5);

              final hasPartner = neighbors.any((n) => generator.assignedBiomes[n] == biome);
              expect(
                hasPartner,
                isTrue,
                reason: 'Seed $seed: $biome region ($r, $c) must belong to a blob of size >= 2 of the same biome type',
              );
            }
          }
        }
      }
    });

    test('All special biomes have distinct border colors configured', () {
      final borderColors = <Color>{};
      final biomes = [
        BiomeType.unknown,
        BiomeType.random,
        BiomeType.diagonal,
        BiomeType.orthogonal,
        BiomeType.range,
        BiomeType.blind,
      ];
      for (final biome in biomes) {
        final color = MinesweeperConfig.biomeBorderColor(biome);
        expect(color, isNotNull, reason: '$biome must have a configured border color');
        expect(borderColors.contains(color!), isFalse, reason: '$biome border color $color must be unique');
        borderColors.add(color);
      }
      expect(MinesweeperConfig.biomeBorderColor(BiomeType.regular), isNull);
    });

    testWidgets('Background panels receive gentle tint matching border/biome color and non-selected borders are dimmer',
        (tester) async {
      final generator = MinesweeperWorldGenerator(
        initialRegionX: 2,
        initialRegionY: 2,
        regionsX: 5,
        regionsY: 5,
        isInfiniteWorld: false,
      );
      // Region (2, 2) is regular; (2, 3) is diagonal (cyan); (3, 2) is orthogonal (orange)
      generator.assignedRanks[(2, 2)] = 0;
      generator.assignedBiomes[(2, 2)] = BiomeType.regular;
      generator.assignedRanks[(2, 3)] = 1;
      generator.assignedBiomes[(2, 3)] = BiomeType.diagonal;
      generator.assignedRanks[(3, 2)] = 1;
      generator.assignedBiomes[(3, 2)] = BiomeType.orthogonal;

      final game = MinesweeperGame(
        initialRegionX: 2,
        initialRegionY: 2,
        lockInaccessibleRegions: false,
        worldGenerator: generator,
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

      // 1. Initial state at (2, 2) (regular biome):
      // Static brighter border is removed: resting border matches baseline nonSelectedRegularBorderColor
      final centerPanelFinder = find.descendant(
        of: find.byKey(const ValueKey('region_panel_0_0')),
        matching: find.byKey(const ValueKey('actual_panel_container')),
      );
      var centerContainer = tester.widget<Container>(centerPanelFinder);
      var centerDeco = centerContainer.decoration as BoxDecoration;
      expect((centerDeco.border as Border).top.color, equals(MinesweeperConfig.nonSelectedRegularBorderColor));
      // Panel background uses original AppColors.panelMedium (regularRegionPanelBackgroundColor) for regular regions
      expect(centerDeco.color, equals(MinesweeperConfig.regularRegionPanelBackgroundColor));

      // Test entry pulse peak brightness (value = 0.5 -> animation = 1.0, reaches firstIterationRegularBorderColor):
      state.entryPulseController.value = 0.5;
      await tester.pump();
      centerContainer = tester.widget<Container>(centerPanelFinder);
      centerDeco = centerContainer.decoration as BoxDecoration;
      expect((centerDeco.border as Border).top.color, equals(MinesweeperConfig.firstIterationRegularBorderColor));

      // Test idle breathing pulse peak (idlePulseController value = 1.0 -> subtle breathing peak):
      state.entryPulseController.stop();
      state.entryPulseController.value = 0.0;
      state.idlePulseController.value = 1.0;
      await tester.pump();
      centerContainer = tester.widget<Container>(centerPanelFinder);
      centerDeco = centerContainer.decoration as BoxDecoration;
      expect((centerDeco.border as Border).top.color, equals(MinesweeperConfig.idlePulseRegularBorderColor));

      // Return controllers to resting baseline
      state.idlePulseController.stop();
      state.idlePulseController.value = 0.0;
      await tester.pump();

      // 2. Reveal empty cells in (2, 3) (diagonal) and (3, 2) (orthogonal) to reveal their biomes
      state.ensureRegionGenerated(2, 3);
      final diagRegion = state.regions[(2, 3)]!;
      for (int i = 0; i < diagRegion.rows * diagRegion.cols; i++) {
        if (diagRegion.mines[i] == 0) {
          state.reveal(2, 3, i ~/ diagRegion.cols, i % diagRegion.cols);
          break;
        }
      }

      state.ensureRegionGenerated(3, 2);
      final orthoRegion = state.regions[(3, 2)]!;
      for (int i = 0; i < orthoRegion.rows * orthoRegion.cols; i++) {
        if (orthoRegion.mines[i] == 0) {
          state.reveal(3, 2, i ~/ orthoRegion.cols, i % orthoRegion.cols);
          break;
        }
      }
      await tester.pumpAndSettle();

      // 3. Verify non-selected special biome regions have dimmed borders and tinted background panels:
      // (2, 3) (dr=0, dc=1 -> region_panel_0_1): Cyan diagonal biome
      final diagPanelFinder = find.descendant(
        of: find.byKey(const ValueKey('region_panel_0_1')),
        matching: find.byKey(const ValueKey('actual_panel_container')),
      );
      final diagContainer = tester.widget<Container>(diagPanelFinder);
      final diagDeco = diagContainer.decoration as BoxDecoration;

      // Border is dimmer than full brightness (40% alpha)
      expect(
        (diagDeco.border as Border).top.color,
        equals(MinesweeperConfig.diagonalBiomeBorderColor.withValues(
          alpha: MinesweeperConfig.nonSelectedBiomeBorderAlpha,
        )),
      );
      // Background panel has gentle cyan tint matching the biome/border color on top of regionPanelBaseColor
      final expectedDiagBg = Color.alphaBlend(
        MinesweeperConfig.diagonalBiomeBorderColor.withValues(
          alpha: MinesweeperConfig.regionPanelTintAlpha,
        ),
        MinesweeperConfig.regionPanelBaseColor,
      );
      expect(diagDeco.color, equals(expectedDiagBg));

      // (3, 2) (dr=1, dc=0 -> region_panel_1_0): Orange orthogonal biome
      final orthoPanelFinder = find.descendant(
        of: find.byKey(const ValueKey('region_panel_1_0')),
        matching: find.byKey(const ValueKey('actual_panel_container')),
      );
      final orthoContainer = tester.widget<Container>(orthoPanelFinder);
      final orthoDeco = orthoContainer.decoration as BoxDecoration;

      // Border is dimmer than full brightness (40% alpha)
      expect(
        (orthoDeco.border as Border).top.color,
        equals(MinesweeperConfig.orthogonalBiomeBorderColor.withValues(
          alpha: MinesweeperConfig.nonSelectedBiomeBorderAlpha,
        )),
      );
      // Background panel has gentle orange tint matching the biome/border color on top of regionPanelBaseColor
      final expectedOrthoBg = Color.alphaBlend(
        MinesweeperConfig.orthogonalBiomeBorderColor.withValues(
          alpha: MinesweeperConfig.regionPanelTintAlpha,
        ),
        MinesweeperConfig.regionPanelBaseColor,
      );
      expect(orthoDeco.color, equals(expectedOrthoBg));

      // 4. Navigate into (2, 3) (diagonal biome):
      // Navigation triggers entry pulse, and after settling returns to resting baseline
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      // (2, 3) is now center panel (dr=0, dc=0)
      final newCenterFinder = find.descendant(
        of: find.byKey(const ValueKey('region_panel_0_0')),
        matching: find.byKey(const ValueKey('actual_panel_container')),
      );
      var newCenterContainer = tester.widget<Container>(newCenterFinder);
      var newCenterDeco = newCenterContainer.decoration as BoxDecoration;

      // At rest after navigation, border is at baseline
      expect(
        (newCenterDeco.border as Border).top.color,
        equals(MinesweeperConfig.diagonalBiomeBorderColor.withValues(
          alpha: MinesweeperConfig.nonSelectedBiomeBorderAlpha,
        )),
      );
      // Retains gentle cyan tint on background
      expect(newCenterDeco.color, equals(expectedDiagBg));

      // Test entry pulse on special biome reaches first iteration peak (alpha = 1.0):
      state.entryPulseController.value = 0.5;
      await tester.pump();
      newCenterContainer = tester.widget<Container>(newCenterFinder);
      newCenterDeco = newCenterContainer.decoration as BoxDecoration;
      expect(
        (newCenterDeco.border as Border).top.color,
        equals(MinesweeperConfig.diagonalBiomeBorderColor.withValues(
          alpha: MinesweeperConfig.firstIterationBiomeBorderAlpha,
        )),
      );

      // Previous region (2, 2) is now neighbor (dr=0, dc=-1) and its border remains dimmed at baseline!
      final prevRegionFinder = find.descendant(
        of: find.byKey(const ValueKey('region_panel_0_-1')),
        matching: find.byKey(const ValueKey('actual_panel_container')),
      );
      final prevContainer = tester.widget<Container>(prevRegionFinder);
      final prevDeco = prevContainer.decoration as BoxDecoration;
      expect(
        (prevDeco.border as Border).top.color,
        equals(MinesweeperConfig.nonSelectedRegularBorderColor),
      );
      expect(prevDeco.color, equals(MinesweeperConfig.regularRegionPanelBackgroundColor));
    });

    testWidgets('Selected region border entry pulse on drag release and slow continuous idle breathing', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final generator = MinesweeperWorldGenerator(
        regionsX: 5,
        regionsY: 5,
        isInfiniteWorld: true,
      );
      generator.assignedRanks[(2, 2)] = 0;
      generator.assignedBiomes[(2, 2)] = BiomeType.regular;
      generator.assignedRanks[(2, 3)] = 1;
      generator.assignedBiomes[(2, 3)] = BiomeType.regular;

      final game = MinesweeperGame(
        initialRegionX: 2,
        initialRegionY: 2,
        lockInaccessibleRegions: false,
        worldGenerator: generator,
        enableContinuousIdlePulseInTests: true,
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

      final dynamic state = tester.state(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MinesweeperGame'),
      );

      // 1. Initial mount starts entry pulse
      expect(state.entryPulseController.isAnimating, isTrue);

      // Advance entry pulse to halfway (peak, value = 0.5)
      state.entryPulseController.value = 0.5;
      await tester.pump();

      final centerPanelFinder = find.descendant(
        of: find.byKey(const ValueKey('region_panel_0_0')),
        matching: find.byKey(const ValueKey('actual_panel_container')),
      );
      var centerContainer = tester.widget<Container>(centerPanelFinder);
      var centerDeco = centerContainer.decoration as BoxDecoration;
      expect(
        (centerDeco.border as Border).top.color,
        equals(MinesweeperConfig.firstIterationRegularBorderColor),
      );

      // Advance entry pulse to completion -> starts continuous idle breathing pulse!
      state.entryPulseController.value = 1.0;
      state.entryPulseController.stop();
      state.idlePulseController.repeat(reverse: true);
      await tester.pump();

      expect(state.idlePulseController.isAnimating, isTrue);

      // Advance idle pulse to peak (value = 1.0)
      state.idlePulseController.value = 1.0;
      await tester.pump();

      centerContainer = tester.widget<Container>(centerPanelFinder);
      centerDeco = centerContainer.decoration as BoxDecoration;
      // Reaches subtle breathing peak, not as bright as the first iteration!
      expect(
        (centerDeco.border as Border).top.color,
        equals(MinesweeperConfig.idlePulseRegularBorderColor),
      );

      // 2. Swiping/navigating into adjacent region (2, 3):
      // Drag touch down pauses/resets pulse
      state.navigateRegion(0, 1);
      // First tick establishes ticker _startTime
      await tester.pump();
      // Pump transition duration (220ms) to complete navigation and trigger entry pulse
      await tester.pump(const Duration(milliseconds: 250));
      expect(state.entryPulseController.isAnimating, isTrue);

      state.entryPulseController.value = 0.5;
      await tester.pump();

      centerContainer = tester.widget<Container>(centerPanelFinder);
      centerDeco = centerContainer.decoration as BoxDecoration;
      expect(
        (centerDeco.border as Border).top.color,
        equals(MinesweeperConfig.firstIterationRegularBorderColor),
      );

      // Stop repeating controllers before tearDown to clean up tickers
      state.entryPulseController.stop();
      state.idlePulseController.stop();
      await tester.pump();
    });

    testWidgets(
        'Tapping on selected region or canceling traversal does not play large pulse, only successful region change plays large pulse',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final generator = MinesweeperWorldGenerator(
        regionsX: 5,
        regionsY: 5,
        isInfiniteWorld: false,
      );
      generator.assignedRanks[(2, 2)] = 0;
      generator.assignedBiomes[(2, 2)] = BiomeType.regular;
      generator.assignedRanks[(2, 3)] = 1;
      generator.assignedBiomes[(2, 3)] = BiomeType.regular;

      final game = MinesweeperGame(
        initialRegionX: 2,
        initialRegionY: 2,
        lockInaccessibleRegions: false,
        worldGenerator: generator,
        enableContinuousIdlePulseInTests: true,
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

      final dynamic state = tester.state(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MinesweeperGame'),
      );

      // Finish initial entry pulse so we are in normal resting/idle state
      state.entryPulseController.stop();
      state.entryPulseController.value = 0.0;
      state.idlePulseController.stop();
      state.idlePulseController.value = 0.0;
      await tester.pump();

      // 1. Tapping on the selected region
      final centerPanelFinder = find.byKey(const ValueKey('region_panel_0_0'));
      await tester.tap(centerPanelFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Large pulse must NOT have played!
      expect(state.entryPulseController.isAnimating, isFalse);
      expect(state.entryPulseController.value, equals(0.0));

      // 2. Initiating a drag traversal below threshold and releasing (canceled traversal)
      final gesture = await tester.startGesture(tester.getCenter(centerPanelFinder));
      await tester.pump();
      // Move 20px (exceeds dragMinThreshold of 10px, but well below swipeThreshold of 64px)
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump();
      // Release to snap back to the same region
      await gesture.up();
      await tester.pump();
      // Pump snapback duration (180ms)
      await tester.pump(const Duration(milliseconds: 250));

      // Traversal was canceled: large pulse must NOT play!
      expect(state.entryPulseController.isAnimating, isFalse);
      expect(state.entryPulseController.value, equals(0.0));
      expect(state.currentRegionRow, equals(2));
      expect(state.currentRegionCol, equals(2));

      // 3. Successful traversal: drag beyond threshold and release
      final successGesture = await tester.startGesture(tester.getCenter(centerPanelFinder));
      await tester.pump();
      await successGesture.moveBy(const Offset(-100, 0)); // Exceeds swipeThreshold
      await tester.pump();
      await successGesture.up();
      await tester.pump();
      // Pump transition duration (220ms)
      await tester.pump(const Duration(milliseconds: 250));

      // Region changed to (2, 3): large pulse MUST play!
      expect(state.currentRegionRow, equals(2));
      expect(state.currentRegionCol, equals(3));
      expect(state.entryPulseController.isAnimating, isTrue);

      // Clean up tickers
      state.entryPulseController.stop();
      state.idlePulseController.stop();
      await tester.pump();
    });

    testWidgets(
        'Unrevealed cells in discovered special biomes receive gentle tint matching biome color, while regular or undiscovered biomes use default color',
        (tester) async {
      final generator = MinesweeperWorldGenerator(
        initialRegionX: 2,
        initialRegionY: 2,
        regionsX: 5,
        regionsY: 5,
        isInfiniteWorld: false,
      );
      // Region (2, 2) is regular; (2, 3) is diagonal (cyan)
      generator.assignedRanks[(2, 2)] = 0;
      generator.assignedBiomes[(2, 2)] = BiomeType.regular;
      generator.assignedRanks[(2, 3)] = 1;
      generator.assignedBiomes[(2, 3)] = BiomeType.diagonal;

      final game = MinesweeperGame(
        initialRegionX: 2,
        initialRegionY: 2,
        lockInaccessibleRegions: false,
        worldGenerator: generator,
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
      final BuildContext context = tester.element(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MinesweeperGame'),
      );
      final defaultCellColor = Theme.of(context).colorScheme.surfaceContainerHighest;

      // 1. In regular region (2, 2) (region_panel_0_0):
      // All unrevealed cells must have default cell color and null biomeColor
      final regularPanel = find.byKey(const ValueKey('region_panel_0_0'));
      final regularCells = find.descendant(
        of: regularPanel,
        matching: find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_RegionCellWidget',
        ),
      );
      expect(regularCells, findsWidgets);

      final firstRegularCellWidget = tester.widget(regularCells.first) as dynamic;
      expect(firstRegularCellWidget.biomeColor, isNull);

      final firstRegularCellContainer = tester.widget<Container>(
        find.descendant(of: regularCells.first, matching: find.byType(Container)).first,
      );
      expect(
        (firstRegularCellContainer.decoration as BoxDecoration).color,
        equals(defaultCellColor),
      );

      // 2. In undiscovered diagonal region (2, 3) (region_panel_0_1):
      // Prior to discovering any empty cells, biome is not revealed, so biomeColor must be null and cell color must be default
      final diagPanel = find.byKey(const ValueKey('region_panel_0_1'));
      final diagCells = find.descendant(
        of: diagPanel,
        matching: find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_RegionCellWidget',
        ),
      );
      expect(diagCells, findsWidgets);

      final undiscoveredCellWidget = tester.widget(diagCells.first) as dynamic;
      expect(undiscoveredCellWidget.biomeColor, isNull);
      final undiscoveredContainer = tester.widget<Container>(
        find.descendant(of: diagCells.first, matching: find.byType(Container)).first,
      );
      expect(
        (undiscoveredContainer.decoration as BoxDecoration).color,
        equals(defaultCellColor),
      );

      // 3. Discover at least one empty cell in (2, 3) to reveal the biome
      state.ensureRegionGenerated(2, 3);
      final diagRegion = state.regions[(2, 3)]!;
      for (int i = 0; i < diagRegion.rows * diagRegion.cols; i++) {
        if (diagRegion.mines[i] == 0) {
          state.reveal(2, 3, i ~/ diagRegion.cols, i % diagRegion.cols);
          break;
        }
      }
      await tester.pumpAndSettle();

      // Now diagRegion.isBiomeRevealed is true!
      // The remaining unrevealed cells in (2, 3) must have biomeColor set to diagonalBiomeBorderColor
      // and their background color must be gently tinted:
      final expectedTintedColor = Color.alphaBlend(
        MinesweeperConfig.diagonalBiomeBorderColor.withValues(
          alpha: MinesweeperConfig.unrevealedCellTintAlpha,
        ),
        defaultCellColor,
      );

      final discoveredDiagCells = find.descendant(
        of: diagPanel,
        matching: find.byWidgetPredicate(
          (w) =>
              w.runtimeType.toString() == '_RegionCellWidget' &&
              (w as dynamic).cellState == CellState.unrevealed,
        ),
      );
      expect(discoveredDiagCells, findsWidgets);

      final discoveredCellWidget = tester.widget(discoveredDiagCells.first) as dynamic;
      expect(discoveredCellWidget.biomeColor, equals(MinesweeperConfig.diagonalBiomeBorderColor));

      final discoveredContainer = tester.widget<Container>(
        find.descendant(of: discoveredDiagCells.first, matching: find.byType(Container)).first,
      );
      expect(
        (discoveredContainer.decoration as BoxDecoration).color,
        equals(expectedTintedColor),
      );

      // Regular region (2, 2) unrevealed cells must still have default color:
      final regularCellAgain = tester.widget(regularCells.first) as dynamic;
      expect(regularCellAgain.biomeColor, isNull);
    });
  });
}

class _MockMaxNoiseGenerator implements VectorPerlin2D {
  @override
  double sample(double x, double y) => 1.0;

  @override
  PerlinNoise2D get noiseX => throw UnimplementedError();

  @override
  PerlinNoise2D get noiseY => throw UnimplementedError();
}
