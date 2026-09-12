import 'package:flutter/material.dart';
import '../game_state.dart';

/// Legacy Run Timer Badge - returns empty SizedBox now that global timer is removed.
class RunTimerBadge extends StatelessWidget {
  final GameStateManager gameState;

  const RunTimerBadge({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

