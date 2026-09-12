import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dominik/game_state.dart';
import 'package:dominik/save_system.dart';
import 'package:dominik/config/achievement_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SaveSystem saveSystem;
  late GameStateManager gameState;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    saveSystem = SaveSystem();
    await saveSystem.init();
    gameState = GameStateManager(saveSystem);
    await gameState.loadState();
  });

  group('Dev tokens tests', () {
    test('addDevTokens adds custom token amount and updates totalTokensEarned in statistics', () {
      expect(gameState.tokens, 0);
      expect(gameState.statistics.totalTokensEarned, 0);

      gameState.addDevTokens(250);

      expect(gameState.tokens, 250);
      expect(gameState.statistics.totalTokensEarned, 250);

      // Verify persistence
      expect(saveSystem.loadTokens(), 250);
      expect(saveSystem.loadStatistics().totalTokensEarned, 250);
    });

    test('addDevTokens multiple times accumulates tokens and lifetime totalTokensEarned', () {
      gameState.addDevTokens(100);
      gameState.addDevTokens(500);
      gameState.addDevTokens(1234);

      expect(gameState.tokens, 1834);
      expect(gameState.statistics.totalTokensEarned, 1834);
    });

    test('addDevTokens ignores zero and negative values', () {
      gameState.addDevTokens(100);

      gameState.addDevTokens(0);
      gameState.addDevTokens(-50);

      expect(gameState.tokens, 100);
      expect(gameState.statistics.totalTokensEarned, 100);
    });

    test('addDevTokens unlocks token accumulation achievements when thresholds are reached', () {
      expect(gameState.getAchievementStatus('tokens_accumulate_1'), AchievementStatus.locked);

      gameState.addDevTokens(AchievementTargets.tokensAccumulate1Target);

      expect(gameState.getAchievementStatus('tokens_accumulate_1'), AchievementStatus.unlocked);
      expect(gameState.getAchievementStatus('tokens_accumulate_2'), AchievementStatus.locked);

      gameState.addDevTokens(AchievementTargets.tokensAccumulate2Target);

      expect(gameState.getAchievementStatus('tokens_accumulate_2'), AchievementStatus.unlocked);
    });

    test('addDevToken adds 100 tokens', () {
      gameState.addDevToken();

      expect(gameState.tokens, 100);
      expect(gameState.statistics.totalTokensEarned, 100);
    });
  });
}
