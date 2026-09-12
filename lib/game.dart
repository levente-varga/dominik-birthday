import 'package:flutter/material.dart';

import 'game_state.dart';

/// Abstract base class for all games in the Birthday Gauntlet.
///
/// Each game receives the [GameStateManager] instance, allowing it to
/// read unlocked skill nodes and levels to configure its parameters dynamically.
abstract class Game {
  /// Stage number (1 to 15) corresponding to the unlocked character index.
  int get stageNumber;

  /// Human-readable title of the game.
  String get name;

  /// Builds the game widget.
  ///
  /// Calls [onComplete] when the player successfully wins the game,
  /// or [onFail] if the player fails.
  Widget buildGame({
    required BuildContext context,
    required VoidCallback onComplete,
    required VoidCallback onFail,
    required GameStateManager gameState,
  });
}
