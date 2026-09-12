import 'dart:math' as math;

/// Configuration and mathematical formulas for Anomalies.
abstract final class AnomalyConfig {
  /// Base token cost for upgrading the Anomaly skill (Level 1 cost).
  static const int baseCost = 1000;

  /// Exponent parameter N for level cost formula: Base * (L)^N
  static const double costExponent = 1.25;

  /// Base rate multiplier for the probability exponential curve
  static const double probabilityBaseRate = 0.01;

  /// Extra token multiplier granted at run end for each anomaly completed.
  static const double runMultiplierPerAnomaly = 1.5;

  /// Calculates upgrade token cost to go from [currentLevel] to [currentLevel + 1].
  /// Formula: floor(baseCost * (currentLevel + 1)^costExponent)
  static int calculateCost(int currentLevel) {
    final l = currentLevel + 1;
    final exactCost = baseCost * math.pow(l, costExponent);
    return (exactCost / 500).ceil() * 250;
  }

  /// Calculates anomaly occurrence probability given skill level [level].
  /// Formula: 1 - e^(-probabilityBaseRate * level^probabilityCurvePower)
  static double calculateProbability(int level) {
    if (level <= 0) return 0.0;
    return 1.0 - math.exp(-probabilityBaseRate * level);
  }
}
