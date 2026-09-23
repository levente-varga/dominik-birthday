import 'dart:math';

import '../../config/config.dart';

// ── Procedural World Generator (Randomized Ranks & Biomes with Blob Constraints) ──

class MinesweeperWorldGenerator {
  final int initialRegionX;
  final int initialRegionY;
  final bool isInfiniteWorld;
  final int? regionsX;
  final int? regionsY;
  final Random random;

  final Map<(int, int), int> assignedRanks = {};
  final Map<(int, int), BiomeType> assignedBiomes = {};

  static const List<(int, int)> _cardinalNeighbors = [
    (-1, 0), // North
    (1, 0),  // South
    (0, -1), // West
    (0, 1),  // East
  ];

  MinesweeperWorldGenerator({
    this.initialRegionX = MinesweeperConfig.initialRegionX,
    this.initialRegionY = MinesweeperConfig.initialRegionY,
    this.isInfiniteWorld = MinesweeperConfig.isInfiniteWorld,
    this.regionsX,
    this.regionsY,
    Random? random,
  }) : random = random ?? Random() {
    _initializeStart();
  }

  void _initializeStart() {
    // Starting region is always rank 0 and regular biome
    assignedRanks[(initialRegionY, initialRegionX)] = 0;
    assignedBiomes[(initialRegionY, initialRegionX)] = BiomeType.regular;
  }

  List<(int, int)> _getValidCardinalNeighbors(int r, int c) {
    final list = <(int, int)>[];
    for (final (dr, dc) in _cardinalNeighbors) {
      final nr = r + dr;
      final nc = c + dc;
      if (!isInfiniteWorld && (regionsX != null && regionsY != null)) {
        if (nr < 0 || nr >= regionsY! || nc < 0 || nc >= regionsX!) continue;
      }
      list.add((nr, nc));
    }
    return list;
  }

  /// Gets or generates the rank for region (r, c).
  int getOrGenerateRank(int r, int c) {
    if (assignedRanks.containsKey((r, c))) {
      return assignedRanks[(r, c)]!;
    }

    if (r == initialRegionY && c == initialRegionX) {
      assignedRanks[(r, c)] = 0;
      return 0;
    }

    final neighbors = _getValidCardinalNeighbors(r, c);

    // 1. Check if any assigned neighbor currently has no partner (lonely rank, blob size 1, rank >= 1)
    for (final neighbor in neighbors) {
      if (assignedRanks.containsKey(neighbor)) {
        final neighborRank = assignedRanks[neighbor]!;
        if (neighborRank > 0 &&
            !_hasAssignedNeighborWithRank(neighbor.$1, neighbor.$2, neighborRank, exclude: (r, c))) {
          assignedRanks[(r, c)] = neighborRank;
          return neighborRank;
        }
      }
    }

    // 2. Generate rank using continuous Perlin noise
    final baseRank = MinesweeperConfig.rankForRegion(
      r,
      c,
      startR: initialRegionY,
      startC: initialRegionX,
    );
    assignedRanks[(r, c)] = baseRank;

    // 3. Ensure baseRank is not alone: if rank >= 1, pair or adopt
    if (neighbors.isEmpty || baseRank == 0) {
      return assignedRanks[(r, c)]!;
    }
    final unassigned = neighbors.where((n) => !assignedRanks.containsKey(n)).toList();
    if (unassigned.isNotEmpty) {
      final sharesWithAssigned = neighbors.any((n) => assignedRanks[n] == baseRank);
      if (!sharesWithAssigned) {
        final partner = unassigned[random.nextInt(unassigned.length)];
        assignedRanks[partner] = baseRank;
      }
    } else {
      // All neighbors are already assigned: check if any neighbor already shares baseRank
      final sharesRank = neighbors.any((n) => assignedRanks[n] == baseRank);
      if (!sharesRank) {
        // Adopt the rank of one of the neighbors (excluding rank 0) to prevent being an isolated single-region rank
        final neighborRanks = neighbors.map((n) => assignedRanks[n]!).where((rk) => rk > 0).toList();
        if (neighborRanks.isNotEmpty) {
          assignedRanks[(r, c)] = neighborRanks[random.nextInt(neighborRanks.length)];
        }
      }
    }

    return assignedRanks[(r, c)]!;
  }

  bool _hasAssignedNeighborWithRank(int r, int c, int rank, {(int, int)? exclude}) {
    for (final n in _getValidCardinalNeighbors(r, c)) {
      if (exclude != null && n == exclude) continue;
      if (assignedRanks[n] == rank) return true;
    }
    return false;
  }

  /// Gets or generates the biome for region (r, c).
  BiomeType getOrGenerateBiome(int r, int c) {
    if (assignedBiomes.containsKey((r, c))) {
      return assignedBiomes[(r, c)]!;
    }

    // If starting region, always regular
    if (r == initialRegionY && c == initialRegionX) {
      assignedBiomes[(r, c)] = BiomeType.regular;
      return BiomeType.regular;
    }

    final rank = getOrGenerateRank(r, c);
    final distance = MinesweeperConfig.calculateRegionDistance(
      r,
      c,
      startR: initialRegionY,
      startC: initialRegionX,
    );
    final neighbors = _getValidCardinalNeighbors(r, c);
    if (neighbors.isEmpty) {
      assignedBiomes[(r, c)] = BiomeType.regular;
      return BiomeType.regular;
    }

    // 1. Check if any assigned neighbor has a special biome and has no partner (blob size 1)
    for (final neighbor in neighbors) {
      final neighborBiome = assignedBiomes[neighbor];
      if (neighborBiome != null && neighborBiome != BiomeType.regular) {
        if (!_hasAssignedNeighborWithBiome(neighbor.$1, neighbor.$2, neighborBiome, exclude: (r, c))) {
          if (BiomeConfig.isBiomeAllowed(biome: neighborBiome, rank: rank, distance: distance)) {
            assignedBiomes[(r, c)] = neighborBiome;
            return neighborBiome;
          }
        }
      }
    }

    // 2. Roll if a special biome starts in this region based on its rank
    final spawnChance = MinesweeperConfig.biomeSpawnChanceForRankFunction(rank);
    final shouldSpawn = random.nextDouble() < spawnChance;

    if (shouldSpawn) {
      final eligibleBiomes = BiomeConfig.getEligibleBiomes(rank: rank, distance: distance);
      if (eligibleBiomes.isNotEmpty) {
        final unassigned = neighbors.where((n) => !assignedBiomes.containsKey(n)).toList();

        final validBiomes = eligibleBiomes.where((b) {
          final hasCompatibleUnassigned = unassigned.any((n) {
            final nRank = getOrGenerateRank(n.$1, n.$2);
            final nDist = MinesweeperConfig.calculateRegionDistance(
              n.$1,
              n.$2,
              startR: initialRegionY,
              startC: initialRegionX,
            );
            return BiomeConfig.isBiomeAllowed(biome: b, rank: nRank, distance: nDist);
          });
          if (hasCompatibleUnassigned) return true;

          return neighbors.any((n) => assignedBiomes[n] == b);
        }).toList();

        if (validBiomes.isNotEmpty) {
          final chosenBiome = _pickWeightedBiome(validBiomes, random);
          final compatibleUnassigned = unassigned.where((n) {
            final nRank = getOrGenerateRank(n.$1, n.$2);
            final nDist = MinesweeperConfig.calculateRegionDistance(
              n.$1,
              n.$2,
              startR: initialRegionY,
              startC: initialRegionX,
            );
            return BiomeConfig.isBiomeAllowed(biome: chosenBiome, rank: nRank, distance: nDist);
          }).toList();

          if (compatibleUnassigned.isNotEmpty) {
            final partner = compatibleUnassigned[random.nextInt(compatibleUnassigned.length)];
            assignedBiomes[(r, c)] = chosenBiome;
            assignedBiomes[partner] = chosenBiome;
            return chosenBiome;
          } else {
            final hasMatchingNeighbor = neighbors.any((n) => assignedBiomes[n] == chosenBiome);
            if (hasMatchingNeighbor) {
              assignedBiomes[(r, c)] = chosenBiome;
              return chosenBiome;
            }
          }
        }
      }
    }

    assignedBiomes[(r, c)] = BiomeType.regular;
    return BiomeType.regular;
  }

  BiomeType _pickWeightedBiome(List<BiomeType> candidates, Random rng) {
    if (candidates.length == 1) return candidates.first;
    double totalWeight = 0.0;
    for (final b in candidates) {
      totalWeight += BiomeConfig.getRule(b).weight;
    }
    if (totalWeight <= 0.0) return candidates[rng.nextInt(candidates.length)];
    double roll = rng.nextDouble() * totalWeight;
    for (final b in candidates) {
      final w = BiomeConfig.getRule(b).weight;
      if (roll < w) return b;
      roll -= w;
    }
    return candidates.last;
  }

  bool _hasAssignedNeighborWithBiome(int r, int c, BiomeType biome, {(int, int)? exclude}) {
    for (final n in _getValidCardinalNeighbors(r, c)) {
      if (exclude != null && n == exclude) continue;
      if (assignedBiomes[n] == biome) return true;
    }
    return false;
  }

  /// Helper to pre-generate all regions in a finite grid and enforce blob invariants
  void pregenerateGrid(int rows, int cols) {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        getOrGenerateRank(r, c);
        getOrGenerateBiome(r, c);
      }
    }
    _enforceRankBlobs(rows, cols);
    _enforceBiomeBlobs(rows, cols);
  }

  void _enforceRankBlobs(int rows, int cols) {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (r == initialRegionY && c == initialRegionX) continue;
        final rank = assignedRanks[(r, c)]!;
        if (rank > 0 && !_hasAssignedNeighborWithRank(r, c, rank)) {
          final neighbors = _getValidCardinalNeighbors(r, c)
              .where((n) => n != (initialRegionY, initialRegionX))
              .toList();
          if (neighbors.isNotEmpty) {
            assignedRanks[(r, c)] = assignedRanks[neighbors.first]!;
          }
        }
      }
    }
  }

  void _enforceBiomeBlobs(int rows, int cols) {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final biome = assignedBiomes[(r, c)]!;
        if (biome != BiomeType.regular && !_hasAssignedNeighborWithBiome(r, c, biome)) {
          final neighbors = _getValidCardinalNeighbors(r, c);
          final regularNeighbors = neighbors.where((n) => assignedBiomes[n] == BiomeType.regular).toList();
          final compatibleNeighbor = regularNeighbors.firstWhere(
            (n) {
              final nRank = assignedRanks[n] ?? 0;
              final nDist = MinesweeperConfig.calculateRegionDistance(
                n.$1,
                n.$2,
                startR: initialRegionY,
                startC: initialRegionX,
              );
              return BiomeConfig.isBiomeAllowed(biome: biome, rank: nRank, distance: nDist);
            },
            orElse: () => (-1, -1),
          );
          if (compatibleNeighbor != (-1, -1)) {
            assignedBiomes[compatibleNeighbor] = biome;
          } else {
            assignedBiomes[(r, c)] = BiomeType.regular;
          }
        }
      }
    }
  }
}
