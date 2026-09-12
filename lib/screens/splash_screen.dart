import 'package:flutter/material.dart';
import '../game_state.dart';

class SplashPageConfig {
  final Widget widget;
  final Duration duration;

  const SplashPageConfig({
    required this.widget,
    required this.duration,
  });
}

class SplashScreen extends StatefulWidget {
  final GameStateManager gameState;
  final List<SplashPageConfig> pages;

  const SplashScreen({
    super.key,
    required this.gameState,
    required this.pages,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  int _currentIndex = 0;
  bool _isTransitioning = false;

  void _finishSplash() {
    if (_isTransitioning) return;
    _isTransitioning = true;
    Navigator.of(context).pushReplacementNamed('/menu');
  }

  @override
  void initState() {
    super.initState();
    
    // Initial duration from first page
    _controller = AnimationController(
      vsync: this,
      duration: widget.pages.isNotEmpty 
          ? widget.pages[0].duration 
          : const Duration(milliseconds: 3500),
    );

    // Fade in: first 20% of duration (ease out)
    // Hold: middle 60%
    // Fade out: last 20% of duration (ease in)
    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_controller);

    // Slowly scale up continuously (linear)
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_currentIndex < widget.pages.length - 1) {
          setState(() {
            _currentIndex++;
            _controller.duration = widget.pages[_currentIndex].duration;
          });
          _controller.forward(from: 0.0);
        } else {
          _finishSplash();
        }
      }
    });

    // Briefly delay before starting the first sequence
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finishSplash,
        child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                filterQuality: FilterQuality.medium,
                child: RepaintBoundary(
                  child: widget.pages[_currentIndex].widget,
                ),
              ),
            );
          },
        ),
      ),
      ),
    );
  }
}
