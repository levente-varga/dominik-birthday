import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/sizes.dart';
import '../game_state.dart';

/// Standardized layout scaffold used by all games.
/// Places a uniform top header card (timer badge + game status/icon)
/// directly above the centered game content.
///
/// Uses [IntrinsicWidth] and [CrossAxisAlignment.stretch] so the header card
/// automatically stretches to match the EXACT width of the game content.
class GameScaffold extends StatelessWidget {
  final GameStateManager gameState;
  final Widget child;
  final Widget? headerTitle;
  final Widget? debugHeader;
  final double spacing;
  final bool isScrollable;
  final bool showHeader;

  const GameScaffold({
    super.key,
    required this.gameState,
    required this.child,
    this.headerTitle,
    this.debugHeader,
    this.spacing = AppSizes.spacingLg,
    this.isScrollable = false,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final showDebugHeader = gameState.isDevMode && debugHeader != null;

    final content = IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Dev Debug Header Card (ONLY visible when Dev Mode is ON) ───
          if (showDebugHeader) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spacingMd,
                vertical: AppSizes.spacingSm + 2,
              ),
              margin: EdgeInsets.only(bottom: spacing),
              decoration: BoxDecoration(
                color: AppColors.amberDim,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                border: Border.all(
                  color: AppColors.amberBright,
                  width: AppSizes.borderStandard,
                ),
              ),
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Colors.amberAccent,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [Flexible(child: debugHeader!)],
                ),
              ),
            ),
          ],

          // ── Info Header Card ───────────────────────────────────────────
          if (showHeader && headerTitle != null) ...[
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spacingLg,
              ),
              decoration: BoxDecoration(
                color: AppColors.panelHigh,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                border: Border.all(
                  color: AppColors.outlineDim,
                  width: AppSizes.borderStandard,
                ),
              ),
              alignment: Alignment.center,
              child: headerTitle!,
            ),
            SizedBox(height: spacing),
          ],

          // ── Game Content ───────────────────────────────────────────────
          child,
        ],
      ),
    );

    if (isScrollable) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.spacingSm),
          child: content,
        ),
      );
    }

    return Center(
      child: content,
    );
  }
}
