import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import 'config/achievement_config.dart';
import 'config/anomaly_config.dart';
import 'models/gauntlet_stage.dart';
import 'save_system.dart';
import 'config/skill_tree_config.dart';

/// Central state manager for the Birthday Gauntlet.
///
/// Manages both transient run state (current run/stage, active flag) and
/// persistent state (unlocked key characters, statistics) via [SaveSystem].
class GameStateManager extends ChangeNotifier {
  final SaveSystem _saveSystem;

  // ── The full activation code (15 characters, no dashes) ──────────────
  // Replace with the real Steam key before gifting!
  static const String activationCode = 'XXXXXYYYYYZZZZZ';

  // ── Persistent state ─────────────────────────────────────────────────
  List<String?> unlockedKeyChars = List<String?>.filled(15, null);
  Statistics statistics = Statistics();
  int _tokens = 0;
  int get tokens => _tokens;
  set tokens(int value) {
    _tokens = value;
    _saveSystem.saveTokens(_tokens);
    checkTokenAchievements();
  }

  List<String> unlockedSkills = [];
  Map<String, int> skillLevels = {};

  // ── Computed in-memory state (not saved) ──────────────────────────────
  /// Product of all collected multiplier achievements. Recalculated on load
  /// and each time an achievement is claimed. Never saved to disk.
  double tokenMultiplier = 1.0;

  // ── Transient run state ──────────────────────────────────────────────
  int _currentRun = 1;
  int _currentStageIndex = 0; // 0-based index within the current run
  bool _isRunActive = false;
  int runBaseIncome = 0;
  int runIncomeSkillTokens = 0;
  int runRewardSkillTokens = 0;
  double runAccumulatorSkillTokens = 0.0;

  /// Sum of all raw (pre-multiplier) earnedTokens across the run.
  int runRawTotal = 0;

  /// floor(runRawTotal * tokenMultiplier) — applied once at run end. Shown in receipt.
  int runMultipliedTotal = 0;

  // ── Public getters ───────────────────────────────────────────────────
  int get currentRun => _currentRun;

  /// 0-based index of the game within the current run.
  int get currentStageIndex => _currentStageIndex;

  /// 1-based stage number (the actual game ID being played right now).
  int get currentStageNumber => _currentStageIndex + 1;

  bool get isRunActive => _isRunActive;

  /// How many stages must be cleared to complete the current run.
  int get totalStagesInCurrentRun => _currentRun;

  /// Formatted display code with dashes: `XXXXX-YYYYY-ZZZZZ`.
  /// Unrevealed characters show as `_`.
  String get displayCode {
    final chars = unlockedKeyChars.map((c) => c ?? '_').toList();
    return '${chars.sublist(0, 5).join()}'
        '-${chars.sublist(5, 10).join()}'
        '-${chars.sublist(10, 15).join()}';
  }

  /// True when all 15 characters have been unlocked.
  bool get isGameComplete => unlockedKeyChars.every((c) => c != null);

  // ── Constructor ──────────────────────────────────────────────────────
  GameStateManager(this._saveSystem);

  // ── Lifecycle ────────────────────────────────────────────────────────

  /// Load persisted state from disk. Call once at app startup.
  Future<void> loadState() async {
    unlockedKeyChars = _saveSystem.loadUnlockedKeyChars();
    statistics = _saveSystem.loadStatistics();
    tokens = _saveSystem.loadTokens();
    unlockedSkills = _saveSystem.loadUnlockedSkills();
    skillLevels = _saveSystem.loadSkillLevels();
    _currentRun = _computeNextRun();
    _recalculateTokenMultiplier();
    _checkPlayTimeAchievement();
    checkSkillAchievements();
    checkCompletionistAchievement();
    checkRunMasterAchievement();
    checkVisitedAllGamesAchievement();
    checkGamesCompletedAchievement();
    notifyListeners();
  }

  /// Recalculates [tokenMultiplier] from all collected multiplier achievements.
  /// Call on load and after any achievement is claimed.
  void _recalculateTokenMultiplier() {
    var product = 1.0;
    for (final a in allAchievements) {
      final mult = a.tokenMultiplier;
      if (mult != null && mult > 1.0) {
        if (getAchievementStatus(a.id) == AchievementStatus.collected) {
          product *= mult;
        }
      }
    }
    tokenMultiplier = product;
  }

  // ── Skill Tree & Token Currency ─────────────────────────────────────

  /// Get current upgrade level for a skill node (0 = unpurchased).
  int getSkillLevel(String id) => skillLevels[id] ?? 0;

  /// Check if a skill node has already been unlocked at least once.
  bool isSkillUnlocked(String id) => (skillLevels[id] ?? 0) >= 1;

  /// Upgrade / purchase a skill node level.
  bool upgradeSkill(String id, int maxLevel, int cost) {
    if (!isDevMode) {
      final node = defaultSkillTreeNodes.where((n) => n.id == id).firstOrNull;
      if (node != null && node.checkIfLocked(this)) {
        return false;
      }
    }
    final currentLevel = skillLevels[id] ?? 0;
    final canAfford = isDevMode || tokens >= cost;
    if (currentLevel < maxLevel && canAfford) {
      if (!isDevMode) {
        tokens -= cost;
      }
      skillLevels[id] = currentLevel + 1;
      if (!unlockedSkills.contains(id)) unlockedSkills.add(id);
      _saveSystem.saveUnlockedSkills(unlockedSkills);
      _saveSystem.saveSkillLevels(skillLevels);
      checkSkillAchievements();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Attempt to purchase/unlock a skill node with tokens.
  bool unlockSkill(String id, int cost) {
    return upgradeSkill(id, 1, cost);
  }

  /// Returns true if there is at least one skill tree node that the player can currently afford to purchase/upgrade.
  bool canAffordAnySkill(List<SkillNodeConfig> nodes) {
    for (final node in nodes) {
      if (!isDevMode && node.checkIfLocked(this)) {
        continue;
      }

      final isRevealed =
          node.parentIds.isEmpty ||
          node.parentIds.any((pId) => getSkillLevel(pId) >= 1);
      if (!isRevealed) continue;

      final currentLevel = getSkillLevel(node.id);
      if (currentLevel >= node.maxLevel) continue;

      final cost = node.costForLevel(currentLevel);
      if (isDevMode || tokens >= cost) {
        return true;
      }
    }
    return false;
  }

  /// Dev helper: refund all spent skill-tree tokens and lock all nodes again.
  int refundAllSkillTokens(List<SkillNodeConfig> nodes) {
    final nodesById = {for (final node in nodes) node.id: node};
    var refundedTokens = 0;

    skillLevels.forEach((id, level) {
      if (level <= 0) return;
      final node = nodesById[id];
      if (node == null) return;

      final purchasedLevels = level > node.maxLevel ? node.maxLevel : level;
      for (var i = 0; i < purchasedLevels; i++) {
        refundedTokens += node.costForLevel(i);
      }
    });

    tokens += refundedTokens;
    skillLevels = {};
    unlockedSkills = [];

    _saveSystem.saveUnlockedSkills(unlockedSkills);
    _saveSystem.saveSkillLevels(skillLevels);
    notifyListeners();

    return refundedTokens;
  }

  // ── Run Stopwatch & Timers ──────────────────────────────────────────
  final Stopwatch _runStopwatch = Stopwatch();
  final Stopwatch _stageStopwatch = Stopwatch();
  int _remainingRunSeconds = 60;

  /// Whether the current game is running in practice mode (no timer).
  bool isPracticeMode = false;

  /// Whether dev mode is currently enabled.
  bool isDevMode = false;

  /// Whether achievements can currently trigger (blocked in practice mode unless dev mode is ON or practice_achievements skill is unlocked).
  bool get canTriggerAchievements =>
      !isPracticeMode || isDevMode || isSkillUnlocked('practice_achievements');

  /// Whether the current active stage is the final stage of the run.
  bool get isLastStageOfRun => (_currentStageIndex + 1) >= _currentRun;

  bool _currentStageWon = false;

  /// Whether the current stage has already been solved/won and is transitioning to the next stage.
  bool get isCurrentStageWon => _currentStageWon;

  /// Default base max run time in seconds (legacy).
  int get maxRunTimerSeconds => RootSkillConfig.baseRunTimeSeconds;

  /// Remaining seconds in the current run timer (legacy).
  int get remainingRunSeconds => _remainingRunSeconds;

  /// Immediately freeze/stop the run countdown timer (legacy no-op).
  void freezeRunTimer() {}

  /// Formatted countdown timer string (legacy).
  String get formattedRunTimer => '0:00';

  /// Total play time in seconds across past runs and the currently active run.
  int get currentTotalPlayTimeSeconds {
    final activeRunSec = (_isRunActive && _runStopwatch.isRunning)
        ? _runStopwatch.elapsed.inSeconds
        : 0;
    return statistics.totalPlayTimeSeconds + activeRunSec;
  }

  void _checkPlayTimeAchievement() {
    if (!canTriggerAchievements) return;
    if (currentTotalPlayTimeSeconds >=
        AchievementTargets.playTimeOneHourSeconds) {
      if (getAchievementStatus('play_time_1h') == AchievementStatus.locked) {
        setAchievementStatus('play_time_1h', AchievementStatus.unlocked);
      }
    }
  }

  /// Formatted play time spent inside active runs (e.g. "6:32" or "1:06:32").
  String get formattedPlayTime {
    final totalSec = currentTotalPlayTimeSeconds;
    final hours = totalSec ~/ 3600;
    final minutes = (totalSec % 3600) ~/ 60;
    final seconds = totalSec % 60;

    final sStr = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      final mStr = minutes.toString().padLeft(2, '0');
      return '$hours:$mStr:$sStr';
    } else {
      return '$minutes:$sStr';
    }
  }

  /// Current level of the anomaly detector skill node.
  int get anomalySkillLevel => getSkillLevel('anomalies');

  /// Current probability of anomaly occurrence (0.0 to 1.0).
  /// Formula: If level is 0, returns 0.0. Otherwise (1 + L) / (5 + L).
  double get anomalyProbability =>
      AnomalyConfig.calculateProbability(anomalySkillLevel);

  /// Formatted anomaly occurrence probability percentage (e.g. "33.3%").
  String get formattedAnomalyProbability {
    final pct = anomalyProbability * 100;
    return '${pct.toCleverString(2)}%';
  }

  /// True if the current game is being played as an Anomaly.
  bool isCurrentGameAnomaly = false;

  /// Tracks how many anomalies have been played in the current run.
  int anomaliesPlayedThisRun = 0;

  /// Bonus multiplier for each anomaly played.
  static final double anomalyTokenMultiplier =
      AnomalyConfig.runMultiplierPerAnomaly;
  double get anomalyMultiplier => anomaliesPlayedThisRun > 0
      ? pow(anomalyTokenMultiplier, anomaliesPlayedThisRun).toDouble()
      : 1.0;

  /// Roll anomaly chance for the current game session.
  void rollAnomalyForCurrentGame() {
    if (isPracticeMode) {
      isCurrentGameAnomaly = false;
      return;
    }
    if (anomalyProbability > 0) {
      isCurrentGameAnomaly = Random().nextDouble() < anomalyProbability;
      if (isCurrentGameAnomaly) {
        final stageNum = currentStageNumber;
        statistics.encounteredAnomalies[stageNum] = true;
        _saveSystem.saveStatistics(statistics);
        checkEncounteredAllAnomaliesAchievement();
      }
    } else {
      isCurrentGameAnomaly = false;
    }
  }

  /// Returns whether the player has encountered the anomaly for [stageNumber] during a normal run.
  bool hasEncounteredAnomaly(int stageNumber) =>
      statistics.encounteredAnomalies[stageNumber] == true;

  /// Returns whether the player has encountered at least one anomaly during a normal run.
  bool get hasEncounteredAnyAnomaly =>
      statistics.encounteredAnomalies.values.any((v) => v == true);

  /// Award tokens to the player balance and update lifetime statistics.
  void addTokens(int amount) {
    if (amount <= 0) return;
    tokens += amount;
    statistics.totalTokensEarned += amount;
    _saveSystem.saveTokens(tokens);
    _saveSystem.saveStatistics(statistics);
    checkTokenAchievements();
    notifyListeners();
  }

  /// Dev helper: add custom amount of tokens to balance and update statistics.
  void addDevTokens(int amount) {
    addTokens(amount);
  }

  /// Dev helper: add 100 tokens to balance.
  void addDevToken() {
    addDevTokens(100);
  }

  // ── Run control ──────────────────────────────────────────────────────

  /// Begin a new run. Resets the stage index, starts run countdown timer, increments run-start stat.
  void startRun({bool notify = true}) {
    _currentRun = _computeNextRun();
    _currentStageIndex = 0;
    _currentStageWon = false;
    _isRunActive = true;
    _remainingRunSeconds = maxRunTimerSeconds;
    runBaseIncome = 0;
    runIncomeSkillTokens = 0;
    runRewardSkillTokens = 0;
    runAccumulatorSkillTokens = 0;
    runRawTotal = 0;
    runMultipliedTotal = 0;
    anomaliesPlayedThisRun = 0;
    statistics.totalRunsStarted++;

    rollAnomalyForCurrentGame();

    // Start run time tracking
    _runStopwatch.stop();
    _runStopwatch.reset();
    _runStopwatch.start();

    _stageStopwatch.stop();
    _stageStopwatch.reset();
    _stageStopwatch.start();

    _saveSystem.saveStatistics(statistics);
    if (notify) {
      notifyListeners();
    }
  }

  /// Checks whether a game stage has been visited/played before (total tries > 0).
  bool isStageVisited(GauntletStage stage) {
    final stageNum = stage.stageNumber;
    final completions = statistics.gameCompletions[stageNum] ?? 0;
    final losses = statistics.gameLosses[stageNum] ?? 0;
    return (completions + losses) > 0;
  }

  /// Checks whether a game stage has been completed/won before (completions > 0).
  bool isStageCompleted(GauntletStage stage) {
    final stageNum = stage.stageNumber;
    final completions = statistics.gameCompletions[stageNum] ?? 0;
    return completions > 0;
  }

  /// Checks achievement for visiting/playing all 15 games (win or loss).
  void checkVisitedAllGamesAchievement() {
    if (!canTriggerAchievements) return;
    if (getAchievementStatus('games_play_all') !=
        AchievementStatus.locked) {
      return;
    }

    final allVisited = GauntletStage.values.every(isStageVisited);

    if (allVisited) {
      setAchievementStatus('games_play_all', AchievementStatus.unlocked);
    }
  }

  /// Checks achievement for encountering all 15 anomaly versions.
  void checkEncounteredAllAnomaliesAchievement() {
    if (!canTriggerAchievements) return;
    if (getAchievementStatus('anomaly_encounter_all') !=
        AchievementStatus.locked) {
      return;
    }
    int anomalyCount = 0;
    for (int i = 1; i <= 15; i++) {
      if (statistics.encounteredAnomalies[i] == true) {
        anomalyCount++;
      }
    }
    if (anomalyCount >= 15) {
      setAchievementStatus('anomaly_encounter_all', AchievementStatus.unlocked);
    }
  }

  /// Checks achievement for completing 500 games across all runs.
  void checkGamesCompletedAchievement() {
    if (!canTriggerAchievements) return;
    if (getAchievementStatus('games_clear_500') !=
        AchievementStatus.locked) {
      return;
    }

    if (statistics.totalGamesCompleted >=
        AchievementTargets.gamesCompletedTarget) {
      setAchievementStatus('games_clear_500', AchievementStatus.unlocked);
    }
  }

  /// Checks status of an achievement.
  AchievementStatus getAchievementStatus(String achievementId) {
    final statusStr = statistics.achievementStates[achievementId] ?? 'locked';
    switch (statusStr) {
      case 'unlocked':
        return AchievementStatus.unlocked;
      case 'collected':
        return AchievementStatus.collected;
      default:
        return AchievementStatus.locked;
    }
  }

  /// Whether the hint popup for an achievement has ever been shown to the user.
  bool isAchievementPopupShown(String achievementId) {
    return statistics.achievementPopupsShown[achievementId] ?? false;
  }

  /// Mark the hint popup for an achievement as shown and persist state.
  void markAchievementPopupShown(String achievementId) {
    if (statistics.achievementPopupsShown[achievementId] == true) return;
    statistics.achievementPopupsShown[achievementId] = true;
    _saveSystem.saveStatistics(statistics);
    notifyListeners();
  }

  /// Records a literal text pick in Stroop Test, incrementing progress and unlocking achievement when reaching target.
  void recordStroopLiteralTextPick() {
    statistics.stroopLiteralTextPicks++;
    _saveSystem.saveStatistics(statistics);

    if (canTriggerAchievements &&
        statistics.stroopLiteralTextPicks >=
            AchievementTargets.stroopLiteralTextPicksTarget &&
        getAchievementStatus('stroop_literal_text') ==
            AchievementStatus.locked) {
      setAchievementStatus('stroop_literal_text', AchievementStatus.unlocked);
    } else {
      notifyListeners();
    }
  }

  /// Whether any achievement is in 'unlocked' or 'collected' state.
  bool get hasAnyUnlockedOrCollectedAchievements {
    return statistics.achievementStates.values.any(
      (s) => s == 'unlocked' || s == 'collected',
    );
  }

  /// Whether any achievement is in 'unlocked' state (ready to be claimed).
  bool get hasAnyUnclaimedAchievements {
    return statistics.achievementStates.values.any((s) => s == 'unlocked');
  }

  final _achievementUnlockedController =
      StreamController<AchievementConfig>.broadcast();

  /// Broadcast stream emitting newly unlocked achievement configs.
  Stream<AchievementConfig> get onAchievementUnlocked =>
      _achievementUnlockedController.stream;

  bool _isAchievementOverlayPaused = false;

  /// Whether the global achievement overlay toast processing is currently paused.
  bool get isAchievementOverlayPaused => _isAchievementOverlayPaused;

  final _achievementPauseController = StreamController<bool>.broadcast();

  /// Broadcast stream emitting pause state changes for the achievement toast queue.
  Stream<bool> get onAchievementQueuePauseChanged =>
      _achievementPauseController.stream;

  /// Pauses or resumes processing of global achievement popup toasts.
  void setAchievementOverlayPaused(bool paused) {
    if (_isAchievementOverlayPaused != paused) {
      _isAchievementOverlayPaused = paused;
      _achievementPauseController.add(paused);
      notifyListeners();
    }
  }

  /// Checks token accumulation achievements.
  void checkTokenAchievements() {
    if (!canTriggerAchievements) return;
    if (tokens >= AchievementTargets.tokensAccumulate1Target) {
      if (getAchievementStatus('tokens_accumulate_1') ==
          AchievementStatus.locked) {
        setAchievementStatus('tokens_accumulate_1', AchievementStatus.unlocked);
      }
    }
    if (tokens >= AchievementTargets.tokensAccumulate2Target) {
      if (getAchievementStatus('tokens_accumulate_2') ==
          AchievementStatus.locked) {
        setAchievementStatus('tokens_accumulate_2', AchievementStatus.unlocked);
      }
    }
  }

  /// Checks skill tree achievements (unlock all skills & max out all skills).
  void checkSkillAchievements() {
    if (!canTriggerAchievements) return;

    bool allUnlocked = true;
    bool allMaxed = true;

    for (final node in defaultSkillTreeNodes) {
      final lvl = getSkillLevel(node.id);
      if (lvl < 1) allUnlocked = false;
      if (!node.isInfinite && lvl < node.maxLevel) allMaxed = false;
    }

    if (allUnlocked) {
      if (getAchievementStatus('skills_unlock_all') ==
          AchievementStatus.locked) {
        setAchievementStatus('skills_unlock_all', AchievementStatus.unlocked);
      }
    }
    if (allMaxed) {
      if (getAchievementStatus('skills_max_all') == AchievementStatus.locked) {
        setAchievementStatus('skills_max_all', AchievementStatus.unlocked);
      }
    }
  }

  /// Checks completionist achievement (all other achievements unlocked or collected).
  void checkCompletionistAchievement() {
    if (!canTriggerAchievements) return;
    if (getAchievementStatus('completionist') != AchievementStatus.locked) {
      return;
    }

    final otherAchievements = allAchievements.where(
      (a) => a.id != 'completionist',
    );
    final allOtherUnlocked = otherAchievements.every(
      (a) => getAchievementStatus(a.id) != AchievementStatus.locked,
    );

    if (allOtherUnlocked) {
      setAchievementStatus('completionist', AchievementStatus.unlocked);
    }
  }

  /// Checks run master achievement (all 15 key characters unlocked / run 15 complete).
  void checkRunMasterAchievement() {
    if (!canTriggerAchievements) return;
    if (getAchievementStatus('run_master') != AchievementStatus.locked) return;

    if (isGameComplete) {
      setAchievementStatus('run_master', AchievementStatus.unlocked);
    }
  }

  /// Checks run speedrun achievement (completing a full 15-stage run in under 60 seconds).
  void checkRunSpeedrunAchievement(int elapsedRunSeconds) {
    if (!canTriggerAchievements) return;
    if (_currentRun < 15) return;
    if (getAchievementStatus('run_under_60s') != AchievementStatus.locked) {
      return;
    }

    if (elapsedRunSeconds <= AchievementTargets.runSpeedrunMaxSeconds) {
      setAchievementStatus('run_under_60s', AchievementStatus.unlocked);
    }
  }

  /// Sets achievement status explicitly (e.g. condition met or dev mode toggle).
  void setAchievementStatus(String achievementId, AchievementStatus status) {
    if (status == AchievementStatus.unlocked && !canTriggerAchievements) {
      return;
    }

    final prevStatus = getAchievementStatus(achievementId);

    // Do not downgrade a collected achievement back to unlocked
    if (prevStatus == AchievementStatus.collected &&
        status == AchievementStatus.unlocked) {
      return;
    }

    final statusStr = status == AchievementStatus.unlocked
        ? 'unlocked'
        : status == AchievementStatus.collected
        ? 'collected'
        : 'locked';
    statistics.achievementStates[achievementId] = statusStr;
    _saveSystem.saveStatistics(statistics);
    notifyListeners();

    if (status == AchievementStatus.unlocked &&
        prevStatus == AchievementStatus.locked) {
      final config = allAchievements.firstWhere(
        (a) => a.id == achievementId,
        orElse: () => AchievementConfig(
          id: achievementId,
          title: 'Achievement Unlocked',
          description: '',
          icon: Icons.star_rounded,
          tokenReward: 1,
        ),
      );
      _achievementUnlockedController.add(config);

      if (achievementId != 'completionist') {
        checkCompletionistAchievement();
      }
    }
  }

  int _testAchievementCounter = 0;

  /// Dev mode helper to trigger a template achievement toast notification popup.
  void triggerTestAchievementToast() {
    _testAchievementCounter++;
    final count = _testAchievementCounter;
    final testConfig = AchievementConfig(
      id: 'test_achievement_$count',
      title: 'Achievement #$count Unlocked!',
      description: 'Template notification test #$count in queue.',
      icon: Icons.emoji_events_rounded,
      tokenReward: 5 * count,
    );
    _achievementUnlockedController.add(testConfig);
  }

  /// Claims reward for an unlocked achievement.
  /// Pass [rewardTokens] for token rewards or [rewardMultiplier] for multiplier rewards.
  void claimAchievement(
    String achievementId, {
    int rewardTokens = 0,
    double? rewardMultiplier,
  }) {
    if (getAchievementStatus(achievementId) == AchievementStatus.unlocked) {
      statistics.achievementStates[achievementId] = 'collected';
      if (rewardTokens > 0) {
        tokens += rewardTokens;
        statistics.totalTokensEarned += rewardTokens;
      }
      _recalculateTokenMultiplier();
      _saveSystem.saveStatistics(statistics);
      notifyListeners();

      if (achievementId != 'completionist') {
        checkCompletionistAchievement();
      }
    }
  }

  /// Records a flawless Minesweeper win (0 misplaced flags) and unlocks achievement at 5.
  void recordFlawlessMinesweeperWin() {
    if (!canTriggerAchievements) return;

    statistics.flawlessMinesweeperCompletions++;
    _saveSystem.saveStatistics(statistics);
    notifyListeners();

    if (statistics.flawlessMinesweeperCompletions >=
        AchievementTargets.flawlessMinesweeperCompletionsTarget) {
      if (getAchievementStatus('flawless_minesweeper_5') ==
          AchievementStatus.locked) {
        setAchievementStatus(
          'flawless_minesweeper_5',
          AchievementStatus.unlocked,
        );
      }
    }
  }

  /// Resets all achievements back to locked state and resets achievement-specific progress counters.
  void resetAchievements() {
    statistics.achievementStates.clear();
    statistics.flawlessMinesweeperCompletions = 0;
    _recalculateTokenMultiplier();
    _saveSystem.saveStatistics(statistics);
    notifyListeners();
  }

  /// Completes the current game and records all awards, tokens, stats, and achievements.
  /// If this was the last stage of the run, immediately stops the timer and finishes the run.
  /// Returns `true` if the entire run is completed.
  bool completeCurrentGame() {
    if (_currentStageWon) return isLastStageOfRun;
    _currentStageWon = true;

    final stageNum = currentStageNumber;

    if (isCurrentGameAnomaly) {
      anomaliesPlayedThisRun++;
      if (getAchievementStatus('anomaly_solved') == AchievementStatus.locked) {
        setAchievementStatus('anomaly_solved', AchievementStatus.unlocked);
      }
    }
    final completionsBefore = statistics.gameCompletions[stageNum] ?? 0;
    final stageElapsedSeconds = _stageStopwatch.elapsed.inSeconds;

    statistics.gamePlayTimeSeconds[stageNum] =
        (statistics.gamePlayTimeSeconds[stageNum] ?? 0) +
        stageElapsedSeconds;

    statistics.gameCompletions[stageNum] = completionsBefore + 1;
    statistics.totalGamesCompleted++;
    checkVisitedAllGamesAchievement();
    checkGamesCompletedAchievement();

    // Base tokens awarded for completing a game (always 1 token)
    var earnedTokens = 1;
    runBaseIncome += 1;

    // Income skill ('income'): +1 per level for each completed game in current run
    final incomeLevel = getSkillLevel('income');
    if (incomeLevel > 0) {
      final incomeBonus =
          incomeLevel *
          currentStageNumber *
          EconomySkillConfig.incomeBonusPerStagePerLevel;
      earnedTokens += incomeBonus;
      runIncomeSkillTokens += incomeBonus;
    }

    // Reward skill ('reward'): tokens equal to completed stage number cubed (Stage³) the first time you complete it
    final rewardLevel = getSkillLevel('reward');
    if (rewardLevel > 0 && completionsBefore == 0) {
      final stageNum = currentStageNumber;
      final rewardBonus = stageNum * stageNum * stageNum;
      earnedTokens += rewardBonus;
      runRewardSkillTokens += rewardBonus;
    }

    // Accumulator skill ('accumulator'): accumulates exact decimal bonus tokens = √(completions / 10) × (stage number)² × level
    final accumulatorLevel = getSkillLevel('accumulator');
    if (accumulatorLevel > 0) {
      final totalTimesCompleted = statistics.gameCompletions[stageNum] ?? 0;
      final baseGain = sqrt(
        totalTimesCompleted / EconomySkillConfig.accumulatorDivisor,
      );
      final accumulatorBonus =
          baseGain * (stageNum * stageNum) * accumulatorLevel;
      runAccumulatorSkillTokens += accumulatorBonus;
    }

    // Add raw tokens to balance (multiplier applied once at run end)
    tokens += earnedTokens;
    runRawTotal += earnedTokens;
    statistics.totalTokensEarned += earnedTokens;
    _saveSystem.saveStatistics(statistics);

    final isLastStage = (_currentStageIndex + 1) >= _currentRun;

    if (isLastStage) {
      // ── Run complete — apply multiplier bonus and unlock a character ──
      _stageStopwatch.stop();
      _runStopwatch.stop();
      final elapsedRunSec = _runStopwatch.elapsed.inSeconds;
      statistics.totalPlayTimeSeconds += elapsedRunSec;
      _runStopwatch.reset();
      _stageStopwatch.reset();
      _checkPlayTimeAchievement();
      checkRunSpeedrunAchievement(elapsedRunSec);

      // Floor the accumulated accumulator bonus at run end summary
      final flooredAccumulator = runAccumulatorSkillTokens.floor();
      if (flooredAccumulator > 0) {
        tokens += flooredAccumulator;
        statistics.totalTokensEarned += flooredAccumulator;
      }

      runRawTotal = runBaseIncome +
          runIncomeSkillTokens +
          runRewardSkillTokens +
          flooredAccumulator;

      // Apply multipliers: floor(subtotal * tokenMultiplier * anomalyMultiplier) - rawTotal = bonus
      runMultipliedTotal = (runRawTotal * tokenMultiplier * anomalyMultiplier)
          .floor();
      final multiplierBonus = runMultipliedTotal - runRawTotal;
      if (multiplierBonus > 0) {
        tokens += multiplierBonus;
        statistics.totalTokensEarned += multiplierBonus;
      }

      final charIndex = _currentRun - 1;
      unlockedKeyChars[charIndex] = activationCode[charIndex];
      _isRunActive = false;

      checkRunMasterAchievement();

      if (_currentRun == 15 &&
          anomaliesPlayedThisRun == 15 &&
          canTriggerAchievements) {
        if (getAchievementStatus('anomaly_run_15') ==
            AchievementStatus.locked) {
          setAchievementStatus('anomaly_run_15', AchievementStatus.unlocked);
        }
      }

      _saveSystem.saveUnlockedKeyChars(unlockedKeyChars);
      _saveSystem.saveStatistics(statistics);
      notifyListeners();
      return true;
    }

    return false;
  }

  /// Advances to the next stage after the transition animation completes.
  void advanceToNextStage() {
    _currentStageWon = false;
    _currentStageIndex++;
    rollAnomalyForCurrentGame();

    _stageStopwatch
      ..stop()
      ..reset()
      ..start();

    _saveSystem.saveStatistics(statistics);
    notifyListeners();
  }

  /// Called when the current game is completed successfully.
  ///
  /// Returns `true` if this was the last stage and the run is now complete.
  bool completeGame() {
    final isRunComplete = completeCurrentGame();
    if (!isRunComplete) {
      advanceToNextStage();
    }
    return isRunComplete;
  }

  /// Returns the relevant previous Number Guesser target depending on whether we are in practice mode or an active run.
  int? get lastNumberGuesserTarget => isPracticeMode
      ? statistics.lastPracticeNumberGuesserTarget
      : statistics.lastNumberGuesserTarget;

  /// Records the secret number from Number Guesser to persist across runs and power its anomaly logic.
  void recordNumberGuesserResult({required int secretNumber}) {
    if (isPracticeMode) {
      statistics.lastPracticeNumberGuesserTarget = secretNumber;
    } else {
      statistics.lastNumberGuesserTarget = secretNumber;
    }
    _saveSystem.saveStatistics(statistics);
  }

  /// Called when the player fails the current game or runs out of time.
  void failGame() {
    _stageStopwatch.stop();

    if (isPracticeMode) {
      _stageStopwatch.reset();
      return;
    }

    final stageNum = currentStageNumber;
    final stageElapsedSeconds = _stageStopwatch.elapsed.inSeconds;

    statistics.gamePlayTimeSeconds[stageNum] =
        (statistics.gamePlayTimeSeconds[stageNum] ?? 0) +
        stageElapsedSeconds;

    _runStopwatch.stop();
    statistics.totalPlayTimeSeconds += _runStopwatch.elapsed.inSeconds;
    _runStopwatch.reset();
    _stageStopwatch.reset();
    _checkPlayTimeAchievement();
    statistics.totalDeaths++;

    // If the current stage was already won (and we ran out of time during the transition to the next stage),
    // do NOT count a loss on this stage!
    if (!_currentStageWon) {
      statistics.gameLosses[stageNum] =
          (statistics.gameLosses[stageNum] ?? 0) + 1;
      checkVisitedAllGamesAchievement();
      statistics.lastStageLostAt = stageNum;
    }

    _isRunActive = false;
    _currentStageWon = false;

    // Floor the accumulated accumulator bonus at run end summary
    final flooredAccumulator = runAccumulatorSkillTokens.floor();
    if (flooredAccumulator > 0) {
      tokens += flooredAccumulator;
      statistics.totalTokensEarned += flooredAccumulator;
    }

    runRawTotal = runBaseIncome +
        runIncomeSkillTokens +
        runRewardSkillTokens +
        flooredAccumulator;

    // Apply multiplier bonus once for the whole partial run
    runMultipliedTotal = (runRawTotal * tokenMultiplier * anomalyMultiplier)
        .floor();
    final multiplierBonus = runMultipliedTotal - runRawTotal;
    if (multiplierBonus > 0) {
      tokens += multiplierBonus;
      statistics.totalTokensEarned += multiplierBonus;
      _saveSystem.saveTokens(tokens);
    }

    // Reset timer so it doesn't show a frozen value after the run ends.
    _remainingRunSeconds = maxRunTimerSeconds;
    _saveSystem.saveStatistics(statistics);
    notifyListeners();
  }

  /// Reset transient run state (called when returning to main menu).
  void resetRunState() {
    _currentStageIndex = 0;
    _isRunActive = false;
    _currentRun = _computeNextRun();
    // Reset timer display so it shows fresh when a new run begins.
    _remainingRunSeconds = maxRunTimerSeconds;
    notifyListeners();
  }

  /// Lifetime solve count for [stageNumber].
  int getSolveCount(int stageNumber) {
    return statistics.gameCompletions[stageNumber] ?? 0;
  }

  /// Marks statistics popup as having been opened permanently.
  void markStatisticsOpened() {
    if (!statistics.hasOpenedStatistics) {
      statistics.hasOpenedStatistics = true;
      _saveSystem.saveStatistics(statistics);
      notifyListeners();
    }
  }

  /// Marks skill tree screen as having been opened permanently.
  void markSkillTreeOpened() {
    if (!statistics.hasOpenedSkillTree) {
      statistics.hasOpenedSkillTree = true;
      _saveSystem.saveStatistics(statistics);
      notifyListeners();
    }
  }

  /// Marks practice info popup as having been shown permanently.
  void markPracticeInfoSeen() {
    if (!statistics.hasSeenPracticeInfo) {
      statistics.hasSeenPracticeInfo = true;
      _saveSystem.saveStatistics(statistics);
      notifyListeners();
    }
  }

  /// Whether a specific key slot has ever been hovered on the main menu.
  bool hasHoveredKeySlot(int slotIndex) {
    return statistics.hoveredKeySlots[slotIndex] ?? false;
  }

  /// Marks a specific key slot as having been hovered permanently.
  void markKeySlotHovered(int slotIndex) {
    if (statistics.hoveredKeySlots[slotIndex] != true) {
      statistics.hoveredKeySlots[slotIndex] = true;
      _saveSystem.saveStatistics(statistics);
      notifyListeners();
    }
  }

  /// Marks the first key slot as having been hovered permanently (alias).
  void markFirstKeySlotHovered() => markKeySlotHovered(0);

  // ── Internals ────────────────────────────────────────────────────────

  /// Determine which run the player should attempt next.
  int _computeNextRun() {
    for (int i = 0; i < 15; i++) {
      if (unlockedKeyChars[i] == null) return i + 1;
    }
    return 15; // all done
  }

  /// Wipe all saved data and reset to fresh state. Dev/debug only.
  Future<void> clearAllData() async {
    await _saveSystem.clearAll();
    unlockedKeyChars = List<String?>.filled(15, null);
    statistics = Statistics();
    tokens = 0;
    unlockedSkills = [];
    skillLevels = {};
    _currentRun = 1;
    _currentStageIndex = 0;
    _isRunActive = false;
    _recalculateTokenMultiplier();
    notifyListeners();
  }
}
