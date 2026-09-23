import 'dart:math' as math;

/// Types of biomes that can appear in regions.
enum BiomeType {
  /// Regular region with standard rules.
  regular,

  /// Unknown biome with lighter red border and non-chordable hidden number '?' cells.
  unknown,

  /// Random biome: all numbers are larger by a random amount unified through the entire region.
  random,

  /// Diagonal biome: numbers only see mines diagonally.
  diagonal,

  /// Orthogonal biome: numbers only see mines orthogonally (opposite of diagonal).
  orthogonal,

  /// Range biome: numbers indicate mines from up to 2 tiles away (even into adjacent regions).
  range,
}

/// Generation rule for a biome type defining its rank range, minimum distance, and rarity weight.
class BiomeRule {
  final BiomeType type;

  /// Minimum region rank required for this biome to generate.
  final int minRank;

  /// Maximum region rank allowed for this biome to generate.
  final int maxRank;

  /// Minimum distance from the starting region (using Manhattan metric by default) required to spawn.
  final int minDistanceFromStart;

  /// Relative rarity weight among eligible biomes when a special biome spawns.
  final double weight;

  const BiomeRule({
    required this.type,
    required this.minRank,
    required this.maxRank,
    this.minDistanceFromStart = 0,
    this.weight = 1.0,
  });

  /// Checks if this biome is allowed to generate at a given [rank] and [distance].
  bool canGenerate({required int rank, required int distance}) {
    return rank >= minRank && rank <= maxRank && distance >= minDistanceFromStart;
  }
}

/// Configuration manager for biome generation rules, rank ranges, distance constraints, and rarity.
class BiomeConfig {
  /// Default rules for all biome types.
  static const Map<BiomeType, BiomeRule> defaultRules = {
    BiomeType.regular: BiomeRule(
      type: BiomeType.regular,
      minRank: 0,
      maxRank: 999,
      minDistanceFromStart: 0,
      weight: 1.0,
    ),
    BiomeType.random: BiomeRule(
      type: BiomeType.random,
      minRank: 1,
      maxRank: 4,
      minDistanceFromStart: 1,
      weight: 1.0,
    ),
    BiomeType.diagonal: BiomeRule(
      type: BiomeType.diagonal,
      minRank: 2,
      maxRank: 5,
      minDistanceFromStart: 2,
      weight: 0.9,
    ),
    BiomeType.orthogonal: BiomeRule(
      type: BiomeType.orthogonal,
      minRank: 3,
      maxRank: 6,
      minDistanceFromStart: 2,
      weight: 0.8,
    ),
    BiomeType.unknown: BiomeRule(
      type: BiomeType.unknown,
      minRank: 4,
      maxRank: 8,
      minDistanceFromStart: 3,
      weight: 0.6,
    ),
    BiomeType.range: BiomeRule(
      type: BiomeType.range,
      minRank: 5,
      maxRank: 8,
      minDistanceFromStart: 4,
      weight: 0.5,
    ),
  };

  /// Active rules for biome generation. Can be modified at runtime (e.g. in tests).
  static Map<BiomeType, BiomeRule> rules = Map<BiomeType, BiomeRule>.from(defaultRules);

  /// Resets active rules back to default settings.
  static void resetToDefaults() {
    rules = Map<BiomeType, BiomeRule>.from(defaultRules);
  }

  /// Gets the rule for a specific biome type.
  static BiomeRule getRule(BiomeType biome) {
    return rules[biome] ??
        defaultRules[biome] ??
        BiomeRule(
          type: biome,
          minRank: 0,
          maxRank: 999,
          minDistanceFromStart: 0,
          weight: 1.0,
        );
  }

  /// Checks if a biome is allowed to generate at the given [rank] and [distance].
  static bool isBiomeAllowed({
    required BiomeType biome,
    required int rank,
    required int distance,
  }) {
    if (biome == BiomeType.regular) return true;
    final rule = rules[biome];
    if (rule == null) return false;
    return rule.canGenerate(rank: rank, distance: distance);
  }

  /// Returns a list of special biomes eligible to generate at [rank] and [distance].
  /// Excludes `BiomeType.regular`.
  static List<BiomeType> getEligibleBiomes({
    required int rank,
    required int distance,
  }) {
    final eligible = <BiomeType>[];
    for (final entry in rules.entries) {
      if (entry.key == BiomeType.regular) continue;
      if (entry.value.canGenerate(rank: rank, distance: distance)) {
        eligible.add(entry.key);
      }
    }
    return eligible;
  }

  /// Selects a biome from eligible biomes using weighted random selection based on [BiomeRule.weight].
  /// If no special biomes are eligible, returns [BiomeType.regular].
  static BiomeType pickBiome({
    required int rank,
    required int distance,
    math.Random? random,
  }) {
    final eligible = getEligibleBiomes(rank: rank, distance: distance);
    if (eligible.isEmpty) {
      return BiomeType.regular;
    }

    final rng = random ?? math.Random();
    double totalWeight = 0.0;
    for (final b in eligible) {
      totalWeight += (rules[b]?.weight ?? 1.0);
    }

    if (totalWeight <= 0.0) {
      return eligible[rng.nextInt(eligible.length)];
    }

    double roll = rng.nextDouble() * totalWeight;
    for (final b in eligible) {
      final w = rules[b]?.weight ?? 1.0;
      if (roll < w) {
        return b;
      }
      roll -= w;
    }

    return eligible.last;
  }
}
