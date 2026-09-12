import 'package:flutter/material.dart';
import 'config.dart';

import '../game_state.dart';
import '../models/gauntlet_stage.dart';
import '../utils/number_formatter.dart';
import 'anomaly_config.dart';

/// Configuration definition for a single skill node in the freeform canvas.
class SkillNodeConfig {
  /// Unique identifier for saving/unlocking (e.g., 'root', 'income')
  final String id;

  /// Display name shown in the hover popup card
  final String title;

  /// Description of the node's effect
  final String description;

  /// Optional mathematical formula displayed below description in italics
  final String? formula;

  /// Icon displayed on the node tile (optional if [imageAsset] is provided)
  final IconData? icon;

  /// Image asset path displayed on the node tile (optional if [icon] is provided)
  final String? imageAsset;

  /// Horizontal position in grid units. Supports fractional values for
  /// sub-cell placement (e.g. 2.5 sits between columns 2 and 3).
  final double gridX;

  /// Vertical position in grid units. Supports fractional values.
  final double gridY;

  /// If true, node renders with an ornate gold starburst frame & single star pip
  final bool isLegendary;

  /// If true, this node can be upgraded indefinitely with dynamically calculated level costs.
  final bool isInfinite;

  /// List of parent node IDs that must be unlocked to reveal & enable this node
  final List<String> parentIds;

  /// Per-level cost list. Level N upgrade costs costPerLevel[N-1].
  final List<int> costPerLevel;

  /// Optional game stage this skill node is linked to.
  /// If set, the node cannot be purchased until this game is visited.
  final GauntletStage? linkedStage;

  /// Optional condition that determines if this skill node is locked (non-unlockable).
  final bool Function(GameStateManager gameState)? isLocked;

  /// Optional lock hint message displayed when hovered in locked state.
  final String? lockHint;

  const SkillNodeConfig({
    required this.id,
    required this.title,
    required this.description,
    this.formula,
    this.icon,
    this.imageAsset,
    required this.gridX,
    required this.gridY,
    this.isLegendary = false,
    this.isInfinite = false,
    required this.costPerLevel,
    required this.parentIds,
    this.linkedStage,
    this.isLocked,
    this.lockHint,
  });

  /// Evaluates whether this skill node is currently locked by a linked stage requirement or custom condition.
  bool checkIfLocked(GameStateManager gameState) {
    if (linkedStage != null && !gameState.isStageVisited(linkedStage!)) {
      return true;
    }
    return isLocked?.call(gameState) ?? false;
  }

  /// Maximum upgrade level derived from [costPerLevel] (or unlimited if [isInfinite]).
  int get maxLevel => isInfinite ? 999999 : costPerLevel.length;

  /// Base token cost shown/used for first unlock level.
  int get cost =>
      isInfinite ? AnomalyConfig.calculateCost(0) : costPerLevel.first;

  /// Returns the token cost to go from [currentLevel] → [currentLevel + 1].
  int costForLevel(int currentLevel) {
    if (isInfinite) {
      return AnomalyConfig.calculateCost(currentLevel);
    }
    if (currentLevel < 0) return costPerLevel.first;
    if (currentLevel >= costPerLevel.length) return costPerLevel.last;
    return costPerLevel[currentLevel];
  }
}

/// Skill Tree Canvas Dimensions
class SkillTreeLayoutSettings {
  static const double canvasWidth = 450.0;
  static const double canvasHeight = 440.0;
}

/// Configuration constants for the root 'Focus' skill node.
abstract final class RootSkillConfig {
  static const int baseRunTimeSeconds = 60;
  static const int bonusSecondsPerLevel = 30;
}

/// Configuration constants for economy skills (income, accumulator).
abstract final class EconomySkillConfig {
  static const int incomeBonusPerStagePerLevel = 1;
  static const double accumulatorDivisor = 10.0;
}

/// The master skill tree node configuration list.
///
/// Positions use a logical integer grid (doubles are supported for
/// fractional sub-cell placement). The renderer auto-computes the cell
/// size from the maximum coordinate values present in the list, so there
/// is no fixed grid dimension to maintain.
///
/// Layout (7 columns × 9 rows, 0-indexed):
///
final List<SkillNodeConfig> defaultSkillTreeNodes = [
  // ── Root & Economy ────────────────────────────────────────────────────────
  SkillNodeConfig(
    id: 'root',
    title: 'Focus',
    description: 'Foundational mastery node.',
    icon: Icons.center_focus_strong_rounded,
    gridX: 0,
    gridY: -2,
    costPerLevel: [1, 100, 10000, 1000000],
    parentIds: [],
  ),
  SkillNodeConfig(
    id: 'income',
    title: 'Token Income',
    description:
        'Receive additional tokens when completing games.\n+${EconomySkillConfig.incomeBonusPerStagePerLevel} per level for each completed game in the current run.',
    icon: Icons.token,
    gridX: 0,
    gridY: 0,
    costPerLevel: [1, 15, 125, 750, 2500],
    parentIds: ['root'],
  ),
  SkillNodeConfig(
    id: 'reward',
    title: 'Reward',
    isLegendary: true,
    description:
        'First time completing a stage awards tokens equal to the stage number cubed (Stage³).',
    icon: Icons.token,
    gridX: 1,
    gridY: -1,
    costPerLevel: [10],
    parentIds: ['income'],
  ),
  SkillNodeConfig(
    id: 'anomalies',
    title: 'Anomalies',
    description:
        'Increases the chance of anomalies. Anomalies are alternate versions of games. Each one grants ×${AnomalyConfig.runMultiplierPerAnomaly} extra multiplier for that run.',
    formula: 'p = 1 - e^(-${AnomalyConfig.probabilityBaseRate} * lvl)',
    imageAsset: 'assets/icons/skull.png',
    gridX: 1,
    gridY: -3,
    isInfinite: true,
    costPerLevel: [],
    parentIds: ['reward'],
  ),
  SkillNodeConfig(
    id: 'practice',
    title: 'Practice',
    isLegendary: true,
    description: 'Unlocks practice mode for completed stages.',
    icon: Icons.fitness_center_rounded,
    gridX: -1,
    gridY: 1,
    costPerLevel: [1],
    parentIds: ['income'],
  ),
  SkillNodeConfig(
    id: 'accumulator',
    title: 'Accumulator',
    isLegendary: true,
    description:
        'When completing a game, get tokens based on how many times that game was completed before (diminishing returns)',
    formula: '√(Completions / 10) × Stage²',
    icon: Icons.token,
    gridX: -1,
    gridY: -1,
    costPerLevel: [1000],
    parentIds: ['income'],
  ),
  SkillNodeConfig(
    id: 'refund',
    title: 'Refund',
    isLegendary: true,
    description:
        'Unlocks the refund button to reset skills and recover spent tokens.',
    icon: Icons.undo_rounded,
    gridX: 2,
    gridY: -4,
    costPerLevel: [1000000],
    parentIds: ['speed_typing_reduction'],
  ),
  SkillNodeConfig(
    id: 'practice_achievements',
    title: 'Practice Mastery',
    isLegendary: true,
    description: 'Allows most achievements to be triggered in practice mode.',
    icon: Icons.emoji_events_rounded,
    gridX: 0,
    gridY: 2,
    costPerLevel: [10000000],
    parentIds: ['practice_anomalies'],
  ),
  SkillNodeConfig(
    id: 'practice_anomalies',
    title: 'Anomaly Practice',
    isLegendary: true,
    description:
        'Allows observed anomalies to be toggled in practice mode.',
    imageAsset: 'assets/icons/skull.png',
    gridX: 1,
    gridY: 1,
    costPerLevel: [10000],
    parentIds: ['practice'],
    isLocked: (gs) => !gs.hasEncounteredAnyAnomaly,
    lockHint: 'Encounter an anomaly in a run first',
  ),

  // ── Stage 1 (Minesweeper) ──────────────────────────────────────────────────
  SkillNodeConfig(
    id: 'minesweeper_grid_size',
    title: 'Minefield Scanner',
    description:
        'Tactical radar enhancement for surveying the vast minefield.',
    icon: Icons.brightness_7_rounded,
    gridX: 0,
    gridY: -4,
    costPerLevel: [1, 2, 5, 20, 400],
    parentIds: ['root'],
    linkedStage: GauntletStage.minesweeper,
  ),
  SkillNodeConfig(
    id: 'minesweeper_no_5050',
    title: 'Guaranteed Logic',
    isLegendary: true,
    description: 'Ensures Minesweeper boards never require 50/50 guesses.',
    icon: Icons.psychology_rounded,
    gridX: -1,
    gridY: -3,
    costPerLevel: [20],
    parentIds: ['minesweeper_grid_size'],
    linkedStage: GauntletStage.minesweeper,
  ),

  // ── Stage 2 (Target Timing) ────────────────────────────────────────────────
  SkillNodeConfig(
    id: 'timing_slow',
    title: 'Pendulum Damper',
    description:
        'Slows the oscillating needle.\n+${formatPercentage(TargetTimingConfig.periodIncreaseRatioPerSlowLevel)} sweep duration per level.',
    icon: Icons.speed_rounded,
    gridX: -2,
    gridY: -4,
    costPerLevel: [2, 3, 7, 15, 500],
    parentIds: ['minesweeper_grid_size'],
    linkedStage: GauntletStage.targetTiming,
  ),
  SkillNodeConfig(
    id: 'timing_wide',
    title: 'Pressure Point',
    description:
        'Widens the green target zone.\n+${formatPercentage(TargetTimingConfig.targetWidthRatioPerWideLevel / TargetTimingConfig.baseTargetWidthRatio)} base width per level.',
    icon: Icons.track_changes_rounded,
    gridX: -2,
    gridY: -2,
    costPerLevel: [2, 4, 9, 20, 800],
    parentIds: ['timing_slow'],
    linkedStage: GauntletStage.targetTiming,
  ),

  // ── Stage 3 (Number Guesser) ───────────────────────────────────────────────
  SkillNodeConfig(
    id: 'guess_numbers_reduce',
    title: 'Fewer Numbers',
    description:
        'Reduce the number of options to choose from.\n-${NumberGuesserConfig.numberReductionPerLevel} numbers per level.',
    icon: Icons.casino_outlined,
    gridX: -4,
    gridY: -4,
    costPerLevel: [4, 7, 12, 30, 1000],
    parentIds: ['timing_slow'],
    linkedStage: GauntletStage.numberGuesser,
  ),
  SkillNodeConfig(
    id: 'hint',
    title: 'Hints',
    isLegendary: true,
    description: 'Tells you a hint about the correct number.',
    icon: Icons.lightbulb,
    gridX: -3,
    gridY: -3,
    costPerLevel: [40],
    parentIds: ['guess_numbers_reduce'],
    linkedStage: GauntletStage.numberGuesser,
  ),

  // ── Stage 4 (Simon Says) ───────────────────────────────────────────────────
  SkillNodeConfig(
    id: 'simon_length',
    title: 'Lights Off',
    description:
        'Lowers the number of lights shown by ${SequenceFlashConfig.lengthReductionPerSkillLevel} per level.',
    icon: Icons.grid_view_rounded,
    gridX: -4,
    gridY: -2,
    costPerLevel: [30, 50, 100, 180, 3000],
    parentIds: ['guess_numbers_reduce'],
    linkedStage: GauntletStage.simonSays,
  ),
  SkillNodeConfig(
    id: 'simon_speed',
    title: 'Faster Blinks',
    description:
        'Speeds up the blinks.\n${formatPercentage(SequenceFlashConfig.flashMsPerSkillLevel / SequenceFlashConfig.baseFlashMs)} base duration per level.',
    icon: Icons.speed_rounded,
    gridX: -3,
    gridY: -1,
    costPerLevel: [20, 40, 80, 150, 2000],
    parentIds: ['simon_length'],
    linkedStage: GauntletStage.simonSays,
  ),

  // ── Stage 5 (Wall Runner) ──────────────────────────────────────────────────
  SkillNodeConfig(
    id: 'path_width',
    title: 'Wider Ways',
    description:
        'Increase the width of the path.\n+${formatPercentage(WallRunnerConfig.pathWidthPerSkillLevel / WallRunnerConfig.basePathWidth)} base width per level.',
    icon: Icons.expand_rounded,
    gridX: -4,
    gridY: 0,
    costPerLevel: [100, 150, 250, 500, 6000],
    parentIds: ['simon_length'],
    linkedStage: GauntletStage.wallRunner,
  ),
  SkillNodeConfig(
    id: 'wall_runner_path_complexity',
    title: 'Direct Route',
    isLegendary: true,
    description:
        'Reduces the complexity and winding length of the path generated in Wall Runner.',
    icon: Icons.alt_route_rounded,
    gridX: -2,
    gridY: 0,
    costPerLevel: [1500],
    parentIds: ['path_width'],
    linkedStage: GauntletStage.wallRunner,
  ),

  // ── Stage 6 (Memory Match) ─────────────────────────────────────────────────
  SkillNodeConfig(
    id: 'memory_match_size',
    title: 'Card Count',
    description:
        'Reduces total card count by ${MemoryMatchConfig.cardCountReductionPerSkillLevel} per level.',
    icon: Icons.question_mark_rounded,
    gridX: -4,
    gridY: 2,
    costPerLevel: [200, 300, 600, 1200, 10000],
    parentIds: ['path_width'],
    linkedStage: GauntletStage.memoryMatch,
  ),
  SkillNodeConfig(
    id: 'memory_match_reveals',
    title: 'Peek',
    description:
        'Increases the allowed number of reveals by ${MemoryMatchConfig.revealsPerSkillLevel} per level.',
    icon: Icons.visibility_rounded,
    gridX: -3,
    gridY: 1,
    costPerLevel: [250, 400, 700, 30000],
    parentIds: ['memory_match_size'],
    linkedStage: GauntletStage.memoryMatch,
  ),

  // ── Stage 7 (Target Shooting) ──────────────────────────────────────────────
  SkillNodeConfig(
    id: 'target_shooting_size',
    title: 'Target Sizing',
    description:
        'Reduces target count by ${TargetShootingConfig.targetCountReductionPerSkillLevel} per level and increases target size by ${formatPercentage(TargetShootingConfig.targetRadiusIncreasePerSkillLevel)} per level.',
    icon: Icons.aspect_ratio_rounded,
    gridX: -4,
    gridY: 4,
    costPerLevel: [400, 600, 1000, 1750, 25000],
    parentIds: ['memory_match_size'],
    linkedStage: GauntletStage.targetShooting,
  ),
  SkillNodeConfig(
    id: 'target_shooting_bpm',
    title: 'Rapid Fire',
    description:
        'Increases automatic firing rate (+${TargetShootingConfig.bulletsPerMinutePerSkillLevel} BPM) and reduces target speed by ${formatPercentage(TargetShootingConfig.targetSpeedReductionPerSkillLevel)} per level.',
    icon: Icons.bolt_rounded,
    gridX: -3,
    gridY: 3,
    costPerLevel: [400, 1000, 50000],
    parentIds: ['target_shooting_size'],
    linkedStage: GauntletStage.targetShooting,
  ),
  SkillNodeConfig(
    id: 'target_shooting_sway',
    title: 'Steady Aim',
    description:
        'Reduces weapon sway by ${formatPercentage(TargetShootingConfig.swayReductionPerSkillLevel)} per level.',
    icon: Icons.center_focus_weak_rounded,
    gridX: -2,
    gridY: 2,
    costPerLevel: [500, 40000],
    parentIds: ['target_shooting_bpm'],
    linkedStage: GauntletStage.targetShooting,
  ),

  // ── Stage 8 (Memory Matrix) ────────────────────────────────────────────────
  SkillNodeConfig(
    id: 'memory_matrix_size',
    title: 'Grid Size',
    description:
        'Reduces grid size by ${MemoryMatrixConfig.gridDimReductionPerSkillLevel}x${MemoryMatrixConfig.gridDimReductionPerSkillLevel} and targets by ${MemoryMatrixConfig.targetReductionPerSkillLevel} per level.',
    icon: Icons.grid_view,
    gridX: -2,
    gridY: 4,
    costPerLevel: [600, 900, 1500, 2500, 100000],
    parentIds: ['target_shooting_size'],
    linkedStage: GauntletStage.memoryMatrix,
  ),

  // ── Stage 9 (Stroop Test) ──────────────────────────────────────────────────
  SkillNodeConfig(
    id: 'stroop_test_iterations',
    title: 'Fewer Tests',
    description:
        'Reduces the required number of Stroop test iterations by ${StroopTestConfig.iterationDecreasePerSkillLevel} per level.',
    icon: Icons.checklist_rounded,
    gridX: 0,
    gridY: 4,
    costPerLevel: [1000, 1500, 2500, 4500, 150000],
    parentIds: ['memory_matrix_size'],
    linkedStage: GauntletStage.stroopTest,
  ),
  SkillNodeConfig(
    id: 'stroop_test_colored_buttons',
    title: 'Chromatic Buttons',
    isLegendary: true,
    description: 'Colors the choice buttons to match their color names.',
    icon: Icons.palette_rounded,
    gridX: -1,
    gridY: 3,
    costPerLevel: [20000],
    parentIds: ['stroop_test_iterations'],
    linkedStage: GauntletStage.stroopTest,
  ),

  // ── Stage 10 (Rapid Mental Math) ──────────────────────────────────────────
  SkillNodeConfig(
    id: 'math_solves',
    title: 'Quick Count',
    description:
        'Reduces the required number of equations to solve by ${MentalMathConfig.targetCountReductionPerSkillLevel} per level.',
    icon: Icons.pin_outlined,
    gridX: 2,
    gridY: 4,
    costPerLevel: [1500, 2500, 5000, 13000, 300000],
    parentIds: ['stroop_test_iterations'],
    linkedStage: GauntletStage.mentalMath,
  ),
  SkillNodeConfig(
    id: 'math_difficulty',
    title: 'Simpler Math',
    isLegendary: true,
    description: 'Reduces the difficulty of equations.',
    icon: Icons.calculate_rounded,
    gridX: 1,
    gridY: 3,
    costPerLevel: [15000],
    parentIds: ['math_solves'],
    linkedStage: GauntletStage.mentalMath,
  ),

  // ── Stage 11 (Code Cracker) ────────────────────────────────────────────────
  SkillNodeConfig(
    id: 'code_cracker_colors',
    title: 'Palette Reduction',
    description:
        'Reduces the number of possible colors by ${CodeCrackerConfig.colorReductionPerSkillLevel} per level.',
    icon: Icons.palette_rounded,
    gridX: 4,
    gridY: 4,
    costPerLevel: [2500, 4000, 7000, 25000, 500000],
    parentIds: ['math_solves'],
    linkedStage: GauntletStage.codeCracker,
  ),
  SkillNodeConfig(
    id: 'code_cracker_digits',
    title: 'Efficient Encoding',
    description:
        'Reduces the code length by ${CodeCrackerConfig.slotsReductionPerSkillLevel} per level.',
    icon: Icons.key_rounded,
    gridX: 3,
    gridY: 3,
    costPerLevel: [20000, 200000],
    parentIds: ['code_cracker_colors'],
    linkedStage: GauntletStage.codeCracker,
  ),

  // ── Stage 12 (Bullet Hell Survival) ────────────────────────────────────────
  SkillNodeConfig(
    id: 'bullet_hell_count',
    title: 'Bullet Density',
    description:
        'Reduces the number of bullets by ${BulletHellConfig.projectileReductionPerSkillLevel} per level.',
    icon: Icons.grain_rounded,
    gridX: 4,
    gridY: 2,
    costPerLevel: [4000, 7000, 13000, 40000, 800000],
    parentIds: ['code_cracker_colors'],
    linkedStage: GauntletStage.bulletHell,
  ),
  SkillNodeConfig(
    id: 'bullet_hell_speed',
    title: 'Chrono Slow',
    description:
        'Reduces the speed of bullets by ${formatPercentage(BulletHellConfig.projectileSpeedReductionPerSkillLevel)} per level.',
    icon: Icons.speed_rounded,
    gridX: 3,
    gridY: 1,
    costPerLevel: [5000, 8000, 15000, 50000, 750000],
    parentIds: ['bullet_hell_count'],
    linkedStage: GauntletStage.bulletHell,
  ),
  SkillNodeConfig(
    id: 'bullet_hell_collectibles',
    title: 'Orb Collector',
    isLegendary: true,
    description:
        'Reduces the required number of collectibles from ${BulletHellConfig.baseCollectibleCount} to ${BulletHellConfig.reducedCollectibleCount}.',
    icon: Icons.stars_rounded,
    gridX: 2,
    gridY: 2,
    costPerLevel: [75000],
    parentIds: ['bullet_hell_speed'],
    linkedStage: GauntletStage.bulletHell,
  ),

  // ── Stage 13 (Spot the Impostor) ───────────────────────────────────────────
  SkillNodeConfig(
    id: 'spot_impostor_grid_size',
    title: 'Smaller Grid',
    description:
        'Reduces the Impostor grid size by ${SpotImpostorConfig.gridSizeDecreasePerSkillLevel}×${SpotImpostorConfig.gridSizeDecreasePerSkillLevel} per level.',
    icon: Icons.grid_view_rounded,
    gridX: 4,
    gridY: 0,
    costPerLevel: [7000, 12000, 20000, 50000, 1500000],
    parentIds: ['bullet_hell_count'],
    linkedStage: GauntletStage.spotImpostor,
  ),
  SkillNodeConfig(
    id: 'spot_impostor_rounds',
    title: 'Fewer Rounds',
    description:
        'Reduces the number of rounds by ${SpotImpostorConfig.roundsDecreasePerSkillLevel} per level.',
    icon: Icons.filter_list_rounded,
    gridX: 2,
    gridY: 0,
    costPerLevel: [25000, 75000, 200000, 500000, 1000000],
    parentIds: ['spot_impostor_grid_size'],
    linkedStage: GauntletStage.spotImpostor,
  ),

  // ── Stage 14 (Ball Bounce) ─────────────────────────────────────────────────
  SkillNodeConfig(
    id: 'bounce_count',
    title: 'Fewer Bounces',
    description:
        'Reduces the required number of bounces by ${BallBounceConfig.bouncesReductionPerSkillLevel} per level.',
    icon: Icons.sports_baseball_rounded,
    gridX: 4,
    gridY: -2,
    costPerLevel: [10000, 20000, 40000, 100000, 5000000],
    parentIds: ['spot_impostor_grid_size'],
    linkedStage: GauntletStage.ballBounce,
  ),
  SkillNodeConfig(
    id: 'bounce_paddle_size',
    title: 'Wide Paddle',
    description:
        'Increases the width of the paddle by +${formatPercentage(BallBounceConfig.paddleWidthIncreasePerSkillLevel)} base width per level.',
    icon: Icons.horizontal_distribute_rounded,
    gridX: 3,
    gridY: -1,
    costPerLevel: [15000, 35000, 75000, 200000, 10000000],
    parentIds: ['bounce_count'],
    linkedStage: GauntletStage.ballBounce,
  ),
  SkillNodeConfig(
    id: 'bounce_speed_increase',
    title: 'Speed Bump',
    description:
        'Increases the ball speed acceleration per bounce (from +${formatPercentage(BallBounceConfig.baseSpeedIncrease)} to +${formatPercentage(BallBounceConfig.baseSpeedIncrease + BallBounceConfig.speedIncreaseBonusPerSkillLevel)}).',
    icon: Icons.speed_rounded,
    gridX: 2,
    gridY: -2,
    isLegendary: true,
    costPerLevel: [300000],
    parentIds: ['bounce_paddle_size'],
    linkedStage: GauntletStage.ballBounce,
  ),

  // ── Stage 15 (Speed Typing) ────────────────────────────────────────────────
  SkillNodeConfig(
    id: 'speed_typing_reduction',
    title: 'Fewer Sentences',
    description:
        'Reduces the number of sentences required to type by ${SpeedTypingConfig.sentenceCountReductionPerSkillLevel} per level.',
    icon: Icons.short_text_rounded,
    gridX: 4,
    gridY: -4,
    costPerLevel: [25000, 60000, 120000, 300000, 15000000],
    parentIds: ['bounce_count'],
    linkedStage: GauntletStage.speedTyping,
  ),
  SkillNodeConfig(
    id: 'speed_typing_easy_words',
    title: 'Simple Vocabulary',
    isLegendary: true,
    description: 'Reduces the complexity of sentences.',
    icon: Icons.child_care_rounded,
    gridX: 3,
    gridY: -3,
    costPerLevel: [5000000],
    parentIds: ['speed_typing_reduction'],
    linkedStage: GauntletStage.speedTyping,
  ),
];
