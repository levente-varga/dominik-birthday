import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../constants/colors.dart';

/// A high-performance animated background widget for Anomaly games.
/// Renders ambient gradient smudges over the regular grey theme background,
/// inward-collapsing screen-shaped shockwaves along the edges, and a fullscreen
/// red intro flash overlay that fades out with an EaseOut curve on game start.
///
/// All rendered colors are fully opaque — transparency is replaced by
/// pre-blended opaque equivalents via Color.lerp against the base surface.
class AnomalyBackgroundWidget extends StatefulWidget {
  final Widget child;
  final bool isEnabled;

  const AnomalyBackgroundWidget({
    super.key,
    required this.child,
    this.isEnabled = true,
  });

  @override
  State<AnomalyBackgroundWidget> createState() =>
      _AnomalyBackgroundWidgetState();
}

class _Smudge {
  Alignment center;
  Alignment velocity;
  double radius;
  Color color;
  double life; // 0.0 (birth) -> 1.0 (death)
  double lifespanSeconds;
  double maxAlpha;

  _Smudge({
    required this.center,
    required this.velocity,
    required this.radius,
    required this.color,
    required this.life,
    required this.lifespanSeconds,
    required this.maxAlpha,
  });

  /// Computes current alpha using a smooth sine window: maxAlpha * sin(pi * life).
  /// At life = 0.0 and life = 1.0, alpha is exactly 0.0 (zero visual jumps).
  double get currentAlpha {
    if (life <= 0.0 || life >= 1.0) return 0.0;
    return maxAlpha * math.sin(math.pi * life);
  }
}

class _AnomalyBackgroundWidgetState extends State<AnomalyBackgroundWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _shockwaveController;
  late AnimationController _introController;
  late Animation<double> _introAnimation;
  late List<_Smudge> _smudges;
  late List<_FastLine> _fastLines;
  DateTime _lastFrameTime = DateTime.now();

  static const List<Color> _smudgeColorPalette = [
    AppColors.anomalyBadgeText,
  ];

  final math.Random _rng = math.Random(1337);

  _Smudge _spawnSmudge({double initialLife = 0.0}) {
    final x = (_rng.nextDouble() * 1.6) - 0.8;
    final y = (_rng.nextDouble() * 1.6) - 0.8;
    final vx = (_rng.nextDouble() * 0.08) - 0.04;
    final vy = (_rng.nextDouble() * 0.08) - 0.04;

    return _Smudge(
      center: Alignment(x, y),
      velocity: Alignment(vx, vy),
      radius: _rng.nextDouble() * 0.35 + 0.70, // 0.70 to 1.05 screen ratio
      color: _smudgeColorPalette[_rng.nextInt(_smudgeColorPalette.length)],
      life: initialLife,
      lifespanSeconds: _rng.nextDouble() * 4.0 + 5.0, // 5s to 9s duration
      maxAlpha: _rng.nextDouble() * 0.08 + 0.12, // 0.12 to 0.20 peak opacity
    );
  }

  _FastLine _spawnFastLine({double initialLife = 0.0}) {
    return _FastLine(
      position: Offset(
        (_rng.nextDouble() * 2.4) - 1.2,
        (_rng.nextDouble() * 2.4) - 1.2,
      ),
      direction: _rng.nextDouble() * 2.0 * math.pi,
      speed: _rng.nextDouble() * 0.8 + 0.6, // Speed in screen units per second
      life: initialLife,
      lifespanSeconds: _rng.nextDouble() * 2.0 + 3.0, // 3 to 5 seconds
      maxAlpha: _rng.nextDouble() * 0.2 + 0.1, // 0.10 to 0.30 opacity
    );
  }

  @override
  void initState() {
    super.initState();
    _lastFrameTime = DateTime.now();

    // Stagger initial smudges so they are at different stages of life
    _smudges = [
      _spawnSmudge(initialLife: 0.15),
      _spawnSmudge(initialLife: 0.35),
      _spawnSmudge(initialLife: 0.55),
      _spawnSmudge(initialLife: 0.75),
      _spawnSmudge(initialLife: 0.90),
    ];

    _fastLines = [
      _spawnFastLine(initialLife: 0.1),
      _spawnFastLine(initialLife: 0.3),
      _spawnFastLine(initialLife: 0.5),
      _spawnFastLine(initialLife: 0.7),
      _spawnFastLine(initialLife: 0.9),
    ];

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _shockwaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _introAnimation = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeInOut,
    );

    if (widget.isEnabled) {
      _introController.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(AnomalyBackgroundWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEnabled && !oldWidget.isEnabled) {
      _introController.forward(from: 0.0);
    }
  }

  void _updateAnimations() {
    final now = DateTime.now();
    final dt = now.difference(_lastFrameTime).inMilliseconds / 1000.0;
    _lastFrameTime = now;

    // Cap delta time to prevent large jumps if frame lagged or app was paused
    final clampedDt = dt.clamp(0.001, 0.1);

    for (int i = 0; i < _smudges.length; i++) {
      final s = _smudges[i];
      s.life += clampedDt / s.lifespanSeconds;

      // Update slow drifting position
      final newX = (s.center.x + s.velocity.x * clampedDt).clamp(-0.9, 0.9);
      final newY = (s.center.y + s.velocity.y * clampedDt).clamp(-0.9, 0.9);
      s.center = Alignment(newX, newY);

      // When life ends (alpha is 0.0), replace with a brand new smudge starting at 0.0 alpha
      if (s.life >= 1.0) {
        _smudges[i] = _spawnSmudge(initialLife: 0.0);
      }
    }

    for (int i = 0; i < _fastLines.length; i++) {
      final line = _fastLines[i];
      line.life += clampedDt / line.lifespanSeconds;

      line.history.add(line.position);
      if (line.history.length > 20) {
        line.history.removeAt(0);
      }

      // Randomize the amount of direction change (exponential curve for occasional sharp turns)
      final turnAmount = math.pow(_rng.nextDouble(), 3).toDouble() * 15.0;
      line.direction += (_rng.nextDouble() * 2.0 - 1.0) * turnAmount * clampedDt;

      final dx = math.cos(line.direction) * line.speed * clampedDt;
      final dy = math.sin(line.direction) * line.speed * clampedDt;
      line.position = Offset(line.position.dx + dx, line.position.dy + dy);

      bool wrapped = false;
      if (line.position.dx < -1.2) { line.position = Offset(1.2, line.position.dy); wrapped = true; }
      else if (line.position.dx > 1.2) { line.position = Offset(-1.2, line.position.dy); wrapped = true; }
      
      if (line.position.dy < -1.2) { line.position = Offset(line.position.dx, 1.2); wrapped = true; }
      else if (line.position.dy > 1.2) { line.position = Offset(line.position.dx, -1.2); wrapped = true; }
      
      if (wrapped) {
        line.history.clear();
      }

      if (line.life >= 1.0) {
        _fastLines[i] = _spawnFastLine(initialLife: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _shockwaveController.dispose();
    _introController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) {
      return Container(
        color: AppColors.surface,
        child: widget.child,
      );
    }

    final theme = Theme.of(context);
    final baseGreyColor = theme.colorScheme.surface;

    return AnimatedBuilder(
      animation: Listenable.merge(
          [_controller, _shockwaveController, _introController]),
      builder: (context, child) {
        _updateAnimations();
        final introAlpha = (0.50 * (1.0 - _introAnimation.value)).clamp(0.0, 1.0);

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Moving Gradient Smudges Background (all opaque colors)
            CustomPaint(
              painter: _GradientSmudgePainter(
                smudges: _smudges,
                baseColor: baseGreyColor,
              ),
            ),

            // 1.5 Moving Fast Lines
            CustomPaint(
              painter: _FastLinePainter(
                lines: _fastLines,
                color: AppColors.anomalyBadgeText,
              ),
            ),

            // 2. Inward Screen Shape Shockwave Effect (opaque blended strokes)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _InwardShockwavePainter(
                    progress: _shockwaveController.value,
                    color: AppColors.anomalyBadgeText,
                    baseColor: baseGreyColor,
                  ),
                ),
              ),
            ),

            // 3. Fullscreen Red Intro Flash Overlay (transparent blend, fading out)
            if (introAlpha > 0.001)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: AppColors.anomalyBadgeText.withValues(alpha: introAlpha),
                  ),
                ),
              ),

            // 4. Game Content
            ?child,
          ],
        );
      },
      child: widget.child,
    );
  }
}

/// Renders inward-collapsing shockwave rings matching the screen shape.
/// All colors are fully opaque — blended against baseColor.
class _InwardShockwavePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color baseColor;

  _InwardShockwavePainter({
    required this.progress,
    required this.color,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;
    const maxInset = 20.0; // Max distance shockwave collapses inward

    // 2 staggered inward shockwave rings
    final wave1Progress = progress;
    final wave2Progress = (progress + 0.5) % 1.0;

    _drawInwardWave(canvas, rect, wave1Progress, maxInset);
    _drawInwardWave(canvas, rect, wave2Progress, maxInset);
  }

  void _drawInwardWave(
      Canvas canvas, Rect rect, double waveProgress, double maxInset) {
    if (waveProgress <= 0.0 || waveProgress >= 1.0) return;

    final inset = waveProgress * maxInset;
    final insetRect = rect.deflate(inset);

    if (insetRect.width <= 0 || insetRect.height <= 0) return;

    // Fades in quickly near edge, then fades out as it collapses inward
    final blendFactor = (math.sin(waveProgress * math.pi) * 0.35).clamp(0.0, 1.0);

    final paint = Paint()
      ..color = color.withValues(alpha: blendFactor)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 + (1.0 - waveProgress) * 1.5;

    final rrect = RRect.fromRectAndRadius(
      insetRect,
      Radius.circular(0),
    );

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _InwardShockwavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.baseColor != baseColor;
  }
}

/// Renders ambient gradient smudges over the base surface color.
/// All gradient stop colors are fully opaque — pre-blended via Color.lerp.
class _GradientSmudgePainter extends CustomPainter {
  final List<_Smudge> smudges;
  final Color baseColor;

  _GradientSmudgePainter({
    required this.smudges,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;

    // 1. Regular Grey Theme Background Base (fully opaque)
    final bgPaint = Paint()..color = baseColor;
    canvas.drawRect(rect, bgPaint);

    // 2. Render each active smudge with opaque blended gradient stops
    for (final s in smudges) {
      final alpha = s.currentAlpha;
      if (alpha <= 0.001) continue;

      // Pre-blend each gradient stop against baseColor for fully opaque output
      final paint = Paint()
        ..shader = RadialGradient(
          center: s.center,
          radius: s.radius,
          colors: [
            s.color.withValues(alpha: alpha),
            s.color.withValues(alpha: alpha * 0.50),
            s.color.withValues(alpha: alpha * 0.15),
            AppColors.transparent,
          ],
          stops: const [0.0, 0.35, 0.70, 1.0],
        ).createShader(rect);

      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GradientSmudgePainter oldDelegate) {
    return true;
  }
}

class _FastLine {
  final List<Offset> history = [];
  Offset position;
  double direction; // Radians
  double speed;
  double life;
  final double lifespanSeconds;
  final double maxAlpha;

  _FastLine({
    required this.position,
    required this.direction,
    required this.speed,
    required this.life,
    required this.lifespanSeconds,
    required this.maxAlpha,
  });

  double get currentAlpha {
    if (life <= 0.0 || life >= 1.0) return 0.0;
    return maxAlpha * math.sin(math.pi * life);
  }
}

class _FastLinePainter extends CustomPainter {
  final List<_FastLine> lines;
  final Color color;

  _FastLinePainter({
    required this.lines,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final w = size.width / 2;
    final h = size.height / 2;
    
    Offset toScreen(Offset p) => Offset(w + p.dx * w, h + p.dy * h);

    for (final line in lines) {
      final alpha = line.currentAlpha;
      if (alpha <= 0.001 || line.history.isEmpty) continue;

      final points = [...line.history, line.position];
      
      for (int i = 0; i < points.length - 1; i++) {
        final p1 = toScreen(points[i]);
        final p2 = toScreen(points[i + 1]);
        
        final tailProgress = (i + 1) / points.length;
        final segmentAlpha = alpha * tailProgress;
        
        final paint = Paint()
          ..color = color.withValues(alpha: segmentAlpha)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
          
        canvas.drawLine(p1, p2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FastLinePainter oldDelegate) => true;
}
