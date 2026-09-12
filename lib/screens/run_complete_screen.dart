import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/colors.dart';

import '../game_state.dart';
import '../widgets/menu_button.dart';
import '../widgets/token_receipt_widget.dart';

/// Shown when the player successfully completes all stages in a run.
///
/// Reveals the newly unlocked activation-code character and provides
/// a button to return to the main menu.
class RunCompleteScreen extends StatefulWidget {
  final GameStateManager gameState;

  const RunCompleteScreen({super.key, required this.gameState});

  @override
  State<RunCompleteScreen> createState() => _RunCompleteScreenState();
}

class _RunCompleteScreenState extends State<RunCompleteScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.15, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gs = widget.gameState;
    final completedRun = gs.currentRun;
    final charIndex = (completedRun - 1).clamp(0, 14);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Trophy icon
                  Icon(
                    Icons.emoji_events_rounded,
                    size: 64,
                    color: Colors.amber.shade600,
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Run $completedRun Complete!',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Container Slots 3D Reveal Widget (plays only for current completed stage)
                  SlotRevealAnimationWidget(
                    unlockedKeyChars: gs.unlockedKeyChars,
                    charIndex: charIndex,
                  ),

                  const SizedBox(height: 24),

                  TokenReceiptWidget(
                    baseIncome: gs.runBaseIncome,
                    incomeSkillTokens: gs.runIncomeSkillTokens,
                    rewardSkillTokens: gs.runRewardSkillTokens,
                    accumulatorSkillTokens:
                        gs.runAccumulatorSkillTokens.floor(),
                    tokenMultiplier: gs.tokenMultiplier,
                    anomalyMultiplier: gs.anomalyMultiplier,
                    multipliedTotal: gs.runMultipliedTotal,
                  ),

                  const SizedBox(height: 28),

                  MenuButton(
                    label: gs.isGameComplete ? 'View Victory' : 'Continue',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () {
                      gs.resetRunState();
                      Navigator.of(context)
                          .popUntil((route) => route.isFirst);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 3D Container Slot Reveal Animation Widget ──────────────────────────────

class SlotRevealAnimationWidget extends StatefulWidget {
  final List<String?> unlockedKeyChars;
  final int charIndex;

  const SlotRevealAnimationWidget({
    super.key,
    required this.unlockedKeyChars,
    required this.charIndex,
  });

  @override
  State<SlotRevealAnimationWidget> createState() =>
      _SlotRevealAnimationWidgetState();
}

class _SlotRevealAnimationWidgetState extends State<SlotRevealAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _zoomAnim;
  late final Animation<double> _flipOutAnim;
  late final Animation<double> _flipInAnim;
  late final Animation<double> _darkeningAnim;

  late final double _targetX;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _zoomAnim = Tween<double>(begin: 1.0, end: 2.3).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.75, curve: Curves.easeInOutCubic),
      ),
    );

    _flipOutAnim = Tween<double>(begin: 0.0, end: math.pi / 2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.55, curve: Curves.easeInCirc),
      ),
    );

    _flipInAnim = Tween<double>(begin: -math.pi / 2, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.85, curve: Curves.easeOutCirc),
      ),
    );

    _darkeningAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.05, 0.35, curve: Curves.easeOutExpo),
      ),
    );

    // Calculate target center X for slot charIndex
    // 15 slots in 3 groups of 5 + 2 dashes
    // slot width = 15 + 2 = 17px, dash width = 8px
    // total row width = 15 * 17 + 2 * 8 = 271px (fits completely inside any card width)
    final idx = widget.charIndex.clamp(0, 14);
    if (idx < 5) {
      _targetX = idx * 17.0 + 8.5;
    } else if (idx < 10) {
      _targetX = 5 * 17.0 + 8.0 + (idx - 5) * 17.0 + 8.5;
    } else {
      _targetX = 10 * 17.0 + 16.0 + (idx - 10) * 17.0 + 8.5;
    }

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final isFlipped = _controller.value >= 0.55;
        final currentAngle = isFlipped ? _flipInAnim.value : _flipOutAnim.value;
        final currentScale = _zoomAnim.value;
        final zoomProgress = ((currentScale - 1.0) / 1.3).clamp(0.0, 1.0);

        // Translate target slot center (_targetX) to unscaled row center (135.5)
        const rowCenterX = 135.5;
        final deltaX = _targetX - rowCenterX;
        final translationX = -deltaX * currentScale * zoomProgress;

        final screenWidth = MediaQuery.of(context).size.width;

        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 360),
          height: 135,
          clipBehavior: Clip.none,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Zoomed Preview centered on target slot (overflows parent boundaries visually)
              Transform.translate(
                offset: Offset(translationX, 0.0),
                child: Transform.scale(
                  scale: currentScale,
                  child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Group 1 (slots 0..4)
                    for (int i = 0; i < 5; i++)
                      _buildSlotTile(i, isFlipped, currentAngle, theme),
                    const _DashSeparator(),
                    // Group 2 (slots 5..9)
                    for (int i = 5; i < 10; i++)
                      _buildSlotTile(i, isFlipped, currentAngle, theme),
                    const _DashSeparator(),
                    // Group 3 (slots 10..14)
                    for (int i = 10; i < 15; i++)
                      _buildSlotTile(i, isFlipped, currentAngle, theme),
                  ],
                ),
              ),
            ),

              // Soft Radial Vignette Overlay spanning edge-to-edge across the entire app screen
              OverflowBox(
                maxWidth: screenWidth,
                child: SizedBox(
                  width: screenWidth,
                  height: 135,
                  child: CustomPaint(
                    size: Size(screenWidth, 135),
                    painter: _RadialDarkeningOverlayPainter(
                      bgColor: theme.colorScheme.surface,
                      alpha: _darkeningAnim.value,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSlotTile(
      int index, bool isFlipped, double angle, ThemeData theme) {
    final isTarget = index == widget.charIndex;
    final bool slotUnlocked = isTarget
        ? isFlipped
        : (widget.unlockedKeyChars[index] != null || index < widget.charIndex);

    Widget tile = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 15,
      height: 23,
      margin: const EdgeInsets.symmetric(horizontal: 1.0),
      decoration: BoxDecoration(
        color: slotUnlocked
            ? AppColors.greenBright
            : AppColors.panelMedium,
        borderRadius: BorderRadius.circular(4.5),
        border: Border.all(
          color: slotUnlocked
              ? Colors.green
              : AppColors.outlineDim,
          width: 1.2,
        ),
        boxShadow: slotUnlocked
            ? [
                BoxShadow(
                  color: Colors.green.withValues(alpha: isTarget ? 0.6 : 0.3),
                  blurRadius: isTarget ? 8 : 4,
                  spreadRadius: isTarget ? 1.5 : 0.5,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: slotUnlocked
          ? const Icon(
              Icons.check_rounded,
              size: 10,
              color: Colors.white,
            )
          : null,
    );

    if (isTarget) {
      tile = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.003) // 3D Perspective projection
          ..rotateY(angle),
        child: tile,
      );
    }

    return tile;
  }
}

class _DashSeparator extends StatelessWidget {
  const _DashSeparator();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 8,
      child: Center(
        child: RepaintBoundary(
          child: Text(
            '–',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textDim,
            ),
          ),
        ),
      ),
    );
  }
}

class _RadialDarkeningOverlayPainter extends CustomPainter {
  final Color bgColor;
  final double alpha;

  _RadialDarkeningOverlayPainter({
    required this.bgColor,
    required this.alpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (alpha <= 0.001) return;

    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.35,
        colors: [
          AppColors.transparent,
          bgColor.withValues(alpha: 0.5 * alpha),
          bgColor.withValues(alpha: 1.0 * alpha),
        ],
        stops: const [0.35, 0.75, 1.0],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _RadialDarkeningOverlayPainter oldDelegate) =>
      true;
}
