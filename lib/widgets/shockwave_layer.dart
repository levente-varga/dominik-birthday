import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Centralized utility for drawing the standard game shockwave.
class ShockwaveUtil {
  /// Draws an expanding, fading hollow rounded-rect ring.
  static void drawShockwave(
    Canvas canvas,
    Size size,
    double progress,
    Rect baseRect, {
    required Color color,
    double maxExpansion = 14.0,
    double cornerRadius = 8.0,
    double strokeWidth = 2.5,
    double fadeCurve = 1.0,
  }) {
    final linearOpacity = (1.0 - progress).clamp(0.0, 1.0);
    final opacity = math.pow(linearOpacity, fadeCurve).toDouble();
    if (opacity == 0.0) return;

    // Curve the expansion with a deceleration so it feels punchy at the start
    final expansion =
        maxExpansion * (1.0 - (1.0 - progress) * (1.0 - progress));
    final inflatedRect = baseRect.inflate(expansion);

    final rrect = RRect.fromRectAndRadius(
      inflatedRect,
      Radius.circular(cornerRadius + expansion * 0.4),
    );

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawRRect(rrect, paint);
  }
}

/// A fire-and-forget shockwave configuration.
class ShockwaveConfig {
  final Rect rect;
  final Color color;
  final AnimationController controller;
  final double maxExpansion;
  final double cornerRadius;
  final double strokeWidth;
  final double fadeCurve;

  ShockwaveConfig({
    required this.rect,
    required this.color,
    required this.controller,
    this.maxExpansion = 14.0,
    this.cornerRadius = 8.0,
    this.strokeWidth = 2.5,
    this.fadeCurve = 3.0,
  });
}

/// A controller that lets external widgets trigger localized shockwaves.
class ShockwaveLayerController extends ChangeNotifier {
  final List<ShockwaveConfig> activeShockwaves = [];

  void addShockwave(ShockwaveConfig config) {
    activeShockwaves.add(config);
    config.controller.addListener(notifyListeners);
    config.controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        config.controller.removeListener(notifyListeners);
        activeShockwaves.remove(config);
        config.controller.dispose();
        notifyListeners();
      }
    });
    config.controller.forward();
    notifyListeners();
  }

  @override
  void dispose() {
    for (var sw in activeShockwaves) {
      sw.controller.dispose();
    }
    activeShockwaves.clear();
    super.dispose();
  }
}

/// Renders all active shockwaves for a given controller.
class ShockwaveLayer extends StatefulWidget {
  final ShockwaveLayerController controller;

  const ShockwaveLayer({super.key, required this.controller});

  @override
  State<ShockwaveLayer> createState() => _ShockwaveLayerState();
}

class _ShockwaveLayerState extends State<ShockwaveLayer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUpdate);
  }

  @override
  void didUpdateWidget(covariant ShockwaveLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onUpdate);
      widget.controller.addListener(_onUpdate);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.activeShockwaves.isEmpty) return const SizedBox();

    // By not using RepaintBoundary, we allow the shockwaves to spill over
    // and seamlessly overlap with adjacent widgets as long as the parent
    // provides a Stack with clipBehavior: Clip.none.
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _MultiShockwavePainter(
          shockwaves: widget.controller.activeShockwaves,
        ),
      ),
    );
  }
}

class _MultiShockwavePainter extends CustomPainter {
  final List<ShockwaveConfig> shockwaves;

  _MultiShockwavePainter({required this.shockwaves});

  @override
  void paint(Canvas canvas, Size size) {
    for (final sw in shockwaves) {
      ShockwaveUtil.drawShockwave(
        canvas,
        size,
        sw.controller.value,
        sw.rect,
        color: sw.color,
        maxExpansion: sw.maxExpansion,
        cornerRadius: sw.cornerRadius,
        strokeWidth: sw.strokeWidth,
        fadeCurve: sw.fadeCurve,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MultiShockwavePainter oldDelegate) => true;
}
