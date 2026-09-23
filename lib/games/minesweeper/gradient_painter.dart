import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../config/config.dart';

// ── Game Area Gradient Overlay Painter ───────────────────────────────────────

class GameAreaGradientPainter extends CustomPainter {
  final Rect centerRect;
  final double nearAlpha;
  final double farAlpha;
  final Color color;
  final OverlayGradientStyle style;

  const GameAreaGradientPainter({
    required this.centerRect,
    required this.nearAlpha,
    required this.farAlpha,
    required this.color,
    this.style = OverlayGradientStyle.splitLinear,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final x1 = centerRect.left;
    final y1 = centerRect.top;
    final x2 = centerRect.right;
    final y2 = centerRect.bottom;

    final nearColor = color.withValues(alpha: nearAlpha);
    final farColor = color.withValues(alpha: farAlpha);

    if (style == OverlayGradientStyle.radial) {
      final clipPath = Path()
        ..addRect(Rect.fromLTWH(0, 0, w, h))
        ..addRect(centerRect)
        ..fillType = PathFillType.evenOdd;

      canvas.save();
      canvas.clipPath(clipPath);

      final center = Offset(w / 2, h / 2);
      final radius = sqrt((w / 2) * (w / 2) + (h / 2) * (h / 2));
      final innerRadius = min(centerRect.width, centerRect.height) / 2;
      final tInner = (innerRadius / radius).clamp(0.0, 1.0);

      final paint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          [nearColor, nearColor, farColor],
          [0.0, tInner, 1.0],
        );
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
      canvas.restore();
      return;
    }

    // ── Split Linear Gradients (One H, One V) ─────────────────────────
    // Diagonal splits at the 4 corners:
    // Top-Left: (0, 0) <-> (x1, y1)
    // Top-Right: (w, 0) <-> (x2, y1)
    // Bottom-Left: (0, h) <-> (x1, y2)
    // Bottom-Right: (w, h) <-> (x2, y2)
    //
    // The horizontal and vertical linear gradients meet precisely at
    // these diagonal miter lines without overlapping. Along each diagonal,
    // the progress parameters match identically, ensuring continuous
    // color blending with zero overlap or double-darkening artifact.

    // 1. Top Trapezoid (Vertical Linear Gradient)
    final topPath = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(x2, y1)
      ..lineTo(x1, y1)
      ..close();

    final topPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, y1),
        Offset(0, 0),
        [nearColor, farColor],
      );
    canvas.drawPath(topPath, topPaint);

    // 2. Bottom Trapezoid (Vertical Linear Gradient)
    final bottomPath = Path()
      ..moveTo(x1, y2)
      ..lineTo(x2, y2)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final bottomPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, y2),
        Offset(0, h),
        [nearColor, farColor],
      );
    canvas.drawPath(bottomPath, bottomPaint);

    // 3. Left Trapezoid (Horizontal Linear Gradient)
    final leftPath = Path()
      ..moveTo(0, 0)
      ..lineTo(x1, y1)
      ..lineTo(x1, y2)
      ..lineTo(0, h)
      ..close();

    final leftPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(x1, 0),
        Offset(0, 0),
        [nearColor, farColor],
      );
    canvas.drawPath(leftPath, leftPaint);

    // 4. Right Trapezoid (Horizontal Linear Gradient)
    final rightPath = Path()
      ..moveTo(x2, y1)
      ..lineTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(x2, y2)
      ..close();

    final rightPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(x2, 0),
        Offset(w, 0),
        [nearColor, farColor],
      );
    canvas.drawPath(rightPath, rightPaint);
  }

  @override
  bool shouldRepaint(covariant GameAreaGradientPainter oldDelegate) {
    return oldDelegate.centerRect != centerRect ||
        oldDelegate.nearAlpha != nearAlpha ||
        oldDelegate.farAlpha != farAlpha ||
        oldDelegate.color != color ||
        oldDelegate.style != style;
  }
}
