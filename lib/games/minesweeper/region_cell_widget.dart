part of '../minesweeper.dart';

// ── Region Cell Widget (Classic Look & Feel) ────────────────────────────────

class _RegionCellWidget extends StatefulWidget {
  final int cellState;
  final int adjacentMines;
  final bool hasMine;
  final double gap;
  final bool gameOver;
  final bool gameWon;
  final bool isNeighbor;
  final bool isInteractable;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Duration longTapDuration;
  final double backgroundOpacity;
  final double contentOpacity;
  final Color touchHighlightColor;
  final Duration touchHighlightFadeDuration;
  final Color? biomeColor;

  const _RegionCellWidget({
    required this.cellState,
    required this.adjacentMines,
    required this.hasMine,
    required this.gap,
    required this.gameOver,
    required this.gameWon,
    this.isNeighbor = false,
    this.isInteractable = true,
    this.backgroundOpacity = 1.0,
    this.contentOpacity = 1.0,
    this.biomeColor,
    this.onTap,
    this.onLongPress,
    this.longTapDuration = MinesweeperConfig.longTapDuration,
    this.touchHighlightColor = MinesweeperConfig.touchHighlightColor,
    this.touchHighlightFadeDuration = MinesweeperConfig.touchHighlightFadeDuration,
  });

  static const numberColors = [
    AppColors.surface, // 0 (unused)
    Color(0xFF29B6F6), // 1: Light Blue (Classic 1)
    Color(0xFF66BB6A), // 2: Green (Classic 2)
    Color(0xFFEF5350), // 3: Red (Classic 3)
    Color(0xFF7E57C2), // 4: Purple (Classic 4)
    Color(0xFF8D6E63), // 5: Brown (Classic 5)
    Color(0xFF26A69A), // 6: Teal (Classic 6)
    Color(0xFFAB47BC), // 7: Magenta / Violet (Classic 7)
    Color(0xFF78909C), // 8: Slate / Cool Grey (Classic 8)
    Color(0xFFFFA726), // 9: Amber / Orange
    Color(0xFFEC407A), // 10: Vivid Pink
    Color(0xFF00E676), // 11: Neon Spring Green
    Color(0xFFFFEE58), // 12: Bright Yellow
    Color(0xFF00B0FF), // 13: Vivid Sky Blue
    Color(0xFFFF7043), // 14: Deep Coral Orange
    Color(0xFF5C6BC0), // 15: Indigo
    Color(0xFF1DE9B6), // 16: Aquamarine / Mint
    Color(0xFFFF4081), // 17: Hot Rose
    Color(0xFFAEEA00), // 18: Lime / Chartreuse
    Color(0xFFBA68C8), // 19: Orchid Lavender
    Color(0xFFFFD700), // 20: Gold
    Color(0xFF00E5FF), // 21: Electric Cyan
    Color(0xFFFF8A65), // 22: Salmon Peach
    Color(0xFFD500F9), // 23: Neon Magenta
    Color(0xFFFFFFFF), // 24: Crisp Pure White
  ];

  static final List<TextStyle> numberTextStyles = List.generate(
    numberColors.length,
    (i) => TextStyle(
      fontSize: i >= 10 ? 13.0 : MinesweeperConfig.cellNumberFontSize,
      fontWeight: FontWeight.w900,
      color: numberColors[i],
    ),
  );

  @override
  State<_RegionCellWidget> createState() => _RegionCellWidgetState();
}

typedef RegionCellWidget = _RegionCellWidget;

class _RegionCellWidgetState extends State<_RegionCellWidget> {
  int? _activePointerId;
  Offset? _downPosition;
  bool _isPressed = false;

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.isInteractable || widget.gameOver || widget.gameWon) return;
    if (widget.cellState != CellState.unrevealed &&
        widget.cellState != CellState.flagged) {
      return;
    }
    if (_activePointerId != null) return;
    _activePointerId = event.pointer;
    _downPosition = event.position;
    if (mounted) {
      setState(() {
        _isPressed = true;
      });
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_isPressed || event.pointer != _activePointerId) return;
    if (_downPosition != null) {
      final distance = (event.position - _downPosition!).distance;
      if (distance > 12.0) {
        if (mounted) {
          setState(() {
            _isPressed = false;
          });
        }
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer == _activePointerId) {
      _activePointerId = null;
      _downPosition = null;
      if (_isPressed && mounted) {
        setState(() {
          _isPressed = false;
        });
      }
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _activePointerId) {
      _activePointerId = null;
      _downPosition = null;
      if (_isPressed && mounted) {
        setState(() {
          _isPressed = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(_RegionCellWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!widget.isInteractable ||
            widget.cellState != oldWidget.cellState ||
            (widget.cellState != CellState.unrevealed &&
                widget.cellState != CellState.flagged)) &&
        _isPressed) {
      _isPressed = false;
      _activePointerId = null;
      _downPosition = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCorrectlyFlaggedOnLoss = widget.gameOver &&
        widget.cellState == CellState.flagged &&
        widget.hasMine;

    final isRevealed = widget.cellState == CellState.revealed ||
        widget.cellState == CellState.activatedMine ||
        widget.cellState == CellState.revealedMine ||
        widget.cellState == CellState.hiddenNumber ||
        isCorrectlyFlaggedOnLoss;

    final bgOpt = widget.backgroundOpacity.clamp(0.0, 1.0);
    final cntOpt = widget.contentOpacity.clamp(0.0, 1.0);
    final showBg = bgOpt > 0.01;
    final bgColor = _backgroundColor(theme);

    final isUnrevealedOrFlagged = widget.cellState == CellState.unrevealed ||
        widget.cellState == CellState.flagged;

    final shouldHighlight = _isPressed &&
        isUnrevealedOrFlagged &&
        widget.isInteractable &&
        !widget.gameOver &&
        !widget.gameWon;

    final tileBox = Padding(
      padding: EdgeInsets.all(widget.gap / 2),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: showBg
                ? BoxDecoration(
                    color: bgColor.withValues(alpha: bgColor.a * bgOpt),
                    borderRadius: BorderRadius.circular(8),
                    border: isRevealed
                        ? null
                        : Border.all(
                            color: AppColors.outlineDim.withValues(
                              alpha: AppColors.outlineDim.a * bgOpt,
                            ),
                            width: 0.5,
                          ),
                    boxShadow: isRevealed || bgOpt < 0.05
                        ? null
                        : [
                            BoxShadow(
                              color: AppColors.whiteDim.withValues(
                                alpha: AppColors.whiteDim.a * bgOpt,
                              ),
                              offset: const Offset(-1, -1),
                              blurRadius: 0,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: 0.25 * bgOpt,
                              ),
                              offset: const Offset(1, 1),
                              blurRadius: 0,
                            ),
                          ],
                  )
                : const BoxDecoration(color: Colors.transparent),
          ),
          if (!widget.isNeighbor || widget.isInteractable)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  key: const ValueKey('cell_touch_highlight'),
                  opacity: shouldHighlight ? 1.0 : 0.0,
                  duration: widget.touchHighlightFadeDuration,
                  curve: Curves.easeOut,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: widget.touchHighlightColor,
                    ),
                  ),
                ),
              ),
            ),
          if (cntOpt > 0.01)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Opacity(
                    opacity: cntOpt,
                    child: _buildContent(theme),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (!widget.isInteractable) {
      // Non-interactable (neighbor cell or board is animating): MUST NOT BE INTERACTABLE!
      return IgnorePointer(
        child: tileBox,
      );
    }

    final gestures = <Type, GestureRecognizerFactory>{};

    if (widget.onTap != null) {
      gestures[TapGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
        () => TapGestureRecognizer(debugOwner: this),
        (TapGestureRecognizer instance) {
          instance.onTap = widget.onTap;
        },
      );
    }

    if (widget.onLongPress != null) {
      gestures[LongPressGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
        () => LongPressGestureRecognizer(
          duration: widget.longTapDuration,
          debugOwner: this,
        ),
        (LongPressGestureRecognizer instance) {
          instance.onLongPress = () {
            if (mounted && _isPressed) {
              setState(() {
                _isPressed = false;
                _activePointerId = null;
                _downPosition = null;
              });
            }
            widget.onLongPress?.call();
          };
        },
      );
    }

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: gestures,
        child: tileBox,
      ),
    );
  }

  Color _backgroundColor(ThemeData theme) {
    if (widget.gameWon && widget.cellState == CellState.flagged) {
      return Colors.green.shade700;
    }
    if (widget.gameOver &&
        widget.cellState == CellState.flagged &&
        widget.hasMine) {
      return MinesweeperConfig.correctFlagLossBackgroundColor;
    }
    if (widget.cellState == CellState.activatedMine ||
        widget.cellState == CellState.revealedMine) {
      return Colors.red.shade900;
    }
    if (widget.cellState == CellState.revealed ||
        widget.cellState == CellState.hiddenNumber) {
      return theme.colorScheme.surface;
    }
    final defaultUnrevealedColor = theme.colorScheme.surfaceContainerHighest;
    if (widget.biomeColor != null) {
      return Color.alphaBlend(
        widget.biomeColor!.withValues(
          alpha: MinesweeperConfig.unrevealedCellTintAlpha,
        ),
        defaultUnrevealedColor,
      );
    }
    return defaultUnrevealedColor;
  }

  Widget? _buildContent(ThemeData theme) {
    if (widget.cellState == CellState.flagged) {
      final isCorrectlyFlaggedOnLoss = widget.gameOver && widget.hasMine;
      return Icon(
        Icons.flag_rounded,
        size: MinesweeperConfig.cellFlagIconSize,
        color: isCorrectlyFlaggedOnLoss
            ? MinesweeperConfig.correctFlagLossIconColor
            : (widget.gameWon ? Colors.white : Colors.orange.shade400),
      );
    }

    if (widget.cellState == CellState.activatedMine ||
        widget.cellState == CellState.revealedMine) {
      return const Icon(
        Icons.brightness_7_rounded,
        size: 20,
        color: Colors.black,
      );
    }

    if (widget.cellState == CellState.hiddenNumber) {
      return const HiddenNumberText();
    }

    if (widget.cellState == CellState.revealed) {
      if (widget.adjacentMines <= 0) return null;
      final count = widget.adjacentMines;
      final style = count < _RegionCellWidget.numberTextStyles.length
          ? _RegionCellWidget.numberTextStyles[count]
          : const TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            );
      return Text(
        '$count',
        style: style,
      );
    }

    return null;
  }
}

// ── Anomaly '?' Hidden Number Animated Text ─────────────────────────────────

class HiddenNumberText extends StatefulWidget {
  const HiddenNumberText({super.key});

  @override
  State<HiddenNumberText> createState() => _HiddenNumberTextState();
}

class _HiddenNumberTextState extends State<HiddenNumberText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _colorAnimation = TweenSequence<Color?>([
      for (int i = 1; i <= 8; i++)
        TweenSequenceItem(
          weight: 1.0,
          tween: ColorTween(
            begin: _RegionCellWidget.numberColors[i],
            end: _RegionCellWidget.numberColors[i == 8 ? 1 : i + 1],
          ),
        ),
    ]).animate(_controller);
    _controller.repeat();
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
          '?',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: _colorAnimation.value,
          ),
        );
      },
    );
  }
}
