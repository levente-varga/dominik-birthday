import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../game_registry.dart';
import '../game_state.dart';
import '../widgets/anomaly_background.dart';
import '../widgets/confirm_popup.dart';
import '../generated/embedded_assets.dart';

/// Test screen for practicing an individual game without affecting run state.
class TestStageScreen extends StatefulWidget {
  final int stageNumber;
  final GameStateManager gameState;
  final bool isDevMode;

  const TestStageScreen({
    super.key,
    required this.stageNumber,
    required this.gameState,
    this.isDevMode = false,
  });

  @override
  State<TestStageScreen> createState() => _TestStageScreenState();
}

class _TestStageScreenState extends State<TestStageScreen>
    with SingleTickerProviderStateMixin {
  int _gameKey = 0;
  bool _isTransitioning = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    widget.gameState.isPracticeMode = true;
    widget.gameState.isCurrentGameAnomaly = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (!widget.gameState.statistics.hasSeenPracticeInfo) {
          widget.gameState.markPracticeInfoSeen();
          showOkPopup(
            context,
            title: 'Practice Mode',
            icon: Icons.fitness_center_rounded,
            iconColor: AppColors.practiceBadgeText,
            body:
                'In practice mode, no tokens, progression, statistics, or achievements can be collected, but skill effects apply.',
          );
        }
      }
    });

    // 250ms fade out -> swap game -> 250ms fade in (500ms total transition)
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    widget.gameState.isPracticeMode = false;
    widget.gameState.isCurrentGameAnomaly = false;
    _fadeController.dispose();
    super.dispose();
  }

  void _toggleAnomaly() {
    if (!mounted || _isTransitioning) return;

    setState(() {
      _isTransitioning = true;
    });

    _fadeController.forward().then((_) {
      if (!mounted) return;
      widget.gameState.isCurrentGameAnomaly =
          !widget.gameState.isCurrentGameAnomaly;
      setState(() {
        _gameKey++;
      });
      _fadeController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isTransitioning = false;
          });
        }
      });
    });
  }

  void _handleStageEnd() {
    if (!mounted || _isTransitioning) return;

    setState(() {
      _isTransitioning = true;
    });

    _fadeController.forward().then((_) {
      if (!mounted) return;
      setState(() {
        _gameKey++;
      });
      _fadeController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isTransitioning = false;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final game = GameRegistry.getStage(widget.stageNumber);

    return AnomalyBackgroundWidget(
      key: ValueKey('test_anomaly_bg_$_gameKey'),
      isEnabled: widget.gameState.isCurrentGameAnomaly,
      child: Scaffold(
        backgroundColor: AppColors.transparent,
        body: Stack(
          children: [
            if (widget.gameState.isCurrentGameAnomaly)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 140,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        // Left: Back button aligned left
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  backgroundColor:
                                      AppColors.headerButtonBackground,
                                  side: BorderSide(
                                    color: AppColors.headerButtonBorder,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Icon(
                                  Icons.arrow_back_rounded,
                                  size: 16,
                                  color: AppColors.headerButtonIcon,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Center: Practice mode Badge centered
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: widget.gameState.isPracticeMode
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.practiceBadgeBorder,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.fitness_center_rounded,
                                          size: 16,
                                          color: AppColors.practiceBadgeText,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Practice mode',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.practiceBadgeText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),

                        // Right: Action buttons aligned right
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Toggle Anomaly Button (visible in dev mode, or if practice_anomalies skill is unlocked and stage anomaly was encountered)
                                if (widget.isDevMode ||
                                    widget.gameState.isDevMode ||
                                    (widget.gameState.isSkillUnlocked(
                                          'practice_anomalies',
                                        ) &&
                                        widget.gameState.hasEncounteredAnomaly(
                                          widget.stageNumber,
                                        ))) ...[
                                  SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: OutlinedButton(
                                      onPressed: _isTransitioning
                                          ? null
                                          : _toggleAnomaly,
                                      style: OutlinedButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        backgroundColor:
                                            AppColors.headerButtonBackground,
                                        side: BorderSide(
                                          color:
                                              widget
                                                      .gameState
                                                      .isCurrentGameAnomaly
                                                  ? AppColors.anomalyBadgeText
                                                  : AppColors.headerButtonBorder,
                                          width: 1.5,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: EmbeddedAssets.getImage(
                                        'assets/icons/skull.png',
                                        width: 16,
                                        height: 16,
                                        color:
                                            widget
                                                    .gameState
                                                    .isCurrentGameAnomaly
                                                ? AppColors.anomalyBadgeText
                                                : AppColors.headerButtonIcon,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                // Manual Restart Level Button matching Back button styling
                                SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: OutlinedButton(
                                    onPressed: _isTransitioning
                                        ? null
                                        : _handleStageEnd,
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      backgroundColor:
                                          AppColors.headerButtonBackground,
                                      side: BorderSide(
                                        color: AppColors.headerButtonBorder,
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.refresh_rounded,
                                      size: 16,
                                      color: AppColors.headerButtonIcon,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: KeyedSubtree(
                        key: ValueKey(_gameKey),
                        child: Center(
                          child: game.buildGame(
                            context: context,
                            onComplete: _handleStageEnd,
                            onFail: _handleStageEnd,
                            gameState: widget.gameState,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
