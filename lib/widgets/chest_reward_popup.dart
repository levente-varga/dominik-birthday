import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../games/minesweeper/chest_reward.dart';

/// Displays the chest opening popup allowing the player to pick between two unique reward options.
Future<ChestRewardOption?> showChestRewardPopup(
  BuildContext context, {
  required List<ChestRewardOption> options,
  required ValueChanged<ChestRewardOption> onSelected,
}) {
  assert(options.length >= 2, 'Chest popup requires at least two options.');

  return showGeneralDialog<ChestRewardOption>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Treasure Chest',
    barrierColor: AppColors.overlayBarrier,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) {
      return ChestRewardPopup(
        options: options.take(2).toList(),
        onSelected: (chosen) {
          Navigator.of(context).pop(chosen);
          onSelected(chosen);
        },
      );
    },
    transitionBuilder: (ctx, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      final scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(curved);
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: AnimatedBuilder(
          animation: scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: scaleAnimation.value,
            filterQuality: FilterQuality.medium,
            child: RepaintBoundary(child: child),
          ),
          child: child,
        ),
      );
    },
  );
}

class ChestRewardPopup extends StatelessWidget {
  final List<ChestRewardOption> options;
  final ValueChanged<ChestRewardOption> onSelected;

  const ChestRewardPopup({
    super.key,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Material(
        color: AppColors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, minWidth: 320),
          child: Container(
            key: const ValueKey('chest_reward_popup_container'),
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.panelDim,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.amber.shade700.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.15),
                  blurRadius: 36,
                  spreadRadius: 4,
                ),
                const BoxShadow(
                  color: AppColors.overlayBarrier,
                  blurRadius: 24,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header Icon & Title ──────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade900.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.amber.shade400,
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        Icons.inventory_2_rounded,
                        color: Colors.amber.shade300,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TREASURE CHEST',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: Colors.amber.shade300,
                          ),
                        ),
                        Text(
                          'Choose one reward to claim:',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Two Option Cards ─────────────────────────────────────────
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isWide = constraints.maxWidth >= 420;

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _ChestOptionCard(
                              option: options[0],
                              onChoose: () => onSelected(options[0]),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _ChestOptionCard(
                              option: options[1],
                              onChoose: () => onSelected(options[1]),
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ChestOptionCard(
                            option: options[0],
                            onChoose: () => onSelected(options[0]),
                          ),
                          const SizedBox(height: 16),
                          _ChestOptionCard(
                            option: options[1],
                            onChoose: () => onSelected(options[1]),
                          ),
                        ],
                      );
                    }
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

class _ChestOptionCard extends StatefulWidget {
  final ChestRewardOption option;
  final VoidCallback onChoose;

  const _ChestOptionCard({
    required this.option,
    required this.onChoose,
  });

  @override
  State<_ChestOptionCard> createState() => _ChestOptionCardState();
}

class _ChestOptionCardState extends State<_ChestOptionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final opt = widget.option;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onChoose,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: _isHovered
                ? opt.accentColor.withValues(alpha: 0.12)
                : AppColors.panelMedium,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? opt.accentColor : AppColors.outlineDim,
              width: _isHovered ? 2.0 : 1.5,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: opt.accentColor.withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Category Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: opt.accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  opt.categoryLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: opt.accentColor,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Glowing Icon Container
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: opt.accentColor.withValues(alpha: 0.15),
                  border: Border.all(
                    color: opt.accentColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    opt.icon,
                    size: 30,
                    color: opt.accentColor,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Option Title
              Text(
                opt.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBright,
                ),
              ),

              const SizedBox(height: 8),

              // Description
              SizedBox(
                height: 60,
                child: Center(
                  child: Text(
                    opt.description,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMedium,
                      height: 1.3,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Choose Button
              SizedBox(
                width: double.infinity,
                height: 38,
                child: FilledButton(
                  onPressed: widget.onChoose,
                  style: FilledButton.styleFrom(
                    backgroundColor: opt.accentColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: _isHovered ? 4 : 0,
                  ),
                  child: const Text(
                    'CLAIM',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
