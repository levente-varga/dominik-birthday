import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/config.dart';

// ── Sparkling Projectiles Widget ───────────────────────────────────────────

/// Renders floating, sparkling white projectile particles around and in front
/// of a region panel containing an unfound item.
class RegionSparklesWidget extends StatefulWidget {
  final double width;
  final double height;
  final bool active;
  final bool? enableContinuousInTests;
  final List<SparkleParticle>? particles;
  final ValueChanged<List<SparkleParticle>>? onParticlesCreated;

  const RegionSparklesWidget({
    super.key,
    required this.width,
    required this.height,
    required this.active,
    this.enableContinuousInTests,
    this.particles,
    this.onParticlesCreated,
  });

  @override
  State<RegionSparklesWidget> createState() => _RegionSparklesWidgetState();
}

class SparkleParticle {
  double x;
  double y;
  double vx;
  double vy;
  double life; // 0.0 to 1.0
  double speed; // progress added per frame
  double size;
  double flashRate;
  double flashPhase;

  SparkleParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.speed,
    required this.size,
    required this.flashRate,
    required this.flashPhase,
  });

  static SparkleParticle random(
    math.Random rng,
    double width,
    double height, {
    double initialLife = 0.0,
  }) {
    // Spawns across panel face and around the border with 16px outward overflow
    const overflow = 16.0;
    final x = (rng.nextDouble() * (width + (2 * overflow))) - overflow;
    final y = (rng.nextDouble() * (height + (2 * overflow))) - overflow;
    final vx = (rng.nextDouble() - 0.5) * 8.0;
    final vy = -4.0 - (rng.nextDouble() * 12.0); // Gentle upward float
    final size = 3.0 + (rng.nextDouble() * 3.5);
    final lifespanSeconds = 1.2 + (rng.nextDouble() * 1.0);
    final speed = 1.0 / (lifespanSeconds * 60.0); // Assuming 60fps tick rate
    final flashRate = 2.0 + (rng.nextDouble() * 2.0);
    final flashPhase = rng.nextDouble() * math.pi * 2.0;

    return SparkleParticle(
      x: x,
      y: y,
      vx: vx,
      vy: vy,
      life: initialLife,
      speed: speed,
      size: size,
      flashRate: flashRate,
      flashPhase: flashPhase,
    );
  }

  void reset(math.Random rng, double width, double height) {
    const overflow = 16.0;
    x = (rng.nextDouble() * (width + (2 * overflow))) - overflow;
    y = (rng.nextDouble() * (height + (2 * overflow))) - overflow;
    vx = (rng.nextDouble() - 0.5) * 8.0;
    vy = -4.0 - (rng.nextDouble() * 12.0);
    size = 3.0 + (rng.nextDouble() * 3.5);
    final lifespanSeconds = 1.2 + (rng.nextDouble() * 1.0);
    speed = 1.0 / (lifespanSeconds * 60.0);
    flashRate = 2.0 + (rng.nextDouble() * 2.0);
    flashPhase = rng.nextDouble() * math.pi * 2.0;
    life = 0.0;
  }

  void update(math.Random rng, double width, double height) {
    x += vx * 0.016;
    y += vy * 0.016;
    life += speed;
    if (life >= 1.0) {
      reset(rng, width, height);
    }
  }
}

class _RegionSparklesWidgetState extends State<RegionSparklesWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final math.Random _rng = math.Random();
  late List<SparkleParticle> _particles;
  static const int _particleCount = 14;

  @visibleForTesting
  List<SparkleParticle> get particles => _particles;

  @override
  void initState() {
    super.initState();
    if (widget.particles != null && widget.particles!.isNotEmpty) {
      _particles = widget.particles!;
    } else {
      _particles = [];
      _initParticles();
      widget.onParticlesCreated?.call(_particles);
    }
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..addListener(_onTick);

    _updateAnimationState();
  }

  void _initParticles() {
    _particles.clear();
    for (int i = 0; i < _particleCount; i++) {
      final initialLife = _rng.nextDouble();
      _particles.add(
        SparkleParticle.random(
          _rng,
          widget.width,
          widget.height,
          initialLife: initialLife,
        ),
      );
    }
  }

  bool get _shouldRepeat {
    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTest) {
      return widget.enableContinuousInTests ??
          MinesweeperConfig.enableContinuousSparklesInTests;
    }
    return true;
  }

  void _updateAnimationState() {
    if (!widget.active) {
      _controller.stop();
      return;
    }

    if (_shouldRepeat) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      if (!_controller.isAnimating && _controller.value == 0.0) {
        _controller.forward();
      }
    }
  }

  @override
  void didUpdateWidget(RegionSparklesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.particles != null && widget.particles != _particles) {
      _particles = widget.particles!;
    } else if (widget.particles == null) {
      widget.onParticlesCreated?.call(_particles);
    }
    if (oldWidget.active != widget.active ||
        oldWidget.width != widget.width ||
        oldWidget.height != widget.height) {
      _updateAnimationState();
    }
  }

  void _onTick() {
    if (!widget.active) return;
    for (final p in _particles) {
      p.update(_rng, widget.width, widget.height);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      size: Size(widget.width, widget.height),
      painter: _SparklesPainter(particles: _particles),
    );
  }
}

class _SparklesPainter extends CustomPainter {
  final List<SparkleParticle> particles;

  _SparklesPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      if (p.life < 0.0 || p.life > 1.0) continue;

      // Fade-in over first 20%, fade-out over last 30%
      final fadeIn = (p.life / 0.20).clamp(0.0, 1.0);
      final fadeOut = ((1.0 - p.life) / 0.30).clamp(0.0, 1.0);

      // Flashing oscillation
      final flash = 0.5 + 0.5 * math.sin((p.life * p.flashRate * math.pi * 2.0) + p.flashPhase);
      final opacity = (fadeIn * fadeOut * (0.4 + 0.6 * flash)).clamp(0.0, 1.0);

      if (opacity <= 0.01) continue;

      final currentRadius = p.size * (0.7 + 0.3 * flash);

      // Soft white glow
      final glowPaint = Paint()
        ..color = Colors.white.withValues(alpha: opacity * 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawCircle(Offset(p.x, p.y), currentRadius * 1.1, glowPaint);

      // Sharp white core
      final corePaint = Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      // 4-point diamond sparkle path
      final path = Path();
      path.moveTo(p.x, p.y - currentRadius);
      path.quadraticBezierTo(p.x, p.y, p.x + currentRadius, p.y);
      path.quadraticBezierTo(p.x, p.y, p.x, p.y + currentRadius);
      path.quadraticBezierTo(p.x, p.y, p.x - currentRadius, p.y);
      path.quadraticBezierTo(p.x, p.y, p.x, p.y - currentRadius);
      canvas.drawPath(path, corePaint);

      // Center bright pinpoint
      canvas.drawCircle(Offset(p.x, p.y), currentRadius * 0.35, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklesPainter oldDelegate) => true;
}
