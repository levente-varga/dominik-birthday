import 'game.dart';
import 'games/minesweeper.dart';
import 'placeholder_game.dart';

/// Central registry of all gauntlet stages.
/// Only Stage 1 (Minesweeper) is implemented; all other games have been removed.
class GameRegistry {
  GameRegistry._();

  static final List<Game> stages = [
    MinesweeperGame(), // Stage 1
    for (int i = 2; i <= 15; i++)
      PlaceholderGame(stageNumber: i, name: 'Stage $i'),
  ];

  /// Get the game for a 1-based [stageNumber].
  static Game getStage(int stageNumber) {
    assert(stageNumber >= 1 && stageNumber <= 15);
    return stages[stageNumber - 1];
  }

  /// Whether stage [stageNumber] is fully implemented (not a placeholder).
  static bool isImplemented(int stageNumber) {
    return stageNumber == 1 && getStage(stageNumber) is! PlaceholderGame;
  }
}
