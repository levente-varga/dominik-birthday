import 'package:flutter/material.dart';
import '../constants/colors.dart';
import 'shockwave_layer.dart';

/// Styled menu button matching the main menu design, size, and layout.
class MenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool showYellowDot;
  final double size;
  final double? iconSize;

  const MenuButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.showYellowDot = false,
    this.size = 48.0,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final contentColor = isEnabled ? AppColors.textBright : AppColors.textDim;

    final buttonWidget = SizedBox(
      width: size,
      height: size,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.panelMedium,
          foregroundColor: contentColor,
          padding: EdgeInsets.zero,
          side: const BorderSide(color: AppColors.outlineDim, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(size * 0.25),
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            size: iconSize ?? (size * 0.45),
            color: contentColor,
          ),
        ),
      ),
    );

    if (!showYellowDot) return buttonWidget;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        buttonWidget,
        const Positioned(top: -2, right: -2, child: PingingYellowDot(size: 12)),
      ],
    );
  }
}

/// Standalone pinging yellow notification dot with shockwave pulse effect.
class PingingYellowDot extends StatefulWidget {
  final double size;
  const PingingYellowDot({super.key, this.size = 12.0});

  @override
  State<PingingYellowDot> createState() => _PingingYellowDotState();
}

class _PingingYellowDotState extends State<PingingYellowDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shockwaveController;
  late final Animation<double> _shockwaveAnimation;

  @override
  void initState() {
    super.initState();
    _shockwaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    _shockwaveAnimation = CurvedAnimation(
      parent: _shockwaveController,
      curve: Curves.easeOutExpo,
    );
  }

  @override
  void dispose() {
    _shockwaveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _shockwaveAnimation,
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _MenuButtonShockwavePainter(
                progress: _shockwaveAnimation.value,
                color: AppColors.warning,
              ),
            ),
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.surface,
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.amberBright,
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Faint mockup border container for reserved space of hidden menu buttons.
class MenuButtonMockup extends StatelessWidget {
  final double size;

  const MenuButtonMockup({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.panelDim,
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: AppColors.outlineDim, width: 1.5),
      ),
    );
  }
}

class _MenuButtonShockwavePainter extends CustomPainter {
  final double progress;
  final Color color;

  _MenuButtonShockwavePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    ShockwaveUtil.drawShockwave(
      canvas,
      size,
      progress,
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: 0, // dot emits from the center outward
        height: 0,
      ),
      color: color,
      maxExpansion: 12.0,
      cornerRadius: 999.0,
      strokeWidth: 2.5,
      fadeCurve: 2.0,
    );
  }

  @override
  bool shouldRepaint(covariant _MenuButtonShockwavePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
