import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/colors.dart';

import '../config/achievement_config.dart';
import '../game_state.dart';
import 'animated_reward_text.dart';
import '../generated/embedded_assets.dart';

/// Global overlay widget that listens for achievement unlock events and displays
/// a glowing gold toast notification across the entire application, prevailing
/// over scene changes, routes, and menu transitions.
class GlobalAchievementOverlay extends StatefulWidget {
  final GameStateManager gameState;
  final Widget child;

  const GlobalAchievementOverlay({
    super.key,
    required this.gameState,
    required this.child,
  });

  @override
  State<GlobalAchievementOverlay> createState() =>
      _GlobalAchievementOverlayState();
}

class _GlobalAchievementOverlayState extends State<GlobalAchievementOverlay>
    with SingleTickerProviderStateMixin {
  StreamSubscription<AchievementConfig>? _subscription;
  StreamSubscription<bool>? _pauseSubscription;
  final List<AchievementConfig> _queue = [];
  AchievementConfig? _currentAchievement;
  bool _isProcessing = false;

  late final AnimationController _animController;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _slideAnimation = Tween<double>(begin: -100.0, end: 32.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCirc,
        reverseCurve: Curves.easeOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    _subscription = widget.gameState.onAchievementUnlocked.listen((
      achievement,
    ) {
      _queue.add(achievement);
      if (!_isProcessing && !widget.gameState.isAchievementOverlayPaused) {
        _processQueue();
      }
    });

    _pauseSubscription = widget.gameState.onAchievementQueuePauseChanged.listen(
      (isPaused) {
        if (isPaused) {
          _pauseAndDiscardCurrent();
        } else {
          if (!_isProcessing && _queue.isNotEmpty) {
            _processQueue();
          }
        }
      },
    );
  }

  AchievementConfig? _discardingAchievement;

  void _pauseAndDiscardCurrent() {
    _dismissTimer?.cancel();
    _dismissTimer = null;

    if (_currentAchievement != null) {
      final toastToRequeue = _currentAchievement!;
      _currentAchievement = null;
      _discardingAchievement = toastToRequeue;
      // Re-insert at the front of the queue so it is preserved
      _queue.insert(0, toastToRequeue);

      // Play slide-out and fade-out smoothly
      _animController.reverse().then((_) {
        if (!mounted) return;
        setState(() {
          _discardingAchievement = null;
          _isProcessing = false;
        });
      });
    } else if (_discardingAchievement != null) {
      _animController.reverse();
    } else {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _processQueue() {
    if (widget.gameState.isAchievementOverlayPaused) {
      return;
    }

    if (_queue.isEmpty) {
      setState(() {
        _isProcessing = false;
        _currentAchievement = null;
      });
      return;
    }

    _isProcessing = true;
    setState(() {
      _currentAchievement = _queue.removeAt(0);
    });

    _animController.forward(from: 0.0);

    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(milliseconds: 4180), () {
      if (!mounted) return;
      if (widget.gameState.isAchievementOverlayPaused) {
        _pauseAndDiscardCurrent();
        return;
      }
      _animController.reverse().then((_) {
        if (!mounted) return;
        if (widget.gameState.isAchievementOverlayPaused) {
          _pauseAndDiscardCurrent();
          return;
        }
        // Brief 100ms pause between queued toasts for visual polish
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;
          if (!widget.gameState.isAchievementOverlayPaused) {
            _processQueue();
          } else {
            setState(() {
              _isProcessing = false;
              _currentAchievement = null;
            });
          }
        });
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pauseSubscription?.cancel();
    _dismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeToast = _currentAchievement ?? _discardingAchievement;

    return Stack(
      children: [
        // Main Application View (Navigator / Routes / Screens)
        widget.child,

        // Global Achievement Toast Overlay (Sits ABOVE all screens)
        if (activeToast != null)
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Positioned(
                top: _slideAnimation.value,
                left: 0,
                right: 0,
                child: Center(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Material(
                      type: MaterialType.transparency,
                      child: _AchievementToastWidget(
                        key: ValueKey(activeToast.id),
                        achievement: activeToast,
                        gameState: widget.gameState,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _AchievementToastWidget extends StatefulWidget {
  final AchievementConfig achievement;
  final GameStateManager gameState;

  const _AchievementToastWidget({
    super.key,
    required this.achievement,
    required this.gameState,
  });

  @override
  State<_AchievementToastWidget> createState() =>
      _AchievementToastWidgetState();
}

class _AchievementToastWidgetState extends State<_AchievementToastWidget>
    with TickerProviderStateMixin {
  late final AnimationController _flareController;
  late final Animation<double> _flareAnim;

  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerProgress;

  @override
  void initState() {
    super.initState();

    _flareController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _flareAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _flareController, curve: Curves.easeOutQuad),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _shimmerProgress = Tween<double>(begin: 0.1, end: 0.8).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInExpo),
    );

    // Trigger golden flare burst right as the toast lands on screen (200ms)
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _flareController.forward();
      }
    });

    // Trigger golden shimmer sweep almost immediately (150ms)
    Future.delayed(const Duration(milliseconds: 0), () {
      if (mounted) {
        _shimmerController.forward();
      }
    });
  }

  @override
  void dispose() {
    _flareController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flareAnim,
      builder: (context, child) {
        final flare = _flareAnim.value;
        final blur =
            16.0 + (flare * 36.0); // 52px flare burst -> 16px steady glow
        final spread =
            2.0 + (flare * 10.0); // 12px flare burst -> 2px steady glow
        final alpha =
            0.40 + (flare * 0.55); // 0.95 flare burst -> 0.40 steady glow

        return Container(
          width: 370,
          decoration: BoxDecoration(
            color: const Color(0xFF14120B), // Dark obsidian theme
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.warning.withValues(alpha: alpha),
                blurRadius: blur,
                spreadRadius: spread,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.80),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Inner Toast Content
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      // Gold Icon or Image Asset
                      if (widget.achievement.imageAsset != null)
                        EmbeddedAssets.getImage(
                          widget.achievement.imageAsset!,
                          width: 26,
                          height: 26,
                          color: Colors.amber.shade300,
                        )
                      else if (widget.achievement.icon != null)
                        Icon(
                          widget.achievement.icon,
                          color: Colors.amber.shade300,
                          size: 26,
                        ),
                      const SizedBox(width: 12),

                      // Achievement Details
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.achievement.title,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              getFormattedAchievementDescription(
                                widget.achievement,
                                widget.gameState,
                              ),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Reward Badge (Skill Tree Header style)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.achievement.rewardString != null
                                ? const Color(0xFFEF5350)
                                : widget.achievement.tokenMultiplier != null
                                ? AppColors.pinkMedium
                                : AppColors.amberDim,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.achievement.tokenMultiplier == null &&
                                widget.achievement.rewardString == null) ...[
                              const Icon(
                                Icons.token,
                                size: 16,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (widget.achievement.rewardString != null)
                              AnimatedRewardText(
                                text: widget.achievement.rewardString!,
                                fontSize: 12,
                              )
                            else
                              Text(
                                widget.achievement.tokenMultiplier != null
                                    ? '×${widget.achievement.tokenMultiplier!.toStringAsFixed(2)}'
                                    : '+${widget.achievement.tokenReward}',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      widget.achievement.tokenMultiplier != null
                                      ? Colors.pink.shade400
                                      : Colors.amber.shade400,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Golden Shimmer Sweep Highlight Overlay
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _shimmerProgress,
                    builder: (context, child) {
                      final p = _shimmerProgress.value;
                      return IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment(-2.5 + p * 4.0, -0.8),
                              end: Alignment(-1.0 + p * 4.0, 0.8),
                              colors: [
                                AppColors.transparent,
                                AppColors.shineAmber,
                                AppColors.shineWhite,
                                AppColors.shineAmber,
                                AppColors.transparent,
                              ],
                              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
