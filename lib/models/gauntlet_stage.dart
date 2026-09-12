/// Represents each of the 15 game stages in the Birthday Gauntlet.
enum GauntletStage {
  minesweeper,      // Stage 1
  targetTiming,     // Stage 2
  numberGuesser,    // Stage 3
  simonSays,        // Stage 4
  wallRunner,       // Stage 5
  memoryMatch,      // Stage 6
  targetShooting,   // Stage 7
  memoryMatrix,     // Stage 8
  stroopTest,       // Stage 9
  mentalMath,       // Stage 10
  codeCracker,      // Stage 11
  bulletHell,       // Stage 12
  spotImpostor,     // Stage 13
  ballBounce,       // Stage 14
  speedTyping,      // Stage 15
}

extension GauntletStageExtension on GauntletStage {
  /// 1-based stage number (1 to 15).
  int get stageNumber => index + 1;

  /// Display name for tooltips and headers.
  String get displayName => switch (this) {
        GauntletStage.minesweeper => 'Minesweeper',
        GauntletStage.targetTiming => 'Target Timing',
        GauntletStage.numberGuesser => 'Number Guesser',
        GauntletStage.simonSays => 'Simon Says',
        GauntletStage.wallRunner => 'Wall Runner',
        GauntletStage.targetShooting => 'Target Shooting',
        GauntletStage.memoryMatrix => 'Memory Matrix',
        GauntletStage.memoryMatch => 'Memory Match',
        GauntletStage.stroopTest => 'Stroop Test',
        GauntletStage.mentalMath => 'Mental Math',
        GauntletStage.bulletHell => 'Bullet Hell',
        GauntletStage.codeCracker => 'Code Cracker',
        GauntletStage.spotImpostor => 'Spot Impostor',
        GauntletStage.speedTyping => 'Speed Typing',
        GauntletStage.ballBounce => 'Ball Bounce',
      };

  /// Get [GauntletStage] from 1-based stage number.
  static GauntletStage fromStageNumber(int stageNumber) {
    return GauntletStage.values[(stageNumber - 1).clamp(0, 14)];
  }
}
