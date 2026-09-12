import 'package:flutter/material.dart';
import '../constants/colors.dart';

import '../game_state.dart';
import '../widgets/menu_button.dart';
import '../widgets/token_receipt_widget.dart';

/// Shown when the player fails a game during a run.
///
/// Displays which stage they died on, updates statistics, and provides
/// a button to return to the main menu.
class DeathScreen extends StatelessWidget {
  final GameStateManager gameState;

  const DeathScreen({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stageLost = gameState.statistics.lastStageLostAt ?? 0;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Skull / fail icon
                const Icon(
                  Icons.heart_broken_rounded,
                  size: 64,
                  color: Color(0xFFB71C1C),
                ),
                const SizedBox(height: 16),

                Text(
                  'Run Failed',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFC62828),
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Fell at Stage $stageLost',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.textBright,
                  ),
                ),
                const SizedBox(height: 20),

                TokenReceiptWidget(
                  baseIncome: gameState.runBaseIncome,
                  incomeSkillTokens: gameState.runIncomeSkillTokens,
                  rewardSkillTokens: gameState.runRewardSkillTokens,
                  accumulatorSkillTokens:
                      gameState.runAccumulatorSkillTokens.floor(),
                  tokenMultiplier: gameState.tokenMultiplier,
                  anomalyMultiplier: gameState.anomalyMultiplier,
                  multipliedTotal: gameState.runMultipliedTotal,
                ),

                const SizedBox(height: 28),

                MenuButton(
                  label: 'Return to Menu',
                  icon: Icons.home_rounded,
                  onPressed: () {
                    gameState.resetRunState();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
