import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/gauntlet_stage.dart';
import 'speed_typing_config.dart';
import 'spot_impostor_config.dart';

export 'speed_typing_config.dart';
export 'spot_impostor_config.dart';

/// Base class for game configurations.
abstract class BaseGameConfig {
  /// Standard delay before proceeding upon completing a stage.
  static const Duration winTransitionDelay = Duration(milliseconds: 600);

  /// Standard delay before proceeding upon failing a stage.
  static const Duration failTransitionDelay = Duration(milliseconds: 600);

  final IconData icon;

  const BaseGameConfig({required this.icon});

  /// Utility helper to retrieve the [IconData] for a given [GauntletStage].
  static IconData getIconForStage(GauntletStage stage) => switch (stage) {
    GauntletStage.minesweeper => const MinesweeperConfig().icon,
    GauntletStage.targetTiming => const TargetTimingConfig().icon,
    GauntletStage.numberGuesser => const NumberGuesserConfig().icon,
    GauntletStage.simonSays => const SequenceFlashConfig().icon,
    GauntletStage.wallRunner => const WallRunnerConfig().icon,
    GauntletStage.memoryMatch => const MemoryMatchConfig().icon,
    GauntletStage.targetShooting => const TargetShootingConfig().icon,
    GauntletStage.memoryMatrix => const MemoryMatrixConfig().icon,
    GauntletStage.stroopTest => const StroopTestConfig().icon,
    GauntletStage.mentalMath => const MentalMathConfig().icon,
    GauntletStage.codeCracker => const CodeCrackerConfig().icon,
    GauntletStage.bulletHell => const BulletHellConfig().icon,
    GauntletStage.spotImpostor => const SpotImpostorConfig().icon,
    GauntletStage.ballBounce => const BallBounceConfig().icon,
    GauntletStage.speedTyping => const SpeedTypingConfig().icon,
  };

  /// Utility helper to retrieve the [IconData] for a 1-based stage number.
  static IconData getIconForStageNumber(int stageNumber) {
    if (stageNumber >= 1 && stageNumber <= GauntletStage.values.length) {
      return getIconForStage(
        GauntletStageExtension.fromStageNumber(stageNumber),
      );
    }
    return Icons.help_outline_rounded;
  }
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
  static const double boardPadding = 2;

  /// Gap between adjacent region panels (Option B distinct panel gap)
  static const double panelGap = 4.0;

  /// Corner radius of region panels (default 14.0)
  static const double panelCornerRadius = 14.0;
  static const double regionPanelCornerRadius = 14.0;

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
  static const double neighborRegionTransparency = 0.50;

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
