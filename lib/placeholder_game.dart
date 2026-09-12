import 'package:flutter/material.dart';

import 'constants/colors.dart';
import 'constants/sizes.dart';
import 'game.dart';
import 'game_state.dart';
import 'widgets/game_scaffold.dart';

/// A stub game used as a placeholder until the real stage is implemented.
///
/// Shows the stage name and two buttons (Win / Lose) so the full game loop
/// can be tested end-to-end without any real gameplay.
class PlaceholderGame extends Game {
  @override
  final int stageNumber;

  @override
  final String name;

  PlaceholderGame({required this.stageNumber, required this.name});

  @override
  Widget buildGame({
    required BuildContext context,
    required VoidCallback onComplete,
    required VoidCallback onFail,
    required GameStateManager gameState,
  }) {
    return _PlaceholderGameWidget(
      stageNumber: stageNumber,
      name: name,
      gameState: gameState,
      onComplete: onComplete,
      onFail: onFail,
    );
  }
}

class _PlaceholderGameWidget extends StatelessWidget {
  final int stageNumber;
  final String name;
  final GameStateManager gameState;
  final VoidCallback onComplete;
  final VoidCallback onFail;

  const _PlaceholderGameWidget({
    required this.stageNumber,
    required this.name,
    required this.gameState,
    required this.onComplete,
    required this.onFail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GameScaffold(
      gameState: gameState,
      headerTitle: Row(
        children: [
          const Icon(Icons.help_outline_rounded, size: AppSizes.fontXl, color: AppColors.warning),
          const SizedBox(width: AppSizes.spacingSm - 2),
          Text(
            'Stage $stageNumber',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Game name
          Text(
            name,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Coming Soon',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textMedium,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  onFail();
                },
                icon: const Icon(Icons.close_rounded, color: Colors.red),
                label: const Text('Fail'),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: onComplete,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Win'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
