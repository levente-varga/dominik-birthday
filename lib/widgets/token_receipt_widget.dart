import 'package:flutter/material.dart';
import '../constants/colors.dart';

class _IncomeTypeRow {
  final String label;
  final int amount;

  const _IncomeTypeRow({required this.label, required this.amount});
}

class TokenReceiptWidget extends StatefulWidget {
  final int baseIncome;
  final int incomeSkillTokens;
  final int rewardSkillTokens;
  final int accumulatorSkillTokens;
  final double tokenMultiplier;
  final double anomalyMultiplier;
  /// The exact total already added to the balance (sum of per-stage floor results).
  /// When provided and multiplier > 1.0, this is shown as the true total.
  final int? multipliedTotal;

  const TokenReceiptWidget({
    super.key,
    required this.baseIncome,
    required this.incomeSkillTokens,
    required this.rewardSkillTokens,
    this.accumulatorSkillTokens = 0,
    this.tokenMultiplier = 1.0,
    this.anomalyMultiplier = 1.0,
    this.multipliedTotal,
  });

  @override
  State<TokenReceiptWidget> createState() => _TokenReceiptWidgetState();
}

class _TokenReceiptWidgetState extends State<TokenReceiptWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_IncomeTypeRow> _rows;
  late final List<Animation<double>> _fadeAnimations;

  @override
  void initState() {
    super.initState();
    _rows = [];

    if (widget.baseIncome > 0) {
      _rows.add(_IncomeTypeRow(label: 'Stages Completed', amount: widget.baseIncome));
    }
    if (widget.incomeSkillTokens > 0) {
      _rows.add(_IncomeTypeRow(label: 'Token Income', amount: widget.incomeSkillTokens));
    }
    if (widget.rewardSkillTokens > 0) {
      _rows.add(_IncomeTypeRow(label: 'First Time Completion', amount: widget.rewardSkillTokens));
    }
    if (widget.accumulatorSkillTokens > 0) {
      _rows.add(_IncomeTypeRow(label: 'Accumulator', amount: widget.accumulatorSkillTokens));
    }

    final hasMultiplier = widget.tokenMultiplier > 1.0;
    final hasAnomalyMultiplier = widget.anomalyMultiplier > 1.0;
    // rows + optional multiplier rows + total row
    final totalItems = _rows.length + (hasMultiplier ? 1 : 0) + (hasAnomalyMultiplier ? 1 : 0) + 1;
    final durationMs = (totalItems * 180).clamp(400, 1200);

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );

    _fadeAnimations = [];
    final stepFraction = 1.0 / totalItems;

    for (int i = 0; i < totalItems; i++) {
      final start = i * stepFraction;
      final end = (start + stepFraction).clamp(0.0, 1.0);
      _fadeAnimations.add(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.easeIn),
        ),
      );
    }

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_rows.isEmpty) return const SizedBox.shrink();

    final subtotal = _rows.fold<int>(0, (sum, item) => sum + item.amount);
    if (subtotal <= 0) return const SizedBox.shrink();

    final hasMultiplier = widget.tokenMultiplier > 1.0;
    final hasAnomalyMultiplier = widget.anomalyMultiplier > 1.0;
    // Use the exact pre-computed total when available (avoids floor vs round
    // discrepancies from per-stage accumulation). Fall back to floor for safety.
    final totalTokens = (hasMultiplier || hasAnomalyMultiplier)
        ? (widget.multipliedTotal ?? (subtotal * widget.tokenMultiplier * widget.anomalyMultiplier).floor())
        : subtotal;

    final theme = Theme.of(context);

    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.panelMedium,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outlineDim,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Income type rows with staggered fade-in
          for (int i = 0; i < _rows.length; i++) ...[
            FadeTransition(
              opacity: _fadeAnimations[i],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _rows[i].label,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: AppColors.textBright,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '+${_rows[i].amount}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Anomaly Multiplier row (only shown when anomalyMultiplier > 1.0)
          if (hasAnomalyMultiplier) ...[
            FadeTransition(
              opacity: _fadeAnimations[_rows.length + (hasMultiplier ? 1 : 0)],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Anomaly Bonus',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: AppColors.textBright,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '×${widget.anomalyMultiplier.toStringAsFixed(1)}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.anomalyBadgeText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Multiplier row (only shown when multiplier > 1.0)
          if (hasMultiplier) ...[
            FadeTransition(
              opacity: _fadeAnimations[_rows.length],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Multiplier',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: AppColors.textBright,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '×${widget.tokenMultiplier.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.pink.shade400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 6),
          Divider(
            color: AppColors.outlineDim,
            height: 1,
          ),
          const SizedBox(height: 8),

          // Total Row with final staggered fade-in
          FadeTransition(
            opacity: _fadeAnimations[_rows.length + (hasMultiplier ? 1 : 0)],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Gained',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.token,
                      size: 16,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$totalTokens',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
