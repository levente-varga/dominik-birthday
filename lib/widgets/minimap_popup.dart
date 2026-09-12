import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// Shows an empty popup matching the styling of main menu popups.
void showMinimapPopup(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Minimap',
    barrierColor: AppColors.overlayBarrier,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const MinimapPopup();
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

/// Empty popup dialog matching Main Menu popup styling.
class MinimapPopup extends StatelessWidget {
  const MinimapPopup({super.key});

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
                        side: const BorderSide(
                          color: AppColors.outlineDim,
                          width: 1.5,
                        ),
                        shape: const CircleBorder(),
                      ),
                    ),
                  ),
                ),
              ),

              // Main Popup Container (empty body matching main menu popups)
              Container(
                key: const ValueKey('minimap_popup_container'),
                width: double.infinity,
                height: 480,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.outlineMedium,
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.overlayBarrier,
                      blurRadius: 32,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
