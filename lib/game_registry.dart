import 'game.dart';
import 'games/minesweeper.dart';

/// Central registry of all gauntlet stages.
/// Only Stage 1 (Minesweeper) is implemented; all other games have been removed.
class GameRegistry {
  GameRegistry._();

  static final List<Game> stages = [
    MinesweeperGame(), // Stage 1
  ];

  /// Get the game for a 1-based [stageNumber].
  static Game getStage(int stageNumber) {
    return stages[0];
  }

  /// Whether stage [stageNumber] is fully implemented (not a placeholder).
  static bool isImplemented(int stageNumber) {
    return stageNumber == 1;
  }
}
