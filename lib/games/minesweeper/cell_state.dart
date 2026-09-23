// ── Cell state constants (packed in Uint8List for zero GC overhead) ──────────

abstract final class CellState {
  static const int unrevealed = 0;
  static const int revealed = 1;
  static const int flagged = 2;
  static const int activatedMine = 3; // The mine the player clicked
  static const int revealedMine = 4; // Other mines shown upon defeat
  static const int hiddenNumber = 5; // Anomaly '?'
}
