import 'package:flutter/material.dart';

import '../game_state.dart';
import '../models/gauntlet_stage.dart';
import 'skill_tree_config.dart';

/// The three potential states for an achievement.
enum AchievementStatus { locked, unlocked, collected }

/// Extension on double to format numbers cleanly without trailing zeros.
extension CleverDoubleExtension on double {
  /// Formats double with up to [maxDecimals] places, stripping any trailing zeros or decimal point.
  /// Examples: 1.15 -> "1.15", 1.20 -> "1.2", 1.50 -> "1.5", 1.00 -> "1"
  String toCleverString([int maxDecimals = 2]) {
    String str = toStringAsFixed(maxDecimals);
    if (str.contains('.')) {
      str = str.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return str;
  }
}

/// Configuration data model for an individual achievement node.
class AchievementConfig {
  final String id;
  final String title;
  final String description;
  final IconData? icon;
  final String? imageAsset;
  final int tokenReward;
  final double? tokenMultiplier;
  final bool isLegendary;
  final bool isUltimate;
  final GauntletStage? linkedStage;
  final String? rewardString;
  final bool Function(GameStateManager gameState)? isLocked;

  const AchievementConfig({
    required this.id,
    required this.title,
    required this.description,
    this.icon,
    this.imageAsset,
    this.tokenReward = 0,
    this.tokenMultiplier,
    this.isLegendary = false,
    this.isUltimate = false,
    this.linkedStage,
    this.rewardString,
    this.isLocked,
  }) : assert(
         icon != null || imageAsset != null,
         'An achievement must specify either an icon or an imageAsset.',
       ),
       assert(
         ((tokenReward > 0 ? 1 : 0) +
                 (tokenMultiplier != null && tokenMultiplier > 1.0 ? 1 : 0) +
                 (rewardString != null && rewardString != '' ? 1 : 0)) ==
             1,
         'An achievement must grant exactly ONE reward type: tokenReward, tokenMultiplier, OR rewardString.',
       );

  /// Evaluates whether this achievement node should be displayed as greyed out / locked on the achievements screen.
  bool checkIfLocked(GameStateManager gameState) {
    if (linkedStage != null && !gameState.isStageCompleted(linkedStage!)) {
      return true;
    }
    return isLocked?.call(gameState) ?? false;
  }
}

/// Target values and thresholds required by achievements.
abstract final class AchievementTargets {
  static const int flawlessMinesweeperCompletionsTarget = 5;
  static const int minesweeperNoFlagsPlacedTarget = 0;
  static const int minesweeperChordMinesTarget = 2;
  static const int targetTimingMaxDirectionChanges = 1;
  static const int flawlessMemoryMatchMaxCardReveals = 2;
  static const int memoryMatchFirstTryReveals = 2;
  static const int bulletHellSurviveSeconds = 30;
  static const int codeCrackerMaxAttempts = 1;
  static const int wallRunnerChokePercentageTarget = 99;
  static const int spotImpostorTimeLimitSeconds = 3;
  static const int runMasterTotalStages = 15;
  static const int playTimeOneHourSeconds = 3600;
  static const int tokensAccumulate1Target = 1000;
  static const int tokensAccumulate2Target = 100000;
  static const int ballBounceCleanBouncesTarget = 7;
  static const int targetShootingPatienceDurationSec = 10;
  static const int targetShootingFlawlessMaxMisses = 0;
  static const int speedTypingWpmTarget = 100;
  static const int speedTypingFlawlessMaxMistakes = 0;
  static const int stroopZeroHesitationMaxResponseMs = 1500;
  static const int stroopLiteralTextPicksTarget = 5;
  static const bool memoryMatrixSweepRequireAscending = true;
  static const int simonSaysMetronomeMaxVarianceMs = 35;
  static const int runSpeedrunMaxSeconds = 90;
  static const int gamesCompletedTarget = 1000;
}

/// Hand-customizable template list of achievements.

// ── Individual Achievement Definitions ─────────────────────────────────────

final gamesPlayAll = AchievementConfig(
  id: 'games_play_all',
  title: 'Explorer',
  description: 'Play at least one attempt in all games.',
  icon: Icons.explore_rounded,
  tokenMultiplier: 1.25,
  isLocked: (gs) => gs.statistics.totalGamesCompleted <= 0,
);

final runMaster = AchievementConfig(
  id: 'run_master',
  title: 'All the way',
  description: 'Complete a full run through all stages.',
  icon: Icons.directions_run_rounded,
  tokenMultiplier: 1.5,
  isLegendary: true,
  isLocked: (gs) => gs.statistics.totalGamesCompleted <= 0,
);

final completionist = AchievementConfig(
  id: 'completionist',
  title: 'Completionist',
  description: 'Unlock all other achievements.',
  icon: Icons.emoji_events_rounded,
  rewardString: '???',
  isLegendary: true,
  isUltimate: true,
);

final skillsMaxAll = AchievementConfig(
  id: 'skills_max_all',
  title: 'Master of All',
  description: 'Max out all finite skill nodes.',
  icon: Icons.military_tech,
  tokenMultiplier: 1.5,
  isLegendary: true,
  isLocked: (gs) => !gs.statistics.hasOpenedSkillTree,
);

final skillsUnlockAll = AchievementConfig(
  id: 'skills_unlock_all',
  title: 'Jack of All Trades',
  description: 'Unlock all skill nodes.',
  icon: Icons.account_tree_rounded,
  tokenMultiplier: 1.25,
  isLocked: (gs) => !gs.statistics.hasOpenedSkillTree,
);

final flawlessMinesweeper5 = AchievementConfig(
  id: 'flawless_minesweeper_5',
  title: 'Flawless Sweeper',
  description:
      'Clear ${AchievementTargets.flawlessMinesweeperCompletionsTarget} times without misplacing a flag.',
  icon: Icons.brightness_7_rounded,
  tokenReward: 5,
  linkedStage: GauntletStage.minesweeper,
);

final minesweeperNoFlags = AchievementConfig(
  id: 'minesweeper_no_flags',
  title: 'Flagless Sweeper',
  description: 'Reveal all empty cells before placing any flags.',
  icon: Icons.outlined_flag_rounded,
  tokenMultiplier: 1.1,
  linkedStage: GauntletStage.minesweeper,
);

final minesweeperChordMultiMine = AchievementConfig(
  id: 'minesweeper_chord_multi_mine',
  title: 'Overconfident',
  description:
      'Trigger ${AchievementTargets.minesweeperChordMinesTarget} or more mines at once.',
  imageAsset: 'assets/icons/burst.png',
  tokenMultiplier: 1.2,
  linkedStage: GauntletStage.minesweeper,
);

final targetTimingOneSweep = AchievementConfig(
  id: 'target_timing_one_sweep',
  title: 'Period',
  description:
      'Hit all targets within ${AchievementTargets.targetTimingMaxDirectionChanges + 1} sweeps.',
  icon: Icons.track_changes_rounded,
  tokenMultiplier: 1.2,
  linkedStage: GauntletStage.targetTiming,
);

final targetTimingCritical = AchievementConfig(
  id: 'target_timing_critical',
  title: 'Critical',
  description:
      'Hit all targets with critical hits.',
  icon: Icons.center_focus_strong_rounded,
  tokenMultiplier: 1.2,
  linkedStage: GauntletStage.targetTiming,
);

final simonSaysMetronome = AchievementConfig(
  id: 'simon_says_metronome',
  title: 'Metronome',
  description: 'Replicate the sequence in the exact same pace it was shown at.',
  icon: Icons.graphic_eq_rounded,
  tokenMultiplier: 1.2,
  linkedStage: GauntletStage.simonSays,
);

final simonSaysDirectPath = AchievementConfig(
  id: 'simon_says_direct_path',
  title: 'Beeline',
  description:
      'Complete the sequence without ever hovering a button out of order.',
  icon: Icons.alt_route_rounded,
  tokenMultiplier: 1.1,
  linkedStage: GauntletStage.simonSays,
);

final wallRunnerSoClose = AchievementConfig(
  id: 'wall_runner_choke_99',
  title: 'So Close!',
  description:
      'Fail after covering over ${AchievementTargets.wallRunnerChokePercentageTarget}% of the path.',
  icon: Icons.sentiment_very_dissatisfied_rounded,
  tokenMultiplier: 1.1,
  linkedStage: GauntletStage.wallRunner,
);

final wallRunnerWallJumper = AchievementConfig(
  id: 'wall_runner_wall_jumper',
  title: 'Wall Jumper',
  description: 'Jump over a wall.',
  icon: Icons.sports_gymnastics_rounded,
  tokenMultiplier: 1.15,
  linkedStage: GauntletStage.wallRunner,
);

final targetShootingPeaceful = AchievementConfig(
  id: 'target_shooting_patience',
  title: 'Peace',
  description:
      'Keep all targets alive for ${AchievementTargets.targetShootingPatienceDurationSec} seconds.',
  imageAsset: 'assets/icons/peace.png',
  tokenMultiplier: 1.2,
  linkedStage: GauntletStage.targetShooting,
);

final targetShootingFlawless = AchievementConfig(
  id: 'target_shooting_flawless',
  title: 'Sharpshooter',
  description: 'Do not miss a single shot.',
  icon: Icons.gps_fixed_rounded,
  tokenMultiplier: 1.15,
  linkedStage: GauntletStage.targetShooting,
);

final memoryMatrixSweep = AchievementConfig(
  id: 'memory_matrix_sweep',
  title: 'Reading',
  description: 'Tap the tiles in strict left-to-right, top-to-bottom order.',
  icon: Icons.menu_book_rounded,
  tokenMultiplier: 1.1,
  linkedStage: GauntletStage.memoryMatrix,
);

final memoryMatchFirstTry = AchievementConfig(
  id: 'memory_match_first_try',
  title: 'Beginner\'s Luck',
  description: 'Find a match on the first two reveals.',
  icon: Icons.auto_awesome_rounded,
  tokenMultiplier: 1.2,
  linkedStage: GauntletStage.memoryMatch,
);

final flawlessMemoryMatch = AchievementConfig(
  id: 'flawless_memory_match',
  title: 'Flawless Memory',
  description: 'Do not reveal any card more than two times.',
  icon: Icons.style_rounded,
  tokenMultiplier: 1.15,
  linkedStage: GauntletStage.memoryMatch,
);

final stroopZeroHesitation = AchievementConfig(
  id: 'stroop_zero_hesitation',
  title: 'Zero Hesitation',
  description:
      'Answer each prompt in under ${AchievementTargets.stroopZeroHesitationMaxResponseMs}ms.',
  icon: Icons.bolt_rounded,
  tokenMultiplier: 1.25,
  linkedStage: GauntletStage.stroopTest,
);

final stroopLiteralText = AchievementConfig(
  id: 'stroop_literal_text',
  title: 'Literal Thinker',
  description:
      'Press the button representing the color text word instead of ink color ${AchievementTargets.stroopLiteralTextPicksTarget} times.',
  icon: Icons.spellcheck_rounded,
  tokenMultiplier: 1.1,
  linkedStage: GauntletStage.stroopTest,
);

final mentalMathAllText = AchievementConfig(
  id: 'mental_math_all_text',
  title: 'Wordsmith',
  description: 'Solve all equations using text instead of numbers.',
  icon: Icons.font_download_rounded,
  tokenMultiplier: 1.15,
  linkedStage: GauntletStage.mentalMath,
);

final mentalMathBinary = AchievementConfig(
  id: 'mental_math_binary',
  title: 'Binary',
  description:
      'Enter a correct equation result converted into binary (base-2).',
  icon: Icons.terminal_rounded,
  tokenMultiplier: 1.1,
  linkedStage: GauntletStage.mentalMath,
);

final bulletHellSurvive = AchievementConfig(
  id: 'bullet_hell_survive_60s',
  title: 'Bullet Dodger',
  description:
      'Survive for ${AchievementTargets.bulletHellSurviveSeconds} seconds.',
  icon: Icons.shield_rounded,
  tokenMultiplier: 1.15,
  linkedStage: GauntletStage.bulletHell,
);

final codeCrackerFirstTry = AchievementConfig(
  id: 'code_cracker_first_try',
  title: 'Codebreaker',
  description: 'Guess the code on your first try.',
  icon: Icons.lock_open_rounded,
  tokenMultiplier: 1.2,
  linkedStage: GauntletStage.codeCracker,
);

final codeCrackerPureLogic = AchievementConfig(
  id: 'code_cracker_pure_logic',
  title: 'Big Brain',
  description:
      'Win by making every subsequent guess fully consistent with all previous clues (2+ guesses).',
  imageAsset: 'assets/icons/brain.png',
  tokenMultiplier: 1.2,
  linkedStage: GauntletStage.codeCracker,
);

final spotImpostorUnder1s = AchievementConfig(
  id: 'spot_impostor_under_1s',
  title: 'Eagle Eye',
  description:
      'Find an impostor within ${AchievementTargets.spotImpostorTimeLimitSeconds} second${AchievementTargets.spotImpostorTimeLimitSeconds > 1 ? 's' : ''}.',
  icon: Icons.remove_red_eye_rounded,
  tokenMultiplier: 1.2,
  linkedStage: GauntletStage.spotImpostor,
);

final speedTypingFlawless = AchievementConfig(
  id: 'speed_typing_flawless',
  title: 'Vibe Coder',
  description: 'Make no mistakes.',
  icon: Icons.keyboard_rounded,
  tokenMultiplier: 1.1,
  linkedStage: GauntletStage.speedTyping,
);

final speedTyping100wpm = AchievementConfig(
  id: 'speed_typing_100wpm',
  title: 'Titkárnő',
  description: 'Reach ${AchievementTargets.speedTypingWpmTarget} WPM.',
  icon: Icons.flash_on_rounded,
  tokenMultiplier: 1.3,
  linkedStage: GauntletStage.speedTyping,
);

final ballBounceCleanBounces = AchievementConfig(
  id: 'ball_bounce_clean_bounces',
  title: 'Don\'t Touch This',
  description:
      'Bounce the ball ${AchievementTargets.ballBounceCleanBouncesTarget} times without it touching the side walls.',
  icon: Icons.sports_tennis_rounded,
  tokenMultiplier: 1.2,
  linkedStage: GauntletStage.ballBounce,
);

final ballBounceAlwaysBelow = AchievementConfig(
  id: 'ball_bounce_always_below',
  title: 'Shadow',
  description:
      'Keep the paddle directly beneath the ball\'s center at all times.',
  imageAsset: 'assets/icons/ninja.png',
  tokenMultiplier: 1.25,
  linkedStage: GauntletStage.ballBounce,
);

final hiddenCClick = AchievementConfig(
  id: 'hidden_c_click',
  title: 'Easter Egg',
  description: 'Nyomd meg a C-t.',
  icon: Icons.egg,
  tokenMultiplier: 1.05,
);

final playTime1h = AchievementConfig(
  id: 'play_time_1h',
  title: 'Was It Worth It?',
  description: 'Spend 1 hour playing.',
  icon: Icons.timer_rounded,
  tokenMultiplier: 1.3,
);

final tokensAccumulate1 = AchievementConfig(
  id: 'tokens_accumulate_1',
  title: 'Pénzecske',
  description:
      'Hold at least ${AchievementTargets.tokensAccumulate1Target} tokens at once.',
  icon: Icons.savings_rounded,
  tokenMultiplier: 1.15,
  isLocked: (gs) => gs.statistics.totalTokensEarned <= 0,
);

final tokensAccumulate2 = AchievementConfig(
  id: 'tokens_accumulate_2',
  title: 'Giga Money',
  description:
      'Hold at least ${AchievementTargets.tokensAccumulate2Target} tokens at once.',
  icon: Icons.account_balance_wallet_rounded,
  isLegendary: true,
  tokenMultiplier: 1.3,
  isLocked: (gs) => gs.statistics.totalTokensEarned <= 0,
);

final anomalySolved = AchievementConfig(
  id: 'anomaly_solved',
  title: 'Glitch Fixer',
  description: 'Solve an anomaly.',
  icon: Icons.bug_report_rounded,
  tokenMultiplier: 1.15,
  isLocked: (gs) => gs.anomalyProbability <= 0,
);

final runUnder60s = AchievementConfig(
  id: 'run_under_60s',
  title: 'Lightning Run',
  description:
      'Complete a full run in under ${AchievementTargets.runSpeedrunMaxSeconds} seconds.',
  isLegendary: true,
  isUltimate: true,
  icon: Icons.speed_rounded,
  tokenMultiplier: 2.0,
  isLocked: (gs) => gs.statistics.totalGamesCompleted <= 0,
);

final gamesClears = AchievementConfig(
  id: 'games_clear_500',
  title: 'Game Marathon',
  description:
      'Clear ${AchievementTargets.gamesCompletedTarget} games across all runs.',
  icon: Icons.sports_esports_rounded,
  tokenMultiplier: 1.3,
);

final anomalyEncounterAll = AchievementConfig(
  id: 'anomaly_encounter_all',
  title: 'Anomalist',
  description: 'Encounter the anomaly version of every game at least once.',
  icon: Icons.warning_amber_rounded,
  tokenMultiplier: 1.5,
  isLegendary: true,
  isLocked: (gs) => gs.anomalyProbability <= 0,
);

final anomalyRun15 = AchievementConfig(
  id: 'anomaly_run_15',
  title: 'Absolute Chaos',
  description:
      'Complete a full 15-stage run where every single stage was an anomaly!',
  imageAsset: 'assets/icons/skull.png',
  tokenMultiplier: 2.0,
  isUltimate: true,
  isLegendary: true,
  isLocked: (gs) => gs.anomalyProbability <= 0,
);

/// Major achievement rows displayed ABOVE the divider on the Achievements Screen.
final List<List<AchievementConfig>> majorAchievementRows = [
  // Row 0: Top Legendary & Ultimate achievements
  [gamesPlayAll, runMaster, completionist, skillsMaxAll, skillsUnlockAll],
  // Row 1: Major Meta & Endgame achievements
  [anomalyEncounterAll, anomalyRun15, runUnder60s, tokensAccumulate2],
];

/// Minor achievement rows displayed BELOW the divider on the Achievements Screen.
final List<List<AchievementConfig>> minorAchievementRows = [
  // Row 0 (6 items): Stages 1 - 4
  [
    flawlessMinesweeper5,
    minesweeperNoFlags,
    minesweeperChordMultiMine,
    targetTimingOneSweep,
    targetTimingCritical,
    simonSaysMetronome,
  ],
  // Row 1 (6 items): Stages 4 - 7
  [
    simonSaysDirectPath,
    wallRunnerSoClose,
    wallRunnerWallJumper,
    memoryMatchFirstTry,
    flawlessMemoryMatch,
    targetShootingPeaceful,
  ],
  // Row 2 (7 items): Stages 7 - 11
  [
    targetShootingFlawless,
    memoryMatrixSweep,
    stroopZeroHesitation,
    stroopLiteralText,
    mentalMathAllText,
    mentalMathBinary,
    codeCrackerFirstTry,
  ],
  // Row 3 (6 items): Stages 11 - 15
  [
    codeCrackerPureLogic,
    bulletHellSurvive,
    spotImpostorUnder1s,
    ballBounceCleanBounces,
    ballBounceAlwaysBelow,
    speedTypingFlawless,
  ],
  // Row 4 (6 items): Stage 15 & Stageless
  [
    speedTyping100wpm,
    hiddenCClick,
    playTime1h,
    tokensAccumulate1,
    anomalySolved,
    gamesClears,
  ],
];

/// Flattened list of all achievements across all major and minor rows.
final List<AchievementConfig> allAchievements = [
  ...majorAchievementRows.expand((r) => r),
  ...minorAchievementRows.expand((r) => r),
];

/// Helper to format achievement description, appending dynamic progress (e.g. (4/5) or (2/3)) if applicable.
String getFormattedAchievementDescription(
  AchievementConfig achievement,
  GameStateManager gameState,
) {
  if (achievement.id == 'flawless_minesweeper_5') {
    final count = gameState.statistics.flawlessMinesweeperCompletions.clamp(
      0,
      AchievementTargets.flawlessMinesweeperCompletionsTarget,
    );
    return '${achievement.description} ($count/${AchievementTargets.flawlessMinesweeperCompletionsTarget})';
  } else if (achievement.id == 'games_clear_500') {
    final count = gameState.statistics.totalGamesCompleted.clamp(
      0,
      AchievementTargets.gamesCompletedTarget,
    );
    return '${achievement.description} ($count/${AchievementTargets.gamesCompletedTarget})';
  } else if (achievement.id == 'stroop_literal_text') {
    final count = gameState.statistics.stroopLiteralTextPicks.clamp(
      0,
      AchievementTargets.stroopLiteralTextPicksTarget,
    );
    return '${achievement.description} ($count/${AchievementTargets.stroopLiteralTextPicksTarget})';
  } else if (achievement.id == 'play_time_1h') {
    final minutes = (gameState.currentTotalPlayTimeSeconds ~/ 60).clamp(0, 60);
    return '${achievement.description} ($minutes/60m)';
  } else if (achievement.id == 'tokens_accumulate_10k') {
    final count = gameState.tokens.clamp(
      0,
      AchievementTargets.tokensAccumulate1Target,
    );
    return '${achievement.description} ($count/${AchievementTargets.tokensAccumulate1Target})';
  } else if (achievement.id == 'tokens_accumulate_100k') {
    final count = gameState.tokens.clamp(
      0,
      AchievementTargets.tokensAccumulate2Target,
    );
    return '${achievement.description} ($count/${AchievementTargets.tokensAccumulate2Target})';
  } else if (achievement.id == 'skills_unlock_all') {
    final total = defaultSkillTreeNodes.length;
    int count = 0;
    for (final n in defaultSkillTreeNodes) {
      if (gameState.getSkillLevel(n.id) >= 1) count++;
    }
    return '${achievement.description} ($count/$total)';
  } else if (achievement.id == 'skills_max_all') {
    final finiteNodes = defaultSkillTreeNodes.where((n) => !n.isInfinite).toList();
    final total = finiteNodes.length;
    int count = 0;
    for (final n in finiteNodes) {
      if (gameState.getSkillLevel(n.id) >= n.maxLevel) count++;
    }
    return '${achievement.description} ($count/$total)';
  } else if (achievement.id == 'games_play_all') {
    int count = 0;
    for (final s in GauntletStage.values) {
      if (gameState.isStageVisited(s)) count++;
    }
    return '${achievement.description} ($count/15)';
  } else if (achievement.id == 'anomaly_encounter_all') {
    int count = 0;
    for (int i = 1; i <= 15; i++) {
      if (gameState.statistics.encounteredAnomalies[i] == true) count++;
    }
    return '${achievement.description} ($count/15)';
  } else if (achievement.id == 'completionist') {
    final others = allAchievements.where((a) => a.id != 'completionist');
    final total = others.length;
    int count = 0;
    for (final a in others) {
      if (gameState.getAchievementStatus(a.id) != AchievementStatus.locked) {
        count++;
      }
    }
    return '${achievement.description} ($count/$total)';
  } else if (achievement.id == 'run_master') {
    final count = gameState.unlockedKeyChars.where((c) => c != null).length;
    return '${achievement.description} ($count/${AchievementTargets.runMasterTotalStages})';
  }
  return achievement.description;
}
