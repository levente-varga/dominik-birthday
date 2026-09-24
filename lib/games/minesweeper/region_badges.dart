import 'package:flutter/material.dart';

import '../../config/config.dart';
import '../../constants/colors.dart';

// ── Region Mine Counter Badge ────────────────────────────────────────────────

class RegionMineCounterBadge extends StatelessWidget {
  final int? remainingMines;
  final bool isVertical;

  const RegionMineCounterBadge({
    super.key,
    this.remainingMines,
    this.isVertical = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isVertical) {
      return Container(
        key: const ValueKey('region_mine_counter_badge'),
        width: MinesweeperConfig.headerButtonSize,
        padding: const EdgeInsets.symmetric(
          vertical: 4.0,
          horizontal: 2.0,
        ),
        decoration: BoxDecoration(
          color: AppColors.panelDim,
          borderRadius: BorderRadius.circular(MinesweeperConfig.headerControlRadius),
          border: Border.all(
            color: AppColors.outlineDim,
            width: MinesweeperConfig.headerControlBorderWidth,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              MinesweeperConfig.mineCounterIcon,
              size: MinesweeperConfig.mineCounterIconSize,
              color: MinesweeperConfig.mineCounterIconColor,
            ),
            const SizedBox(height: 2.0),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                remainingMines != null ? '$remainingMines' : '?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: MinesweeperConfig.mineCounterFontSize,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBright,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const ValueKey('region_mine_counter_badge'),
      height: MinesweeperConfig.headerBadgeHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: MinesweeperConfig.mineCounterHorizontalPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.panelDim,
        borderRadius: BorderRadius.circular(MinesweeperConfig.headerControlRadius),
        border: Border.all(
          color: AppColors.outlineDim,
          width: MinesweeperConfig.headerControlBorderWidth,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            MinesweeperConfig.mineCounterIcon,
            size: MinesweeperConfig.mineCounterIconSize,
            color: MinesweeperConfig.mineCounterIconColor,
          ),
          const SizedBox(width: MinesweeperConfig.mineCounterGap),
          Text(
            remainingMines != null ? '$remainingMines' : '?',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: MinesweeperConfig.mineCounterFontSize,
              fontWeight: FontWeight.bold,
              color: AppColors.textBright,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Region Rank Badge ────────────────────────────────────────────────────────

class RegionRankBadge extends StatelessWidget {
  final int rank;
  final bool isVertical;

  const RegionRankBadge({
    super.key,
    required this.rank,
    this.isVertical = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isVertical) {
      return Container(
        key: const ValueKey('region_rank_badge'),
        width: MinesweeperConfig.headerButtonSize,
        padding: const EdgeInsets.symmetric(
          vertical: 4.0,
          horizontal: 2.0,
        ),
        decoration: BoxDecoration(
          color: AppColors.panelDim,
          borderRadius: BorderRadius.circular(MinesweeperConfig.headerControlRadius),
          border: Border.all(
            color: AppColors.outlineDim,
            width: MinesweeperConfig.headerControlBorderWidth,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              MinesweeperConfig.rankIcon,
              size: MinesweeperConfig.rankBadgeIconSize,
              color: MinesweeperConfig.rankIconColor,
            ),
            const SizedBox(height: 2.0),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${MinesweeperConfig.rankPrefix}$rank',
                key: const ValueKey('region_rank_text'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: MinesweeperConfig.rankBadgeFontSize,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBright,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const ValueKey('region_rank_badge'),
      height: MinesweeperConfig.headerBadgeHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: MinesweeperConfig.mineCounterHorizontalPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.panelDim,
        borderRadius: BorderRadius.circular(MinesweeperConfig.headerControlRadius),
        border: Border.all(
          color: AppColors.outlineDim,
          width: MinesweeperConfig.headerControlBorderWidth,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            MinesweeperConfig.rankIcon,
            size: MinesweeperConfig.rankBadgeIconSize,
            color: MinesweeperConfig.rankIconColor,
          ),
          const SizedBox(width: MinesweeperConfig.mineCounterGap),
          Text(
            '${MinesweeperConfig.rankPrefix}$rank',
            key: const ValueKey('region_rank_text'),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: MinesweeperConfig.rankBadgeFontSize,
              fontWeight: FontWeight.bold,
              color: AppColors.textBright,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Region Pause Button ──────────────────────────────────────────────────────

class RegionPauseButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isGameOver;

  const RegionPauseButton({
    super.key,
    this.onTap,
    this.isGameOver = false,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: ValueKey(isGameOver ? 'region_home_button' : 'region_pause_button'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: MinesweeperConfig.headerButtonSize,
          height: MinesweeperConfig.headerButtonSize,
          decoration: BoxDecoration(
            color: AppColors.panelDim,
            borderRadius: BorderRadius.circular(MinesweeperConfig.headerControlRadius),
            border: Border.all(
              color: AppColors.outlineDim,
              width: MinesweeperConfig.headerControlBorderWidth,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            isGameOver ? Icons.home_rounded : Icons.pause_rounded,
            size: isGameOver
                ? MinesweeperConfig.homeButtonIconSize
                : MinesweeperConfig.pauseButtonIconSize,
            color: AppColors.textBright,
          ),
        ),
      ),
    );
  }
}

// ── Empty Corner Button ──────────────────────────────────────────────────────

class EmptyCornerButton extends StatelessWidget {
  const EmptyCornerButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MinesweeperConfig.headerButtonSize,
      height: MinesweeperConfig.headerButtonSize,
      decoration: BoxDecoration(
        color: AppColors.panelDim,
        borderRadius:
            BorderRadius.circular(MinesweeperConfig.headerControlRadius),
        border: Border.all(
          color: AppColors.outlineDim,
          width: MinesweeperConfig.headerControlBorderWidth,
        ),
      ),
    );
  }
}

