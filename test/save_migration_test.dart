import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dominik/game_state.dart';
import 'package:dominik/save_system.dart';
import 'package:dominik/config/skill_tree_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Existing save file from previous release loads cleanly without breaking', () async {
    // 1. Setup mock save data representing a save from the previous release:
    // - practice and practice_achievements unlocked (before parent changed to practice_anomalies)
    // - spot_impostor_rounds at level 2 (when max was 2, now 5)
    // - existing tokens and stats
    // - existing achievements
    SharedPreferences.setMockInitialValues({});
    final saveSystem = SaveSystem();
    await saveSystem.init();

    // Directly populate save vault as if loaded from disk
    await saveSystem.saveTokens(5000);
    await saveSystem.saveUnlockedSkills([
      'root',
      'practice',
      'practice_achievements',
      'spot_impostor_grid_size',
      'spot_impostor_rounds',
    ]);
    await saveSystem.saveSkillLevels({
      'root': 2,
      'practice': 1,
      'practice_achievements': 1,
      'spot_impostor_grid_size': 1,
      'spot_impostor_rounds': 2,
    });
    final oldStats = Statistics(
      totalTokensEarned: 15000,
      totalRunsStarted: 5,
      totalGamesCompleted: 20,
      achievementStates: {
        'first_win': 'collected',
      },
    );
    await saveSystem.saveStatistics(oldStats);

    // 2. Initialize GameStateManager and load state
    final gameState = GameStateManager(saveSystem);
    await gameState.loadState();

    // Verify tokens and stats
    expect(gameState.tokens, 5000);
    expect(gameState.statistics.totalTokensEarned, 15000);
    expect(gameState.statistics.totalRunsStarted, 5);

    // Verify skill levels
    expect(gameState.getSkillLevel('root'), 2);
    expect(gameState.isSkillUnlocked('practice_achievements'), isTrue);
    expect(gameState.getSkillLevel('spot_impostor_rounds'), 2);

    // Verify practice achievements behavior remains unlocked
    expect(gameState.canTriggerAchievements, isTrue);

    // Verify spot_impostor_rounds can now be upgraded to level 3 (since max is now 5)
    final spotNode = defaultSkillTreeNodes.firstWhere((n) => n.id == 'spot_impostor_rounds');
    expect(spotNode.maxLevel, 5);
    expect(gameState.getSkillLevel('spot_impostor_rounds') < spotNode.maxLevel, isTrue);

    // Verify refunding all skills works safely
    final refunded = gameState.refundAllSkillTokens(defaultSkillTreeNodes);
    expect(refunded > 0, isTrue);
    expect(gameState.getSkillLevel('root'), 0);
    expect(gameState.getSkillLevel('spot_impostor_rounds'), 0);
  });

  test('Save loading ignores obsolete streak keys and game operates without streaks', () async {
    final legacyJson = <String, dynamic>{
      'totalRunsStarted': 10,
      'totalDeaths': 4,
      'totalPlayTimeSeconds': 120,
      'totalGamesCompleted': 15,
      'totalTokensEarned': 500,
      'gameCompletions': {'1': 5, '2': 3},
      'gameLosses': {'1': 2, '2': 1},
      // Obsolete streak keys from older saves:
      'gameWinStreaks': {'1': 3, '2': 2},
      'gameLossStreaks': {'1': 0, '2': 1},
      'currentLoseStreak': 1,
      'lastStageLostAt': 2,
    };

    final stats = Statistics.fromJson(legacyJson);
    expect(stats.totalRunsStarted, 10);
    expect(stats.totalDeaths, 4);
    expect(stats.gameCompletions[1], 5);
    expect(stats.gameLosses[2], 1);
    expect(stats.lastStageLostAt, 2);

    final serialized = stats.toJson();
    expect(serialized.containsKey('gameWinStreaks'), isFalse);
    expect(serialized.containsKey('gameLossStreaks'), isFalse);
    expect(serialized.containsKey('currentLoseStreak'), isFalse);

    // Verify GameState operates without streaks
    SharedPreferences.setMockInitialValues({});
    final saveSystem = SaveSystem();
    await saveSystem.init();
    await saveSystem.saveStatistics(stats);

    final gameState = GameStateManager(saveSystem);
    await gameState.loadState();

    gameState.startRun();
    expect(gameState.currentStageNumber, 1);
    gameState.failGame();
    expect(gameState.statistics.gameLosses[1], 3);
    expect(gameState.statistics.lastStageLostAt, 1);

    gameState.startRun();
    expect(gameState.currentStageNumber, 1);
    gameState.completeCurrentGame();
    expect(gameState.statistics.gameCompletions[1], 6);
  });
}
