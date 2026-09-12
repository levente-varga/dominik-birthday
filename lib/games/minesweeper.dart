import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/achievement_config.dart';
import '../config/config.dart';
import '../constants/colors.dart';
import '../game.dart';
import '../game_state.dart';
import '../widgets/game_scaffold.dart';
import '../widgets/minimap_popup.dart';
import '../widgets/shockwave_layer.dart';

// ── Cell state constants (packed in Uint8List for zero GC overhead) ──────────

abstract final class CellState {
  static const int unrevealed = 0;
  static const int revealed = 1;
  static const int flagged = 2;
  static const int activatedMine = 3; // The mine the player clicked
  static const int revealedMine = 4; // Other mines shown upon defeat
  static const int hiddenNumber = 5; // Anomaly '?'
}

// ── Game entry point ───────────────────────────────────────────────────────

class MinesweeperGame extends Game {
  @override
  final int stageNumber = 1;

  @override
  final String name = 'Minesweeper Sweep';

  final double? panelGap;
  final double? panelCornerRadius;
  final double? regionPanelCornerRadius;
  final double? boardPadding;
  final int? peekDepth;
  final Duration? longTapDuration;
  final double? gradientNearTransparency;
  final double? gradientFarTransparency;
  final double? incomingPanelOverlayTransparency;
  final Color? touchHighlightColor;
  final Duration? touchHighlightFadeDuration;
  final Color? adjacentPanelOutlineColor;
  final OverlayGradientStyle? overlayGradientStyle;
  final double? neighborRegionTransparency;
  final bool? lockInaccessibleRegions;
  final Duration? regionUnlockFadeDuration;
  final double? swipeThreshold;
  final VoidCallback? onPause;

  MinesweeperGame({
    this.panelGap,
    this.panelCornerRadius,
    this.regionPanelCornerRadius,
    this.boardPadding,
    this.peekDepth,
    this.longTapDuration,
    this.gradientNearTransparency,
    this.gradientFarTransparency,
    this.incomingPanelOverlayTransparency,
    this.touchHighlightColor,
    this.touchHighlightFadeDuration,
    this.adjacentPanelOutlineColor,
    this.overlayGradientStyle,
    this.neighborRegionTransparency,
    this.lockInaccessibleRegions,
    this.regionUnlockFadeDuration,
    this.swipeThreshold,
    this.onPause,
  });

  @override
  Widget buildGame({
    required BuildContext context,
    required VoidCallback onComplete,
    required VoidCallback onFail,
    required GameStateManager gameState,
  }) {
    return _MinesweeperGame(
      regionsX: MinesweeperConfig.regionsX,
      regionsY: MinesweeperConfig.regionsY,
      regionRows: MinesweeperConfig.regionRows,
      regionCols: MinesweeperConfig.regionCols,
      mineCount: MinesweeperConfig.totalMines,
      mineDensity: MinesweeperConfig.mineDensity,
      initialRegionX: MinesweeperConfig.initialRegionX,
      initialRegionY: MinesweeperConfig.initialRegionY,
      swipeThreshold: swipeThreshold ?? MinesweeperConfig.swipeThreshold,
      panelGap: panelGap ?? MinesweeperConfig.panelGap,
      panelCornerRadius: panelCornerRadius ??
          regionPanelCornerRadius ??
          MinesweeperConfig.panelCornerRadius,
      boardPadding: boardPadding ?? MinesweeperConfig.boardPadding,
      peekDepth: peekDepth ?? MinesweeperConfig.peekDepth,
      longTapDuration: longTapDuration ?? MinesweeperConfig.longTapDuration,
      gradientNearTransparency: gradientNearTransparency ??
          MinesweeperConfig.gradientNearTransparency,
      gradientFarTransparency: gradientFarTransparency ??
          MinesweeperConfig.gradientFarTransparency,
      incomingPanelOverlayTransparency: incomingPanelOverlayTransparency ??
          MinesweeperConfig.incomingPanelOverlayTransparency,
      touchHighlightColor: touchHighlightColor ?? MinesweeperConfig.touchHighlightColor,
      touchHighlightFadeDuration: touchHighlightFadeDuration ??
          MinesweeperConfig.touchHighlightFadeDuration,
      adjacentPanelOutlineColor: adjacentPanelOutlineColor ??
          MinesweeperConfig.adjacentPanelOutlineColor,
      overlayGradientStyle: overlayGradientStyle ??
          MinesweeperConfig.overlayGradientStyle,
      neighborRegionTransparency: neighborRegionTransparency ??
          MinesweeperConfig.neighborRegionTransparency,
      lockInaccessibleRegions: lockInaccessibleRegions ??
          MinesweeperConfig.lockInaccessibleRegions,
      regionUnlockFadeDuration: regionUnlockFadeDuration ??
          MinesweeperConfig.regionUnlockFadeDuration,
      onPause: onPause,
      gameState: gameState,
      onComplete: onComplete,
      onFail: onFail,
    );
  }
}

// ── Main game widget ───────────────────────────────────────────────────────

class _MinesweeperGame extends StatefulWidget {
  final int regionsX;
  final int regionsY;
  final int regionRows;
  final int regionCols;
  final int mineCount;
  final double mineDensity;
  final int initialRegionX;
  final int initialRegionY;
  final double swipeThreshold;
  final double panelGap;
  final double panelCornerRadius;
  final double boardPadding;
  final int peekDepth;
  final Duration longTapDuration;
  final double gradientNearTransparency;
  final double gradientFarTransparency;
  final double incomingPanelOverlayTransparency;
  final Color touchHighlightColor;
  final Duration touchHighlightFadeDuration;
  final Color adjacentPanelOutlineColor;
  final OverlayGradientStyle overlayGradientStyle;
  final double neighborRegionTransparency;
  final bool lockInaccessibleRegions;
  final Duration regionUnlockFadeDuration;
  final VoidCallback? onPause;
  final GameStateManager gameState;
  final VoidCallback onComplete;
  final VoidCallback onFail;

  const _MinesweeperGame({
    required this.regionsX,
    required this.regionsY,
    required this.regionRows,
    required this.regionCols,
    required this.mineCount,
    this.mineDensity = MinesweeperConfig.mineDensity,
    required this.initialRegionX,
    required this.initialRegionY,
    this.swipeThreshold = MinesweeperConfig.swipeThreshold,
    this.panelGap = MinesweeperConfig.panelGap,
    this.panelCornerRadius = MinesweeperConfig.panelCornerRadius,
    this.boardPadding = MinesweeperConfig.boardPadding,
    this.peekDepth = MinesweeperConfig.peekDepth,
    this.longTapDuration = MinesweeperConfig.longTapDuration,
    this.gradientNearTransparency = MinesweeperConfig.gradientNearTransparency,
    this.gradientFarTransparency = MinesweeperConfig.gradientFarTransparency,
    this.incomingPanelOverlayTransparency =
        MinesweeperConfig.incomingPanelOverlayTransparency,
    this.touchHighlightColor = MinesweeperConfig.touchHighlightColor,
    this.touchHighlightFadeDuration = MinesweeperConfig.touchHighlightFadeDuration,
    this.adjacentPanelOutlineColor = MinesweeperConfig.adjacentPanelOutlineColor,
    this.overlayGradientStyle = MinesweeperConfig.overlayGradientStyle,
    this.neighborRegionTransparency =
        MinesweeperConfig.neighborRegionTransparency,
    this.lockInaccessibleRegions = MinesweeperConfig.lockInaccessibleRegions,
    this.regionUnlockFadeDuration = MinesweeperConfig.regionUnlockFadeDuration,
    this.onPause,
    required this.gameState,
    required this.onComplete,
    required this.onFail,
  });

  @override
  State<_MinesweeperGame> createState() => _MinesweeperGameState();
}

class _MinesweeperGameState extends State<_MinesweeperGame>
    with TickerProviderStateMixin {
  // Global world map arrays (worldRows * worldCols)
  late Uint8List _mines; // 1 = mine, 0 = safe
  late Uint8List _adjacent; // 0..8 count across world map
  late Uint8List _cellStates; // CellState values

  // Active region coordinates (0-indexed)
  late int _currentRegionRow;
  late int _currentRegionCol;

  bool _minesPlaced = false;
  bool _gameOver = false;
  bool _gameWon = false;
  bool _hasMisplacedFlag = false;

  int _revealedCount = 0;
  int _flagCount = 0;
  int _correctlyFlaggedMines = 0;
  int _totalFlagsPlacedInSession = 0;
  late int _actualMineCount;

  // Active shockwave animations
  final ShockwaveLayerController _shockwaveLayerController =
      ShockwaveLayerController();

  final FocusNode _focusNode = FocusNode();

  // ── Swipe & Multi-Panel Transition State ─────────────────────────────────
  late final AnimationController _slideController;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  Animation<Offset>? _offsetAnimation;
  Animation<double>? _progressAnimation;
  Animation<double>? _gradientAnimation;

  Offset _planeOffset = Offset.zero;
  double _transitionProgress = 0.0;
  double _gradientProgress = 0.0;
  bool _isThresholdFlipped = false;
  int _swipeDRow = 0;
  int _swipeDCol = 0;

  Offset? _dragStartPos;
  Offset _rawDragDelta = Offset.zero;
  Axis? _lockedAxis;
  bool _dragExceededTapSlop = false;
  bool _isTransitioning = false;
  int? _targetTransitionRow;
  int? _targetTransitionCol;
  int _transitionGeneration = 0;
  bool _touchStartedWhileAnimating = false;

  bool get _isAnimating =>
      _isTransitioning ||
      _slideController.isAnimating ||
      _planeOffset != Offset.zero ||
      _transitionProgress > 0.0 ||
      _swipeDRow != 0 ||
      _swipeDCol != 0;

  int get _worldRows => widget.regionsY * widget.regionRows;
  int get _worldCols => widget.regionsX * widget.regionCols;
  int get _totalWorldCells => _worldRows * _worldCols;
  int get _safeCells =>
      _totalWorldCells - (_minesPlaced ? _actualMineCount : widget.mineCount);

  int get _currentRegionMineCount {
    if (!_minesPlaced) {
      return (widget.regionRows * widget.regionCols * widget.mineDensity).round();
    }
    int count = 0;
    final minR = _currentRegionRow * widget.regionRows;
    final maxR = minR + widget.regionRows;
    final minC = _currentRegionCol * widget.regionCols;
    final maxC = minC + widget.regionCols;
    for (int r = minR; r < maxR; r++) {
      for (int c = minC; c < maxC; c++) {
        if (_mines[_globalIndex(r, c)] == 1) {
          count++;
        }
      }
    }
    return count;
  }

  int get _currentRegionFlagCount {
    int count = 0;
    final minR = _currentRegionRow * widget.regionRows;
    final maxR = minR + widget.regionRows;
    final minC = _currentRegionCol * widget.regionCols;
    final maxC = minC + widget.regionCols;
    for (int r = minR; r < maxR; r++) {
      for (int c = minC; c < maxC; c++) {
        if (_cellStates[_globalIndex(r, c)] == CellState.flagged) {
          count++;
        }
      }
    }
    return count;
  }

  int get _currentRegionRemainingMines =>
      _currentRegionMineCount - _currentRegionFlagCount;

  // ── Unlocked region tracking & fade-in animations ──────────────────────────
  final Set<int> _unlockedRegionIndices = <int>{};
  final Map<int, AnimationController> _unlockControllers = <int, AnimationController>{};
  final Map<int, Animation<double>> _unlockAnimations = <int, Animation<double>>{};

  int _regionIndex(int r, int c) => r * widget.regionsX + c;

  void _initUnlockedRegions() {
    _unlockedRegionIndices.clear();
    for (int r = 0; r < widget.regionsY; r++) {
      for (int c = 0; c < widget.regionsX; c++) {
        if (_isRegionAccessible(r, c)) {
          _unlockedRegionIndices.add(_regionIndex(r, c));
        }
      }
    }
  }

  void _checkNewlyUnlockedRegions() {
    if (!widget.lockInaccessibleRegions) return;

    for (int r = 0; r < widget.regionsY; r++) {
      for (int c = 0; c < widget.regionsX; c++) {
        final idx = _regionIndex(r, c);
        if (!_unlockedRegionIndices.contains(idx) && _isRegionAccessible(r, c)) {
          _unlockedRegionIndices.add(idx);
          _startUnlockFadeAnimation(idx);
        }
      }
    }
  }

  void _startUnlockFadeAnimation(int idx) {
    final controller = AnimationController(
      vsync: this,
      duration: widget.regionUnlockFadeDuration,
    );
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOut,
    );
    _unlockControllers[idx] = controller;
    _unlockAnimations[idx] = animation;

    controller.addListener(() {
      setState(() {});
    });

    controller.forward().then((_) {
      if (mounted) {
        _unlockControllers.remove(idx)?.dispose();
        _unlockAnimations.remove(idx);
        setState(() {});
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _currentRegionRow = widget.initialRegionY.clamp(0, widget.regionsY - 1);
    _currentRegionCol = widget.initialRegionX.clamp(0, widget.regionsX - 1);
    _actualMineCount = widget.mineCount;
    _initGridArrays();
    _initUnlockedRegions();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _slideController.addListener(() {
      setState(() {
        if (_offsetAnimation != null) {
          _planeOffset = _offsetAnimation!.value;
        }
        if (_progressAnimation != null) {
          _transitionProgress = _progressAnimation!.value;
        }
        if (_gradientAnimation != null) {
          _gradientProgress = _gradientAnimation!.value;
        }
      });
    });

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.addListener(() {
      setState(() {
        if (!_slideController.isAnimating) {
          _transitionProgress = _fadeAnimation.value;
          _gradientProgress = _fadeAnimation.value;
        }
      });
    });
  }

  @override
  void dispose() {
    for (final controller in _unlockControllers.values) {
      controller.dispose();
    }
    _unlockControllers.clear();
    _unlockAnimations.clear();
    _focusNode.dispose();
    _shockwaveLayerController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _initGridArrays() {
    final size = _totalWorldCells;
    _mines = Uint8List(size);
    _adjacent = Uint8List(size);
    _cellStates = Uint8List(size);
  }

  int _globalIndex(int r, int c) => r * _worldCols + c;

  /// Returns true if region (r, c) is accessible to the player.
  ///
  /// A region is accessible if:
  /// 1. lockInaccessibleRegions is false (disabled).
  /// 2. It is the initial starting region.
  /// 3. It is the current active region.
  /// 4. Any cell inside the region is already revealed.
  /// 5. At least one cell directly adjacent (sharing an orthogonal edge) to it in the world is revealed.
  bool _isRegionAccessible(int r, int c) {
    if (!widget.lockInaccessibleRegions) return true;

    // Out of bounds regions cannot be accessed
    if (r < 0 || r >= widget.regionsY || c < 0 || c >= widget.regionsX) {
      return false;
    }

    // The starting region is always accessible
    final initR = widget.initialRegionY.clamp(0, widget.regionsY - 1);
    final initC = widget.initialRegionX.clamp(0, widget.regionsX - 1);
    if (r == initR && c == initC) {
      return true;
    }

    // Current active region is always accessible
    if (r == _currentRegionRow && c == _currentRegionCol) {
      return true;
    }

    final minR = r * widget.regionRows;
    final maxR = minR + widget.regionRows;
    final minC = c * widget.regionCols;
    final maxC = minC + widget.regionCols;

    // If any cell inside the region is already revealed, it is accessible
    for (int row = minR; row < maxR; row++) {
      for (int col = minC; col < maxC; col++) {
        final state = _cellStates[_globalIndex(row, col)];
        if (state == CellState.revealed || state == CellState.hiddenNumber) {
          return true;
        }
      }
    }

    // A region is accessible if any cell directly adjacent (sharing an edge)
    // to it in the world is revealed.
    // 1. North adjacent cells: row minR - 1, cols minC..maxC - 1
    if (minR - 1 >= 0) {
      final adjRow = minR - 1;
      for (int col = minC; col < maxC; col++) {
        final state = _cellStates[_globalIndex(adjRow, col)];
        if (state == CellState.revealed || state == CellState.hiddenNumber) {
          return true;
        }
      }
    }

    // 2. South adjacent cells: row maxR, cols minC..maxC - 1
    if (maxR < _worldRows) {
      final adjRow = maxR;
      for (int col = minC; col < maxC; col++) {
        final state = _cellStates[_globalIndex(adjRow, col)];
        if (state == CellState.revealed || state == CellState.hiddenNumber) {
          return true;
        }
      }
    }

    // 3. West adjacent cells: col minC - 1, rows minR..maxR - 1
    if (minC - 1 >= 0) {
      final adjCol = minC - 1;
      for (int row = minR; row < maxR; row++) {
        final state = _cellStates[_globalIndex(row, adjCol)];
        if (state == CellState.revealed || state == CellState.hiddenNumber) {
          return true;
        }
      }
    }

    // 4. East adjacent cells: col maxC, rows minR..maxR - 1
    if (maxC < _worldCols) {
      final adjCol = maxC;
      for (int row = minR; row < maxR; row++) {
        final state = _cellStates[_globalIndex(row, adjCol)];
        if (state == CellState.revealed || state == CellState.hiddenNumber) {
          return true;
        }
      }
    }

    return false;
  }

  // ── Mine placement with safe clearing on first click ───────────────────────

  void _placeMines(int safeGlobalRow, int safeGlobalCol) {
    final rng = Random();
    final totalCells = _totalWorldCells;

    // Safe zone around first click in global coordinates
    final safeIndices = <int>{};
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        final r = safeGlobalRow + dr;
        final c = safeGlobalCol + dc;
        if (r >= 0 && r < _worldRows && c >= 0 && c < _worldCols) {
          safeIndices.add(_globalIndex(r, c));
        }
      }
    }

    // Distribute mines efficiently using rejection sampling across global map
    final targetMines = min(widget.mineCount, totalCells - safeIndices.length);
    int placed = 0;
    while (placed < targetMines) {
      final idx = rng.nextInt(totalCells);
      if (!safeIndices.contains(idx) && _mines[idx] == 0) {
        _mines[idx] = 1;
        placed++;
      }
    }

    _actualMineCount = placed;

    // Compute adjacent counts across the entire connected global world map
    for (int r = 0; r < _worldRows; r++) {
      for (int c = 0; c < _worldCols; c++) {
        final idx = _globalIndex(r, c);
        if (_mines[idx] == 1) {
          for (int dr = -1; dr <= 1; dr++) {
            for (int dc = -1; dc <= 1; dc++) {
              if (dr == 0 && dc == 0) continue;
              final nr = r + dr;
              final nc = c + dc;
              if (nr >= 0 && nr < _worldRows && nc >= 0 && nc < _worldCols) {
                _adjacent[_globalIndex(nr, nc)]++;
              }
            }
          }
        }
      }
    }

    _minesPlaced = true;
  }

  // ── Game actions ───────────────────────────────────────────────────────────

  void _addShockwave(int localRow, int localCol) {
    final ctrl = AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 600),
    );

    const cellSize = MinesweeperConfig.cellSize;
    const cellGap = MinesweeperConfig.cellGap;
    const totalTileSize = cellSize + cellGap;

    final centerDx = (localCol + 0.5) * totalTileSize;
    final centerDy = (localRow + 0.5) * totalTileSize;
    final rect = Rect.fromCenter(
      center: Offset(centerDx, centerDy),
      width: cellSize,
      height: cellSize,
    );

    _shockwaveLayerController.addShockwave(
      ShockwaveConfig(
        rect: rect,
        color: AppColors.error,
        controller: ctrl,
        maxExpansion: 18.0,
        cornerRadius: 8.0,
        strokeWidth: 2.5,
      ),
    );
  }

  void _reveal(int localRow, int localCol) {
    if (_gameOver || _gameWon) return;

    if (localRow < 0 ||
        localRow >= widget.regionRows ||
        localCol < 0 ||
        localCol >= widget.regionCols) {
      return;
    }

    final globalRow = _currentRegionRow * widget.regionRows + localRow;
    final globalCol = _currentRegionCol * widget.regionCols + localCol;

    if (globalRow < 0 ||
        globalRow >= _worldRows ||
        globalCol < 0 ||
        globalCol >= _worldCols) {
      return;
    }

    final gIdx = _globalIndex(globalRow, globalCol);

    final state = _cellStates[gIdx];
    if (state == CellState.revealed ||
        state == CellState.flagged ||
        state == CellState.hiddenNumber) {
      return;
    }

    // First click: place mines ensuring this cell & surrounding area are safe
    if (!_minesPlaced) {
      _placeMines(globalRow, globalCol);
    }

    if (_mines[gIdx] == 1) {
      _cellStates[gIdx] = CellState.activatedMine;
      _addShockwave(localRow, localCol);
      setState(() {
        _gameOver = true;
        _revealAllMines();
      });
      Future.delayed(BaseGameConfig.failTransitionDelay, () {
        if (mounted) widget.onFail();
      });
      return;
    }

    setState(() {
      final newlyRevealed = <int>[];
      _floodReveal(globalRow, globalCol, newlyRevealed);
      _checkWin();

      if (widget.gameState.isCurrentGameAnomaly &&
          !_gameOver &&
          !_gameWon) {
        bool revealedZero = newlyRevealed.any((i) => _adjacent[i] == 0);
        if (revealedZero) {
          final candidates = newlyRevealed
              .where((i) {
                final r = i ~/ _worldCols;
                final c = i % _worldCols;
                return _adjacent[i] > 0 &&
                    r > 0 &&
                    r < _worldRows - 1 &&
                    c > 0 &&
                    c < _worldCols - 1;
              })
              .toList();
          if (candidates.isNotEmpty) {
            final chosen = candidates[Random().nextInt(candidates.length)];
            _cellStates[chosen] = CellState.hiddenNumber;
          }
        }
      }

      _checkNewlyUnlockedRegions();
    });
  }

  /// Iterative non-recursive BFS flood fill that stops on region edges
  void _floodReveal(int startGlobalRow, int startGlobalCol, [List<int>? newlyRevealed]) {
    final startIdx = _globalIndex(startGlobalRow, startGlobalCol);
    if (_cellStates[startIdx] != CellState.unrevealed ||
        _mines[startIdx] == 1) {
      return;
    }

    final regionR = startGlobalRow ~/ widget.regionRows;
    final regionC = startGlobalCol ~/ widget.regionCols;
    final minR = regionR * widget.regionRows;
    final maxR = minR + widget.regionRows;
    final minC = regionC * widget.regionCols;
    final maxC = minC + widget.regionCols;

    final queue = <int>[startIdx];
    _cellStates[startIdx] = CellState.revealed;
    _revealedCount++;
    newlyRevealed?.add(startIdx);

    int head = 0;
    while (head < queue.length) {
      final idx = queue[head++];
      if (_adjacent[idx] == 0) {
        final r = idx ~/ _worldCols;
        final c = idx % _worldCols;

        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;
            final nr = r + dr;
            final nc = c + dc;
            if (nr >= minR && nr < maxR && nc >= minC && nc < maxC) {
              final nIdx = _globalIndex(nr, nc);
              if (_cellStates[nIdx] == CellState.unrevealed &&
                  _mines[nIdx] == 0) {
                _cellStates[nIdx] = CellState.revealed;
                _revealedCount++;
                newlyRevealed?.add(nIdx);
                queue.add(nIdx);
              }
            }
          }
        }
      }
    }
  }

  void _toggleFlag(int localRow, int localCol) {
    if (_gameOver || _gameWon) return;

    if (localRow < 0 ||
        localRow >= widget.regionRows ||
        localCol < 0 ||
        localCol >= widget.regionCols) {
      return;
    }

    final globalRow = _currentRegionRow * widget.regionRows + localRow;
    final globalCol = _currentRegionCol * widget.regionCols + localCol;

    if (globalRow < 0 ||
        globalRow >= _worldRows ||
        globalCol < 0 ||
        globalCol >= _worldCols) {
      return;
    }

    final gIdx = _globalIndex(globalRow, globalCol);
    final state = _cellStates[gIdx];
    if (state == CellState.revealed || state == CellState.hiddenNumber) return;

    setState(() {
      if (state == CellState.flagged) {
        _cellStates[gIdx] = CellState.unrevealed;
        _flagCount--;
        if (_mines[gIdx] == 1) {
          _correctlyFlaggedMines--;
        }
      } else {
        _cellStates[gIdx] = CellState.flagged;
        _flagCount++;
        _totalFlagsPlacedInSession++;
        if (_mines[gIdx] == 1) {
          _correctlyFlaggedMines++;
        } else {
          _hasMisplacedFlag = true;
        }
      }
      _checkWin();
    });
  }

  void _chord(int localRow, int localCol) {
    if (_gameOver || _gameWon) return;

    if (localRow < 0 ||
        localRow >= widget.regionRows ||
        localCol < 0 ||
        localCol >= widget.regionCols) {
      return;
    }

    final globalRow = _currentRegionRow * widget.regionRows + localRow;
    final globalCol = _currentRegionCol * widget.regionCols + localCol;

    if (globalRow < 0 ||
        globalRow >= _worldRows ||
        globalCol < 0 ||
        globalCol >= _worldCols) {
      return;
    }

    final gIdx = _globalIndex(globalRow, globalCol);

    if (_cellStates[gIdx] != CellState.revealed || _adjacent[gIdx] <= 0) {
      return;
    }

    final minR = _currentRegionRow * widget.regionRows;
    final maxR = minR + widget.regionRows;
    final minC = _currentRegionCol * widget.regionCols;
    final maxC = minC + widget.regionCols;

    int flaggedCount = 0;
    final unflaggedNeighbors = <Point<int>>[];

    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = globalRow + dr;
        final nc = globalCol + dc;
        if (nr >= 0 && nr < _worldRows && nc >= 0 && nc < _worldCols) {
          final nIdx = _globalIndex(nr, nc);
          final nState = _cellStates[nIdx];
          if (nState == CellState.flagged) {
            flaggedCount++;
          } else if (nState == CellState.unrevealed) {
            // Middle click chording MUST NOT interact with or reveal cells in other regions
            if (nr >= minR && nr < maxR && nc >= minC && nc < maxC) {
              unflaggedNeighbors.add(Point(nr, nc));
            }
          }
        }
      }
    }

    if (flaggedCount != _adjacent[gIdx] || unflaggedNeighbors.isEmpty) {
      return;
    }

    bool hitMine = false;
    int minesRevealedByChord = 0;

    setState(() {
      final newlyRevealed = <int>[];
      for (final pt in unflaggedNeighbors) {
        final nIdx = _globalIndex(pt.x, pt.y);
        if (_mines[nIdx] == 1) {
          hitMine = true;
          minesRevealedByChord++;
          _cellStates[nIdx] = CellState.activatedMine;
          final lRow = pt.x - (_currentRegionRow * widget.regionRows);
          final lCol = pt.y - (_currentRegionCol * widget.regionCols);
          _addShockwave(lRow, lCol);
        } else {
          _floodReveal(pt.x, pt.y, newlyRevealed);
        }
      }

      if (widget.gameState.isCurrentGameAnomaly &&
          !hitMine &&
          !_gameOver &&
          !_gameWon) {
        bool revealedZero = newlyRevealed.any((i) => _adjacent[i] == 0);
        if (revealedZero) {
          final candidates = newlyRevealed
              .where((i) {
                final r = i ~/ _worldCols;
                final c = i % _worldCols;
                return _adjacent[i] > 0 &&
                    r > 0 &&
                    r < _worldRows - 1 &&
                    c > 0 &&
                    c < _worldCols - 1;
              })
              .toList();
          if (candidates.isNotEmpty) {
            final chosen = candidates[Random().nextInt(candidates.length)];
            _cellStates[chosen] = CellState.hiddenNumber;
          }
        }
      }

      if (minesRevealedByChord >=
              AchievementTargets.minesweeperChordMinesTarget &&
          widget.gameState.canTriggerAchievements) {
        if (widget.gameState.getAchievementStatus(
              'minesweeper_chord_multi_mine',
            ) ==
            AchievementStatus.locked) {
          widget.gameState.setAchievementStatus(
            'minesweeper_chord_multi_mine',
            AchievementStatus.unlocked,
          );
        }
      }

      if (hitMine) {
        _gameOver = true;
        _revealAllMines();
        Future.delayed(BaseGameConfig.failTransitionDelay, () {
          if (mounted) widget.onFail();
        });
      } else {
        _checkWin();
      }

      _checkNewlyUnlockedRegions();
    });
  }

  void _revealAllMines() {
    final minR = _currentRegionRow * widget.regionRows;
    final maxR = minR + widget.regionRows;
    final minC = _currentRegionCol * widget.regionCols;
    final maxC = minC + widget.regionCols;
    for (int r = minR; r < maxR; r++) {
      for (int c = minC; c < maxC; c++) {
        final i = _globalIndex(r, c);
        if (_mines[i] == 1 && _cellStates[i] != CellState.activatedMine) {
          _cellStates[i] = CellState.revealedMine;
        }
      }
    }
  }

  void _checkWin() {
    if (_gameOver || _gameWon) return;

    // Requirement 1: Reveal ALL non-mine cells in the entire world map
    final allSafeRevealed = _revealedCount >= _safeCells;

    // Requirement 2: Flag ALL mine cells in the entire world map
    final allMinesFlagged =
        _correctlyFlaggedMines == _actualMineCount &&
        _flagCount == _actualMineCount;

    final isNoFlagsAchievementTrigger =
        allSafeRevealed &&
        _totalFlagsPlacedInSession <=
            AchievementTargets.minesweeperNoFlagsPlacedTarget;

    if (isNoFlagsAchievementTrigger &&
        widget.gameState.canTriggerAchievements) {
      if (widget.gameState.getAchievementStatus('minesweeper_no_flags') ==
          AchievementStatus.locked) {
        widget.gameState.setAchievementStatus(
          'minesweeper_no_flags',
          AchievementStatus.unlocked,
        );
      }
    }

    if (allSafeRevealed && allMinesFlagged) {
      _gameWon = true;
      if (!_hasMisplacedFlag) {
        widget.gameState.recordFlawlessMinesweeperWin();
      }
      Future.delayed(BaseGameConfig.winTransitionDelay, () {
        if (mounted) widget.onComplete();
      });
    }
  }

  // ── Swipe Gestures & Region Navigation ────────────────────────────────────

  double _applyEaseOut(double delta, bool canMove) {
    final maxVisualDelta = canMove ? 100.0 : 35.0;
    final sign = delta.sign;
    final abs = delta.abs();
    return sign * maxVisualDelta * (1.0 - exp(-abs / (maxVisualDelta * 1.5)));
  }

  void _finishTransitionImmediately() {
    _transitionGeneration++;
    if (!_isTransitioning &&
        !_slideController.isAnimating &&
        _planeOffset == Offset.zero &&
        _transitionProgress == 0.0) {
      return;
    }
    _slideController.stop();
    _fadeController.stop();
    if (_isTransitioning &&
        _targetTransitionRow != null &&
        _targetTransitionCol != null) {
      _currentRegionRow = _targetTransitionRow!;
      _currentRegionCol = _targetTransitionCol!;
    }
    _targetTransitionRow = null;
    _targetTransitionCol = null;
    _planeOffset = Offset.zero;
    _fadeController.value = 0.0;
    _transitionProgress = 0.0;
    _gradientProgress = 0.0;
    _offsetAnimation = null;
    _progressAnimation = null;
    _gradientAnimation = null;
    _isThresholdFlipped = false;
    _swipeDRow = 0;
    _swipeDCol = 0;
    _isTransitioning = false;
  }

  void _onPointerDown(PointerDownEvent event) {
    _touchStartedWhileAnimating = _isAnimating;
    if (_isTransitioning || _slideController.isAnimating) {
      setState(() {
        _finishTransitionImmediately();
      });
    }
    _dragStartPos = event.position;
    _rawDragDelta = Offset.zero;
    _lockedAxis = null;
    _dragExceededTapSlop = false;
    _isThresholdFlipped = false;
    _slideController.stop();
    _fadeController.stop();
    _fadeController.value = 0.0;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_dragStartPos == null) return;
    final delta = event.position - _dragStartPos!;
    _rawDragDelta = delta;

    if (delta.distance > 8.0) {
      _dragExceededTapSlop = true;
    }

    if (delta.distance > 4.0) {
      _lockedAxis ??= (delta.dx.abs() >= delta.dy.abs())
          ? Axis.horizontal
          : Axis.vertical;

      int dRow = 0;
      int dCol = 0;
      double rawComponent = 0.0;

      if (_lockedAxis == Axis.horizontal) {
        rawComponent = delta.dx;
        if (rawComponent < -1.0) {
          dCol = 1;
        } else if (rawComponent > 1.0) {
          dCol = -1;
        } else {
          dCol = 0;
        }
      } else {
        rawComponent = delta.dy;
        if (rawComponent < -1.0) {
          dRow = 1;
        } else if (rawComponent > 1.0) {
          dRow = -1;
        } else {
          dRow = 0;
        }
      }

      final targetRow = _currentRegionRow + dRow;
      final targetCol = _currentRegionCol + dCol;
      final canTransition = (dRow != 0 || dCol != 0) &&
          targetRow >= 0 &&
          targetRow < widget.regionsY &&
          targetCol >= 0 &&
          targetCol < widget.regionsX &&
          _isRegionAccessible(targetRow, targetCol);

      final visualDelta = _applyEaseOut(rawComponent, canTransition);

      double visualDx = 0.0;
      double visualDy = 0.0;
      if (_lockedAxis == Axis.horizontal) {
        visualDx = visualDelta;
      } else {
        visualDy = visualDelta;
      }

      final isOverThreshold =
          canTransition && rawComponent.abs() >= widget.swipeThreshold;

      if (isOverThreshold) {
        if (!_isThresholdFlipped || _swipeDRow != dRow || _swipeDCol != dCol) {
          _isThresholdFlipped = true;
          _swipeDRow = dRow;
          _swipeDCol = dCol;
          _fadeController.forward();
        }
      } else {
        if (_isThresholdFlipped) {
          _isThresholdFlipped = false;
          _fadeController.reverse();
        }
        if (canTransition) {
          _swipeDRow = dRow;
          _swipeDCol = dCol;
        } else {
          _swipeDRow = 0;
          _swipeDCol = 0;
        }
      }

      setState(() {
        _planeOffset = Offset(visualDx, visualDy);
      });
    } else if (_lockedAxis != null) {
      if (_isThresholdFlipped) {
        _isThresholdFlipped = false;
        _fadeController.reverse();
      }
      setState(() {
        _planeOffset = delta;
        _swipeDRow = 0;
        _swipeDCol = 0;
      });
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _touchStartedWhileAnimating = false;
    if (_dragStartPos == null) return;
    final totalDelta = _rawDragDelta;
    final lockedAxis = _lockedAxis;
    _dragStartPos = null;
    _lockedAxis = null;

    final double threshold = widget.swipeThreshold;
    int dRow = 0;
    int dCol = 0;

    if (lockedAxis == Axis.horizontal && totalDelta.dx.abs() >= threshold) {
      // Swipe Left (dx <= -threshold) -> transition East (dCol = +1)
      // Swipe Right (dx >= threshold) -> transition West (dCol = -1)
      dCol = totalDelta.dx < 0 ? 1 : -1;
    } else if (lockedAxis == Axis.vertical && totalDelta.dy.abs() >= threshold) {
      // Swipe Up (dy <= -threshold) -> transition South (dRow = +1)
      // Swipe Down (dy >= threshold) -> transition North (dRow = -1)
      dRow = totalDelta.dy < 0 ? 1 : -1;
    }

    final targetRow = _currentRegionRow + dRow;
    final targetCol = _currentRegionCol + dCol;
    final canTransition = (dRow != 0 || dCol != 0) &&
        targetRow >= 0 &&
        targetRow < widget.regionsY &&
        targetCol >= 0 &&
        targetCol < widget.regionsX &&
        _isRegionAccessible(targetRow, targetCol);

    if (canTransition) {
      _animateTransition(dRow, dCol, targetRow, targetCol);
    } else {
      if (_isThresholdFlipped) {
        _isThresholdFlipped = false;
        _fadeController.reverse();
      }
      _animateSnapBack();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _touchStartedWhileAnimating = false;
    _dragStartPos = null;
    _lockedAxis = null;
    if (_isThresholdFlipped) {
      _isThresholdFlipped = false;
      _fadeController.reverse();
    }
    _animateSnapBack();
  }

  void _animateSnapBack() {
    _slideController.stop();
    _isThresholdFlipped = false;
    _fadeController.reverse();
    setState(() {
      _targetTransitionRow = null;
      _targetTransitionCol = null;
      _swipeDRow = 0;
      _swipeDCol = 0;
    });
    if (_planeOffset == Offset.zero) {
      setState(() {
        _gradientAnimation = null;
        _offsetAnimation = null;
        _progressAnimation = null;
        _swipeDRow = 0;
        _swipeDCol = 0;
        _transitionProgress = 0.0;
        _gradientProgress = 0.0;
      });
      return;
    }
    final gen = ++_transitionGeneration;
    _offsetAnimation = Tween<Offset>(
      begin: _planeOffset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOut,
      ),
    );
    _progressAnimation = Tween<double>(
      begin: _transitionProgress,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOut,
      ),
    );
    _gradientAnimation = Tween<double>(
      begin: _gradientProgress,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOut,
      ),
    );
    _slideController.duration = const Duration(milliseconds: 180);
    _slideController.forward(from: 0.0).then((_) {
      if (!mounted || _transitionGeneration != gen) return;
      setState(() {
        _planeOffset = Offset.zero;
        _fadeController.value = 0.0;
        _transitionProgress = 0.0;
        _gradientProgress = 0.0;
        _offsetAnimation = null;
        _progressAnimation = null;
        _gradientAnimation = null;
        _isThresholdFlipped = false;
        _swipeDRow = 0;
        _swipeDCol = 0;
      });
    }).catchError((_) {});
  }

  void _animateTransition(
    int dRow,
    int dCol,
    int targetRow,
    int targetCol,
  ) {
    if (_isTransitioning || _slideController.isAnimating) {
      _finishTransitionImmediately();
    }
    _isTransitioning = true;
    _targetTransitionRow = targetRow;
    _targetTransitionCol = targetCol;
    _slideController.stop();
    _fadeController.stop();
    _fadeController.value = 1.0;

    const double totalTileSize =
        MinesweeperConfig.cellSize + MinesweeperConfig.cellGap;
    const double borderWidth = 1.5;
    final double panelWidth =
        widget.regionCols * totalTileSize + (widget.boardPadding + borderWidth) * 2;
    final double panelHeight =
        widget.regionRows * totalTileSize + (widget.boardPadding + borderWidth) * 2;
    final double strideX = panelWidth + widget.panelGap;
    final double strideY = panelHeight + widget.panelGap;
    final targetOffset = Offset(-dCol * strideX, -dRow * strideY);
    _swipeDRow = dRow;
    _swipeDCol = dCol;

    _offsetAnimation = Tween<Offset>(
      begin: _planeOffset,
      end: targetOffset,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      ),
    );
    _progressAnimation = Tween<double>(
      begin: _transitionProgress,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      ),
    );
    _gradientAnimation = Tween<double>(
      begin: _gradientProgress,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      ),
    );

    final gen = ++_transitionGeneration;
    _slideController.duration = const Duration(milliseconds: 220);
    _slideController.forward(from: 0.0).then((_) {
      if (!mounted || _transitionGeneration != gen) return;
      setState(() {
        _currentRegionRow = targetRow;
        _currentRegionCol = targetCol;
        _targetTransitionRow = null;
        _targetTransitionCol = null;
        _planeOffset = Offset.zero;
        _fadeController.value = 0.0;
        _transitionProgress = 0.0;
        _gradientProgress = 0.0;
        _gradientAnimation = null;
        _offsetAnimation = null;
        _progressAnimation = null;
        _isThresholdFlipped = false;
        _swipeDRow = 0;
        _swipeDCol = 0;
        _isTransitioning = false;
      });
    }).catchError((_) {});
  }

  void _navigateRegion(int dRow, int dCol) {
    if (_isTransitioning || _slideController.isAnimating) {
      setState(() {
        _finishTransitionImmediately();
      });
    }
    final nextRow = (_currentRegionRow + dRow).clamp(0, widget.regionsY - 1);
    final nextCol = (_currentRegionCol + dCol).clamp(0, widget.regionsX - 1);
    if ((nextRow != _currentRegionRow || nextCol != _currentRegionCol) &&
        _isRegionAccessible(nextRow, nextCol)) {
      _animateTransition(dRow, dCol, nextRow, nextCol);
    }
  }

  // ── Cell Interaction Handlers ──────────────────────────────────────────────

  void _handleCellTap(int localRow, int localCol) {
    if (_touchStartedWhileAnimating ||
        _dragExceededTapSlop ||
        _gameOver ||
        _gameWon ||
        _isAnimating) {
      return;
    }

    final globalRow = _currentRegionRow * widget.regionRows + localRow;
    final globalCol = _currentRegionCol * widget.regionCols + localCol;
    if (globalRow < 0 ||
        globalRow >= _worldRows ||
        globalCol < 0 ||
        globalCol >= _worldCols) {
      return;
    }

    final gIdx = _globalIndex(globalRow, globalCol);
    final state = _cellStates[gIdx];

    if (state == CellState.unrevealed) {
      _reveal(localRow, localCol);
    } else if (state == CellState.revealed && _adjacent[gIdx] > 0) {
      _chord(localRow, localCol);
    }
  }

  void _handleCellLongPress(int localRow, int localCol) {
    if (_touchStartedWhileAnimating ||
        _dragExceededTapSlop ||
        _gameOver ||
        _gameWon ||
        _isAnimating) {
      return;
    }

    final globalRow = _currentRegionRow * widget.regionRows + localRow;
    final globalCol = _currentRegionCol * widget.regionCols + localCol;
    if (globalRow < 0 ||
        globalRow >= _worldRows ||
        globalCol < 0 ||
        globalCol >= _worldCols) {
      return;
    }

    final gIdx = _globalIndex(globalRow, globalCol);
    final state = _cellStates[gIdx];

    if (state == CellState.unrevealed || state == CellState.flagged) {
      HapticFeedback.mediumImpact();
      _toggleFlag(localRow, localCol);
    }
  }

  Widget _buildCellForPanel(
    int dr,
    int dc,
    int r,
    int c,
    double totalTileSize,
    double cellGap,
  ) {
    final regionRow = _currentRegionRow + dr;
    final regionCol = _currentRegionCol + dc;
    final globalRow = regionRow * widget.regionRows + r;
    final globalCol = regionCol * widget.regionCols + c;
    final gIdx = _globalIndex(globalRow, globalCol);

    final isCurrentPanel = (dr == 0 && dc == 0);
    final isNeighbor = !isCurrentPanel;
    final isInteractable = isCurrentPanel && !_isAnimating;

    return SizedBox(
      width: totalTileSize,
      height: totalTileSize,
      child: _RegionCellWidget(
        cellState: _cellStates[gIdx],
        adjacentMines: _adjacent[gIdx],
        hasMine: _mines[gIdx] == 1,
        gap: cellGap,
        gameOver: _gameOver,
        gameWon: _gameWon,
        isNeighbor: isNeighbor,
        isInteractable: isInteractable,
        backgroundOpacity: 1.0,
        contentOpacity: 1.0,
        onTap: isInteractable ? () => _handleCellTap(r, c) : null,
        onLongPress: isInteractable ? () => _handleCellLongPress(r, c) : null,
        longTapDuration: widget.longTapDuration,
        touchHighlightColor: widget.touchHighlightColor,
        touchHighlightFadeDuration: widget.touchHighlightFadeDuration,
      ),
    );
  }

  Widget _buildRegionPanel(
    int dr,
    int dc,
    double totalTileSize,
    double cellGap,
    double paddingAmount,
    double borderWidth,
    double panelGap,
  ) {
    final regionRow = _currentRegionRow + dr;
    final regionCol = _currentRegionCol + dc;

    if (regionRow < 0 ||
        regionRow >= widget.regionsY ||
        regionCol < 0 ||
        regionCol >= widget.regionsX) {
      return const SizedBox.shrink();
    }

    final activeGridWidth = widget.regionCols * totalTileSize;
    final activeGridHeight = widget.regionRows * totalTileSize;
    final panelWidth =
        activeGridWidth + (paddingAmount * 2) + (borderWidth * 2);
    final panelHeight =
        activeGridHeight + (paddingAmount * 2) + (borderWidth * 2);

    final strideX = panelWidth + panelGap;
    final strideY = panelHeight + panelGap;
    final panelInset = paddingAmount + borderWidth;
    final peekMarginX = widget.peekDepth * totalTileSize + panelInset + panelGap;
    final peekMarginY = widget.peekDepth * totalTileSize + panelInset + panelGap;

    final panelLeft = peekMarginX + (dc * strideX) + _planeOffset.dx;
    final panelTop = peekMarginY + (dr * strideY) + _planeOffset.dy;

    final neighborBaseOpacity =
        (1.0 - widget.neighborRegionTransparency).clamp(0.0, 1.0);
    final p = _transitionProgress.clamp(0.0, 1.0);
    final isTransition = _swipeDRow != 0 || _swipeDCol != 0;

    double panelOpacity;
    if (dr == 0 && dc == 0) {
      // Current region: start at 0% transparency (1.0 opacity) and fade to 50% transparency (neighborBaseOpacity)
      panelOpacity = 1.0 - (p * (1.0 - neighborBaseOpacity));
    } else if (isTransition && dr == _swipeDRow && dc == _swipeDCol) {
      // Potential new selected region: start at 50% transparency (neighborBaseOpacity) and fade to 0% transparency (1.0 opacity)
      panelOpacity = neighborBaseOpacity + (p * (1.0 - neighborBaseOpacity));
    } else {
      // Neighbor regions: 50% transparency (neighborBaseOpacity)
      panelOpacity = neighborBaseOpacity;
    }

    final regionIdx = _regionIndex(regionRow, regionCol);
    final unlockFade = _unlockAnimations[regionIdx]?.value ?? 1.0;
    panelOpacity = (panelOpacity * unlockFade).clamp(0.0, 1.0);

    return Positioned(
      key: ValueKey('region_panel_${dr}_$dc'),
      left: panelLeft,
      top: panelTop,
      width: panelWidth,
      height: panelHeight,
      child: Opacity(
        opacity: panelOpacity.clamp(0.0, 1.0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Panel Container Box (Card Fill + Shadow + Normal Border)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  key: const ValueKey('actual_panel_container'),
                  decoration: BoxDecoration(
                    color: AppColors.panelMedium,
                    borderRadius:
                        BorderRadius.circular(widget.panelCornerRadius),
                    border: Border.all(
                      color: AppColors.outlineDim,
                      width: borderWidth,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Cell Grid (Entire Region)
            Positioned(
              left: paddingAmount + borderWidth,
              top: paddingAmount + borderWidth,
              width: activeGridWidth,
              height: activeGridHeight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int r = 0; r < widget.regionRows; r++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int c = 0; c < widget.regionCols; c++)
                          _buildCellForPanel(
                            dr,
                            dc,
                            r,
                            c,
                            totalTileSize,
                            cellGap,
                          ),
                      ],
                    ),
                ],
              ),
            ),

            // 3. Shockwave Layer (Active Region Only)
            if (dr == 0 && dc == 0)
              Positioned(
                left: paddingAmount + borderWidth,
                top: paddingAmount + borderWidth,
                width: activeGridWidth,
                height: activeGridHeight,
                child: IgnorePointer(
                  child: ShockwaveLayer(
                    controller: _shockwaveLayerController,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard(
    double totalTileSize,
    double cellGap,
    double paddingAmount,
    double borderWidth,
    double panelGap,
  ) {
    final activeGridWidth = widget.regionCols * totalTileSize;
    final activeGridHeight = widget.regionRows * totalTileSize;
    final panelWidth =
        activeGridWidth + (paddingAmount * 2) + (borderWidth * 2);
    final panelHeight =
        activeGridHeight + (paddingAmount * 2) + (borderWidth * 2);
    final panelInset = paddingAmount + borderWidth;
    final peekMarginX = widget.peekDepth * totalTileSize + panelInset + panelGap;
    final peekMarginY = widget.peekDepth * totalTileSize + panelInset + panelGap;

    final viewportWidth = panelWidth + (2 * peekMarginX);
    final viewportHeight = panelHeight + (2 * peekMarginY);

    final nearAlpha =
        (1.0 - widget.gradientNearTransparency).clamp(0.0, 1.0);
    final farAlpha =
        (1.0 - widget.gradientFarTransparency).clamp(0.0, 1.0);

    // Stable rendering order:
    // 1. Non-active, non-incoming neighbor panels
    // 2. Outgoing center panel (0, 0)
    // 3. Incoming panel (_swipeDRow, _swipeDCol)
    final otherPanels = <(int, int)>[];
    (int, int)? incomingPanel;
    (int, int)? centerPanel;

    final panelsToRender = <(int, int)>{};

    // 1. Current selected region and its 8 neighbors (only if accessible)
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        final r = _currentRegionRow + dr;
        final c = _currentRegionCol + dc;
        if (r >= 0 && r < widget.regionsY && c >= 0 && c < widget.regionsX) {
          if (_isRegionAccessible(r, c)) {
            panelsToRender.add((dr, dc));
          }
        }
      }
    }

    // 2. The MOMENT the player starts dragging (or transitioning),
    // load the neighbors of the potential new selected region (only if accessible)!
    if (_swipeDRow != 0 || _swipeDCol != 0) {
      for (int r = -1; r <= 1; r++) {
        for (int c = -1; c <= 1; c++) {
          final pDr = _swipeDRow + r;
          final pDc = _swipeDCol + c;
          final targetR = _currentRegionRow + pDr;
          final targetC = _currentRegionCol + pDc;
          if (targetR >= 0 &&
              targetR < widget.regionsY &&
              targetC >= 0 &&
              targetC < widget.regionsX) {
            if (_isRegionAccessible(targetR, targetC)) {
              panelsToRender.add((pDr, pDc));
            }
          }
        }
      }
    }

    for (final (dr, dc) in panelsToRender) {
      if (dr == 0 && dc == 0) {
        centerPanel = (0, 0);
      } else if (_swipeDRow != 0 || _swipeDCol != 0) {
        if (dr == _swipeDRow && dc == _swipeDCol) {
          incomingPanel = (dr, dc);
        } else {
          otherPanels.add((dr, dc));
        }
      } else {
        otherPanels.add((dr, dc));
      }
    }

    final panelOrder = <(int, int)>[
      ...otherPanels,
      ?centerPanel,
      ?incomingPanel,
    ];

    return SizedBox(
      width: viewportWidth,
      height: viewportHeight,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (final (dr, dc) in panelOrder)
              _buildRegionPanel(
                dr,
                dc,
                totalTileSize,
                cellGap,
                paddingAmount,
                borderWidth,
                panelGap,
              ),

            // ── Game Area Gradient Overlay ───────────────────────────────
            // Overlaid on top of the entire game area. Sized so it leaves the
            // centered active region unaffected. Splits H and V linear gradients
            // diagonally at the corners so they do not overlap.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  key: const ValueKey('game_area_gradient_overlay'),
                  painter: GameAreaGradientPainter(
                    centerRect: Rect.fromLTWH(
                      peekMarginX,
                      peekMarginY,
                      panelWidth,
                      panelHeight,
                    ),
                    nearAlpha: nearAlpha,
                    farAlpha: farAlpha,
                    color: AppColors.surface,
                    style: widget.overlayGradientStyle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const cellSize = MinesweeperConfig.cellSize;
    const cellGap = MinesweeperConfig.cellGap;
    const totalTileSize = cellSize + cellGap;
    final paddingAmount = widget.boardPadding;
    const borderWidth = 1.5;
    final panelGap = widget.panelGap;
    final activeGridWidth = widget.regionCols * totalTileSize;
    final activeGridHeight = widget.regionRows * totalTileSize;
    final panelWidth =
        activeGridWidth + (paddingAmount * 2) + (borderWidth * 2);
    final panelHeight =
        activeGridHeight + (paddingAmount * 2) + (borderWidth * 2);
    final strideX = panelWidth + panelGap;
    final strideY = panelHeight + panelGap;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
              event.logicalKey == LogicalKeyboardKey.keyW) {
            _navigateRegion(-1, 0);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
              event.logicalKey == LogicalKeyboardKey.keyS) {
            _navigateRegion(1, 0);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
              event.logicalKey == LogicalKeyboardKey.keyA) {
            _navigateRegion(0, -1);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
              event.logicalKey == LogicalKeyboardKey.keyD) {
            _navigateRegion(0, 1);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        children: [
          GameScaffold(
            gameState: widget.gameState,
            spacing: 0,
            showHeader: false,
            isScrollable: false,
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: _buildBoard(
                totalTileSize,
                cellGap,
                paddingAmount,
                borderWidth,
                panelGap,
              ),
            ),
          ),

          // ── Top Header Controls (Mine Counter, Minimap, Pause Button) ───────
          // Aligned horizontally with the resting position of the selected region:
          // Left edge of the mine counter aligns with the left edge of the region.
          // Minimap is centered in the region.
          // Right edge of the pause button aligns with the right edge of the region.
          // They remain stationary at the top and do not move during swipe.
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: panelWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: _RegionMineCounterBadge(
                          remainingMines: _currentRegionRemainingMines,
                        ),
                      ),
                    ),
                    RegionMiniMapSelector(
                      regionsX: widget.regionsX,
                      regionsY: widget.regionsY,
                      currentRegionRow: _currentRegionRow,
                      currentRegionCol: _currentRegionCol,
                      selectedRegionRow: (_isThresholdFlipped || _isTransitioning)
                          ? (_currentRegionRow + _swipeDRow)
                          : _currentRegionRow,
                      selectedRegionCol: (_isThresholdFlipped || _isTransitioning)
                          ? (_currentRegionCol + _swipeDCol)
                          : _currentRegionCol,
                      regionRows: widget.regionRows,
                      regionCols: widget.regionCols,
                      cellStates: _cellStates,
                      worldCols: _worldCols,
                      isRegionAccessible: _isRegionAccessible,
                      unlockFadeDuration: widget.regionUnlockFadeDuration,
                      planeOffset: _planeOffset,
                      strideX: strideX,
                      strideY: strideY,
                      onTap: () => showMinimapPopup(context),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topRight,
                        child: _RegionPauseButton(
                          onTap: widget.onPause,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Game Area Gradient Overlay Painter ───────────────────────────────────────

class GameAreaGradientPainter extends CustomPainter {
  final Rect centerRect;
  final double nearAlpha;
  final double farAlpha;
  final Color color;
  final OverlayGradientStyle style;

  const GameAreaGradientPainter({
    required this.centerRect,
    required this.nearAlpha,
    required this.farAlpha,
    required this.color,
    this.style = OverlayGradientStyle.splitLinear,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final x1 = centerRect.left;
    final y1 = centerRect.top;
    final x2 = centerRect.right;
    final y2 = centerRect.bottom;

    final nearColor = color.withValues(alpha: nearAlpha);
    final farColor = color.withValues(alpha: farAlpha);

    if (style == OverlayGradientStyle.radial) {
      final clipPath = Path()
        ..addRect(Rect.fromLTWH(0, 0, w, h))
        ..addRect(centerRect)
        ..fillType = PathFillType.evenOdd;

      canvas.save();
      canvas.clipPath(clipPath);

      final center = Offset(w / 2, h / 2);
      final radius = sqrt((w / 2) * (w / 2) + (h / 2) * (h / 2));
      final innerRadius = min(centerRect.width, centerRect.height) / 2;
      final tInner = (innerRadius / radius).clamp(0.0, 1.0);

      final paint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          [nearColor, nearColor, farColor],
          [0.0, tInner, 1.0],
        );
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
      canvas.restore();
      return;
    }

    // ── Split Linear Gradients (One H, One V) ─────────────────────────
    // Diagonal splits at the 4 corners:
    // Top-Left: (0, 0) <-> (x1, y1)
    // Top-Right: (w, 0) <-> (x2, y1)
    // Bottom-Left: (0, h) <-> (x1, y2)
    // Bottom-Right: (w, h) <-> (x2, y2)
    //
    // The horizontal and vertical linear gradients meet precisely at
    // these diagonal miter lines without overlapping. Along each diagonal,
    // the progress parameters match identically, ensuring continuous
    // color blending with zero overlap or double-darkening artifact.

    // 1. Top Trapezoid (Vertical Linear Gradient)
    final topPath = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(x2, y1)
      ..lineTo(x1, y1)
      ..close();

    final topPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, y1),
        Offset(0, 0),
        [nearColor, farColor],
      );
    canvas.drawPath(topPath, topPaint);

    // 2. Bottom Trapezoid (Vertical Linear Gradient)
    final bottomPath = Path()
      ..moveTo(x1, y2)
      ..lineTo(x2, y2)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final bottomPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, y2),
        Offset(0, h),
        [nearColor, farColor],
      );
    canvas.drawPath(bottomPath, bottomPaint);

    // 3. Left Trapezoid (Horizontal Linear Gradient)
    final leftPath = Path()
      ..moveTo(0, 0)
      ..lineTo(x1, y1)
      ..lineTo(x1, y2)
      ..lineTo(0, h)
      ..close();

    final leftPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(x1, 0),
        Offset(0, 0),
        [nearColor, farColor],
      );
    canvas.drawPath(leftPath, leftPaint);

    // 4. Right Trapezoid (Horizontal Linear Gradient)
    final rightPath = Path()
      ..moveTo(x2, y1)
      ..lineTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(x2, y2)
      ..close();

    final rightPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(x2, 0),
        Offset(w, 0),
        [nearColor, farColor],
      );
    canvas.drawPath(rightPath, rightPaint);
  }

  @override
  bool shouldRepaint(covariant GameAreaGradientPainter oldDelegate) {
    return oldDelegate.centerRect != centerRect ||
        oldDelegate.nearAlpha != nearAlpha ||
        oldDelegate.farAlpha != farAlpha ||
        oldDelegate.color != color ||
        oldDelegate.style != style;
  }
}

// ── Region Mine Counter Badge ────────────────────────────────────────────────

const double _headerControlHeight = 28.0;

class _RegionMineCounterBadge extends StatelessWidget {
  final int remainingMines;

  const _RegionMineCounterBadge({
    required this.remainingMines,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('region_mine_counter_badge'),
      height: _headerControlHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.panelDim,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.outlineDim, width: 1),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            const MinesweeperConfig().icon,
            size: 14,
            color: AppColors.red,
          ),
          const SizedBox(width: 5),
          Text(
            '$remainingMines',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textBright,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Region Pause Button ──────────────────────────────────────────────────────

class _RegionPauseButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _RegionPauseButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: const ValueKey('region_pause_button'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: _headerControlHeight,
          height: _headerControlHeight,
          decoration: BoxDecoration(
            color: AppColors.panelDim,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.outlineDim, width: 1),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.pause_rounded,
            size: 14,
            color: AppColors.textBright,
          ),
        ),
      ),
    );
  }
}

// ── Interactive Region Mini-Map Selector ────────────────────────────────────

class RegionMiniMapSelector extends StatefulWidget {
  final int regionsX;
  final int regionsY;
  final int currentRegionRow;
  final int currentRegionCol;
  final int? selectedRegionRow;
  final int? selectedRegionCol;
  final int regionRows;
  final int regionCols;
  final Uint8List cellStates;
  final int worldCols;
  final bool Function(int r, int c)? isRegionAccessible;
  final Duration unlockFadeDuration;
  final Offset planeOffset;
  final double strideX;
  final double strideY;
  final double flipProgress;
  final int swipeDRow;
  final int swipeDCol;
  final VoidCallback onTap;

  const RegionMiniMapSelector({
    super.key,
    required this.regionsX,
    required this.regionsY,
    required this.currentRegionRow,
    required this.currentRegionCol,
    this.selectedRegionRow,
    this.selectedRegionCol,
    required this.regionRows,
    required this.regionCols,
    required this.cellStates,
    required this.worldCols,
    this.isRegionAccessible,
    this.unlockFadeDuration = MinesweeperConfig.regionUnlockFadeDuration,
    this.planeOffset = Offset.zero,
    this.strideX = 1.0,
    this.strideY = 1.0,
    this.flipProgress = 0.0,
    this.swipeDRow = 0,
    this.swipeDCol = 0,
    required this.onTap,
  });

  @override
  State<RegionMiniMapSelector> createState() => _RegionMiniMapSelectorState();
}

class _RegionMiniMapSelectorState extends State<RegionMiniMapSelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;
  late Offset _targetSector;

  Offset _getTargetSector() {
    final targetCol = widget.selectedRegionCol ?? widget.currentRegionCol;
    final targetRow = widget.selectedRegionRow ?? widget.currentRegionRow;
    return Offset(targetCol.toDouble(), targetRow.toDouble());
  }

  @override
  void initState() {
    super.initState();
    _targetSector = _getTargetSector();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        setState(() {});
      });
    _animation = AlwaysStoppedAnimation<Offset>(_targetSector);
  }

  @override
  void didUpdateWidget(covariant RegionMiniMapSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTarget = _getTargetSector();
    if (newTarget != _targetSector) {
      final currentPos = _animation.value;
      _targetSector = newTarget;
      _animation = Tween<Offset>(
        begin: currentPos,
        end: newTarget,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOut,
        ),
      );
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewportWidth = widget.regionsX * 10.0;
    final viewportHeight = widget.regionsY * 10.0;
    final centerX = viewportWidth / 2.0;
    final centerY = viewportHeight / 2.0;

    final scaleX = widget.strideX > 0 ? 10.0 / widget.strideX : 0.0;
    final scaleY = widget.strideY > 0 ? 10.0 / widget.strideY : 0.0;

    final activeSelectedRow = widget.selectedRegionRow ?? widget.currentRegionRow;
    final activeSelectedCol = widget.selectedRegionCol ?? widget.currentRegionCol;

    final mapLeft =
        (centerX - (widget.currentRegionCol * 10.0 + 5.0)) +
        (widget.planeOffset.dx * scaleX);
    final mapTop =
        (centerY - (widget.currentRegionRow * 10.0 + 5.0)) +
        (widget.planeOffset.dy * scaleY);

    final sectorPos = _animation.value;
    final overlayLeft = mapLeft + (sectorPos.dx * 10.0) + 1.0;
    final overlayTop = mapTop + (sectorPos.dy * 10.0) + 1.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: const ValueKey('minimap_selector'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            color: AppColors.panelDim,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.outlineDim, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2.5),
          child: SizedBox(
            width: viewportWidth,
            height: viewportHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Back layer: Translating map (no white selected coloring)
                Positioned(
                  left: mapLeft,
                  top: mapTop,
                  width: viewportWidth,
                  height: viewportHeight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int c = 0; c < widget.regionsX; c++)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int r = 0; r < widget.regionsY; r++)
                              _buildMiniMapCell(r, c),
                          ],
                        ),
                    ],
                  ),
                ),

                // Front layer: Animated selection tracking the selected region in the back layer
                Positioned(
                  key: ValueKey(
                    'active_minimap_sector_${activeSelectedCol + 1}_${activeSelectedRow + 1}',
                  ),
                  left: overlayLeft,
                  top: overlayTop,
                  width: 8.0,
                  height: 8.0,
                  child: IgnorePointer(
                    child: AnimatedContainer(
                      key: const ValueKey('active_minimap_sector'),
                      duration: Duration.zero,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildMiniMapCell(int r, int c) {
    final isAccessible = widget.isRegionAccessible?.call(r, c) ?? true;

    // Check if region has any revealed cells
    bool hasRevealed = false;
    final minR = r * widget.regionRows;
    final minC = c * widget.regionCols;
    for (int lr = 0; lr < widget.regionRows; lr++) {
      for (int lc = 0; lc < widget.regionCols; lc++) {
        final gIdx = (minR + lr) * widget.worldCols + (minC + lc);
        if (widget.cellStates[gIdx] == CellState.revealed ||
            widget.cellStates[gIdx] == CellState.hiddenNumber) {
          hasRevealed = true;
          break;
        }
      }
      if (hasRevealed) break;
    }

    Color cellBg;
    if (!isAccessible) {
      cellBg = Colors.transparent;
    } else if (hasRevealed) {
      cellBg = AppColors.greenMedium;
    } else {
      cellBg = AppColors.panelHigh;
    }

    return Container(
      key: ValueKey('minimap_sector_${c + 1}_${r + 1}'),
      margin: const EdgeInsets.all(1.0),
      child: AnimatedContainer(
        duration: isAccessible ? widget.unlockFadeDuration : Duration.zero,
        curve: Curves.easeOut,
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: cellBg,
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    );
  }
}

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
    this.onTap,
    this.onLongPress,
    this.longTapDuration = MinesweeperConfig.longTapDuration,
    this.touchHighlightColor = MinesweeperConfig.touchHighlightColor,
    this.touchHighlightFadeDuration = MinesweeperConfig.touchHighlightFadeDuration,
  });

  static const _numberColors = [
    AppColors.surface, // 0 (unused)
    Colors.blue, // 1
    Colors.green, // 2
    Colors.red, // 3
    Colors.indigo, // 4
    Colors.brown, // 5
    Colors.teal, // 6
    Colors.purple, // 7
    Colors.grey, // 8
  ];

  @override
  State<_RegionCellWidget> createState() => _RegionCellWidgetState();
}

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
    final isRevealed = widget.cellState == CellState.revealed ||
        widget.cellState == CellState.activatedMine ||
        widget.cellState == CellState.revealedMine ||
        widget.cellState == CellState.hiddenNumber;

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
    if (widget.cellState == CellState.activatedMine ||
        widget.cellState == CellState.revealedMine) {
      return Colors.red.shade900;
    }
    if (widget.cellState == CellState.revealed ||
        widget.cellState == CellState.hiddenNumber) {
      return theme.colorScheme.surface;
    }
    return theme.colorScheme.surfaceContainerHighest;
  }

  Widget? _buildContent(ThemeData theme) {
    if (widget.cellState == CellState.flagged) {
      return Icon(
        Icons.flag_rounded,
        size: 18,
        color: widget.gameWon ? Colors.white : Colors.orange.shade400,
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
      return const _HiddenNumberText();
    }

    if (widget.cellState == CellState.revealed) {
      if (widget.adjacentMines == 0) return null;
      return Text(
        '${widget.adjacentMines}',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: _RegionCellWidget._numberColors[widget.adjacentMines.clamp(0, 8)],
        ),
      );
    }

    return null;
  }
}

// ── Anomaly '?' Hidden Number Animated Text ─────────────────────────────────

class _HiddenNumberText extends StatefulWidget {
  const _HiddenNumberText();

  @override
  State<_HiddenNumberText> createState() => _HiddenNumberTextState();
}

class _HiddenNumberTextState extends State<_HiddenNumberText>
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
            begin: _RegionCellWidget._numberColors[i],
            end: _RegionCellWidget._numberColors[i == 8 ? 1 : i + 1],
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
