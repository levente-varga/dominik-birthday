import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../games/minesweeper/perlin_noise.dart';
import 'biome_config.dart';

export 'speed_typing_config.dart';
export 'spot_impostor_config.dart';
export 'biome_config.dart';

/// Base class for game configurations.
abstract class BaseGameConfig {
  /// Standard delay before proceeding upon completing a stage.
  static const Duration winTransitionDelay = Duration(milliseconds: 600);

  /// Standard delay before proceeding upon failing a stage.
  static const Duration failTransitionDelay = Duration(milliseconds: 600);

  final IconData icon;

  const BaseGameConfig({required this.icon});
}

class MinesweeperConfig extends BaseGameConfig {
  /// Number of regions across the world map
  static const int regionsX = 5;
  static const int regionsY = 5;

  /// Starting region coordinates (0-indexed, default is middle region)
  static const int initialRegionX = 2;
  static const int initialRegionY = 2;

  /// Number of cells per region (parameterized for experimentation, e.g. 7x7)
  static const int regionRows = 7;
  static const int regionCols = 7;

  /// Mine density (fraction of total world cells that are mines, e.g. 0.15 = 15%)
  static const double mineDensity = 0.15;

  /// Number of cells in a single region
  static int get cellsPerRegion => regionRows * regionCols;

  /// Exact number of mines in each region (uniform across all regions)
  static int get minesPerRegion => (cellsPerRegion * mineDensity).round();

  /// Distance metric used for region distance calculations. Defaults to Manhattan distance.
  static const RegionDistanceMetric distanceMetric = RegionDistanceMetric.manhattan;

  /// Calculates the distance of a region at ([r], [c]) from the starting region at ([startR], [startC]).
  static int calculateRegionDistance(
    int r,
    int c, {
    int startR = initialRegionY,
    int startC = initialRegionX,
    RegionDistanceMetric metric = distanceMetric,
  }) {
    final dr = (r - startR).abs();
    final dc = (c - startC).abs();
    switch (metric) {
      case RegionDistanceMetric.chebyshev:
        return math.max(dr, dc);
      case RegionDistanceMetric.manhattan:
        return dr + dc;
      case RegionDistanceMetric.euclidean:
        return math.sqrt(dr * dr + dc * dc).round();
    }
  }

  /// Power exponent applied to noise when generating ranks.
  /// Higher values make higher ranks exponentially less likely.
  static const double rankNoisePower = 2.0;

  /// Highest rank possible on the world map, corresponding to noise = 1.0.
  static const int highestRank = 8;

  /// Scaling factor (wavelength) of the rank Perlin noise.
  /// Sized so that regions directly adjacent to the starting region are rank 1.
  static const double rankNoiseScale = 6.0;

  /// Default seed for reproducible Perlin rank noise generation.
  static const int rankNoiseSeed = 42;

  /// Active 2D Vector Perlin generator for rank noise.
  static VectorPerlin2D rankNoiseGenerator = VectorPerlin2D(rankNoiseSeed);

  /// Resets or updates the seed for rank noise generation.
  static void setRankNoiseSeed(int seed) {
    rankNoiseGenerator = VectorPerlin2D(seed);
  }

  /// Samples continuous 2D Vector Perlin noise in [0.0, 1.0] for region ([r], [c]).
  /// Returns 0.0 for the starting region ([startR], [startC]).
  static double sampleRankNoise(
    int r,
    int c, {
    int startR = initialRegionY,
    int startC = initialRegionX,
    double scale = rankNoiseScale,
    VectorPerlin2D? generator,
  }) {
    if (r == startR && c == startC) return 0.0;
    final gen = generator ?? rankNoiseGenerator;
    final dr = (r - startR).toDouble() / scale;
    final dc = (c - startC).toDouble() / scale;
    return gen.sample(dr, dc);
  }

  /// Calculates the rank of a region at ([r], [c]) using Perlin noise.
  /// Rank 0 is guaranteed for the starting region where noise is 0.0.
  /// Where noise is 1.0, it evaluates to [highestRank].
  /// The continuous noise is raised to [rankNoisePower] (making higher values less likely),
  /// scaled to [highestRank], and clamped between 1 and [highestRank] for non-start regions.
  static int calculateRegionRank(
    int r,
    int c, {
    int startR = initialRegionY,
    int startC = initialRegionX,
    RegionDistanceMetric metric = distanceMetric,
    double? power,
    int? maxRank,
    double? scale,
    VectorPerlin2D? generator,
  }) {
    if (r == startR && c == startC) return 0;
    final p = power ?? rankNoisePower;
    final maxR = maxRank ?? highestRank;
    final s = scale ?? rankNoiseScale;
    final noise = sampleRankNoise(
      r,
      c,
      startR: startR,
      startC: startC,
      scale: s,
      generator: generator,
    );
    final vPow = math.pow(noise, p).toDouble();
    final rawRank = (vPow * maxR).round();
    return rawRank.clamp(1, maxR);
  }

  /// Rolls a randomized rank based on Manhattan distance from the starting region.
  /// With each increasing distance from the start, the chance for a higher rank gets higher.
  static int rollRankForDistance(int distance, {math.Random? random}) {
    if (distance <= 0) return 0;
    final rng = random ?? math.Random();
    int rank = 0;
    for (int i = 0; i < distance; i++) {
      if (rng.nextDouble() < 0.75) {
        rank++;
      }
    }
    if (rng.nextDouble() < 0.15) {
      rank++;
    }
    return rank;
  }

  /// Pluggable function to roll a rank based on distance.
  static int Function(int distance, {math.Random? random})
      rollRankForDistanceFunction = rollRankForDistance;

  /// Probability of a biome starting in a region of a given [rank] (0.0 to 1.0).
  /// The higher the rank, the higher the chance of a biome starting in it.
  static double biomeSpawnChanceForRank(int rank) {
    if (rank <= 0) return 0.0;
    return (0.05 + rank * 0.15).clamp(0.0, 0.85);
  }

  /// Pluggable function to determine biome spawn chance.
  static double Function(int rank) biomeSpawnChanceForRankFunction =
      biomeSpawnChanceForRank;

  /// Pluggable function to determine the rank of a region.
  /// Defaults to [calculateRegionRank].
  static int Function(
    int r,
    int c, {
    int startR,
    int startC,
    RegionDistanceMetric metric,
  }) rankForRegionFunction = calculateRegionRank;

  /// Returns the rank for a region at ([r], [c]).
  static int rankForRegion(
    int r,
    int c, {
    int startR = initialRegionY,
    int startC = initialRegionX,
    RegionDistanceMetric metric = distanceMetric,
  }) {
    return rankForRegionFunction(
      r,
      c,
      startR: startR,
      startC: startC,
      metric: metric,
    );
  }

  /// Function that determines the amount of mines for a region of a given [rank].
  ///
  /// Linear correlation: base mines (for rank 0) plus an increased amount equal to its rank.
  static int rankToMineCount(
    int rank, {
    int? baseMines,
    int? maxMines,
  }) {
    final base = baseMines ?? minesPerRegion;
    final target = base + rank;
    final maxAllowed = maxMines ?? (cellsPerRegion - 1);
    return target.clamp(0, maxAllowed);
  }

  /// Pluggable function that determines the amount of mines relative to rank.
  /// Defaults to [rankToMineCount].
  static int Function(int rank, {int? baseMines, int? maxMines})
      rankToMineCountFunction = rankToMineCount;

  /// Calculates the number of mines for a region at ([r], [c]) based on its rank.
  static int minesForRegion(
    int r,
    int c, {
    int startR = initialRegionY,
    int startC = initialRegionX,
    int? baseMines,
    int? maxMines,
    RegionDistanceMetric metric = distanceMetric,
  }) {
    final rank = rankForRegion(
      r,
      c,
      startR: startR,
      startC: startC,
      metric: metric,
    );
    return rankToMineCountFunction(
      rank,
      baseMines: baseMines,
      maxMines: maxMines,
    );
  }

  /// Legacy alias: maps distance to mine count using [rankToMineCount].
  static int calculateMinesForDistance(
    int distance, {
    int? baseMines,
    int? maxMines,
  }) =>
      rankToMineCount(distance, baseMines: baseMines, maxMines: maxMines);

  /// Legacy alias for pluggable distance-to-mine function.
  static int Function(int distance, {int? baseMines, int? maxMines})
      get minesForDistanceFunction => rankToMineCountFunction;
  static set minesForDistanceFunction(
    int Function(int distance, {int? baseMines, int? maxMines}) fn,
  ) {
    rankToMineCountFunction = fn;
  }

  /// Total world map dimensions
  static int get worldRows => regionsY * regionRows;
  static int get worldCols => regionsX * regionCols;
  static int get totalCells => worldRows * worldCols;
  static int get totalMines => regionsX * regionsY * minesPerRegion;

  /// Legacy properties for backwards compatibility
  static int get baseRows => worldRows;
  static int get baseCols => worldCols;
  static int get baseMines => totalMines;
  static const int gridDimReductionPerSkillLevel = 0;
  static int get minRows => worldRows;
  static int get minCols => worldCols;

  /// Visual cell styling for region display
  static const double cellSize = 34.0;
  static const double cellGap = 4.0;
  static const double boardPadding = 1;

  /// Gap between adjacent region panels (Option B distinct panel gap)
  static const double panelGap = 2.0;

  /// Corner radius of region panels (default 12.0)
  static const double panelCornerRadius = 12.0;
  static const double regionPanelCornerRadius = 12.0;

  /// Number of adjacent rows/columns shown from neighboring panels (default 2)
  static const int peekDepth = 2;

  /// Touch navigation swipe settings
  static const double swipeThreshold = 80.0;

  /// Minimum drag distance required before the map begins translating (default 10.0)
  static const double dragMinThreshold = 10.0;

  /// Number of sectors displayed across the minimap (7x7 sector window)
  static const int minimapSize = 7;
  static const int minimapCols = 7;
  static const int minimapRows = 7;

  /// Mine field cell styling
  static const double cellFlagIconSize = 18.0;
  static const double cellNumberFontSize = 15.0;

  /// Top header control sizing and spacing
  static const double headerControlTop = 12.0;
  static const double headerCornerPadding = 12.0;
  static const double headerButtonSize = 42.0;
  static const double headerControlHeight = 42.0;
  static const double headerControlRadius = 9.0;
  static const double headerControlBorderWidth = 1.0;

  /// Control bar gradient overlay styling (1 cell wide, 40% transparent to 100% transparent)
  static const double barGradientOverlayNearAlpha = 0.60; // 40% transparent (60% opacity)
  static const double barGradientOverlayFarAlpha = 0.0; // 100% transparent (0% opacity)

  /// Badge sizing and styling
  static const double headerBadgeHeight = headerButtonSize;
  static const double headerBadgeRadius = 9.0;
  static const double headerBadgeBorderWidth = 1.0;
  static const double headerBadgeHorizontalPadding = 8.0;
  static const double headerBadgeGap = 6.0;
  static const double headerBadgeInnerGap = 5.0;

  /// Mine counter badge styling
  static const IconData mineCounterIcon = Icons.brightness_7_rounded;
  static const Color mineCounterIconColor = Colors.red;
  static const double mineCounterHorizontalPadding = headerBadgeHorizontalPadding;
  static const double mineCounterIconSize = cellFlagIconSize;
  static const double mineCounterGap = headerBadgeInnerGap;
  static const double mineCounterFontSize = cellNumberFontSize;

  /// Rank badge styling
  static const IconData rankIcon = Icons.military_tech_rounded;
  static const Color rankIconColor = Color(0xFFFFC107);
  static const String rankPrefix = '';
  static const double rankBadgeIconSize = cellFlagIconSize;
  static const double rankBadgeFontSize = cellNumberFontSize;

  /// Pause / Home button styling
  static const double pauseButtonIconSize = 21.0;
  static const double homeButtonIconSize = 24.0;

  /// Minimap sizing and layout
  static const double minimapCellSlot = 15.0;
  static const double minimapCellInner = 12.0;
  static const double minimapCellMargin = 1.5;
  static const double minimapCellRadius = 2.25;
  static const double minimapOverlayRadius = 2.25;
  static const double minimapPadding = 0.0;
  static const double minimapRadius = 9.0;
  static const double minimapInnerRadius = 8.0;
  static const double minimapDotSize = 4.5;

  /// Minimap cell background colors
  static const Color minimapFinishedColor = AppColors.amberMedium; // pale gold for finished regions
  static const Color minimapStartedColor = AppColors.blueMedium; // pale blue for started regions
  static const Color minimapDiscoveredColor = AppColors.panelHigh;

  /// Correctly placed flag styling on loss
  static const Color correctFlagLossBackgroundColor = Color(0xFFFFC107);
  static const Color correctFlagLossIconColor = Colors.black;

  /// Biome styling & configuration
  static const Color unknownBiomeBorderColor = Color(0xFFEF5350); // Lighter red (Material Red 400)
  static const Color randomBiomeBorderColor = Color(0xFFAB47BC); // Purple
  static const Color diagonalBiomeBorderColor = Color(0xFF00BCD4); // Cyan
  static const Color orthogonalBiomeBorderColor = Color(0xFFFFA726); // Amber/Orange
  static const Color rangeBiomeBorderColor = Color(0xFF66BB6A); // Green

  static Color? biomeBorderColor(BiomeType biome) {
    switch (biome) {
      case BiomeType.unknown:
        return unknownBiomeBorderColor;
      case BiomeType.random:
        return randomBiomeBorderColor;
      case BiomeType.diagonal:
        return diagonalBiomeBorderColor;
      case BiomeType.orthogonal:
        return orthogonalBiomeBorderColor;
      case BiomeType.range:
        return rangeBiomeBorderColor;
      case BiomeType.regular:
        return null;
    }
  }

  static const double unknownBiomeBorderWidth = 1.5;
  static const double unknownBiomeMinimapBorderWidth = 1.0;
  static const int unknownBiomeHiddenCellCount = 2;

  /// Region panel styling & selection highlighting
  /// Base background color for special biome region panels (default #16141A)
  static const Color regionPanelBaseColor = Color(0xFF16141A);

  /// Background color for regular / basic region panels (original AppColors.panelMedium = #201E24)
  static const Color regularRegionPanelBackgroundColor = AppColors.panelMedium;

  /// Gentle tint alpha for region background panel matching border/biome color (default 8%)
  static const double regionPanelTintAlpha = 0.08;

  /// Gentler tint alpha for unrevealed cells matching border/biome color (default 5.0%)
  static const double unrevealedCellTintAlpha = 0.050;

  /// First iteration peak border color for selected regular region on entry pulse (first iteration level, 60% alpha)
  static const Color firstIterationRegularBorderColor = Color(0x99C7C1CA);

  /// Idle breathing pulse peak border color for selected regular region (subtle, ~25% alpha)
  static const Color idlePulseRegularBorderColor = Color(0x40C7C1CA);

  /// Non-selected / baseline region regular border color (dim outline, 10% alpha)
  static const Color nonSelectedRegularBorderColor = Color(0x1A9E9E9E);

  /// Opacity multiplier for border of selected special biome on entry pulse (first iteration level, 100%)
  static const double firstIterationBiomeBorderAlpha = 1.0;

  /// Opacity multiplier for border of selected special biome during idle breathing pulse (subtle, 55%)
  static const double idlePulseBiomeBorderAlpha = 0.55;

  /// Opacity multiplier / alpha for borders of non-selected / baseline special biome regions (default 40%)
  static const double nonSelectedBiomeBorderAlpha = 0.40;

  /// Duration for single entry pulse (ease-out in + ease-out out)
  static const Duration borderEntryPulseDuration = Duration(milliseconds: 650);

  /// Half-cycle duration for slow idle breathing border pulse
  static const Duration borderIdlePulseDuration = Duration(milliseconds: 1800);

  /// Whether continuous idle border pulsing is enabled
  static const bool enableContinuousIdlePulse = true;

  /// Whether continuous idle border pulsing should repeat indefinitely in test environments
  static const bool enableContinuousIdlePulseInTests = false;

  /// Selected region regular border color (alias for backward compatibility)
  static const Color selectedRegularBorderColor = firstIterationRegularBorderColor;

  /// Opacity multiplier for selected special biome border (alias for backward compatibility)
  static const double selectedBiomeBorderAlpha = firstIterationBiomeBorderAlpha;

  static const int randomBiomeMinOffset = 1;
  static const int randomBiomeMaxOffset = 3;

  /// Computes the outer corner radius for the minimap, scaled when expanded by sizeRatio
  static double minimapCornerRadius({required bool isExpanded, double sizeRatio = 1.0}) {
    if (!isExpanded) return minimapRadius;
    return minimapRadius * sizeRatio;
  }

  /// Computes the inner clip corner radius for the minimap, scaled when expanded by sizeRatio
  static double minimapInnerCornerRadius({required bool isExpanded, double sizeRatio = 1.0}) {
    if (!isExpanded) return minimapInnerRadius;
    return minimapInnerRadius * sizeRatio;
  }

  /// Unified padding around the minimap when expanded
  static const double minimapExpandedPadding = 16.0;

  /// Duration for minimap expand and collapse animation
  static const Duration minimapExpandDuration = Duration(milliseconds: 300);

  /// Curve for minimap expand and collapse animation
  static const Curve minimapExpandCurve = Curves.easeOutCirc;

  /// Duration and curve for minimap selected region jumping to center during drag
  static const Duration minimapJumpDuration = Duration(milliseconds: 180);
  static const Curve minimapJumpCurve = Curves.easeOut;

  /// Duration for candidate region fade-in and fade-out cross-fade transitions
  static const Duration candidateFadeDuration = Duration(milliseconds: 200);

  /// Duration required to place or remove a flag via long tap
  static const Duration longTapDuration = Duration(milliseconds: 250);

  /// Overlay transparency settings (0.0 = fully opaque / 100% overlay, 1.0 = fully transparent / 0% overlay)
  /// Near edge (closest to active panel) gradient transparency (1.0 = 0% overlay opacity)
  static const double gradientNearTransparency = 1.0;

  /// Far edge (facing away from active panel) gradient transparency (0.0 = 100% overlay opacity)
  static const double gradientFarTransparency = 0.0;

  /// Transparency for neighbor region panels (0.50 = 50% faded)
  static const double neighborRegionTransparency = 0.3;

  /// Constant overlay transparency applied to the rest of the incoming panel (non-edge cells)
  static const double incomingPanelOverlayTransparency = 0.20;

  /// Touch highlight color applied to tapped unrevealed and flagged cells (a bit lighter grey than ordinary)
  static const Color touchHighlightColor = Color(0x2EFFFFFF);
  static const Duration touchHighlightFadeDuration = Duration(milliseconds: 150);

  /// Faint darkgrey border color for adjacent panel outlines when the panel is hidden
  static const Color adjacentPanelOutlineColor = Color(0xFF383540);

  /// Style of gradient overlay applied on top of the game area around the active region
  static const OverlayGradientStyle overlayGradientStyle =
      OverlayGradientStyle.splitLinear;

  /// Whether regions are locked and hidden until a directly adjacent cell is revealed
  static const bool lockInaccessibleRegions = true;

  /// Duration for newly unlocked regions to fade in
  static const Duration regionUnlockFadeDuration = Duration(milliseconds: 350);

  /// Whether the game world is infinite and generates regions procedurally on discovery
  static const bool isInfiniteWorld = true;

  /// Number of cleared regions required to win / complete the stage in Run mode
  static const int regionsToWin = 1;

  const MinesweeperConfig() : super(icon: Icons.brightness_7_rounded);
}

/// Distance metric for calculating region distance from the starting region.
enum RegionDistanceMetric {
  /// Chebyshev distance (L-infinity norm): max(|dr|, |dc|).
  /// Diagonal neighbor regions are 1 step away (matching 8-directional swipe navigation).
  chebyshev,

  /// Manhattan distance (L1 norm): |dr| + |dc|.
  manhattan,

  /// Euclidean distance (L2 norm): sqrt(dr^2 + dc^2).
  euclidean,
}

/// Style of gradient overlay applied on the game area around the active region.
enum OverlayGradientStyle {
  /// Two linear gradients (one H, one V) split diagonally at the corners so they don't overlap.
  splitLinear,

  /// Radial gradient from the center with the active region clipped out.
  radial,
}



// ── Legacy Stage Configs (Preserved for Skill Tree & Stage metadata references) ──

class TargetShootingConfig extends BaseGameConfig {
  static const int targetCount = 20;
  static const int targetCountReductionPerSkillLevel = 2;
  static const double targetRadius = 15.0;
  static const double targetRadiusIncreasePerSkillLevel = 0.10;
  static const int bulletsPerMinute = 40;
  static const int bulletsPerMinutePerSkillLevel = 20;
  static const double swayStrength = 4.0;
  static const double swayReductionPerSkillLevel = 0.50;
  static const double targetSpeed = 2.5;
  static const double targetSpeedReductionPerSkillLevel = 0.05;

  const TargetShootingConfig() : super(icon: Icons.gps_fixed_rounded);
}

class BallBounceConfig extends BaseGameConfig {
  static const double initialSpeed = 4;
  static const double basePaddleWidth = 30.0;
  static const double paddleWidthIncreasePerSkillLevel = 0.35;
  static const double baseSpeedIncrease = 0.08;
  static const double speedIncreaseBonusPerSkillLevel = 0.05;
  static const double maxSpeedIncrease = 0.10;
  static const int targetBounces = 20;
  static const int bouncesReductionPerSkillLevel = 2;
  static const double anomalyMaxWallDeflectionDegrees = 30.0;
  static const double minAngleFromHorizontalDegrees = 10.0;

  const BallBounceConfig() : super(icon: Icons.sports_tennis_rounded);
}

class BulletHellConfig extends BaseGameConfig {
  static const double baseProjectileSpeedMin = 2.0;
  static const double baseProjectileSpeedVariance = 1.5;
  static const int baseProjectileCount = 20;
  static const int minProjectileCount = 6;
  static const int projectileReductionPerSkillLevel = 2;
  static const double projectileSpeedReductionPerSkillLevel = 0.08;
  static const int baseCollectibleCount = 8;
  static const int reducedCollectibleCount = 4;
  static const double missileConversionRatio = 0.2;
  static const double missileSpeedRatio = 1.5;
  static const double anomalyHomingRotationSpeed = 3;

  const BulletHellConfig() : super(icon: Icons.shield_rounded);
}

class CodeCrackerConfig extends BaseGameConfig {
  static const int slots = 4;
  static const int minSlots = 2;
  static const int slotsReductionPerSkillLevel = 1;
  static const int colorCount = 8;
  static const int colorReductionPerSkillLevel = 1;
  static const int minColorCount = 3;
  static const int baseMaxAttempts = 6;

  const CodeCrackerConfig() : super(icon: Icons.key_rounded);
}

class MemoryMatchConfig extends BaseGameConfig {
  static const int baseCardCount = 56;
  static const int cardCountReductionPerSkillLevel = 8;
  static const int baseMaxRevealsPerTurn = 2;
  static const int revealsPerSkillLevel = 1;
  static const int anomalyBonusReveals = 2;

  const MemoryMatchConfig() : super(icon: Icons.style_rounded);

  static (int cols, int rows) calculateOptimalGridDimensions(int totalCards) {
    int bestCols = totalCards;
    int bestRows = 1;
    int minDiff = totalCards;

    final sqrtVal = (math.sqrt(totalCards)).floor();
    for (int r = sqrtVal; r >= 1; r--) {
      if (totalCards % r == 0) {
        final c = totalCards ~/ r;
        final diff = c - r;
        if (diff < minDiff) {
          minDiff = diff;
          bestCols = c;
          bestRows = r;
        }
        break;
      }
    }

    return (bestCols, bestRows);
  }
}

class MemoryMatrixConfig extends BaseGameConfig {
  static const int gridDim = 9;
  static const int gridDimReductionPerSkillLevel = 1;
  static const int minGridDim = 4;
  static const int baseTargetCount = 14;
  static const int targetReductionPerSkillLevel = 2;
  static const int minTargetCount = 3;
  static const int baseRevealMs = 700;
  static const int extraRevealMsForAnomaly = 350;

  const MemoryMatrixConfig() : super(icon: Icons.grid_on_rounded);
}

class MentalMathConfig extends BaseGameConfig {
  static const int baseTargetCount = 6;
  static const int targetCountReductionPerSkillLevel = 1;
  static const int minTargetCount = 1;
  static const int includeComplexThreshold = 2;
  static const int defaultDifficulty = 0;

  const MentalMathConfig() : super(icon: Icons.functions_rounded);
}

class NumberGuesserConfig extends BaseGameConfig {
  static const int baseMaxNumber = 9;
  static const int numberReductionPerLevel = 1;
  static const int minMaxNumber = 3;
  static const int baseAttempts = 1;

  const NumberGuesserConfig() : super(icon: Icons.casino_outlined);
}

class SequenceFlashConfig extends BaseGameConfig {
  static const int sequenceLength = 14;
  static const int baseFlashMs = 600;
  static const int flashMsPerSkillLevel = -80;
  static const int lengthReductionPerSkillLevel = 2;

  const SequenceFlashConfig() : super(icon: Icons.grid_view_rounded);
}

class StroopTestConfig extends BaseGameConfig {
  static const int baseIterations = 20;
  static const int iterationDecreasePerSkillLevel = 3;
  static const int minIterations = 3;

  const StroopTestConfig() : super(icon: Icons.palette_rounded);
}

class TargetTimingConfig extends BaseGameConfig {
  static const int basePeriodMs = 400;
  static const double periodIncreaseRatioPerSlowLevel = 0.2;
  static const double baseTargetWidthRatio = 0.05;
  static const double targetWidthRatioPerWideLevel = 0.015;
  static const int locksNeeded = 3;
  static const int anomalyTargetFadeDurationMs = 350;
  static const double centerHitThresholdRatio = 0.20;

  const TargetTimingConfig() : super(icon: Icons.lock_outline_rounded);
}

class WallRunnerConfig extends BaseGameConfig {
  static const double basePathWidth = 6.0;
  static const double pathWidthPerSkillLevel = 3.0;
  static const int baseMinPathLength = 18;
  static const int simplifiedMinPathLength = 10;
  static const int wallGraceDurationMs = 10;

  const WallRunnerConfig() : super(icon: Icons.gesture_rounded);
}
