import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../generated/embedded_assets.dart';

/// Shows the special victory reward popup that triggers at the very end
/// of the completionist slot flip animation.
void showCompletionistRewardPopup(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Completionist Reward',
    barrierColor: AppColors.overlayBarrier,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return const _CompletionistRewardPopup();
    },
    transitionBuilder: (ctx, animation, _, child) {
      final scaleAnimation = Tween<double>(
        begin: 0.92,
        end: 1.0,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
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

class _CompletionistRewardPopup extends StatefulWidget {
  const _CompletionistRewardPopup();

  @override
  State<_CompletionistRewardPopup> createState() =>
      _CompletionistRewardPopupState();
}

class _CompletionistRewardPopupState extends State<_CompletionistRewardPopup> {
  int _secondsRemaining = 3;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        setState(() {
          _secondsRemaining = 0;
        });
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isButtonEnabled = _secondsRemaining <= 0;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 480,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.amberMedium, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: AppColors.amberBright,
                blurRadius: 32,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: AppColors.overlayBarrier,
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 1. Top Row: Game Header Image (spider.jpg) ───────────────
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: EmbeddedAssets.getImage(
                    'assets/images/spider.jpg',
                    fit: BoxFit.cover,
                  ),
                ),

                // ── 2. Mid Row: Text (Placeholder) ───────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 22, 28, 18),
                  child: Text(
                    'Nagyon boldog születésnapot és lengedezést kívánunk!\n\nLevi a Tán és Hominik',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textBright,
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // ── 3. Bottom Row: Single "wohooo!" Button (3s Lockout) ──────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                  child: Center(
                    child: SizedBox(
                      height: 38,
                      child: OutlinedButton(
                        onPressed: isButtonEnabled
                            ? () => Navigator.of(context).pop()
                            : null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 36,
                            vertical: 0,
                          ),
                          minimumSize: Size.zero,
                          backgroundColor: isButtonEnabled
                              ? Color.lerp(
                                  AppColors.surface,
                                  Colors.amber,
                                  0.15,
                                )!
                              : AppColors.panelDim,
                          side: BorderSide(
                            color: isButtonEnabled
                                ? Colors.amber.shade400
                                : AppColors.outlineDim,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'wohooo!',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isButtonEnabled
                                ? Colors.amber.shade300
                                : AppColors.textDim,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
