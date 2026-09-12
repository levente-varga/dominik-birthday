import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../game_state.dart';
import '../generated/embedded_assets.dart';
import '../models/gauntlet_stage.dart';
import '../utils/number_formatter.dart';

/// Shows the Statistics screen as a compact, simplified popup matching Main Menu styling.
void showStatisticsPopup(
  BuildContext context,
  GameStateManager gameState, {
  bool isDevMode = false,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Statistics',
    barrierColor: AppColors.overlayBarrier,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return StatisticsPopup(gameState: gameState, isDevMode: isDevMode);
    },
    transitionBuilder: (ctx, animation, _, child) {
      final scaleAnimation = Tween<double>(
        begin: 0.92,
        end: 1.0,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: AnimatedBuilder(
          animation: scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: scaleAnimation.value,
            filterQuality: FilterQuality.medium,
            child: RepaintBoundary(child: child),
          ),
          child: child,
        ),
      );
    },
  );
}

/// Compact, simplified Statistics Popup with stage numbers only and targeted color accents.
class StatisticsPopup extends StatelessWidget {
  final GameStateManager gameState;
  final bool isDevMode;

  const StatisticsPopup({
    super.key,
    required this.gameState,
    this.isDevMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Material(
        color: AppColors.transparent,
        child: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Bar: Close Button placed outside top-right
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.panelMedium,
                        foregroundColor: AppColors.textBright,
                        side: BorderSide(
                          color: AppColors.outlineDim,
                          width: 1.5,
                        ),
                        shape: const CircleBorder(),
                      ),
                    ),
                  ),
                ),
              ),

              // Main Popup Card matching Main Menu surface background
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.outlineMedium,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.50),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListenableBuilder(
                    listenable: gameState,
                    builder: (context, _) {
                      final stats = gameState.statistics;
                      final isDev = isDevMode || gameState.isDevMode;

                      // In dev mode show all 15 stages, otherwise only stages that have data
                      final activeStages = [
                        for (int stage = 1; stage <= 15; stage++)
                          if (isDev ||
                              (stats.gameCompletions[stage] ?? 0) > 0 ||
                              (stats.gameLosses[stage] ?? 0) > 0 ||
                              (stats.encounteredAnomalies[stage] ?? false) ||
                              gameState.unlockedKeyChars[stage - 1] != null)
                            stage,
                      ];

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Header Summary Bar with Time & Game Metrics ──
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.panelMedium,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.outlineDim,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _SummaryMetric(
                                  label: 'Runs',
                                  value: formatWithCommas(
                                    stats.totalRunsStarted,
                                  ),
                                  color: theme.colorScheme.primary,
                                ),
                                _MetricDivider(),
                                _SummaryMetric(
                                  label: 'Deaths',
                                  value: formatWithCommas(stats.totalDeaths),
                                  color: Colors.red.shade400,
                                ),
                                _MetricDivider(),
                                _SummaryMetric(
                                  label: 'Time',
                                  value: gameState.formattedPlayTime,
                                  color: Colors.cyan.shade300,
                                ),
                                _MetricDivider(),
                                _SummaryMetric(
                                  label: 'Cleared',
                                  value: formatWithCommas(
                                    stats.totalGamesCompleted,
                                  ),
                                  color: Colors.green.shade400,
                                ),
                                _MetricDivider(),
                                _SummaryMetric(
                                  label: 'Tokens',
                                  value: formatWithCommas(
                                    stats.totalTokensEarned,
                                  ),
                                  color: Colors.amber.shade400,
                                ),
                              ],
                            ),
                          ),

                          if (activeStages.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Flexible(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (
                                      int i = 0;
                                      i < activeStages.length;
                                      i += 2
                                    ) ...[
                                      if (i > 0) const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _StageCard(
                                              stageNumber: activeStages[i],
                                              playTimeSeconds:
                                                  stats
                                                      .gamePlayTimeSeconds[activeStages[i]] ??
                                                  0,
                                              wins:
                                                  stats
                                                      .gameCompletions[activeStages[i]] ??
                                                  0,
                                              losses:
                                                  stats
                                                      .gameLosses[activeStages[i]] ??
                                                  0,
                                              hasObservedAnomaly:
                                                  stats.encounteredAnomalies[activeStages[i]] ==
                                                  true,
                                              isUnlocked:
                                                  gameState
                                                      .unlockedKeyChars[activeStages[i] -
                                                      1] !=
                                                  null,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (i + 1 < activeStages.length)
                                            Expanded(
                                              child: _StageCard(
                                                stageNumber:
                                                    activeStages[i + 1],
                                                playTimeSeconds:
                                                    stats
                                                        .gamePlayTimeSeconds[activeStages[i +
                                                        1]] ??
                                                    0,
                                                wins:
                                                    stats
                                                        .gameCompletions[activeStages[i +
                                                        1]] ??
                                                    0,
                                                losses:
                                                    stats
                                                        .gameLosses[activeStages[i +
                                                        1]] ??
                                                    0,
                                                hasObservedAnomaly:
                                                    stats.encounteredAnomalies[activeStages[i +
                                                        1]] ==
                                                    true,
                                                isUnlocked:
                                                    gameState
                                                        .unlockedKeyChars[activeStages[i +
                                                            1] -
                                                        1] !=
                                                    null,
                                              ),
                                            )
                                          else
                                            const Expanded(child: SizedBox()),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fallback route wrapper if needed.
class StatisticsScreen extends StatelessWidget {
  final GameStateManager gameState;

  const StatisticsScreen({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: StatisticsPopup(gameState: gameState));
  }
}

// ── Summary Metric Item ───────────────────────────────────────────────────

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w300,
            color: AppColors.textMedium,
          ),
        ),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 22, color: AppColors.outlineDim);
  }
}

// ── Stage Specific Statistic Card (2-Row Layout) ──

class _StageCard extends StatelessWidget {
  final int stageNumber;
  final int playTimeSeconds;
  final int wins;
  final int losses;
  final bool hasObservedAnomaly;
  final bool isUnlocked;

  const _StageCard({
    required this.stageNumber,
    required this.playTimeSeconds,
    required this.wins,
    required this.losses,
    required this.hasObservedAnomaly,
    required this.isUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gameName = GauntletStageExtension.fromStageNumber(
      stageNumber,
    ).displayName;
    final totalTries = wins + losses;
    final formattedStageTime = _formatDuration(playTimeSeconds);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.panelMedium,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked ? AppColors.amberMedium : AppColors.outlineDim,
          width: isUnlocked ? 1.5 : 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Row: Stage Number + Game Name + Anomaly Skull ──
          Row(
            children: [
              Text(
                'Stage $stageNumber',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isUnlocked
                      ? Colors.amber.shade300
                      : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                ' • ',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: AppColors.textDim,
                ),
              ),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  gameName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasObservedAnomaly) ...[
                const SizedBox(width: 6),
                EmbeddedAssets.getImage(
                  'assets/icons/skull.png',
                  width: 12,
                  height: 12,
                  color: AppColors.textMedium,
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),

          // ── Bottom Row: 3 Columns (Tries | Time | W/L) ──
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tries: ${formatWithCommas(totalTries)}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: AppColors.textMedium,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    formattedStageTime,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: AppColors.cyanBright,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${formatWithCommas(wins)}W',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: wins > 0
                              ? Colors.green.shade400
                              : AppColors.textMedium,
                        ),
                      ),
                      Text(
                        ' / ',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppColors.textDim,
                        ),
                      ),
                      Text(
                        '${formatWithCommas(losses)}L',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: losses > 0
                              ? Colors.red.shade400
                              : AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(int totalSec) {
    final hours = totalSec ~/ 3600;
    final minutes = (totalSec % 3600) ~/ 60;
    final seconds = totalSec % 60;

    final sStr = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      final mStr = minutes.toString().padLeft(2, '0');
      return '$hours:$mStr:$sStr';
    }
    return '$minutes:$sStr';
  }
}
