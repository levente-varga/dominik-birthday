import 'package:flutter/material.dart';

class AnimatedRewardText extends StatefulWidget {
  final String text;
  final double fontSize;
  
  const AnimatedRewardText({
    super.key,
    required this.text,
    this.fontSize = 10,
  });

  @override
  State<AnimatedRewardText> createState() => _AnimatedRewardTextState();
}

class _AnimatedRewardTextState extends State<AnimatedRewardText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    final colors = [
      Colors.white,
      Colors.amber.shade400,
      Colors.pink.shade400,
      const Color(0xFFEF5350), // Anomaly red
    ];

    final tweens = <TweenSequenceItem<Color?>>[];
    for (int i = 0; i < colors.length; i++) {
      tweens.add(
        TweenSequenceItem(
          tween: ColorTween(
            begin: colors[i],
            end: colors[(i + 1) % colors.length],
          ),
          weight: 1.0,
        ),
      );
    }
    _colorAnimation = TweenSequence<Color?>(tweens).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Text(
          widget.text,
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.bold,
            color: _colorAnimation.value,
          ),
        );
      },
    );
  }
}
