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
  final double? dragMinThreshold;
  final int? regionsToWin;
  final bool? isInfiniteWorld;
  final int? initialRegionX;
  final int? initialRegionY;
  final int? minesPerRegion;
  final double? mineDensity;
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
    this.dragMinThreshold,
    this.regionsToWin,
    this.isInfiniteWorld,
    this.initialRegionX,
    this.initialRegionY,
    this.minesPerRegion,
    this.mineDensity,
    this.onPause,
  });

  @override
  Widget buildGame({
    required BuildContext context,
    required VoidCallback onComplete,
    required VoidCallback onFail,
    required GameStateManager gameState,
  }) {
    final resolvedMinesPerRegion = minesPerRegion ??
        (mineDensity != null
            ? (MinesweeperConfig.regionRows *
                    MinesweeperConfig.regionCols *
                    mineDensity!)
                .round()
            : MinesweeperConfig.minesPerRegion);

    return _MinesweeperGame(
      regionsX: MinesweeperConfig.regionsX,
      regionsY: MinesweeperConfig.regionsY,
      regionRows: MinesweeperConfig.regionRows,
      regionCols: MinesweeperConfig.regionCols,
      mineCount: MinesweeperConfig.totalMines,
      minesPerRegion: resolvedMinesPerRegion,
      mineDensity: mineDensity ?? MinesweeperConfig.mineDensity,
      initialRegionX: initialRegionX ?? MinesweeperConfig.initialRegionX,
      initialRegionY: initialRegionY ?? MinesweeperConfig.initialRegionY,
      swipeThreshold: swipeThreshold ?? MinesweeperConfig.swipeThreshold,
      dragMinThreshold: dragMinThreshold ?? MinesweeperConfig.dragMinThreshold,
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
      regionsToWin: regionsToWin ?? MinesweeperConfig.regionsToWin,
      isInfiniteWorld: isInfiniteWorld ?? MinesweeperConfig.isInfiniteWorld,
      onPause: onPause,
      gameState: gameState,
      onComplete: onComplete,
      onFail: onFail,
    );
  }
}

// ── Dynamic Region Data Model ───────────────────────────────────────────────

class RegionData {
  final int r;
  final int c;
  final int rows;
  final int cols;
  final bool isStartingRegion;
  late final Uint8List mines; // 1 = mine, 0 = safe
  late final Uint8List cellStates; // CellState values
  late final Uint8List adjacent; // cached adjacent mine counts (255 = uncomputed)
  bool isGenerated = false;
  bool isUnlocked = false;
  bool isCleared = false;
  int mineCount = 0;
  int flagCount = 0;
  int revealedCount = 0;

  RegionData({
    required this.r,
    required this.c,
    required this.rows,
    required this.cols,
    this.isStartingRegion = false,
  }) {
    final size = rows * cols;
    mines = Uint8List(size);
    cellStates = Uint8List(size);
    adjacent = Uint8List(size)..fillRange(0, size, 255);
  }

  int localIndex(int lr, int lc) => lr * cols + lc;
  int get safeCells => (rows * cols) - mineCount;
  bool get allSafeRevealed => revealedCount >= safeCells;
}

// ── Main game widget ───────────────────────────────────────────────────────

class _MinesweeperGame extends StatefulWidget {
  final int regionsX;
  final int regionsY;
  final int regionRows;
  final int regionCols;
  final int mineCount;
  final int minesPerRegion;
  final double mineDensity;
  final int initialRegionX;
  final int initialRegionY;
  final double swipeThreshold;
  final double dragMinThreshold;
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
  final int regionsToWin;
  final bool isInfiniteWorld;
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
    required this.minesPerRegion,
    this.mineDensity = MinesweeperConfig.mineDensity,
    required this.initialRegionX,
    required this.initialRegionY,
    this.swipeThreshold = MinesweeperConfig.swipeThreshold,
    this.dragMinThreshold = MinesweeperConfig.dragMinThreshold,
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
    this.regionsToWin = MinesweeperConfig.regionsToWin,
    this.isInfiniteWorld = MinesweeperConfig.isInfiniteWorld,
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
  // Dynamic regions storage: (regionR, regionC) -> RegionData
  final Map<(int, int), RegionData> _regions = {};
  final Map<(int, int), Set<int>> _forbiddenMineIndices = {};

  @visibleForTesting
  Map<(int, int), RegionData> get regions => _regions;

  @visibleForTesting
  Set<(int, int)> get unlockedRegions => _unlockedRegions;

  // Active region coordinates (can be any integer coordinate)
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
  late final AnimationController _centerDimController;
  late final Animation<double> _centerDimAnimation;
  final Map<(int, int), AnimationController> _candidateFadeControllers = {};
  final Map<(int, int), Animation<double>> _candidateFadeAnimations = {};
  Animation<Offset>? _offsetAnimation;
  Animation<double>? _progressAnimation;
  Animation<double>? _gradientAnimation;

  AnimationController _getCandidateFadeController((int, int) dir) {
    var controller = _candidateFadeControllers[dir];
    if (controller == null) {
      controller = AnimationController(
        vsync: this,
        duration: MinesweeperConfig.candidateFadeDuration,
      );
      final animation = CurvedAnimation(
        parent: controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeOut,
      );
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      _candidateFadeControllers[dir] = controller;
      _candidateFadeAnimations[dir] = animation;
    }
    return controller;
  }

  void _updateCandidateFade({(int, int)? activeDirection}) {
    if (activeDirection != null) {
      _getCandidateFadeController(activeDirection).forward();
    }
    for (final entry in _candidateFadeControllers.entries) {
      if (entry.key != activeDirection) {
        entry.value.reverse();
      }
    }
  }

  void _resetCandidateFade() {
    for (final controller in _candidateFadeControllers.values) {
      controller.stop();
      controller.value = 0.0;
    }
  }

  bool get _isCandidateFading {
    for (final ctrl in _candidateFadeControllers.values) {
      if (ctrl.isAnimating) return true;
    }
    return false;
  }

  Offset _planeOffset = Offset.zero;
  double _transitionProgress = 0.0;
  double _gradientProgress = 0.0;
  bool _isThresholdFlipped = false;
  int _swipeDRow = 0;
  int _swipeDCol = 0;

  Offset? _dragStartPos;
  Offset _rawDragDelta = Offset.zero;
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
      _centerDimController.isAnimating ||
      _isCandidateFading ||
      _swipeDRow != 0 ||
      _swipeDCol != 0;

  int get _worldRows => widget.regionsY * widget.regionRows;
  int get _worldCols => widget.regionsX * widget.regionCols;
  int get _totalWorldCells => _worldRows * _worldCols;
  int get _safeCells =>
      _totalWorldCells - (_minesPlaced ? _actualMineCount : widget.mineCount);

  int get _currentRegionMineCount {
    final region = _getOrInitRegion(_currentRegionRow, _currentRegionCol);
    if (!region.isGenerated) {
      return MinesweeperConfig.minesForRegion(
        _currentRegionRow,
        _currentRegionCol,
        startR: widget.initialRegionY,
        startC: widget.initialRegionX,
        baseMines: widget.minesPerRegion,
      );
    }
    return region.mineCount;
  }

  int get _currentRegionFlagCount {
    final region = _getOrInitRegion(_currentRegionRow, _currentRegionCol);
    return region.flagCount;
  }

  int get _currentRegionRemainingMines =>
      _currentRegionMineCount - _currentRegionFlagCount;

  // ── Unlocked region tracking & fade-in animations ──────────────────────────
  final Set<(int, int)> _unlockedRegions = <(int, int)>{};
  final Map<(int, int), AnimationController> _unlockControllers =
      <(int, int), AnimationController>{};
  final Map<(int, int), Animation<double>> _unlockAnimations =
      <(int, int), Animation<double>>{};

  void _initUnlockedRegions() {
    _unlockedRegions.clear();
    _unlockedRegions.add((widget.initialRegionY, widget.initialRegionX));
  }

  void _checkNewlyUnlockedRegions() {
    if (!widget.lockInaccessibleRegions) return;

    bool foundNew = true;
    while (foundNew) {
      foundNew = false;
      final currentUnlocked = List<(int, int)>.from(_unlockedRegions);
      for (final (ur, uc) in currentUnlocked) {
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;
            final coord = (ur + dr, uc + dc);
            if (!_unlockedRegions.contains(coord) &&
                _isRegionAccessible(coord.$1, coord.$2)) {
              _unlockedRegions.add(coord);
              _startUnlockFadeAnimation(coord);
              _onRegionUnlocked(coord.$1, coord.$2);
              foundNew = true;
            }
          }
        }
      }
    }
  }

  void _onRegionUnlocked(int r, int c) {
    if (!_minesPlaced) return;

    _ensureRegionGenerated(r, c);

    // 1. Generate all 8 surrounding neighbor regions immediately
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        _ensureRegionGenerated(r + dr, c + dc);
      }
    }

    // 2. Precalculate all adjacent numbers for the unlocked region
    // so when the player starts exploring that region on the edges,
    // we already have the numbers calculated.
    final region = _getOrInitRegion(r, c);
    for (int lr = 0; lr < region.rows; lr++) {
      for (int lc = 0; lc < region.cols; lc++) {
        _getAdjacentMines(r, c, lr, lc);
      }
    }
  }

  void _startUnlockFadeAnimation((int, int) coord) {
    final controller = AnimationController(
      vsync: this,
      duration: widget.regionUnlockFadeDuration,
    );
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOut,
    );
    _unlockControllers[coord] = controller;
    _unlockAnimations[coord] = animation;

    controller.addListener(() {
      setState(() {});
    });

    controller.forward().then((_) {
      if (mounted) {
        _unlockControllers.remove(coord)?.dispose();
        _unlockAnimations.remove(coord);
        setState(() {});
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _currentRegionRow = widget.initialRegionY;
    _currentRegionCol = widget.initialRegionX;
    _actualMineCount = widget.isInfiniteWorld
        ? widget.minesPerRegion
        : (widget.regionsX * widget.regionsY * widget.minesPerRegion);
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

    _centerDimController = AnimationController(
      vsync: this,
      duration: MinesweeperConfig.candidateFadeDuration,
    );
    _centerDimAnimation = CurvedAnimation(
      parent: _centerDimController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeOut,
    );
    _centerDimController.addListener(() {
      if (mounted) setState(() {});
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
    _centerDimController.dispose();
    for (final controller in _candidateFadeControllers.values) {
      controller.dispose();
    }
    _candidateFadeControllers.clear();
    _candidateFadeAnimations.clear();
    _slideController.dispose();
    super.dispose();
  }

  RegionData _getOrInitRegion(int r, int c) {
    return _regions.putIfAbsent(
      (r, c),
      () => RegionData(
        r: r,
        c: c,
        rows: widget.regionRows,
        cols: widget.regionCols,
        isStartingRegion:
            (r == widget.initialRegionY && c == widget.initialRegionX),
      ),
    );
  }

  (int, int, int, int) _resolveCell(
    int regionR,
    int regionC,
    int localR,
    int localC,
  ) {
    int rR = regionR;
    int rC = regionC;
    int lR = localR;
    int lC = localC;

    if (lR < 0) {
      rR -= 1;
      lR += widget.regionRows;
    } else if (lR >= widget.regionRows) {
      rR += 1;
      lR -= widget.regionRows;
    }

    if (lC < 0) {
      rC -= 1;
      lC += widget.regionCols;
    } else if (lC >= widget.regionCols) {
      rC += 1;
      lC -= widget.regionCols;
    }

    return (rR, rC, lR, lC);
  }

  void _ensureRegionGenerated(int r, int c) {
    final region = _getOrInitRegion(r, c);
    if (region.isGenerated) return;
    _generateRegionMines(region);
  }

  void _generateRegionMines(RegionData region) {
    if (region.isGenerated) return;
    region.isGenerated = true;

    final forbidden = _forbiddenMineIndices[(region.r, region.c)] ?? <int>{};
    final totalCells = region.rows * region.cols;
    final availableIndices = <int>[];
    for (int i = 0; i < totalCells; i++) {
      if (!forbidden.contains(i)) {
        availableIndices.add(i);
      }
    }

    final regionMines = MinesweeperConfig.minesForRegion(
      region.r,
      region.c,
      startR: widget.initialRegionY,
      startC: widget.initialRegionX,
      baseMines: widget.minesPerRegion,
    );

    final targetMines = min(
      regionMines,
      availableIndices.length,
    );

    final rng = Random();
    availableIndices.shuffle(rng);
    for (int i = 0; i < targetMines; i++) {
      final idx = availableIndices[i];
      region.mines[idx] = 1;
    }
    region.mineCount = targetMines;
  }

  int _getAdjacentMines(int regionR, int regionC, int localR, int localC) {
    final region = _getOrInitRegion(regionR, regionC);
    final idx = region.localIndex(localR, localC);
    if (region.adjacent[idx] != 255) {
      return region.adjacent[idx];
    }

    int count = 0;
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final (nrR, nrC, nlR, nlC) =
            _resolveCell(regionR, regionC, localR + dr, localC + dc);
        _ensureRegionGenerated(nrR, nrC);
        final neighborRegion = _getOrInitRegion(nrR, nrC);
        if (neighborRegion.mines[neighborRegion.localIndex(nlR, nlC)] == 1) {
          count++;
        }
      }
    }
    region.adjacent[idx] = count;
    return count;
  }

  /// Returns true if region (r, c) is accessible to the player.
  ///
  /// A region is accessible if:
  /// 1. lockInaccessibleRegions is false (disabled).
  /// 2. It is the initial starting region.
  /// 3. It is the current active region.
  /// 4. It has already been unlocked in _unlockedRegions.
  /// 5. Any cell inside the region is already revealed.
  /// 6. At least one cell directly adjacent (sharing an orthogonal edge) to it in the world is revealed.
  /// 7. At least one diagonal neighbor has its touching corner tile revealed.
  bool _isRegionAccessible(int r, int c) {
    if (!widget.lockInaccessibleRegions) return true;

    final initR = widget.initialRegionY;
    final initC = widget.initialRegionX;
    if (r == initR && c == initC) {
      return true;
    }

    if (r == _currentRegionRow && c == _currentRegionCol) {
      return true;
    }

    if (_unlockedRegions.contains((r, c))) {
      return true;
    }

    final region = _regions[(r, c)];
    if (region != null && region.revealedCount > 0) {
      return true;
    }

    // 1. North adjacent cells: bottom row of region (r - 1, c)
    final northRegion = _regions[(r - 1, c)];
    if (northRegion != null) {
      final lastRow = widget.regionRows - 1;
      for (int col = 0; col < widget.regionCols; col++) {
        final state = northRegion.cellStates[northRegion.localIndex(lastRow, col)];
        if (state == CellState.revealed || state == CellState.hiddenNumber) {
          return true;
        }
      }
    }

    // 2. South adjacent cells: top row of region (r + 1, c)
    final southRegion = _regions[(r + 1, c)];
    if (southRegion != null) {
      for (int col = 0; col < widget.regionCols; col++) {
        final state = southRegion.cellStates[southRegion.localIndex(0, col)];
        if (state == CellState.revealed || state == CellState.hiddenNumber) {
          return true;
        }
      }
    }

    // 3. West adjacent cells: right column of region (r, c - 1)
    final westRegion = _regions[(r, c - 1)];
    if (westRegion != null) {
      final lastCol = widget.regionCols - 1;
      for (int row = 0; row < widget.regionRows; row++) {
        final state = westRegion.cellStates[westRegion.localIndex(row, lastCol)];
        if (state == CellState.revealed || state == CellState.hiddenNumber) {
          return true;
        }
      }
    }

    // 4. East adjacent cells: left column of region (r, c + 1)
    final eastRegion = _regions[(r, c + 1)];
    if (eastRegion != null) {
      for (int row = 0; row < widget.regionRows; row++) {
        final state = eastRegion.cellStates[eastRegion.localIndex(row, 0)];
        if (state == CellState.revealed || state == CellState.hiddenNumber) {
          return true;
        }
      }
    }

    // 5. North-West diagonal corner: bottom-right corner of region (r - 1, c - 1)
    final nwRegion = _regions[(r - 1, c - 1)];
    if (nwRegion != null) {
      final lastRow = widget.regionRows - 1;
      final lastCol = widget.regionCols - 1;
      final state = nwRegion.cellStates[nwRegion.localIndex(lastRow, lastCol)];
      if (state == CellState.revealed || state == CellState.hiddenNumber) {
        return true;
      }
    }

    // 6. North-East diagonal corner: bottom-left corner of region (r - 1, c + 1)
    final neRegion = _regions[(r - 1, c + 1)];
    if (neRegion != null) {
      final lastRow = widget.regionRows - 1;
      final state = neRegion.cellStates[neRegion.localIndex(lastRow, 0)];
      if (state == CellState.revealed || state == CellState.hiddenNumber) {
        return true;
      }
    }

    // 7. South-West diagonal corner: top-right corner of region (r + 1, c - 1)
    final swRegion = _regions[(r + 1, c - 1)];
    if (swRegion != null) {
      final lastCol = widget.regionCols - 1;
      final state = swRegion.cellStates[swRegion.localIndex(0, lastCol)];
      if (state == CellState.revealed || state == CellState.hiddenNumber) {
        return true;
      }
    }

    // 8. South-East diagonal corner: top-left corner of region (r + 1, c + 1)
    final seRegion = _regions[(r + 1, c + 1)];
    if (seRegion != null) {
      final state = seRegion.cellStates[seRegion.localIndex(0, 0)];
      if (state == CellState.revealed || state == CellState.hiddenNumber) {
        return true;
      }
    }

    return false;
  }

  bool _hasRegionRevealed(int r, int c) {
    final region = _regions[(r, c)];
    return region != null && region.revealedCount > 0;
  }

  // ── Mine placement with safe clearing on first click ───────────────────────

  void _placeInitialMines(int startLocalR, int startLocalC) {
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        final (targetR, targetC, targetLr, targetLc) = _resolveCell(
          _currentRegionRow,
          _currentRegionCol,
          startLocalR + dr,
          startLocalC + dc,
        );
        final region = _getOrInitRegion(targetR, targetC);
        _forbiddenMineIndices
            .putIfAbsent((targetR, targetC), () => <int>{})
            .add(region.localIndex(targetLr, targetLc));
      }
    }

    final currentRegion = _getOrInitRegion(_currentRegionRow, _currentRegionCol);
    _generateRegionMines(currentRegion);
    _actualMineCount = widget.isInfiniteWorld
        ? currentRegion.mineCount
        : (widget.regionsX * widget.regionsY * widget.minesPerRegion);
    _minesPlaced = true;
    _onRegionUnlocked(_currentRegionRow, _currentRegionCol);
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

    final region = _getOrInitRegion(_currentRegionRow, _currentRegionCol);
    final idx = region.localIndex(localRow, localCol);

    final state = region.cellStates[idx];
    if (state == CellState.revealed ||
        state == CellState.flagged ||
        state == CellState.hiddenNumber) {
      return;
    }

    // First click: place mines ensuring this cell & surrounding area are safe
    if (!_minesPlaced) {
      _placeInitialMines(localRow, localCol);
    }

    if (region.mines[idx] == 1) {
      region.cellStates[idx] = CellState.activatedMine;
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
      _floodReveal(region, localRow, localCol, newlyRevealed);
      _checkWin();

      if (widget.gameState.isCurrentGameAnomaly &&
          !_gameOver &&
          !_gameWon) {
        bool revealedZero = newlyRevealed.any((i) =>
            _getAdjacentMines(region.r, region.c, i ~/ region.cols, i % region.cols) == 0);
        if (revealedZero) {
          final candidates = newlyRevealed
              .where((i) {
                final r = i ~/ region.cols;
                final c = i % region.cols;
                return _getAdjacentMines(region.r, region.c, r, c) > 0 &&
                    r > 0 &&
                    r < region.rows - 1 &&
                    c > 0 &&
                    c < region.cols - 1;
              })
              .toList();
          if (candidates.isNotEmpty) {
            final chosen = candidates[Random().nextInt(candidates.length)];
            region.cellStates[chosen] = CellState.hiddenNumber;
          }
        }
      }

      _checkNewlyUnlockedRegions();
    });
  }

  /// Iterative non-recursive BFS flood fill that stops on region edges
  void _floodReveal(RegionData region, int startLocalR, int startLocalC, [List<int>? newlyRevealed]) {
    final startIdx = region.localIndex(startLocalR, startLocalC);
    if (region.cellStates[startIdx] != CellState.unrevealed ||
        region.mines[startIdx] == 1) {
      return;
    }

    final queue = <int>[startIdx];
    region.cellStates[startIdx] = CellState.revealed;
    region.revealedCount++;
    _revealedCount++;
    newlyRevealed?.add(startIdx);

    int head = 0;
    while (head < queue.length) {
      final idx = queue[head++];
      final lr = idx ~/ region.cols;
      final lc = idx % region.cols;

      if (_getAdjacentMines(region.r, region.c, lr, lc) == 0) {
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;
            final nlr = lr + dr;
            final nlc = lc + dc;
            // Stop strictly at region borders!
            if (nlr >= 0 && nlr < region.rows && nlc >= 0 && nlc < region.cols) {
              final nIdx = region.localIndex(nlr, nlc);
              if (region.cellStates[nIdx] == CellState.unrevealed &&
                  region.mines[nIdx] == 0) {
                region.cellStates[nIdx] = CellState.revealed;
                region.revealedCount++;
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

    final region = _getOrInitRegion(_currentRegionRow, _currentRegionCol);
    final idx = region.localIndex(localRow, localCol);
    final state = region.cellStates[idx];
    if (state == CellState.revealed || state == CellState.hiddenNumber) return;

    setState(() {
      if (state == CellState.flagged) {
        region.cellStates[idx] = CellState.unrevealed;
        region.flagCount--;
        _flagCount--;
        if (region.mines[idx] == 1) {
          _correctlyFlaggedMines--;
        }
      } else {
        region.cellStates[idx] = CellState.flagged;
        region.flagCount++;
        _flagCount++;
        _totalFlagsPlacedInSession++;
        if (region.mines[idx] == 1) {
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

    final region = _getOrInitRegion(_currentRegionRow, _currentRegionCol);
    final idx = region.localIndex(localRow, localCol);

    if (region.cellStates[idx] != CellState.revealed ||
        _getAdjacentMines(region.r, region.c, localRow, localCol) <= 0) {
      return;
    }

    final adjCount = _getAdjacentMines(region.r, region.c, localRow, localCol);
    int flaggedCount = 0;
    final unflaggedNeighbors = <(int, int, int, int)>[];

    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final (nrR, nrC, nlR, nlC) = _resolveCell(
          _currentRegionRow,
          _currentRegionCol,
          localRow + dr,
          localCol + dc,
        );
        _ensureRegionGenerated(nrR, nrC);
        final nRegion = _getOrInitRegion(nrR, nrC);
        final nState = nRegion.cellStates[nRegion.localIndex(nlR, nlC)];

        if (nState == CellState.flagged) {
          flaggedCount++;
        } else if (nState == CellState.unrevealed) {
          unflaggedNeighbors.add((nrR, nrC, nlR, nlC));
        }
      }
    }

    if (flaggedCount != adjCount || unflaggedNeighbors.isEmpty) {
      return;
    }

    bool hitMine = false;
    int minesRevealedByChord = 0;

    setState(() {
      final newlyRevealed = <int>[];
      final newlyUnlockedCoords = <(int, int)>{};

      for (final (nrR, nrC, nlR, nlC) in unflaggedNeighbors) {
        final targetRegion = _getOrInitRegion(nrR, nrC);
        final nIdx = targetRegion.localIndex(nlR, nlC);
        if (targetRegion.cellStates[nIdx] != CellState.unrevealed) {
          continue;
        }

        if (targetRegion.mines[nIdx] == 1) {
          hitMine = true;
          minesRevealedByChord++;
          targetRegion.cellStates[nIdx] = CellState.activatedMine;
          if (nrR == _currentRegionRow && nrC == _currentRegionCol) {
            _addShockwave(nlR, nlC);
          }
        } else {
          final targetNewlyRevealed = <int>[];
          _floodReveal(targetRegion, nlR, nlC, targetNewlyRevealed);
          if (nrR == _currentRegionRow && nrC == _currentRegionCol) {
            newlyRevealed.addAll(targetNewlyRevealed);
          }
          if (nrR != _currentRegionRow || nrC != _currentRegionCol) {
            newlyUnlockedCoords.add((nrR, nrC));
          }
        }
      }

      for (final coord in newlyUnlockedCoords) {
        if (!_unlockedRegions.contains(coord)) {
          _unlockedRegions.add(coord);
          _startUnlockFadeAnimation(coord);
          _onRegionUnlocked(coord.$1, coord.$2);
        }
      }

      if (widget.gameState.isCurrentGameAnomaly &&
          !hitMine &&
          !_gameOver &&
          !_gameWon) {
        bool revealedZero = newlyRevealed.any((i) =>
            _getAdjacentMines(region.r, region.c, i ~/ region.cols, i % region.cols) == 0);
        if (revealedZero) {
          final candidates = newlyRevealed
              .where((i) {
                final r = i ~/ region.cols;
                final c = i % region.cols;
                return _getAdjacentMines(region.r, region.c, r, c) > 0 &&
                    r > 0 &&
                    r < region.rows - 1 &&
                    c > 0 &&
                    c < region.cols - 1;
              })
              .toList();
          if (candidates.isNotEmpty) {
            final chosen = candidates[Random().nextInt(candidates.length)];
            region.cellStates[chosen] = CellState.hiddenNumber;
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
    for (final region in _regions.values) {
      if (!region.isGenerated) continue;
      for (int i = 0; i < region.rows * region.cols; i++) {
        if (region.mines[i] == 1 && region.cellStates[i] != CellState.activatedMine) {
          region.cellStates[i] = CellState.revealedMine;
        }
      }
    }
  }

  void _checkWin() {
    if (_gameOver || _gameWon) return;

    if (!widget.isInfiniteWorld) {
      final allSafeRevealed = _revealedCount >= _safeCells;
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
      return;
    }

    final currentRegion = _getOrInitRegion(_currentRegionRow, _currentRegionCol);
    if (currentRegion.isGenerated && !currentRegion.isCleared) {
      final allSafeRevealed = currentRegion.revealedCount >= currentRegion.safeCells;
      int correctlyFlagged = 0;
      for (int i = 0; i < currentRegion.rows * currentRegion.cols; i++) {
        if (currentRegion.mines[i] == 1 &&
            currentRegion.cellStates[i] == CellState.flagged) {
          correctlyFlagged++;
        }
      }
      final allMinesFlagged = correctlyFlagged == currentRegion.mineCount &&
          currentRegion.flagCount == currentRegion.mineCount;

      if (allSafeRevealed && allMinesFlagged) {
        currentRegion.isCleared = true;
        if (!_hasMisplacedFlag) {
          widget.gameState.recordFlawlessMinesweeperWin();
        }
      }
    }

    final isNoFlagsAchievementTrigger =
        currentRegion.isCleared &&
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
  }

  static const List<(int, int)> _canonicalDirections = [
    (0, 1), // 0: East (0 deg)
    (1, 1), // 1: South-East (45 deg)
    (1, 0), // 2: South (90 deg)
    (1, -1), // 3: South-West (135 deg)
    (0, -1), // 4: West (180 deg)
    (-1, -1), // 5: North-West (225 deg)
    (-1, 0), // 6: North (270 deg)
    (-1, 1), // 7: North-East (315 deg)
  ];

  /// Interpolates the drag extension limit (maxVisualDelta) smoothly between
  /// discovered regions (100.0) and undiscovered/locked regions (35.0) as the
  /// user's drag angle continuously swivels across direction sectors.
  double _getContinuousMaxVisualDelta(Offset delta) {
    if (delta.distance < 0.001) return 35.0;

    final angle = atan2(-delta.dy, -delta.dx);
    var deg = angle * 180.0 / pi;
    if (deg < 0) deg += 360.0;
    if (deg >= 360.0) deg -= 360.0;

    final sector = deg / 45.0;
    final k = sector.floor() % 8;
    final nextK = (k + 1) % 8;
    final t = sector - sector.floor();

    final (drK, dcK) = _canonicalDirections[k];
    final (drNext, dcNext) = _canonicalDirections[nextK];

    final isKAccessible =
        _isRegionAccessible(_currentRegionRow + drK, _currentRegionCol + dcK);
    final isNextAccessible = _isRegionAccessible(
        _currentRegionRow + drNext, _currentRegionCol + dcNext);

    final limitK = isKAccessible ? 100.0 : 35.0;
    final limitNext = isNextAccessible ? 100.0 : 35.0;

    if (limitK == limitNext) return limitK;

    final smoothT = t * t * (3.0 - 2.0 * t);
    return limitK + (limitNext - limitK) * smoothT;
  }

  Offset _applyEaseOutOffset(
    Offset delta,
    double effectiveDistance,
    double maxVisualDelta,
  ) {
    if (effectiveDistance <= 0.0 || delta.distance <= 0.0) return Offset.zero;
    final visualDistance =
        maxVisualDelta * (1.0 - exp(-effectiveDistance / (maxVisualDelta * 1.5)));
    return (delta / delta.distance) * visualDistance;
  }

  /// Determines the (dRow, dCol) transition direction by dividing the 2D plane
  /// into 8 equal spherical (angular) slices of 45 degrees each.
  /// The direction indicates which neighbor region is pulled into center view.
  (int, int) _get8SliceDirection(Offset delta) {
    if (delta.distance < 4.0) return (0, 0);
    // Incoming region is in the opposite direction of the finger pull (-dx, -dy)
    final angle = atan2(-delta.dy, -delta.dx);
    var deg = angle * 180.0 / pi;
    if (deg < 0) deg += 360.0;
    final slice = ((deg + 22.5) ~/ 45) % 8;
    return _canonicalDirections[slice];
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
    _centerDimController.stop();
    _centerDimController.value = 0.0;
    _resetCandidateFade();
    if (_isTransitioning &&
        _targetTransitionRow != null &&
        _targetTransitionCol != null) {
      _currentRegionRow = _targetTransitionRow!;
      _currentRegionCol = _targetTransitionCol!;
      if (!_unlockedRegions.contains((_currentRegionRow, _currentRegionCol))) {
        _unlockedRegions.add((_currentRegionRow, _currentRegionCol));
      }
      if (_minesPlaced) {
        _onRegionUnlocked(_currentRegionRow, _currentRegionCol);
      }
    }
    _targetTransitionRow = null;
    _targetTransitionCol = null;
    _planeOffset = Offset.zero;
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
    _dragExceededTapSlop = false;
    _isThresholdFlipped = false;
    _slideController.stop();
    _centerDimController.stop();
    _centerDimController.value = 0.0;
    _resetCandidateFade();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_dragStartPos == null) return;
    final delta = event.position - _dragStartPos!;
    _rawDragDelta = delta;

    if (delta.distance > 8.0) {
      _dragExceededTapSlop = true;
    }

    final distance = delta.distance;

    if (distance < widget.dragMinThreshold) {
      if (_planeOffset != Offset.zero) {
        setState(() {
          _planeOffset = Offset.zero;
        });
      }
      if (_isThresholdFlipped) {
        _isThresholdFlipped = false;
        _centerDimController.reverse();
        _updateCandidateFade(activeDirection: null);
      }
      _swipeDRow = 0;
      _swipeDCol = 0;
      return;
    }

    final effectiveDistance = distance - widget.dragMinThreshold;
    final (dRow, dCol) = _get8SliceDirection(delta);

    final targetRow = _currentRegionRow + dRow;
    final targetCol = _currentRegionCol + dCol;
    final canTransition = (dRow != 0 || dCol != 0) &&
        _isRegionAccessible(targetRow, targetCol);

    final maxVisualDelta = _getContinuousMaxVisualDelta(delta);
    final visualOffset =
        _applyEaseOutOffset(delta, effectiveDistance, maxVisualDelta);

    final isOverThreshold =
        canTransition && distance >= widget.swipeThreshold;

    if (isOverThreshold) {
      _centerDimController.forward();
      if (!_isThresholdFlipped || _swipeDRow != dRow || _swipeDCol != dCol) {
        _isThresholdFlipped = true;
        _swipeDRow = dRow;
        _swipeDCol = dCol;
        _updateCandidateFade(activeDirection: (dRow, dCol));
      }
    } else {
      if (_isThresholdFlipped) {
        _isThresholdFlipped = false;
        _centerDimController.reverse();
        _updateCandidateFade(activeDirection: null);
      }
      if (canTransition) {
        _swipeDRow = dRow;
        _swipeDCol = dCol;
      } else {
        _swipeDRow = 0;
        _swipeDCol = 0;
        _centerDimController.reverse();
        _updateCandidateFade(activeDirection: null);
      }
    }

    setState(() {
      _planeOffset = visualOffset;
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    _touchStartedWhileAnimating = false;
    if (_dragStartPos == null) return;
    final totalDelta = _rawDragDelta;
    _dragStartPos = null;

    final double threshold = widget.swipeThreshold;
    final distance = totalDelta.distance;
    final (dRow, dCol) = _get8SliceDirection(totalDelta);

    final targetRow = _currentRegionRow + dRow;
    final targetCol = _currentRegionCol + dCol;
    final canTransition = (dRow != 0 || dCol != 0) &&
        _isRegionAccessible(targetRow, targetCol);

    final isOverThreshold = canTransition && distance >= threshold;

    if (isOverThreshold) {
      _animateTransition(dRow, dCol, targetRow, targetCol);
    } else {
      if (_isThresholdFlipped) {
        _isThresholdFlipped = false;
        _centerDimController.reverse();
        _updateCandidateFade(activeDirection: null);
      }
      _animateSnapBack();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _touchStartedWhileAnimating = false;
    _dragStartPos = null;
    if (_isThresholdFlipped) {
      _isThresholdFlipped = false;
      _centerDimController.reverse();
      _updateCandidateFade(activeDirection: null);
    }
    _animateSnapBack();
  }

  void _animateSnapBack() {
    _slideController.stop();
    _isThresholdFlipped = false;
    _centerDimController.reverse();
    _updateCandidateFade(activeDirection: null);
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
        _centerDimController.stop();
        _centerDimController.value = 0.0;
        _resetCandidateFade();
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
        _transitionProgress = 0.0;
        _gradientProgress = 0.0;
        _offsetAnimation = null;
        _progressAnimation = null;
        _gradientAnimation = null;
        _isThresholdFlipped = false;
        _swipeDRow = 0;
        _swipeDCol = 0;
        _centerDimController.stop();
        _centerDimController.value = 0.0;
        _resetCandidateFade();
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
    _centerDimController.stop();
    _centerDimController.value = 1.0;

    final targetCtrl = _getCandidateFadeController((dRow, dCol));
    targetCtrl.stop();
    targetCtrl.value = 1.0;
    for (final entry in _candidateFadeControllers.entries) {
      if (entry.key != (dRow, dCol)) {
        entry.value.stop();
        entry.value.value = 0.0;
      }
    }
    _transitionProgress = 1.0;
    _gradientProgress = 1.0;

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
      begin: 1.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      ),
    );
    _gradientAnimation = Tween<double>(
      begin: 1.0,
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
        if (!_unlockedRegions.contains((targetRow, targetCol))) {
          _unlockedRegions.add((targetRow, targetCol));
        }
        if (_minesPlaced) {
          _onRegionUnlocked(targetRow, targetCol);
        }
        _targetTransitionRow = null;
        _targetTransitionCol = null;
        _planeOffset = Offset.zero;
        _transitionProgress = 0.0;
        _gradientProgress = 0.0;
        _gradientAnimation = null;
        _offsetAnimation = null;
        _progressAnimation = null;
        _isThresholdFlipped = false;
        _swipeDRow = 0;
        _swipeDCol = 0;
        _isTransitioning = false;
        _centerDimController.stop();
        _centerDimController.value = 0.0;
        _resetCandidateFade();
      });
    }).catchError((_) {});
  }

  void _navigateRegion(int dRow, int dCol) {
    if (_isTransitioning || _slideController.isAnimating) {
      setState(() {
        _finishTransitionImmediately();
      });
    }
    final nextRow = _currentRegionRow + dRow;
    final nextCol = _currentRegionCol + dCol;
    if (_isRegionAccessible(nextRow, nextCol)) {
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

    if (localRow < 0 ||
        localRow >= widget.regionRows ||
        localCol < 0 ||
        localCol >= widget.regionCols) {
      return;
    }

    final region = _getOrInitRegion(_currentRegionRow, _currentRegionCol);
    final idx = region.localIndex(localRow, localCol);
    final state = region.cellStates[idx];

    if (state == CellState.unrevealed) {
      _reveal(localRow, localCol);
    } else if (state == CellState.revealed &&
        _getAdjacentMines(_currentRegionRow, _currentRegionCol, localRow, localCol) > 0) {
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

    if (localRow < 0 ||
        localRow >= widget.regionRows ||
        localCol < 0 ||
        localCol >= widget.regionCols) {
      return;
    }

    final region = _getOrInitRegion(_currentRegionRow, _currentRegionCol);
    final idx = region.localIndex(localRow, localCol);
    final state = region.cellStates[idx];

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
    final region = _getOrInitRegion(regionRow, regionCol);
    final idx = region.localIndex(r, c);

    final isCurrentPanel = (dr == 0 && dc == 0);
    final isNeighbor = !isCurrentPanel;
    final isInteractable = isCurrentPanel && !_isAnimating;

    int adjacentMines = 0;
    if (region.cellStates[idx] == CellState.revealed ||
        region.cellStates[idx] == CellState.hiddenNumber) {
      adjacentMines = _getAdjacentMines(regionRow, regionCol, r, c);
    }

    return SizedBox(
      width: totalTileSize,
      height: totalTileSize,
      child: _RegionCellWidget(
        cellState: region.cellStates[idx],
        adjacentMines: adjacentMines,
        hasMine: region.mines[idx] == 1,
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

    double panelOpacity;
    if (_slideController.isAnimating) {
      final p = _transitionProgress.clamp(0.0, 1.0);
      if (dr == 0 && dc == 0) {
        panelOpacity = 1.0 - (p * (1.0 - neighborBaseOpacity));
      } else if (dr == _swipeDRow && dc == _swipeDCol) {
        panelOpacity = neighborBaseOpacity + (p * (1.0 - neighborBaseOpacity));
      } else {
        panelOpacity = neighborBaseOpacity;
      }
    } else if (dr == 0 && dc == 0) {
      final dimProgress = _centerDimAnimation.value.clamp(0.0, 1.0);
      panelOpacity = 1.0 - (dimProgress * (1.0 - neighborBaseOpacity));
    } else {
      final candidateAnim = _candidateFadeAnimations[(dr, dc)];
      final candidateProgress = candidateAnim?.value ?? 0.0;
      panelOpacity =
          neighborBaseOpacity + (candidateProgress * (1.0 - neighborBaseOpacity));
    }

    final unlockFade = _unlockAnimations[(regionRow, regionCol)]?.value ?? 1.0;
    panelOpacity = (panelOpacity * unlockFade).clamp(0.0, 1.0);

    return Positioned(
      key: ValueKey('region_panel_${dr}_$dc'),
      left: panelLeft,
      top: panelTop,
      width: panelWidth,
      height: panelHeight,
      child: RepaintBoundary(
        child: Opacity(
          opacity: panelOpacity.clamp(0.0, 1.0),
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.matrix(Matrix4.identity().storage),
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
        if (_isRegionAccessible(r, c)) {
          panelsToRender.add((dr, dc));
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
          if (_isRegionAccessible(targetR, targetC)) {
            panelsToRender.add((pDr, pDc));
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
                      initialRegionRow: widget.initialRegionY,
                      initialRegionCol: widget.initialRegionX,
                      selectedRegionRow: (_isThresholdFlipped || _isTransitioning)
                          ? (_currentRegionRow + _swipeDRow)
                          : _currentRegionRow,
                      selectedRegionCol: (_isThresholdFlipped || _isTransitioning)
                          ? (_currentRegionCol + _swipeDCol)
                          : _currentRegionCol,
                      regionRows: widget.regionRows,
                      regionCols: widget.regionCols,
                      hasRegionRevealed: (r, c) => _hasRegionRevealed(r, c),
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
  final int minimapCols;
  final int minimapRows;
  final int currentRegionRow;
  final int currentRegionCol;
  final int? initialRegionRow;
  final int? initialRegionCol;
  final int? selectedRegionRow;
  final int? selectedRegionCol;
  final int regionRows;
  final int regionCols;
  final Uint8List? cellStates;
  final int? worldCols;
  final bool Function(int r, int c)? hasRegionRevealed;
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
    this.minimapCols = MinesweeperConfig.minimapCols,
    this.minimapRows = MinesweeperConfig.minimapRows,
    required this.currentRegionRow,
    required this.currentRegionCol,
    this.initialRegionRow,
    this.initialRegionCol,
    this.selectedRegionRow,
    this.selectedRegionCol,
    required this.regionRows,
    required this.regionCols,
    this.cellStates,
    this.worldCols,
    this.hasRegionRevealed,
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
    final viewportWidth = widget.minimapCols * 10.0;
    final viewportHeight = widget.minimapRows * 10.0;
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

    final halfVisibleCols = (widget.minimapCols / 2).ceil();
    final halfVisibleRows = (widget.minimapRows / 2).ceil();
    final minCol = widget.currentRegionCol - halfVisibleCols;
    final maxCol = widget.currentRegionCol + halfVisibleCols;
    final minRow = widget.currentRegionRow - halfVisibleRows;
    final maxRow = widget.currentRegionRow + halfVisibleRows;

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
                  Positioned.fill(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (int c = minCol; c <= maxCol; c++)
                          for (int r = minRow; r <= maxRow; r++)
                            Positioned(
                              left: mapLeft + (c * 10.0),
                              top: mapTop + (r * 10.0),
                              width: 10.0,
                              height: 10.0,
                              child: _buildMiniMapCell(r, c),
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
    if (widget.hasRegionRevealed != null) {
      hasRevealed = widget.hasRegionRevealed!(r, c);
    } else if (widget.cellStates != null && widget.worldCols != null) {
      final minR = r * widget.regionRows;
      final minC = c * widget.regionCols;
      for (int lr = 0; lr < widget.regionRows; lr++) {
        for (int lc = 0; lc < widget.regionCols; lc++) {
          final gIdx = (minR + lr) * widget.worldCols! + (minC + lc);
          if (gIdx >= 0 && gIdx < widget.cellStates!.length) {
            if (widget.cellStates![gIdx] == CellState.revealed ||
                widget.cellStates![gIdx] == CellState.hiddenNumber) {
              hasRevealed = true;
              break;
            }
          }
        }
        if (hasRevealed) break;
      }
    }

    Color cellBg;
    if (!isAccessible) {
      cellBg = Colors.transparent;
    } else if (hasRevealed) {
      cellBg = AppColors.greenMedium;
    } else {
      cellBg = AppColors.panelHigh;
    }

    final startR = widget.initialRegionRow ?? MinesweeperConfig.initialRegionY;
    final startC = widget.initialRegionCol ?? MinesweeperConfig.initialRegionX;
    final isStartingRegion = (r == startR && c == startC);

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
          border: isStartingRegion
              ? Border.all(
                  color: const Color(0x66FFFFFF),
                  width: 1.0,
                )
              : null,
        ),
        child: isStartingRegion
            ? const Center(
                child: DecoratedBox(
                  key: ValueKey('minimap_starting_region_marker'),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: 3.0,
                    height: 3.0,
                  ),
                ),
              )
            : null,
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

  static final List<TextStyle> _numberTextStyles = List.generate(
    9,
    (i) => TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w900,
      color: _numberColors[i],
    ),
  );

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
          if (!widget.isNeighbor)
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
      final count = widget.adjacentMines.clamp(0, 8);
      return Text(
        '$count',
        style: _RegionCellWidget._numberTextStyles[count],
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
