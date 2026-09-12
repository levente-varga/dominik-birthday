import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../constants/colors.dart';

import '../config/achievement_config.dart';
import '../game_state.dart';
import '../models/gauntlet_stage.dart';
import '../utils/number_formatter.dart';
import '../widgets/animated_reward_text.dart';
import '../widgets/shockwave_layer.dart';
import '../widgets/confirm_popup.dart';
import '../generated/embedded_assets.dart';

/// Grid dimensions for Achievements layout
class AchievementsGridSettings {
  static const int gridColumns = 7;
  static const int gridRows = 5;
}

/// Show the Achievements progression popup dialog.
Future<bool?> showAchievementsPopup(
  BuildContext context,
  GameStateManager gameState, {
  bool isDevMode = false,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Achievements',
    barrierColor: AppColors.overlayBarrier,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return AchievementsPopup(gameState: gameState, isDevMode: isDevMode);
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

// ── Achievements Popup Dialog ───────────────────────────────────────────────

class AchievementsPopup extends StatefulWidget {
  final GameStateManager gameState;
  final List<List<AchievementConfig>>? majorRows;
  final List<List<AchievementConfig>>? minorRows;
  final bool isDevMode;

  const AchievementsPopup({
    super.key,
    required this.gameState,
    this.majorRows,
    this.minorRows,
    this.isDevMode = false,
  });

  List<List<AchievementConfig>> get effectiveMajorRows =>
      majorRows ?? majorAchievementRows;

  List<List<AchievementConfig>> get effectiveMinorRows =>
      minorRows ?? minorAchievementRows;

  @override
  State<AchievementsPopup> createState() => _AchievementsPopupState();
}

class _AchievementsPopupState extends State<AchievementsPopup> {
  AchievementConfig? _hoveredAchievement;

  Widget _buildNodeRow(
    List<AchievementConfig> rowItems,
    GameStateManager gs,
    ThemeData theme,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int j = 0; j < rowItems.length; j++) ...[
          if (j > 0) const SizedBox(width: 2),
          () {
            final achievement = rowItems[j];
            final status = gs.getAchievementStatus(achievement.id);
            final isStageLocked =
                status == AchievementStatus.locked &&
                achievement.checkIfLocked(gs) &&
                !widget.isDevMode;

            return _AchievementNodeWidget(
              achievement: achievement,
              status: status,
              isDevMode: widget.isDevMode,
              gameState: gs,
              onHoverEnter: () {
                if (!isStageLocked) {
                  setState(() {
                    _hoveredAchievement = achievement;
                  });
                  gs.markAchievementPopupShown(achievement.id);
                }
              },
              onHoverExit: () {
                setState(() {
                  _hoveredAchievement = null;
                });
              },
              onTap: () {
                if (status == AchievementStatus.unlocked) {
                  gs.claimAchievement(
                    achievement.id,
                    rewardTokens: achievement.tokenReward,
                    rewardMultiplier: achievement.tokenMultiplier,
                  );
                  if (achievement.id == 'completionist') {
                    Navigator.of(context).pop(true);
                  }
                } else if (widget.isDevMode) {
                  final nextStatus = status == AchievementStatus.locked
                      ? AchievementStatus.unlocked
                      : status == AchievementStatus.unlocked
                      ? AchievementStatus.collected
                      : AchievementStatus.locked;
                  gs.setAchievementStatus(achievement.id, nextStatus);
                  if (achievement.id == 'completionist' &&
                      nextStatus == AchievementStatus.collected) {
                    Navigator.of(context).pop(true);
                  }
                }
              },
            );
          }(),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gs = widget.gameState;

    return Center(
      child: Material(
        color: AppColors.transparent,
        child: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Bar: Circular Close Button placed outside top-right
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

              // Main Popup Container
              Container(
                height: 560,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.outlineMedium,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.60),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: ListenableBuilder(
                  listenable: gs,
                  builder: (context, _) {
                    return Stack(
                      children: [
                        Column(
                          children: [
                            // ── Header Bar: Title & Token Counter ───────────
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.panelMedium,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                                border: Border(
                                  bottom: BorderSide(
                                    color: AppColors.outlineDim,
                                  ),
                                ),
                              ),
                              child: SizedBox(
                                height: 28,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.emoji_events_rounded,
                                      color: Colors.amber.shade400,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Achievements',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const Spacer(),

                                    // Tokens Counter Badge (hidden if player has never received a token yet, unless dev mode)
                                    if (gs.statistics.totalTokensEarned > 0 ||
                                        widget.isDevMode)
                                      MouseRegion(
                                        cursor: widget.isDevMode
                                            ? SystemMouseCursors.click
                                            : MouseCursor.defer,
                                        child: GestureDetector(
                                          onTap: widget.isDevMode
                                              ? () => showAddDevTokensPopup(
                                                    context,
                                                    gameState:
                                                        widget.gameState,
                                                  )
                                              : null,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.surface,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: AppColors.amberMedium,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.token,
                                                  size: 14,
                                                  color: Colors.amber,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  formatWithCommas(gs.tokens),
                                                  style: const TextStyle(
                                                    fontFamily: 'monospace',
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.amber,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                    // Token Multiplier Badge (hidden when ×1.0 unless dev mode)
                                    if (gs.tokenMultiplier > 1.0 ||
                                        widget.isDevMode) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surface,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: AppColors.pinkMedium,
                                          ),
                                        ),
                                        child: Text(
                                          '×${gs.tokenMultiplier.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.pink.shade400,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),

                            // ── Main Achievements Canvas (Row Layout) ─────────────────
                            Expanded(
                              child: Stack(
                                children: [
                                  // Subtle Background Pattern
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Color.lerp(
                                          AppColors.surface,
                                          theme
                                              .colorScheme
                                              .surfaceContainerLowest,
                                          0.3,
                                        )!,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              bottom: Radius.circular(19),
                                            ),
                                      ),
                                    ),
                                  ),

                                  // Centered Rows List
                                  Positioned.fill(
                                    child: Center(
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.all(4),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Major achievement rows (ABOVE divider)
                                            for (
                                              int i = 0;
                                              i <
                                                  widget
                                                      .effectiveMajorRows
                                                      .length;
                                              i++
                                            ) ...[
                                              if (i > 0)
                                                const SizedBox(height: 1),
                                              _buildNodeRow(
                                                widget.effectiveMajorRows[i],
                                                gs,
                                                theme,
                                              ),
                                            ],

                                            // Divider separating Major and Minor achievements
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 16,
                                                  ),
                                              child: SizedBox(
                                                width: 320,
                                                child: Divider(
                                                  height: 1,
                                                  thickness: 1,
                                                  color: theme
                                                      .colorScheme
                                                      .outline
                                                      .withValues(alpha: 0.25),
                                                ),
                                              ),
                                            ),

                                            // Minor achievement rows (BELOW divider)
                                            for (
                                              int i = 0;
                                              i <
                                                  widget
                                                      .effectiveMinorRows
                                                      .length;
                                              i++
                                            ) ...[
                                              if (i > 0)
                                                const SizedBox(height: 1),
                                              _buildNodeRow(
                                                widget.effectiveMinorRows[i],
                                                gs,
                                                theme,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Dynamic Hover Tooltip Overlay Card
                                  if (_hoveredAchievement != null) ...[
                                    () {
                                      final item = _hoveredAchievement!;
                                      final status = gs.getAchievementStatus(
                                        item.id,
                                      );
                                      final isStageLocked =
                                          status == AchievementStatus.locked &&
                                          item.checkIfLocked(gs) &&
                                          !widget.isDevMode;

                                      if (isStageLocked) {
                                        return const SizedBox.shrink();
                                      }

                                      // Determine row and index position for tooltip placement
                                      final majorRows =
                                          widget.effectiveMajorRows;
                                      final minorRows =
                                          widget.effectiveMinorRows;
                                      bool isMajor = false;
                                      int rowIndex = 0;
                                      int itemIndex = 0;
                                      int rowLength = 6;

                                      for (
                                        int r = 0;
                                        r < majorRows.length;
                                        r++
                                      ) {
                                        final idx = majorRows[r].indexWhere(
                                          (a) => a.id == item.id,
                                        );
                                        if (idx != -1) {
                                          isMajor = true;
                                          rowIndex = r;
                                          itemIndex = idx;
                                          rowLength = majorRows[r].length;
                                          break;
                                        }
                                      }
                                      if (!isMajor) {
                                        for (
                                          int r = 0;
                                          r < minorRows.length;
                                          r++
                                        ) {
                                          final idx = minorRows[r].indexWhere(
                                            (a) => a.id == item.id,
                                          );
                                          if (idx != -1) {
                                            rowIndex = r;
                                            itemIndex = idx;
                                            rowLength = minorRows[r].length;
                                            break;
                                          }
                                        }
                                      }

                                      final isLeftHalf =
                                          itemIndex < (rowLength / 2);
                                      // Top half consists of Major rows (0, 1) and Minor row 0.
                                      // Minor rows 1, 2, 3, 4 are in the lower half and show their tooltip at the top.
                                      final isTopHalf =
                                          isMajor || rowIndex == 0;

                                      return Positioned(
                                        left: isLeftHalf ? null : 16,
                                        right: isLeftHalf ? 16 : null,
                                        top: isTopHalf ? null : 16,
                                        bottom: isTopHalf ? 16 : null,
                                        child: _AchievementHoverTooltip(
                                          achievement: item,
                                          status: status,
                                          gameState: gs,
                                        ),
                                      );
                                    }(),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Achievement Node Tile Widget ───────────────────────────────────────────

class _AchievementNodeWidget extends StatefulWidget {
  final AchievementConfig achievement;
  final AchievementStatus status;
  final bool isDevMode;
  final GameStateManager gameState;
  final VoidCallback onTap;
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;

  const _AchievementNodeWidget({
    required this.achievement,
    required this.status,
    required this.isDevMode,
    required this.gameState,
    required this.onTap,
    required this.onHoverEnter,
    required this.onHoverExit,
  });

  @override
  State<_AchievementNodeWidget> createState() => _AchievementNodeWidgetState();
}

class _AchievementNodeWidgetState extends State<_AchievementNodeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shockwaveController;
  late final Animation<double> _shockwaveAnimation;

  @override
  void initState() {
    super.initState();
    _shockwaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _shockwaveAnimation = CurvedAnimation(
      parent: _shockwaveController,
      curve: Curves.easeOutExpo,
    );

    if (widget.status == AchievementStatus.unlocked) {
      _shockwaveController.repeat();
    }
  }

  @override
  void didUpdateWidget(_AchievementNodeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isUnlocked = widget.status == AchievementStatus.unlocked;
    if (isUnlocked && !_shockwaveController.isAnimating) {
      _shockwaveController.repeat();
    } else if (!isUnlocked && _shockwaveController.isAnimating) {
      _shockwaveController.stop();
      _shockwaveController.reset();
    }
  }

  @override
  void dispose() {
    _shockwaveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final achievement = widget.achievement;
    final status = widget.status;
    final isDevMode = widget.isDevMode;
    final gameState = widget.gameState;
    final onTap = widget.onTap;
    final onHoverEnter = widget.onHoverEnter;
    final onHoverExit = widget.onHoverExit;
    final theme = Theme.of(context);

    final isUnlocked = status == AchievementStatus.unlocked;
    final isCollected = status == AchievementStatus.collected;
    final isStageLocked =
        status == AchievementStatus.locked &&
        achievement.checkIfLocked(gameState) &&
        !isDevMode;

    // Solid Background Colors matching skill tree style
    final nodeBgColor = isUnlocked
        ? const Color(0xFF4A2B00) // Dark golden bronze for claimable
        : isCollected
        ? const Color(0xFF231911)
        : isStageLocked
        ? theme
              .colorScheme
              .surfaceContainer // Dimmer dark grey for locked nodes (same as locked skill nodes)
        : theme
              .colorScheme
              .surfaceContainerHighest; // Lighter grey for visible not-yet-unlocked nodes

    final borderColor = isUnlocked
        ? Colors.amber.shade400
        : isCollected
        ? AppColors.amberMedium
        : isStageLocked
        ? AppColors.outlineMedium
        : AppColors.outlineMedium;

    final iconColor = isUnlocked
        ? Colors.amber.shade300
        : isCollected
        ? Colors.amber.shade300
        : isStageLocked
        ? AppColors.textDim
        : AppColors.textMedium;

    return SizedBox(
      width: 68,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // ── Golden Shockwave (Claimable Unlocked Achievements, rotated 45 degrees) ──
          if (isUnlocked)
            Transform.rotate(
              angle: math.pi / 4,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _shockwaveAnimation,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _AchievementNodeShockwavePainter(
                        progress: _shockwaveAnimation.value,
                        color: AppColors.warning,
                        cornerRadius: achievement.isUltimate ? 14.0 : 10.0,
                        nodeSize: achievement.isUltimate ? 52.0 : 44.0,
                      ),
                    );
                  },
                ),
              ),
            ),

          // ── Layer 1 (Ultimate Only): Larger 45-degree tilted diamond behind ──
          if (achievement.isUltimate)
            Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: borderColor,
                    width: isUnlocked ? 2.0 : 1.5,
                  ),
                  boxShadow: isUnlocked
                      ? [
                          BoxShadow(
                            color: AppColors.amberBright,
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
            ),

          // ── Layer 2 (Legendary & Ultimate): Upright 0-degree rectangular container ──
          if (achievement.isLegendary)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: borderColor,
                  width: isUnlocked ? 2.0 : 1.5,
                ),
              ),
            ),

          // ── Layer 3: Main 45-degree rotated diamond body & hit-test area ──
          Transform.rotate(
            angle: math.pi / 4,
            child: MouseRegion(
              onEnter: (_) => onHoverEnter(),
              onExit: (_) => onHoverExit(),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: nodeBgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: borderColor,
                      width: isUnlocked ? 2.0 : 1.5,
                    ),
                    boxShadow: isUnlocked
                        ? [
                            BoxShadow(
                              color: AppColors.amberMedium,
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ),

          // ── Layer 4: Content (Icon + Unclaimed Reward Badge) ──
          IgnorePointer(
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: isStageLocked
                      ? Icon(
                          Icons.lock_outline_rounded,
                          size: 16,
                          color: iconColor,
                        )
                      : achievement.imageAsset != null
                      ? EmbeddedAssets.getImage(
                          achievement.imageAsset!,
                          width: achievement.isUltimate ? 22 : 20,
                          height: achievement.isUltimate ? 22 : 20,
                          color: iconColor,
                        )
                      : Icon(
                          achievement.icon,
                          size: achievement.isUltimate ? 22 : 20,
                          color: iconColor,
                        ),
                ),

                // Unclaimed Reward Badge (Bottom-Center)
                if (isUnlocked)
                  Positioned(
                    bottom: -7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: achievement.tokenMultiplier != null
                              ? Colors.pink.shade400
                              : Colors.amber.shade400,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.60),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: achievement.rewardString != null
                          ? AnimatedRewardText(
                              text: achievement.rewardString!,
                              fontSize: 10,
                            )
                          : Text(
                              achievement.tokenMultiplier != null
                                  ? '×${achievement.tokenMultiplier!.toCleverString()}'
                                  : '+${achievement.tokenReward}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: achievement.tokenMultiplier != null
                                    ? Colors.pink.shade400
                                    : Colors.amber.shade400,
                                height: 1.2,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementNodeShockwavePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double cornerRadius;
  final double nodeSize;

  _AchievementNodeShockwavePainter({
    required this.progress,
    required this.color,
    required this.cornerRadius,
    required this.nodeSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    ShockwaveUtil.drawShockwave(
      canvas,
      size,
      progress,
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: nodeSize,
        height: nodeSize,
      ),
      color: color,
      maxExpansion: 16.0,
      cornerRadius: cornerRadius,
      strokeWidth: 2.0,
      fadeCurve: 1.8,
    );
  }

  @override
  bool shouldRepaint(covariant _AchievementNodeShockwavePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.cornerRadius != cornerRadius ||
      oldDelegate.nodeSize != nodeSize;
}

// ── Hover Tooltip Card Overlay ─────────────────────────────────────────────

class _AchievementHoverTooltip extends StatelessWidget {
  final AchievementConfig achievement;
  final AchievementStatus status;
  final GameStateManager gameState;

  const _AchievementHoverTooltip({
    required this.achievement,
    required this.status,
    required this.gameState,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isUnlocked = status == AchievementStatus.unlocked;
    final isCollected = status == AchievementStatus.collected;

    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panelSolid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked || isCollected
              ? Colors.amber.shade400
              : AppColors.outlineMedium,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.60),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title & Icon
          Row(
            children: [
              achievement.imageAsset != null
                  ? EmbeddedAssets.getImage(
                      achievement.imageAsset!,
                      width: 18,
                      height: 18,
                      color: achievement.isLegendary
                          ? Colors.amber
                          : theme.colorScheme.primary,
                    )
                  : Icon(
                      achievement.icon,
                      size: 18,
                      color: achievement.isLegendary
                          ? Colors.amber
                          : theme.colorScheme.primary,
                    ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  achievement.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Rarity & Reward Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                achievement.isLegendary ? 'Legendary' : 'Common',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: achievement.isLegendary
                      ? Colors.amber.shade400
                      : theme.colorScheme.primary,
                ),
              ),
              if (achievement.rewardString != null)
                AnimatedRewardText(
                  text: achievement.rewardString!,
                  fontSize: 11,
                )
              else if (achievement.tokenMultiplier != null)
                Text(
                  '×${achievement.tokenMultiplier!.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink.shade400,
                  ),
                )
              else
                Row(
                  children: [
                    const Icon(Icons.token, size: 12, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '+${achievement.tokenReward}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          const Divider(height: 12),

          // Game Label Tag (shown if achievement is linked to a game)
          if (achievement.linkedStage != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.secContainerMedium,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.secondaryMedium),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    achievement.linkedStage!.displayName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Description / Condition
          Text(
            getFormattedAchievementDescription(achievement, gameState),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textBright,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 8),

          // Action Status Hint
          // Action Status Hint
          isUnlocked && achievement.rewardString != null
              ? AnimatedRewardText(
                  text: 'Click to claim ${achievement.rewardString}!',
                  fontSize: 10,
                )
              : Text(
                  isUnlocked
                      ? achievement.tokenMultiplier != null
                            ? 'Click to apply ×${achievement.tokenMultiplier!.toStringAsFixed(2)} multiplier!'
                            : 'Click to claim ${achievement.tokenReward} tokens!'
                      : isCollected
                      ? 'Reward Claimed'
                      : 'Locked',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isUnlocked
                        ? Colors.amber.shade400
                        : isCollected
                        ? Colors.green
                        : Colors.grey.shade500,
                  ),
                ),
        ],
      ),
    );
  }
}
