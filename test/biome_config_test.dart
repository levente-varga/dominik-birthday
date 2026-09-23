import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dominik/config/biome_config.dart';

void main() {
  setUp(() {
    BiomeConfig.resetToDefaults();
  });

  tearDown(() {
    BiomeConfig.resetToDefaults();
  });

  group('BiomeRule rank range & distance validation', () {
    test('BiomeRule validates rank range correctly', () {
      const rule = BiomeRule(
        type: BiomeType.random,
        minRank: 1,
        maxRank: 4,
        minDistanceFromStart: 1,
      );

      expect(rule.canGenerate(rank: 0, distance: 1), isFalse);
      expect(rule.canGenerate(rank: 1, distance: 1), isTrue);
      expect(rule.canGenerate(rank: 3, distance: 1), isTrue);
      expect(rule.canGenerate(rank: 4, distance: 1), isTrue);
      expect(rule.canGenerate(rank: 5, distance: 1), isFalse);
    });

    test('BiomeRule validates minimum distance correctly', () {
      const rule = BiomeRule(
        type: BiomeType.range,
        minRank: 5,
        maxRank: 8,
        minDistanceFromStart: 4,
      );

      // Within rank range, but distance too small
      expect(rule.canGenerate(rank: 5, distance: 0), isFalse);
      expect(rule.canGenerate(rank: 5, distance: 1), isFalse);
      expect(rule.canGenerate(rank: 5, distance: 3), isFalse);

      // Distance met
      expect(rule.canGenerate(rank: 5, distance: 4), isTrue);
      expect(rule.canGenerate(rank: 6, distance: 10), isTrue);
    });
  });

  group('BiomeConfig eligibility & default rules', () {
    test('Starting region (distance 0, rank 0) has no eligible special biomes', () {
      final eligible = BiomeConfig.getEligibleBiomes(rank: 0, distance: 0);
      expect(eligible, isEmpty);
      expect(BiomeConfig.isBiomeAllowed(biome: BiomeType.regular, rank: 0, distance: 0), isTrue);
      expect(BiomeConfig.isBiomeAllowed(biome: BiomeType.random, rank: 0, distance: 0), isFalse);
    });

    test('Rank 1 at distance 1 only allows random biome', () {
      final eligible = BiomeConfig.getEligibleBiomes(rank: 1, distance: 1);
      expect(eligible, equals([BiomeType.random]));
    });

    test('Rank 2 at distance 2 allows random and diagonal biomes', () {
      final eligible = BiomeConfig.getEligibleBiomes(rank: 2, distance: 2);
      expect(eligible, containsAll([BiomeType.random, BiomeType.diagonal]));
      expect(eligible, isNot(contains(BiomeType.orthogonal)));
      expect(eligible, isNot(contains(BiomeType.unknown)));
      expect(eligible, isNot(contains(BiomeType.range)));
    });

    test('Rank 5 at distance 4 allows diagonal, orthogonal, unknown, and range', () {
      final eligible = BiomeConfig.getEligibleBiomes(rank: 5, distance: 4);
      expect(eligible, containsAll([
        BiomeType.diagonal,
        BiomeType.orthogonal,
        BiomeType.unknown,
        BiomeType.range,
      ]));
      expect(eligible, isNot(contains(BiomeType.random))); // random maxRank is 4
    });

    test('Rank 8 at distance 5 only allows unknown and range', () {
      final eligible = BiomeConfig.getEligibleBiomes(rank: 8, distance: 5);
      expect(eligible, containsAll([BiomeType.unknown, BiomeType.range]));
      expect(eligible.length, equals(2));
    });

    test('Distance gate blocks high-rank biomes if distance is insufficient', () {
      // Even if rank is 5, if distance is only 1, biomes requiring distance >= 2 are blocked
      final eligible = BiomeConfig.getEligibleBiomes(rank: 5, distance: 1);
      expect(eligible, isEmpty);
    });
  });

  group('BiomeConfig pickBiome weighted selection', () {
    test('pickBiome returns regular if no special biomes are eligible', () {
      final picked = BiomeConfig.pickBiome(rank: 0, distance: 0);
      expect(picked, equals(BiomeType.regular));
    });

    test('pickBiome returns eligible special biome when available', () {
      final rng = Random(42);
      final picked = BiomeConfig.pickBiome(rank: 1, distance: 1, random: rng);
      expect(picked, equals(BiomeType.random));
    });

    test('pickBiome selects among eligible biomes according to weights', () {
      final counts = <BiomeType, int>{};
      final rng = Random(123);
      const iterations = 2000;

      for (int i = 0; i < iterations; i++) {
        final b = BiomeConfig.pickBiome(rank: 5, distance: 4, random: rng);
        counts[b] = (counts[b] ?? 0) + 1;
      }

      // All 4 eligible biomes (diagonal: 0.9, orthogonal: 0.8, unknown: 0.6, range: 0.5) must appear
      expect(counts[BiomeType.diagonal], greaterThan(0));
      expect(counts[BiomeType.orthogonal], greaterThan(0));
      expect(counts[BiomeType.unknown], greaterThan(0));
      expect(counts[BiomeType.range], greaterThan(0));

      // Higher weight biomes (diagonal: 0.9) should appear more frequently than range (0.5)
      expect(counts[BiomeType.diagonal]!, greaterThan(counts[BiomeType.range]!));
    });
  });

  group('BiomeConfig runtime custom rules & reset', () {
    test('custom rules can be set and reset to defaults', () {
      BiomeConfig.rules[BiomeType.unknown] = const BiomeRule(
        type: BiomeType.unknown,
        minRank: 1,
        maxRank: 1,
        minDistanceFromStart: 1,
      );

      final eligible = BiomeConfig.getEligibleBiomes(rank: 1, distance: 1);
      expect(eligible, contains(BiomeType.unknown));

      BiomeConfig.resetToDefaults();
      final resetEligible = BiomeConfig.getEligibleBiomes(rank: 1, distance: 1);
      expect(resetEligible, isNot(contains(BiomeType.unknown)));
    });
  });
}
