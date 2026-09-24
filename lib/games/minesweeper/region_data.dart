import 'dart:typed_data';

import '../../config/config.dart';
import 'inventory.dart';
import 'region_sparkles.dart';

// ── Dynamic Region Data Model ───────────────────────────────────────────────

class RegionData {
  final int r;
  final int c;
  final int rows;
  final int cols;
  final bool isStartingRegion;
  final int rank;
  final BiomeType biome;
  final int randomOffset;
  final Set<int> hiddenNumberIndices = {};
  bool hasChest;
  int? chestCellIndex;
  bool chestOpened;
  InventoryItemType? itemType;
  List<SparkleParticle>? sparkleParticles;
  late final Uint8List mines; // 1 = mine, 0 = safe
  late final Uint8List cellStates; // CellState values
  late final Uint8List adjacent; // cached adjacent mine counts (255 = uncomputed)
  bool isGenerated = false;
  bool isUnlocked = false;
  bool isCleared = false;
  int mineCount = 0;
  int flagCount = 0;
  int revealedCount = 0;

  RegionData({
    required this.r,
    required this.c,
    required this.rows,
    required this.cols,
    this.isStartingRegion = false,
    int? rank,
    BiomeType? biome,
    int? randomOffset,
    bool? hasChest,
    int? chestCellIndex,
    bool chestOpened = false,
    this.itemType,
    int? itemCellIndex,
    bool itemFound = false,
  })  : chestCellIndex = chestCellIndex ?? itemCellIndex,
        chestOpened = chestOpened || itemFound,
        hasChest = hasChest ?? (itemType != null || (chestCellIndex ?? itemCellIndex) != null),
        rank = rank ?? MinesweeperConfig.rankForRegion(r, c),
        biome = biome ?? BiomeType.regular,
        randomOffset = randomOffset ??
            ((biome ?? BiomeType.regular) == BiomeType.random
                ? (MinesweeperConfig.randomBiomeMinOffset +
                    (r * 31 + c * 17).abs() %
                        (MinesweeperConfig.randomBiomeMaxOffset -
                            MinesweeperConfig.randomBiomeMinOffset +
                            1))
                : 0) {
    final size = rows * cols;
    mines = Uint8List(size);
    cellStates = Uint8List(size);
    adjacent = Uint8List(size)..fillRange(0, size, 255);
  }

  int localIndex(int lr, int lc) => lr * cols + lc;
  int get safeCells => (rows * cols) - mineCount;
  bool get allSafeRevealed => revealedCount >= safeCells;
  bool get isBiomeRevealed => revealedCount > 0;
  bool get hasUnopenedChest => hasChest && !chestOpened;
  bool get hasItem => hasUnopenedChest;
  int? get itemCellIndex => chestCellIndex;
  set itemCellIndex(int? val) => chestCellIndex = val;
  bool get itemFound => chestOpened;
  set itemFound(bool val) => chestOpened = val;

  /// Returns the number displayed to the player.
  /// For cells in a Random biome, numbers (> 0) are offset by [randomOffset].
  /// Cells with 0 mines remain 0 (blank).
  int getDisplayedNumber(int localIndex) {
    final count = adjacent[localIndex];
    if (count == 255 || count == 0) return 0;
    if (biome == BiomeType.random) {
      return count + randomOffset;
    }
    return count;
  }
}
