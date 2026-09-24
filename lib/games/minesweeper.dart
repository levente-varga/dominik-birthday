import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/achievement_config.dart';
import '../config/config.dart';
import '../constants/colors.dart';
import '../game_state.dart';
import '../widgets/chest_reward_popup.dart';
import '../widgets/options_popup.dart';
import '../widgets/shockwave_layer.dart';
import 'minesweeper/cell_state.dart';
import 'minesweeper/chest_reward.dart';
import 'minesweeper/flying_item_overlay.dart';
import 'minesweeper/inventory.dart';
import 'minesweeper/minimap_selector.dart';
import 'minesweeper/region_badges.dart';
import 'minesweeper/region_data.dart';
import 'minesweeper/region_sparkles.dart';
import 'minesweeper/world_generator.dart';

export 'minesweeper/cell_state.dart';
export 'minesweeper/chest_reward.dart';
export 'minesweeper/flying_item_overlay.dart';
export 'minesweeper/gradient_painter.dart';
export 'minesweeper/inventory.dart';
export 'minesweeper/minimap_selector.dart';
export 'minesweeper/region_badges.dart';
export 'minesweeper/region_data.dart';
export 'minesweeper/region_sparkles.dart';
export 'minesweeper/world_generator.dart';

part 'minesweeper/region_cell_widget.dart';

// ── Game entry point ───────────────────────────────────────────────────────

class MinesweeperGame {
  final int stageNumber = 1;
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
  final MinesweeperWorldGenerator? worldGenerator;
  final Random? random;
  final List<InventoryItemType?>? initialInventory;

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
    this.worldGenerator,
    this.random,
    this.enableContinuousIdlePulseInTests,
    this.enableContinuousSparklesInTests,
    this.initialInventory,
  });

  final bool? enableContinuousIdlePulseInTests;
  final bool? enableContinuousSparklesInTests;

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
      touchHighlightColor:
          touchHighlightColor ?? MinesweeperConfig.touchHighlightColor,
      touchHighlightFadeDuration: touchHighlightFadeDuration ??
          MinesweeperConfig.touchHighlightFadeDuration,
      overlayGradientStyle: overlayGradientStyle ??
          MinesweeperConfig.overlayGradientStyle,
      neighborRegionTransparency: neighborRegionTransparency ??
          MinesweeperConfig.neighborRegionTransparency,
      lockInaccessibleRegions: lockInaccessibleRegions ??
          MinesweeperConfig.lockInaccessibleRegions,
      regionUnlockFadeDuration: regionUnlockFadeDuration ??
          MinesweeperConfig.regionUnlockFadeDuration,
      isInfiniteWorld: isInfiniteWorld ?? MinesweeperConfig.isInfiniteWorld,
      enableContinuousIdlePulseInTests: enableContinuousIdlePulseInTests,
      enableContinuousSparklesInTests: enableContinuousSparklesInTests,
      onPause: onPause,
      worldGenerator: worldGenerator,
      random: random,
      initialInventory: initialInventory,
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
  final Color touchHighlightColor;
  final Duration touchHighlightFadeDuration;
  final OverlayGradientStyle overlayGradientStyle;
  final double neighborRegionTransparency;
  final bool lockInaccessibleRegions;
  final Duration regionUnlockFadeDuration;
  final bool isInfiniteWorld;
  final bool? enableContinuousIdlePulseInTests;
  final bool? enableContinuousSparklesInTests;
  final VoidCallback? onPause;
  final MinesweeperWorldGenerator? worldGenerator;
  final Random? random;
  final List<InventoryItemType?>? initialInventory;
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
    this.touchHighlightColor = MinesweeperConfig.touchHighlightColor,
    this.touchHighlightFadeDuration = MinesweeperConfig.touchHighlightFadeDuration,
    this.overlayGradientStyle = MinesweeperConfig.overlayGradientStyle,
    this.neighborRegionTransparency =
        MinesweeperConfig.neighborRegionTransparency,
    this.lockInaccessibleRegions = MinesweeperConfig.lockInaccessibleRegions,
    this.regionUnlockFadeDuration = MinesweeperConfig.regionUnlockFadeDuration,
    this.isInfiniteWorld = MinesweeperConfig.isInfiniteWorld,
    this.enableContinuousIdlePulseInTests,
    this.enableContinuousSparklesInTests,
    this.onPause,
    this.worldGenerator,
    this.random,
    this.initialInventory,
    required this.gameState,
    required this.onComplete,
    required this.onFail,
  });

  @override
  State<_MinesweeperGame> createState() => _MinesweeperGameState();
}

class _MinesweeperGameState extends State<_MinesweeperGame>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Dynamic regions storage: (regionR, regionC) -> RegionData
  final Map<(int, int), RegionData> _regions = {};
  final Map<(int, int), Set<int>> _forbiddenMineIndices = {};

  @visibleForTesting
  Map<(int, int), RegionData> get regions => _regions;

  @visibleForTesting
  Set<(int, int)> get unlockedRegions => _unlockedRegions;

  @visibleForTesting
  void ensureRegionGenerated(int r, int c) => _ensureRegionGenerated(r, c);

  @visibleForTesting
  void reveal(int r, int c, int lr, int lc) => _reveal(r, c, lr, lc);

  @visibleForTesting
  void handleCellTap(int r, int c, int lr, int lc) => _handleCellTap(r, c, lr, lc);

  @visibleForTesting
  int get currentRegionRank => _currentRegionRank;

  @visibleForTesting
  void toggleFlag(int r, int c, int lr, int lc) => _toggleFlag(r, c, lr, lc);

  late List<InventoryItemType?> _inventory;
  final List<GlobalKey> _inventorySlotKeys = [GlobalKey(), GlobalKey()];
  final List<ActiveItemFlightData> _activeItemFlights = [];
  final Set<int> _reservedInventorySlots = {};

  @visibleForTesting
  List<InventoryItemType?> get inventory => List.unmodifiable(_inventory);

  @visibleForTesting
  List<ActiveItemFlightData> get activeItemFlights =>
      List.unmodifiable(_activeItemFlights);

  @visibleForTesting
  void setInventorySlot(int slotIndex, InventoryItemType? item) {
    if (slotIndex >= 0 && slotIndex < _inventory.length) {
      _inventory[slotIndex] = item;
      setState(() {});
    }
  }

  @visibleForTesting
  void setRegionItem(
    int r,
    int c,
    InventoryItemType itemType,
    int cellIndex,
  ) {
    final region = _getOrInitRegion(r, c);
    region.hasChest = true;
    region.itemType = itemType;
    region.chestCellIndex = cellIndex;
    region.chestOpened = false;
    region.sparkleParticles = null;
    setState(() {});
  }

  @visibleForTesting
  void setRegionChest(int r, int c, int cellIndex) {
    final region = _getOrInitRegion(r, c);
    region.hasChest = true;
    region.chestCellIndex = cellIndex;
    region.chestOpened = false;
    region.sparkleParticles = null;
    setState(() {});
  }

  @visibleForTesting
  void openChest(int r, int c, {ChestRewardOption? optionToPick}) {
    final region = _getOrInitRegion(r, c);
    if (!region.hasChest || region.chestOpened || region.chestCellIndex == null) return;
    final cellIndex = region.chestCellIndex!;
    region.chestOpened = true;
    region.sparkleParticles = null;
    final chosen = optionToPick ??
        ChestRewardOption.generateTwoUniqueOptions(
          _rng,
          currentRegion: (r, c),
          rank: region.rank,
        ).first;
    _applyChestReward(chosen, region, cellIndex);
    setState(() {});
  }

  @visibleForTesting
  Set<(int, int)> get questRegions => _questRegions;

  @visibleForTesting
  Set<(int, int)> get hintRegions => _hintRegions;

  @visibleForTesting
  int get activeBoonRankBonus => _activeBoonRankBonus;

  @visibleForTesting
  bool get hasShield => _inventory.contains(InventoryItemType.shield);

  @visibleForTesting
  void useInventorySlot(int slotIndex) => _useInventorySlot(slotIndex);

  @visibleForTesting
  int flagAllObviousMines() => _flagAllObviousMines();

  @visibleForTesting
  bool get minesPlaced => _minesPlaced;

  @visibleForTesting
  set minesPlaced(bool value) => _minesPlaced = value;

  // Active region coordinates (can be any integer coordinate)
  late int _currentRegionRow;
  late int _currentRegionCol;

  bool _minesPlaced = false;
  bool _gameOver = false;
  bool _gameWon = false;
  bool _hasMisplacedFlag = false;
  bool _isMinimapExpanded = false;
  double _currentScale = 1.0;
  (int, int)? _extendedSelectedRegion;
  final Set<(int, int)> _questRegions = {};
  final Set<(int, int)> _hintRegions = {};
  int _activeBoonRankBonus = 0;
  Random get _rng => widget.random ?? Random();

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
  Animation<Offset>? _offsetAnimation;

  // ── Selected Region Border Pulse State ───────────────────────────────────
  late final AnimationController _entryPulseController;
  late final Animation<double> _entryPulseAnimation;
  late final AnimationController _idlePulseController;
  late final Animation<double> _idlePulseAnimation;

  @visibleForTesting
  AnimationController get entryPulseController => _entryPulseController;

  @visibleForTesting
  AnimationController get idlePulseController => _idlePulseController;

  @visibleForTesting
  Animation<double> get entryPulseAnimation => _entryPulseAnimation;

  @visibleForTesting
  Animation<double> get idlePulseAnimation => _idlePulseAnimation;

  @visibleForTesting
  void startBorderPulseSequence() => _startBorderPulseSequence();

  @visibleForTesting
  void resumeIdlePulse() => _resumeIdlePulse();

  @visibleForTesting
  FocusNode get focusNode => _focusNode;

  @visibleForTesting
  int get currentRegionRow => _currentRegionRow;

  @visibleForTesting
  int get currentRegionCol => _currentRegionCol;

  @visibleForTesting
  AnimationController get slideController => _slideController;

  @visibleForTesting
  void navigateRegion(int dRow, int dCol) => _navigateRegion(dRow, dCol);

  Offset _planeOffset = Offset.zero;
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
      _swipeDRow != 0 ||
      _swipeDCol != 0;

  int get _worldRows => widget.regionsY * widget.regionRows;
  int get _worldCols => widget.regionsX * widget.regionCols;
  int get _safeCells =>
      (_worldRows * _worldCols) - (_minesPlaced ? _actualMineCount : widget.mineCount);

  int get _currentRegionMineCount {
    final region = _getOrInitRegion(_currentRegionRow, _currentRegionCol);
    if (!region.isGenerated) {
      return MinesweeperConfig.rankToMineCountFunction(
        region.rank,
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

  int get _currentRegionRank =>
      _getOrInitRegion(_currentRegionRow, _currentRegionCol).rank;

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
    WidgetsBinding.instance.addObserver(this);
    _inventory = widget.initialInventory != null
        ? List.from(widget.initialInventory!)
        : [InventoryItemType.shield, InventoryItemType.flagObvious];
    _currentRegionRow = widget.initialRegionY;
    _currentRegionCol = widget.initialRegionX;
    _actualMineCount = widget.isInfiniteWorld
        ? widget.minesPerRegion
        : (widget.regionsX * widget.regionsY * widget.minesPerRegion);

    _worldGenerator = widget.worldGenerator ??
        MinesweeperWorldGenerator(
          initialRegionX: widget.initialRegionX,
          initialRegionY: widget.initialRegionY,
          isInfiniteWorld: widget.isInfiniteWorld,
          regionsX: widget.regionsX,
          regionsY: widget.regionsY,
          random: widget.random,
        );
    if (!widget.isInfiniteWorld && widget.regionsX > 0 && widget.regionsY > 0) {
      _worldGenerator.pregenerateGrid(widget.regionsY, widget.regionsX);
    }

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
      });
    });

    _entryPulseController = AnimationController(
      vsync: this,
      duration: MinesweeperConfig.borderEntryPulseDuration,
    );
    _entryPulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50.0,
      ),
    ]).animate(_entryPulseController);

    _idlePulseController = AnimationController(
      vsync: this,
      duration: MinesweeperConfig.borderIdlePulseDuration,
    );
    _idlePulseAnimation = CurvedAnimation(
      parent: _idlePulseController,
      curve: Curves.easeInOut,
    );

    _entryPulseController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted &&
            !_gameOver &&
            !_gameWon &&
            !_isMinimapExpanded &&
            !_slideController.isAnimating &&
            !_isTransitioning &&
            _dragStartPos == null) {
          if (_shouldRepeatIdlePulse) {
            _idlePulseController.repeat(reverse: true);
          } else {
            _idlePulseController.forward(from: 0.0).then((_) {
              if (mounted &&
                  !_gameOver &&
                  !_gameWon &&
                  !_isMinimapExpanded &&
                  !_slideController.isAnimating &&
                  !_isTransitioning &&
                  _dragStartPos == null) {
                _idlePulseController.reverse();
              }
            });
          }
        }
      }
    });

    _startBorderPulseSequence();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _idlePulseController.stop();
      _entryPulseController.stop();
    } else if (!_gameOver &&
        !_gameWon &&
        !_isMinimapExpanded &&
        !_isTransitioning &&
        !_slideController.isAnimating &&
        _dragStartPos == null) {
      if (_shouldRepeatIdlePulse) {
        _idlePulseController.repeat(reverse: true);
      }
    }
  }

  bool get _shouldRepeatIdlePulse {
    final isTestEnvironment =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTestEnvironment) {
      return widget.enableContinuousIdlePulseInTests ??
          MinesweeperConfig.enableContinuousIdlePulseInTests;
    }
    return MinesweeperConfig.enableContinuousIdlePulse;
  }

  void _startBorderPulseSequence() {
    _idlePulseController.stop();
    _idlePulseController.value = 0.0;
    if (!_gameOver && !_gameWon && !_isMinimapExpanded) {
      _entryPulseController.forward(from: 0.0);
    }
  }

  void _resumeIdlePulse() {
    if (!mounted ||
        _gameOver ||
        _gameWon ||
        _isMinimapExpanded ||
        _isTransitioning ||
        _slideController.isAnimating ||
        _entryPulseController.isAnimating) {
      return;
    }
    if (_shouldRepeatIdlePulse) {
      if (!_idlePulseController.isAnimating) {
        _idlePulseController.repeat(reverse: true);
      }
    } else {
      if (!_idlePulseController.isAnimating) {
        _idlePulseController.forward(from: 0.0).then((_) {
          if (mounted &&
              !_gameOver &&
              !_gameWon &&
              !_isMinimapExpanded &&
              !_slideController.isAnimating &&
              !_isTransitioning &&
              _dragStartPos == null) {
            _idlePulseController.reverse();
          }
        });
      }
    }
  }

  late final MinesweeperWorldGenerator _worldGenerator;

  @visibleForTesting
  MinesweeperWorldGenerator get worldGenerator => _worldGenerator;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    for (final controller in _unlockControllers.values) {
      controller.dispose();
    }
    _unlockControllers.clear();
    _unlockAnimations.clear();
    _shockwaveLayerController.dispose();
    _entryPulseController.dispose();
    _idlePulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  RegionData _getOrInitRegion(int r, int c) {
    return _regions.putIfAbsent(
      (r, c),
      () {
        final baseRank = _worldGenerator.getOrGenerateRank(r, c);
        final rank = baseRank + _activeBoonRankBonus;
        final biome = _worldGenerator.getOrGenerateBiome(r, c);
        final isStarting =
            (r == widget.initialRegionY && c == widget.initialRegionX);
        final rng = widget.random ?? Random();
        final chestChance = isStarting
            ? 0.0
            : MinesweeperConfig.itemSpawnChanceForRankFunction(rank);
        final hasChest = rng.nextDouble() < chestChance;

        return RegionData(
          r: r,
          c: c,
          rows: widget.regionRows,
          cols: widget.regionCols,
          isStartingRegion: isStarting,
          rank: rank,
          biome: biome,
          hasChest: hasChest,
        );
      },
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

    while (lR < 0) {
      rR -= 1;
      lR += widget.regionRows;
    }
    while (lR >= widget.regionRows) {
      rR += 1;
      lR -= widget.regionRows;
    }

    while (lC < 0) {
      rC -= 1;
      lC += widget.regionCols;
    }
    while (lC >= widget.regionCols) {
      rC += 1;
      lC -= widget.regionCols;
    }

    return (rR, rC, lR, lC);
  }

  /// Returns neighbor relative offsets (dr, dc) for a given biome.
  List<(int, int)> _getNeighborOffsetsForBiome(BiomeType biome) {
    switch (biome) {
      case BiomeType.diagonal:
        return const [(-1, -1), (-1, 1), (1, -1), (1, 1)];
      case BiomeType.orthogonal:
        return const [(-1, 0), (1, 0), (0, -1), (0, 1)];
      case BiomeType.range:
        return const [
          (-2, -2), (-2, -1), (-2, 0), (-2, 1), (-2, 2),
          (-1, -2), (-1, -1), (-1, 0), (-1, 1), (-1, 2),
          (0, -2),  (0, -1),           (0, 1),  (0, 2),
          (1, -2),  (1, -1),  (1, 0),  (1, 1),  (1, 2),
          (2, -2),  (2, -1),  (2, 0),  (2, 1),  (2, 2),
        ];
      case BiomeType.regular:
      case BiomeType.unknown:
      case BiomeType.random:
      case BiomeType.blind:
        return const [
          (-1, -1), (-1, 0), (-1, 1),
          (0, -1),           (0, 1),
          (1, -1),  (1, 0),  (1, 1),
        ];
    }
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

    final regionMines = MinesweeperConfig.rankToMineCountFunction(
      region.rank,
      baseMines: widget.minesPerRegion,
    );

    final targetMines = min(
      regionMines,
      availableIndices.length,
    );

    final rng = widget.random ?? Random();
    availableIndices.shuffle(rng);
    for (int i = 0; i < targetMines; i++) {
      final idx = availableIndices[i];
      region.mines[idx] = 1;
    }
    region.mineCount = targetMines;

    if (region.hasChest && region.chestCellIndex == null) {
      final safeIndices = <int>[];
      final weights = <double>[];
      double totalWeight = 0.0;
      for (int i = 0; i < totalCells; i++) {
        if (region.mines[i] == 0) {
          safeIndices.add(i);
          final lr = i ~/ region.cols;
          final lc = i % region.cols;
          final w = MinesweeperConfig.centerWeightedCellScore(
            lr,
            lc,
            region.rows,
            region.cols,
          );
          weights.add(w);
          totalWeight += w;
        }
      }

      if (safeIndices.isNotEmpty) {
        final roll = rng.nextDouble() * totalWeight;
        double cumulative = 0.0;
        int chosen = safeIndices.first;
        for (int j = 0; j < safeIndices.length; j++) {
          cumulative += weights[j];
          if (roll <= cumulative) {
            chosen = safeIndices[j];
            break;
          }
        }
        region.chestCellIndex = chosen;
      }
    }

    if (region.biome == BiomeType.unknown) {
      final safeNumberedCandidates = <int>[];
      for (int i = 0; i < totalCells; i++) {
        if (region.mines[i] == 1) continue;
        final lr = i ~/ region.cols;
        final lc = i % region.cols;
        int localAdjMines = 0;
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;
            final nlr = lr + dr;
            final nlc = lc + dc;
            if (nlr >= 0 && nlr < region.rows && nlc >= 0 && nlc < region.cols) {
              if (region.mines[nlr * region.cols + nlc] == 1) {
                localAdjMines++;
              }
            }
          }
        }
        if (localAdjMines > 0) {
          safeNumberedCandidates.add(i);
        }
      }

      final candidates = safeNumberedCandidates.isNotEmpty
          ? safeNumberedCandidates
          : [for (int i = 0; i < totalCells; i++) if (region.mines[i] == 0) i];

      candidates.shuffle(rng);
      final countToHide = min(
        MinesweeperConfig.unknownBiomeHiddenCellCount,
        candidates.length,
      );
      for (int i = 0; i < countToHide; i++) {
        region.hiddenNumberIndices.add(candidates[i]);
      }
    }
  }

  int _getAdjacentMines(int regionR, int regionC, int localR, int localC) {
    final region = _getOrInitRegion(regionR, regionC);
    final idx = region.localIndex(localR, localC);
    if (region.adjacent[idx] != 255) {
      return region.adjacent[idx];
    }

    int count = 0;
    for (final (dr, dc) in _getNeighborOffsetsForBiome(region.biome)) {
      final (nrR, nrC, nlR, nlC) =
          _resolveCell(regionR, regionC, localR + dr, localC + dc);
      _ensureRegionGenerated(nrR, nrC);
      final neighborRegion = _getOrInitRegion(nrR, nrC);
      if (neighborRegion.mines[neighborRegion.localIndex(nlR, nlC)] == 1) {
        count++;
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
    if (!widget.isInfiniteWorld) {
      if (widget.regionsY > 0 && (r < 0 || r >= widget.regionsY)) return false;
      if (widget.regionsX > 0 && (c < 0 || c >= widget.regionsX)) return false;
    }
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

  bool _isRegionCompleted(int r, int c) {
    final region = _regions[(r, c)];
    if (region == null || !region.isGenerated) return false;
    if (region.isCleared) return true;

    if (region.safeCells > 0 && region.revealedCount >= region.safeCells) {
      region.isCleared = true;
      return true;
    }

    final total = region.rows * region.cols;
    for (int i = 0; i < total; i++) {
      if (region.mines[i] == 1) {
        if (region.cellStates[i] != CellState.flagged) return false;
      } else {
        if (region.cellStates[i] != CellState.revealed &&
            region.cellStates[i] != CellState.hiddenNumber) {
          return false;
        }
      }
    }
    region.isCleared = true;
    return true;
  }

  // ── Mine placement with safe clearing on first click ───────────────────────

  void _placeInitialMines(int regionR, int regionC, int startLocalR, int startLocalC) {
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        final (targetR, targetC, targetLr, targetLc) = _resolveCell(
          regionR,
          regionC,
          startLocalR + dr,
          startLocalC + dc,
        );
        final region = _getOrInitRegion(targetR, targetC);
        _forbiddenMineIndices
            .putIfAbsent((targetR, targetC), () => <int>{})
            .add(region.localIndex(targetLr, targetLc));
      }
    }

    final targetRegion = _getOrInitRegion(regionR, regionC);
    _generateRegionMines(targetRegion);
    _actualMineCount = widget.isInfiniteWorld
        ? targetRegion.mineCount
        : (widget.regionsX * widget.regionsY * widget.minesPerRegion);
    _minesPlaced = true;
    _onRegionUnlocked(regionR, regionC);
  }

  // ── Inventory & Item Actions ───────────────────────────────────────────────

  void _breakItem(InventoryItemType type) {
    final idx = _inventory.indexOf(type);
    if (idx != -1) {
      _inventory[idx] = null;
    }
  }

  void _useInventorySlot(int slotIndex) {
    if (_gameOver || _gameWon) return;
    if (slotIndex < 0 || slotIndex >= _inventory.length) return;
    final item = _inventory[slotIndex];
    if (item == null) return;

    if (item == InventoryItemType.flagObvious) {
      if (!_minesPlaced) return;
      _flagAllObviousMines();
      setState(() {
        _inventory[slotIndex] = null;
      });
    }
  }

  int _flagAllObviousMines() {
    int totalFlagged = 0;
    bool progress = true;

    while (progress) {
      progress = false;
      final obviousMinesToFlag = <(int, int, int, int)>{};

      for (final region in _regions.values.toList()) {
        if (region.revealedCount == 0 &&
            !region.cellStates.contains(CellState.revealed)) {
          continue;
        }

        for (int lr = 0; lr < region.rows; lr++) {
          for (int lc = 0; lc < region.cols; lc++) {
            final idx = region.localIndex(lr, lc);
            final state = region.cellStates[idx];
            if (state != CellState.revealed) continue;

            final adjMines = _getAdjacentMines(region.r, region.c, lr, lc);
            if (adjMines == 0) continue;

            int flaggedCount = 0;
            final unrevealed = <(int, int, int, int)>[];

            for (final (dr, dc) in _getNeighborOffsetsForBiome(region.biome)) {
              final (nrR, nrC, nlR, nlC) =
                  _resolveCell(region.r, region.c, lr + dr, lc + dc);
              final neighborRegion = _getOrInitRegion(nrR, nrC);
              final nIdx = neighborRegion.localIndex(nlR, nlC);
              final nState = neighborRegion.cellStates[nIdx];

              if (nState == CellState.flagged) {
                flaggedCount++;
              } else if (nState == CellState.unrevealed) {
                unrevealed.add((nrR, nrC, nlR, nlC));
              }
            }

            final remainingNeeded = adjMines - flaggedCount;
            if (remainingNeeded > 0 && remainingNeeded == unrevealed.length) {
              for (final cell in unrevealed) {
                obviousMinesToFlag.add(cell);
              }
            }
          }
        }
      }

      if (obviousMinesToFlag.isNotEmpty) {
        for (final (rR, rC, lR, lC) in obviousMinesToFlag) {
          final r = _getOrInitRegion(rR, rC);
          final idx = r.localIndex(lR, lC);
          if (r.cellStates[idx] == CellState.unrevealed) {
            r.cellStates[idx] = CellState.flagged;
            r.flagCount++;
            _flagCount++;
            _totalFlagsPlacedInSession++;
            if (r.mines[idx] == 1) {
              _correctlyFlaggedMines++;
            } else {
              _hasMisplacedFlag = true;
            }
            totalFlagged++;
            progress = true;
          }
        }
      }
    }

    if (totalFlagged > 0) {
      _checkWin();
      _checkNewlyUnlockedRegions();
    }

    return totalFlagged;
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

  void _reveal(int regionR, int regionC, int localRow, int localCol) {
    if (_gameOver || _gameWon) return;

    if (localRow < 0 ||
        localRow >= widget.regionRows ||
        localCol < 0 ||
        localCol >= widget.regionCols) {
      return;
    }

    final region = _getOrInitRegion(regionR, regionC);
    final idx = region.localIndex(localRow, localCol);

    final state = region.cellStates[idx];
    if (state == CellState.revealed ||
        state == CellState.flagged ||
        state == CellState.hiddenNumber) {
      return;
    }

    // First click: place mines ensuring this cell & surrounding area are safe
    if (!_minesPlaced) {
      _placeInitialMines(regionR, regionC, localRow, localCol);
    }

    if (region.mines[idx] == 1) {
      if (hasShield) {
        _breakItem(InventoryItemType.shield);
        setState(() {
          region.cellStates[idx] = CellState.flagged;
          region.flagCount++;
          _flagCount++;
          _totalFlagsPlacedInSession++;
          _correctlyFlaggedMines++;
          _checkWin();
        });
        return;
      }

      region.cellStates[idx] = CellState.activatedMine;
      if (regionR == _currentRegionRow && regionC == _currentRegionCol) {
        _addShockwave(localRow, localCol);
      }
      _idlePulseController.stop();
      _entryPulseController.stop();
      setState(() {
        _gameOver = true;
        _revealAllMines();
      });
      if (mounted) widget.onFail();
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
    final isStartHidden = region.hiddenNumberIndices.contains(startIdx);
    region.cellStates[startIdx] =
        isStartHidden ? CellState.hiddenNumber : CellState.revealed;
    region.revealedCount++;
    _revealedCount++;
    newlyRevealed?.add(startIdx);
    _checkItemDiscovery(region, startIdx);

    int head = 0;
    while (head < queue.length) {
      final idx = queue[head++];
      final lr = idx ~/ region.cols;
      final lc = idx % region.cols;

      if (_getAdjacentMines(region.r, region.c, lr, lc) == 0 &&
          !region.hiddenNumberIndices.contains(idx)) {
        for (final (dr, dc) in _getNeighborOffsetsForBiome(region.biome)) {
          final nlr = lr + dr;
          final nlc = lc + dc;
          // Stop strictly at region borders!
          if (nlr >= 0 && nlr < region.rows && nlc >= 0 && nlc < region.cols) {
            final nIdx = region.localIndex(nlr, nlc);
            if (region.cellStates[nIdx] == CellState.unrevealed &&
                region.mines[nIdx] == 0) {
              final isHidden = region.hiddenNumberIndices.contains(nIdx);
              region.cellStates[nIdx] =
                  isHidden ? CellState.hiddenNumber : CellState.revealed;
              region.revealedCount++;
              _revealedCount++;
              newlyRevealed?.add(nIdx);
              _checkItemDiscovery(region, nIdx);
              if (!isHidden) {
                queue.add(nIdx);
              }
            }
          }
        }
      }
    }
  }

  void _checkItemDiscovery(RegionData region, int cellIndex) {
    // Chests remain on the cell until clicked/tapped by the player to be opened.
  }

  void _openChest(RegionData region, int cellIndex) {
    if (!region.hasChest || region.chestOpened) return;

    HapticFeedback.heavyImpact();
    setState(() {
      region.chestOpened = true;
      region.sparkleParticles = null;
    });

    final options = ChestRewardOption.generateTwoUniqueOptions(
      _rng,
      currentRegion: (region.r, region.c),
      rank: region.rank,
    );

    showChestRewardPopup(
      context,
      options: options,
      onSelected: (chosen) {
        _applyChestReward(chosen, region, cellIndex);
      },
    );
  }

  void _applyChestReward(
    ChestRewardOption chosen,
    RegionData region,
    int cellIndex,
  ) {
    switch (chosen.type) {
      case ChestRewardType.item:
        final item = chosen.itemType ?? InventoryItemType.shield;
        _grantItemToInventory(item, region, cellIndex);
        break;
      case ChestRewardType.money:
        final amount = chosen.tokenAmount ?? 20;
        widget.gameState.addTokens(amount);
        break;
      case ChestRewardType.quest:
        if (chosen.targetRegion != null) {
          setState(() {
            _questRegions.add(chosen.targetRegion!);
          });
        }
        break;
      case ChestRewardType.hint:
        if (chosen.targetRegion != null) {
          setState(() {
            _hintRegions.add(chosen.targetRegion!);
          });
        }
        break;
      case ChestRewardType.boon:
        setState(() {
          _activeBoonRankBonus += 1;
        });
        break;
      case ChestRewardType.roll:
        _performRollReward(region, cellIndex);
        break;
    }
  }

  void _grantItemToInventory(
    InventoryItemType itemType,
    RegionData region,
    int cellIndex,
  ) {
    int? targetSlot;
    for (int s = 0; s < _inventory.length; s++) {
      if (_inventory[s] == null && !_reservedInventorySlots.contains(s)) {
        targetSlot = s;
        _reservedInventorySlots.add(s);
        break;
      }
    }

    final lr = cellIndex ~/ region.cols;
    final lc = cellIndex % region.cols;

    final flight = ActiveItemFlightData(
      id: UniqueKey(),
      itemType: itemType,
      regionR: region.r,
      regionC: region.c,
      localR: lr,
      localC: lc,
      targetSlot: targetSlot,
    );

    setState(() {
      _activeItemFlights.add(flight);
    });
  }

  void _performRollReward(RegionData region, int cellIndex) {
    final int roll = 1 + _rng.nextInt(6);
    if (roll == 6) {
      widget.gameState.addTokens(50);
      _grantItemToInventory(InventoryItemType.shield, region, cellIndex);
    } else {
      widget.gameState.addTokens(roll * 10);
    }
  }

  void _toggleFlag(int regionR, int regionC, int localRow, int localCol) {
    if (_gameOver || _gameWon) return;

    if (localRow < 0 ||
        localRow >= widget.regionRows ||
        localCol < 0 ||
        localCol >= widget.regionCols) {
      return;
    }

    final region = _getOrInitRegion(regionR, regionC);
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

  /// Chords a cell by revealing adjacent unflagged cells if flag count matches adjacent mine count.
  /// Unlike standard exploration, chording IS allowed to affect cells across region borders.
  void _chord(int regionR, int regionC, int localRow, int localCol) {
    if (_gameOver || _gameWon) return;

    final region = _getOrInitRegion(regionR, regionC);
    final idx = region.localIndex(localRow, localCol);

    if (region.cellStates[idx] != CellState.revealed ||
        region.hiddenNumberIndices.contains(idx)) {
      return;
    }

    _getAdjacentMines(regionR, regionC, localRow, localCol);
    final targetCount = region.getDisplayedNumber(idx);
    if (targetCount == 0) return;

    int flaggedCount = 0;
    final unflaggedNeighbors = <(int, int, int, int)>[];

    for (final (dr, dc) in _getNeighborOffsetsForBiome(region.biome)) {
      final (targetRegionRow, targetRegionCol, targetLocalRow, targetLocalCol) =
          _resolveCell(regionR, regionC, localRow + dr, localCol + dc);

      if (!_isRegionAccessible(targetRegionRow, targetRegionCol)) {
        continue;
      }

      final targetRegion = _getOrInitRegion(targetRegionRow, targetRegionCol);
      final nIdx = targetRegion.localIndex(targetLocalRow, targetLocalCol);
      final nState = targetRegion.cellStates[nIdx];

      if (nState == CellState.flagged) {
        flaggedCount++;
      } else if (nState == CellState.unrevealed) {
        unflaggedNeighbors.add((
          targetRegionRow,
          targetRegionCol,
          targetLocalRow,
          targetLocalCol,
        ));
      }
    }

    if (flaggedCount != targetCount || unflaggedNeighbors.isEmpty) {
      return;
    }

    final hitMines = <(int, int, int, int)>[];
    final safeNeighbors = <(int, int, int, int)>[];

    for (final (tRegR, tRegC, tLocR, tLocC) in unflaggedNeighbors) {
      final targetRegion = _getOrInitRegion(tRegR, tRegC);
      final nIdx = targetRegion.localIndex(tLocR, tLocC);

      if (targetRegion.cellStates[nIdx] != CellState.unrevealed) {
        continue;
      }

      if (targetRegion.mines[nIdx] == 1) {
        hitMines.add((tRegR, tRegC, tLocR, tLocC));
      } else {
        safeNeighbors.add((tRegR, tRegC, tLocR, tLocC));
      }
    }

    final shieldCount =
        _inventory.where((item) => item == InventoryItemType.shield).length;
    final defusedCount = min(hitMines.length, shieldCount);

    for (int i = 0; i < defusedCount; i++) {
      _breakItem(InventoryItemType.shield);
    }

    setState(() {
      for (int i = 0; i < defusedCount; i++) {
        final (mRegR, mRegC, mLocR, mLocC) = hitMines[i];
        final mRegion = _getOrInitRegion(mRegR, mRegC);
        final mIdx = mRegion.localIndex(mLocR, mLocC);
        mRegion.cellStates[mIdx] = CellState.flagged;
        mRegion.flagCount++;
        _flagCount++;
        _totalFlagsPlacedInSession++;
        _correctlyFlaggedMines++;
      }

      if (defusedCount == hitMines.length) {
        for (final (tRegR, tRegC, tLocR, tLocC) in safeNeighbors) {
          final targetRegion = _getOrInitRegion(tRegR, tRegC);
          final newlyRevealed = <int>[];
          _floodReveal(targetRegion, tLocR, tLocC, newlyRevealed);

          if (widget.gameState.isCurrentGameAnomaly &&
              !_gameOver &&
              !_gameWon) {
            bool revealedZero = newlyRevealed.any((i) =>
                _getAdjacentMines(
                  targetRegion.r,
                  targetRegion.c,
                  i ~/ targetRegion.cols,
                  i % targetRegion.cols,
                ) == 0);
            if (revealedZero) {
              final candidates = newlyRevealed
                  .where((i) {
                    final r = i ~/ targetRegion.cols;
                    final c = i % targetRegion.cols;
                    return _getAdjacentMines(
                              targetRegion.r,
                              targetRegion.c,
                              r,
                              c,
                            ) > 0 &&
                        r > 0 &&
                        r < targetRegion.rows - 1 &&
                        c > 0 &&
                        c < targetRegion.cols - 1;
                  })
                  .toList();
              if (candidates.isNotEmpty) {
                final chosen =
                    candidates[Random().nextInt(candidates.length)];
                targetRegion.cellStates[chosen] = CellState.hiddenNumber;
              }
            }
          }
        }

        _checkWin();
        _checkNewlyUnlockedRegions();
      } else {
        for (int i = defusedCount; i < hitMines.length; i++) {
          final (tRegR, tRegC, tLocR, tLocC) = hitMines[i];
          final targetRegion = _getOrInitRegion(tRegR, tRegC);
          final nIdx = targetRegion.localIndex(tLocR, tLocC);
          targetRegion.cellStates[nIdx] = CellState.activatedMine;
          if (tRegR == _currentRegionRow && tRegC == _currentRegionCol) {
            _addShockwave(tLocR, tLocC);
          }
        }
        _idlePulseController.stop();
        _entryPulseController.stop();
        _gameOver = true;
        _revealAllMines();
        if (mounted) widget.onFail();
      }
    });
  }

  void _revealAllMines() {
    for (final region in _regions.values) {
      if (region.isCleared || _isRegionCompleted(region.r, region.c)) continue;
      final size = region.rows * region.cols;
      for (int i = 0; i < size; i++) {
        if (region.mines[i] == 1) {
          if (region.cellStates[i] != CellState.activatedMine &&
              region.cellStates[i] != CellState.flagged) {
            region.cellStates[i] = CellState.revealedMine;
          }
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
        _idlePulseController.stop();
        _entryPulseController.stop();
        if (!_hasMisplacedFlag) {
          widget.gameState.recordFlawlessMinesweeperWin();
        }
        Future.delayed(BaseGameConfig.winTransitionDelay, () {
          if (mounted) widget.onComplete();
        });
        return;
      }
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

      if (allSafeRevealed) {
        currentRegion.isCleared = true;
        if (!_hasMisplacedFlag && allMinesFlagged) {
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
  (int, int) _get8SliceDirection(Offset delta) {
    if (delta.distance < 4.0) return (0, 0);
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
        _planeOffset == Offset.zero) {
      return;
    }
    _slideController.stop();
    final bool didChangeRegion = _isTransitioning &&
        _targetTransitionRow != null &&
        _targetTransitionCol != null &&
        (_targetTransitionRow != _currentRegionRow ||
            _targetTransitionCol != _currentRegionCol);
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
    _offsetAnimation = null;
    _isThresholdFlipped = false;
    _swipeDRow = 0;
    _swipeDCol = 0;
    _isTransitioning = false;
    if (didChangeRegion && !_entryPulseController.isAnimating) {
      _startBorderPulseSequence();
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_isMinimapExpanded) return;
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
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_dragStartPos == null) return;
    final delta = event.position - _dragStartPos!;
    _rawDragDelta = delta;

    if (delta.distance > 12.0) {
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
      }
      _swipeDRow = 0;
      _swipeDCol = 0;
      return;
    }

    if (_entryPulseController.isAnimating ||
        _entryPulseController.value > 0.0 ||
        _idlePulseController.isAnimating ||
        _idlePulseController.value > 0.0) {
      _entryPulseController.stop();
      _entryPulseController.value = 0.0;
      _idlePulseController.stop();
      _idlePulseController.value = 0.0;
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
      if (!_isThresholdFlipped || _swipeDRow != dRow || _swipeDCol != dCol) {
        _isThresholdFlipped = true;
        _swipeDRow = dRow;
        _swipeDCol = dCol;
      }
    } else {
      if (_isThresholdFlipped) {
        _isThresholdFlipped = false;
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
      _planeOffset = _currentScale > 0 ? (visualOffset / _currentScale) : visualOffset;
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
      }
      _animateSnapBack();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _touchStartedWhileAnimating = false;
    _dragStartPos = null;
    if (_isThresholdFlipped) {
      _isThresholdFlipped = false;
    }
    _animateSnapBack();
  }

  void _animateSnapBack() {
    _slideController.stop();
    _isThresholdFlipped = false;
    setState(() {
      _targetTransitionRow = null;
      _targetTransitionCol = null;
      _swipeDRow = 0;
      _swipeDCol = 0;
    });
    if (_planeOffset == Offset.zero) {
      setState(() {
        _offsetAnimation = null;
        _swipeDRow = 0;
        _swipeDCol = 0;
      });
      _resumeIdlePulse();
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
    _slideController.duration = const Duration(milliseconds: 180);
    _slideController.forward(from: 0.0).then((_) {
      if (!mounted || _transitionGeneration != gen) return;
      setState(() {
        _planeOffset = Offset.zero;
        _offsetAnimation = null;
        _isThresholdFlipped = false;
        _swipeDRow = 0;
        _swipeDCol = 0;
      });
      _resumeIdlePulse();
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

    _startBorderPulseSequence();

    final gen = ++_transitionGeneration;
    _slideController.duration = const Duration(milliseconds: 220);
    _slideController.forward(from: 0.0).then((_) {
      if (!mounted || _transitionGeneration != gen) return;
      setState(() {
        _currentRegionRow = targetRow;
        _currentRegionCol = targetCol;
        if (_questRegions.remove((targetRow, targetCol))) {
          widget.gameState.addTokens(50);
        }
        if (!_unlockedRegions.contains((targetRow, targetCol))) {
          _unlockedRegions.add((targetRow, targetCol));
        }
        if (_minesPlaced) {
          _onRegionUnlocked(targetRow, targetCol);
        }
        _targetTransitionRow = null;
        _targetTransitionCol = null;
        _planeOffset = Offset.zero;
        _offsetAnimation = null;
        _isThresholdFlipped = false;
        _swipeDRow = 0;
        _swipeDCol = 0;
        _isTransitioning = false;
      });
      _resumeIdlePulse();
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

  void _selectAndCollapseMinimap() {
    final targetRow = _extendedSelectedRegion?.$1 ?? _currentRegionRow;
    final targetCol = _extendedSelectedRegion?.$2 ?? _currentRegionCol;

    setState(() {
      _isMinimapExpanded = false;
      _extendedSelectedRegion = null;

      if (targetRow != _currentRegionRow || targetCol != _currentRegionCol) {
        if (_isRegionAccessible(targetRow, targetCol)) {
          _currentRegionRow = targetRow;
          _currentRegionCol = targetCol;
          if (_questRegions.remove((targetRow, targetCol))) {
            widget.gameState.addTokens(50);
          }
          if (!_unlockedRegions.contains((targetRow, targetCol))) {
            _unlockedRegions.add((targetRow, targetCol));
          }
          _getOrInitRegion(targetRow, targetCol);
          if (_minesPlaced) {
            _onRegionUnlocked(targetRow, targetCol);
          }
          _slideController.stop();
          _planeOffset = Offset.zero;
          _targetTransitionRow = null;
          _targetTransitionCol = null;
          _offsetAnimation = null;
          _isThresholdFlipped = false;
          _swipeDRow = 0;
          _swipeDCol = 0;
          _isTransitioning = false;
          _startBorderPulseSequence();
        }
      } else {
        _resumeIdlePulse();
      }
    });
  }

  // ── Cell Interaction Handlers ──────────────────────────────────────────────

  void _handleCellTap(int targetRegionRow, int targetRegionCol, int localRow, int localCol) {
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

    if (!_isRegionAccessible(targetRegionRow, targetRegionCol)) {
      return;
    }

    final region = _getOrInitRegion(targetRegionRow, targetRegionCol);
    final idx = region.localIndex(localRow, localCol);
    final state = region.cellStates[idx];

    // If the cell is revealed and has an unopened chest, opening the chest takes precedence!
    if (region.hasChest &&
        !region.chestOpened &&
        region.chestCellIndex == idx &&
        (state == CellState.revealed || state == CellState.hiddenNumber)) {
      _openChest(region, idx);
      return;
    }

    if (state == CellState.unrevealed) {
      _reveal(targetRegionRow, targetRegionCol, localRow, localCol);
    } else if (state == CellState.revealed &&
        (_getAdjacentMines(targetRegionRow, targetRegionCol, localRow, localCol) > 0 ||
            region.getDisplayedNumber(idx) > 0)) {
      _chord(targetRegionRow, targetRegionCol, localRow, localCol);
    }
  }

  void _handleCellLongPress(int targetRegionRow, int targetRegionCol, int localRow, int localCol) {
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

    if (!_isRegionAccessible(targetRegionRow, targetRegionCol)) {
      return;
    }

    final region = _getOrInitRegion(targetRegionRow, targetRegionCol);
    final idx = region.localIndex(localRow, localCol);
    final state = region.cellStates[idx];

    if (state == CellState.unrevealed || state == CellState.flagged) {
      HapticFeedback.mediumImpact();
      _toggleFlag(targetRegionRow, targetRegionCol, localRow, localCol);
    }
  }

  Widget _buildCellForPanel(
    int dr,
    int dc,
    int r,
    int c,
    double totalTileSize,
    double cellGap, {
    Color? biomeColor,
  }) {
    final regionRow = _currentRegionRow + dr;
    final regionCol = _currentRegionCol + dc;
    final region = _getOrInitRegion(regionRow, regionCol);
    final idx = region.localIndex(r, c);

    final isCurrentPanel = (dr == 0 && dc == 0);
    final isNeighbor = !isCurrentPanel;
    final isAccessible = _isRegionAccessible(regionRow, regionCol);
    final isInteractable =
        isAccessible && !_isAnimating && !_gameOver && !_gameWon;

    int adjacentMines = 0;
    if (region.cellStates[idx] == CellState.revealed ||
        region.cellStates[idx] == CellState.hiddenNumber) {
      _getAdjacentMines(regionRow, regionCol, r, c);
      adjacentMines = region.getDisplayedNumber(idx);
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
        biomeColor: biomeColor,
        hasChest: region.hasChest && region.chestCellIndex == idx,
        isChestOpened: region.chestOpened,
        onTap: isInteractable ? () => _handleCellTap(regionRow, regionCol, r, c) : null,
        onLongPress: isInteractable ? () => _handleCellLongPress(regionRow, regionCol, r, c) : null,
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
    double originX,
    double originY,
  ) {
    final regionRow = _currentRegionRow + dr;
    final regionCol = _currentRegionCol + dc;
    final targetRegion = _getOrInitRegion(regionRow, regionCol);
    final isSpecialBiome =
        targetRegion.biome != BiomeType.regular && targetRegion.isBiomeRevealed;
    final biomeColor = MinesweeperConfig.biomeBorderColor(targetRegion.biome);

    final activeGridWidth = widget.regionCols * totalTileSize;
    final activeGridHeight = widget.regionRows * totalTileSize;
    final panelWidth =
        activeGridWidth + (paddingAmount * 2) + (borderWidth * 2);
    final panelHeight =
        activeGridHeight + (paddingAmount * 2) + (borderWidth * 2);

    final strideX = panelWidth + panelGap;
    final strideY = panelHeight + panelGap;

    final panelLeft = originX + (dc * strideX) + _planeOffset.dx;
    final panelTop = originY + (dr * strideY) + _planeOffset.dy;

    final unlockAnimation = _unlockAnimations[(regionRow, regionCol)];

    final selectedDr =
        (_isThresholdFlipped || _isTransitioning) ? _swipeDRow : 0;
    final selectedDc =
        (_isThresholdFlipped || _isTransitioning) ? _swipeDCol : 0;
    final isSelected = (dr == selectedDr && dc == selectedDc);

    Color getActiveBorderColor() {
      if (!isSelected) {
        if (isSpecialBiome && biomeColor != null) {
          return biomeColor.withValues(
            alpha: MinesweeperConfig.nonSelectedBiomeBorderAlpha,
          );
        }
        return MinesweeperConfig.nonSelectedRegularBorderColor;
      }

      if (_entryPulseAnimation.value > 0.0 || _entryPulseController.isAnimating) {
        final t = _entryPulseAnimation.value.clamp(0.0, 1.0);
        if (t > 0.0) {
          if (isSpecialBiome && biomeColor != null) {
            final alpha = ui.lerpDouble(
              MinesweeperConfig.nonSelectedBiomeBorderAlpha,
              MinesweeperConfig.firstIterationBiomeBorderAlpha,
              t,
            )!;
            return biomeColor.withValues(alpha: alpha);
          } else {
            return Color.lerp(
              MinesweeperConfig.nonSelectedRegularBorderColor,
              MinesweeperConfig.firstIterationRegularBorderColor,
              t,
            )!;
          }
        }
      }

      if (_idlePulseAnimation.value > 0.0 || _idlePulseController.isAnimating) {
        final t = _idlePulseAnimation.value.clamp(0.0, 1.0);
        if (t > 0.0) {
          if (isSpecialBiome && biomeColor != null) {
            final alpha = ui.lerpDouble(
              MinesweeperConfig.nonSelectedBiomeBorderAlpha,
              MinesweeperConfig.idlePulseBiomeBorderAlpha,
              t,
            )!;
            return biomeColor.withValues(alpha: alpha);
          } else {
            return Color.lerp(
              MinesweeperConfig.nonSelectedRegularBorderColor,
              MinesweeperConfig.idlePulseRegularBorderColor,
              t,
            )!;
          }
        }
      }

      if (isSpecialBiome && biomeColor != null) {
        return biomeColor.withValues(
          alpha: MinesweeperConfig.nonSelectedBiomeBorderAlpha,
        );
      }
      return MinesweeperConfig.nonSelectedRegularBorderColor;
    }

    final Color panelBackgroundColor = (isSpecialBiome && biomeColor != null)
        ? Color.alphaBlend(
            biomeColor.withValues(
              alpha: MinesweeperConfig.regionPanelTintAlpha,
            ),
            MinesweeperConfig.regionPanelBaseColor,
          )
        : MinesweeperConfig.regularRegionPanelBackgroundColor;

    final stackWidget = Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Panel Container Box (Card Fill + Shadow + Normal Border)
        Positioned.fill(
          child: IgnorePointer(
            child: isSelected
                ? AnimatedBuilder(
                    animation: Listenable.merge([
                      _entryPulseController,
                      _idlePulseController,
                    ]),
                    builder: (context, _) {
                      return Container(
                        key: const ValueKey('actual_panel_container'),
                        decoration: BoxDecoration(
                          color: panelBackgroundColor,
                          borderRadius: BorderRadius.circular(
                            widget.panelCornerRadius,
                          ),
                          border: Border.all(
                            color: getActiveBorderColor(),
                            width: isSpecialBiome
                                ? MinesweeperConfig.unknownBiomeBorderWidth
                                : borderWidth,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : Container(
                    key: const ValueKey('actual_panel_container'),
                    decoration: BoxDecoration(
                      color: panelBackgroundColor,
                      borderRadius: BorderRadius.circular(
                        widget.panelCornerRadius,
                      ),
                      border: Border.all(
                        color: getActiveBorderColor(),
                        width: isSpecialBiome
                            ? MinesweeperConfig.unknownBiomeBorderWidth
                            : borderWidth,
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
                        biomeColor: isSpecialBiome ? biomeColor : null,
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

        // 4. Sparkles Layer (Regions containing unopened chests)
        if (targetRegion.hasItem)
          Positioned(
            left: 0,
            top: 0,
            width: panelWidth,
            height: panelHeight,
            child: IgnorePointer(
              child: RegionSparklesWidget(
                key: ValueKey('region_sparkles_${regionRow}_$regionCol'),
                width: panelWidth,
                height: panelHeight,
                active: targetRegion.hasItem,
                enableContinuousInTests:
                    widget.enableContinuousSparklesInTests,
                particles: targetRegion.sparkleParticles,
                onParticlesCreated: (particles) {
                  targetRegion.sparkleParticles = particles;
                },
              ),
            ),
          ),

        // 5. Quest Marker Layer ('!')
        if (_questRegions.contains((regionRow, regionCol)))
          Positioned(
            top: 8,
            right: 8,
            child: IgnorePointer(
              child: Container(
                key: ValueKey('region_quest_marker_${regionRow}_$regionCol'),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amberAccent, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.6),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Text(
                  '!',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.amberAccent,
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    final imageFilteredWidget = ImageFiltered(
      imageFilter: ui.ImageFilter.matrix(Matrix4.identity().storage),
      child: stackWidget,
    );

    final Widget opacityWidget = (unlockAnimation != null)
        ? AnimatedBuilder(
            animation: unlockAnimation,
            builder: (context, child) => Opacity(
              opacity: unlockAnimation.value.clamp(0.0, 1.0),
              child: child,
            ),
            child: imageFilteredWidget,
          )
        : Opacity(
            opacity: 1.0,
            child: imageFilteredWidget,
          );

    return Positioned(
      key: ValueKey('region_panel_${dr}_$dc'),
      left: panelLeft,
      top: panelTop,
      width: panelWidth,
      height: panelHeight,
      child: RepaintBoundary(
        child: opacityWidget,
      ),
    );
  }

  Widget _buildBoard(
    double virtualWidth,
    double virtualHeight,
    double originX,
    double originY,
    List<(int, int)> panelOrder,
    double totalTileSize,
    double cellGap,
    double paddingAmount,
    double borderWidth,
    double panelGap,
  ) {
    return SizedBox(
      width: virtualWidth,
      height: virtualHeight,
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
                originX,
                originY,
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
    final panelInset = paddingAmount + borderWidth;

    // Minimum required visible margin: selected region + nearest 2 rows/columns of adjacent regions
    final minMarginX = 2 * totalTileSize + panelInset + panelGap;
    final minMarginY = 2 * totalTileSize + panelInset + panelGap;
    final minViewportWidth = panelWidth + (2 * minMarginX);
    final minViewportHeight = panelHeight + (2 * minMarginY);

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;
          final availableWidth =
              screenWidth.isFinite ? screenWidth : minViewportWidth;
          final availableHeight =
              screenHeight.isFinite ? screenHeight : minViewportHeight;

          // Downscale rule:
          // No matter how narrow/short the screen size is, the selected region and
          // the nearest two rows/columns of adjacent regions must always be visible!
          final scale = min(
            1.0,
            min(
              availableWidth / minViewportWidth,
              availableHeight / minViewportHeight,
            ),
          );
          _currentScale = scale;
          final virtualWidth = availableWidth / scale;
          final virtualHeight = availableHeight / scale;

          final originX = (virtualWidth - panelWidth) / 2.0;
          final originY = (virtualHeight - panelHeight) / 2.0;

          final minDc =
              ((- (originX + panelWidth + _planeOffset.dx)) / strideX).floor() - 1;
          final maxDc =
              ((virtualWidth - originX - _planeOffset.dx) / strideX).ceil() + 1;
          final minDr =
              ((- (originY + panelHeight + _planeOffset.dy)) / strideY).floor() - 1;
          final maxDr =
              ((virtualHeight - originY - _planeOffset.dy) / strideY).ceil() + 1;

          int startDr = min(minDr, -1);
          int endDr = max(maxDr, 1);
          int startDc = min(minDc, -1);
          int endDc = max(maxDc, 1);

          if (_swipeDRow != 0 || _swipeDCol != 0) {
            startDr = min(startDr, _swipeDRow - 1);
            endDr = max(endDr, _swipeDRow + 1);
            startDc = min(startDc, _swipeDCol - 1);
            endDc = max(endDc, _swipeDCol + 1);
          }

          final panelsToRender = <(int, int)>{};
          for (int dr = startDr; dr <= endDr; dr++) {
            for (int dc = startDc; dc <= endDc; dc++) {
              final r = _currentRegionRow + dr;
              final c = _currentRegionCol + dc;

              if (!widget.isInfiniteWorld) {
                if (widget.regionsY > 0 && (r < 0 || r >= widget.regionsY)) continue;
                if (widget.regionsX > 0 && (c < 0 || c >= widget.regionsX)) continue;
              }

              if (_isRegionAccessible(r, c)) {
                final pLeft = originX + (dc * strideX) + _planeOffset.dx;
                final pTop = originY + (dr * strideY) + _planeOffset.dy;
                final pRight = pLeft + panelWidth;
                final pBottom = pTop + panelHeight;

                final isImmediate = (dr.abs() <= 1 && dc.abs() <= 1) ||
                    ((_swipeDRow != 0 || _swipeDCol != 0) &&
                        (dr - _swipeDRow).abs() <= 1 &&
                        (dc - _swipeDCol).abs() <= 1);
                final intersectsViewport = pRight > 0 &&
                    pLeft < virtualWidth &&
                    pBottom > 0 &&
                    pTop < virtualHeight;

                if (isImmediate || intersectsViewport) {
                  panelsToRender.add((dr, dc));
                }
              }
            }
          }

          final otherPanels = <(int, int)>[];
          (int, int)? incomingPanel;
          (int, int)? centerPanel;

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

          final boardWidget = SizedBox(
            width: availableWidth,
            height: availableHeight,
            child: FittedBox(
              fit: BoxFit.fill,
              alignment: Alignment.center,
              child: _buildBoard(
                virtualWidth,
                virtualHeight,
                originX,
                originY,
                panelOrder,
                totalTileSize,
                cellGap,
                paddingAmount,
                borderWidth,
                panelGap,
              ),
            ),
          );

          final compactWidth =
              (MinesweeperConfig.minimapCols * MinesweeperConfig.minimapCellSlot) +
              (MinesweeperConfig.minimapPadding * 2) +
              (MinesweeperConfig.headerControlBorderWidth * 2);
          final compactHeight =
              (MinesweeperConfig.minimapRows * MinesweeperConfig.minimapCellSlot) +
              (MinesweeperConfig.minimapPadding * 2) +
              (MinesweeperConfig.headerControlBorderWidth * 2);

          final padding = MinesweeperConfig.minimapExpandedPadding;
          final expandedSize = min(
            availableWidth - (2 * padding),
            availableHeight - (2 * padding),
          );
          final expandedWidth = expandedSize;
          final expandedHeight = expandedSize;

          final minimapSizeRatio =
              compactWidth > 0 ? expandedWidth / compactWidth : 1.0;

          int minCol = 0;
          int maxCol = widget.regionsX > 0 ? widget.regionsX - 1 : 0;
          int minRow = 0;
          int maxRow = widget.regionsY > 0 ? widget.regionsY - 1 : 0;

          void includeCoord(int r, int c) {
            if (c < minCol) minCol = c;
            if (c > maxCol) maxCol = c;
            if (r < minRow) minRow = r;
            if (r > maxRow) maxRow = r;
          }

          if (!widget.lockInaccessibleRegions) {
            minCol = 0;
            maxCol = widget.regionsX > 0 ? widget.regionsX - 1 : 0;
            minRow = 0;
            maxRow = widget.regionsY > 0 ? widget.regionsY - 1 : 0;
            if (widget.isInfiniteWorld) {
              includeCoord(widget.initialRegionY, widget.initialRegionX);
              includeCoord(_currentRegionRow, _currentRegionCol);
              for (final k in _regions.keys) {
                includeCoord(k.$1, k.$2);
              }
              for (final k in _unlockedRegions) {
                includeCoord(k.$1, k.$2);
              }
            }
          } else {
            minCol = _currentRegionCol;
            maxCol = _currentRegionCol;
            minRow = _currentRegionRow;
            maxRow = _currentRegionRow;
            includeCoord(widget.initialRegionY, widget.initialRegionX);
            includeCoord(_currentRegionRow, _currentRegionCol);
            final candidateRegions = <(int, int)>{
              (widget.initialRegionY, widget.initialRegionX),
              (_currentRegionRow, _currentRegionCol),
              ..._unlockedRegions,
            };

            if (widget.regionsX > 0 &&
                widget.regionsY > 0 &&
                !widget.isInfiniteWorld) {
              for (int r = 0; r < widget.regionsY; r++) {
                for (int c = 0; c < widget.regionsX; c++) {
                  candidateRegions.add((r, c));
                }
              }
            } else {
              for (final key in _regions.keys) {
                candidateRegions.add(key);
                for (int dr = -1; dr <= 1; dr++) {
                  for (int dc = -1; dc <= 1; dc++) {
                    candidateRegions.add((key.$1 + dr, key.$2 + dc));
                  }
                }
              }
            }

            for (final coord in candidateRegions) {
              if (_isRegionAccessible(coord.$1, coord.$2)) {
                includeCoord(coord.$1, coord.$2);
              }
            }
          }

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Board fills entire screen (over safe areas)
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerUp,
                  onPointerCancel: _onPointerCancel,
                  child: boardWidget,
                ),
              ),

              // 2. Control bar (top bar in portrait, left sidebar in landscape) with opaque background
              Positioned.fill(
                child: Builder(
                  builder: (context) {
                  final mediaQuery = MediaQuery.of(context);
                  final safePadding = mediaQuery.padding;
                  final safeWidth =
                      max(0.0, availableWidth - safePadding.left - safePadding.right);
                  final isHorizontal = availableWidth > availableHeight;

                  final double targetWidth =
                      _isMinimapExpanded ? expandedWidth : compactWidth;
                  final double targetHeight =
                      _isMinimapExpanded ? expandedHeight : compactHeight;

                  final double targetTop = _isMinimapExpanded
                      ? (availableHeight - expandedHeight) / 2.0
                      : (isHorizontal
                          ? (availableHeight - compactHeight) / 2.0
                          : availableHeight -
                              safePadding.bottom -
                              MinesweeperConfig.headerControlTop -
                              compactHeight);

                  final double targetLeft = _isMinimapExpanded
                      ? (availableWidth - expandedWidth) / 2.0
                      : (isHorizontal
                          ? availableWidth -
                              safePadding.right -
                              MinesweeperConfig.headerCornerPadding -
                              compactWidth
                          : (availableWidth - compactWidth) / 2.0);

                  final headerWidth = min(minViewportWidth, safeWidth) -
                      (2 * MinesweeperConfig.headerCornerPadding);
                  const minRequiredHeaderWidth = 200.0;
                  final minimapScale = (!_isMinimapExpanded &&
                          availableWidth < compactWidth + 24.0)
                      ? (availableWidth / (compactWidth + 24.0))
                      : 1.0;

                  final rankBadge = RegionRankBadge(
                    rank: _currentRegionRank,
                    isVertical: isHorizontal,
                  );

                  final isBlindBiome =
                      _getOrInitRegion(_currentRegionRow, _currentRegionCol).biome ==
                          BiomeType.blind;

                  final mineCounterBadge = RegionMineCounterBadge(
                    remainingMines:
                        isBlindBiome ? null : _currentRegionRemainingMines,
                    isVertical: isHorizontal,
                  );

                  final pauseButton = RegionPauseButton(
                    isGameOver: _gameOver,
                    onTap: _gameOver
                        ? () => Navigator.of(context)
                            .popUntil((route) => route.isFirst)
                        : (widget.onPause ??
                            () => showOptionsPopup(context)),
                  );

                  final headerRow = Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: rankBadge,
                        ),
                      ),
                      mineCounterBadge,
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: pauseButton,
                        ),
                      ),
                    ],
                  );

                  final bottomBarRow = Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      InventorySlotButton(
                        key: const ValueKey('bottom_bar_left_button'),
                        slotKey: _inventorySlotKeys[0],
                        itemType: _inventory.isNotEmpty ? _inventory[0] : null,
                        onTap: () => _useInventorySlot(0),
                      ),
                      const SizedBox(width: 8.0),
                      InventorySlotButton(
                        key: const ValueKey('bottom_bar_right_button'),
                        slotKey: _inventorySlotKeys[1],
                        itemType: _inventory.length > 1 ? _inventory[1] : null,
                        onTap: () => _useInventorySlot(1),
                      ),
                      const Spacer(),
                    ],
                  );

                  final leftSidebarWidth = safePadding.left +
                      MinesweeperConfig.headerButtonSize +
                      (2 * MinesweeperConfig.headerCornerPadding);
                  final rightSidebarWidth = safePadding.right +
                      MinesweeperConfig.headerButtonSize +
                      (2 * MinesweeperConfig.headerCornerPadding);
                  final topBarHeight = safePadding.top +
                      (2 * MinesweeperConfig.headerControlTop) +
                      MinesweeperConfig.headerBadgeHeight +
                      1.0;
                  final bottomBarHeight = safePadding.bottom +
                      (2 * MinesweeperConfig.headerControlTop) +
                      MinesweeperConfig.headerButtonSize +
                      1.0;
                  final overlayDepth = totalTileSize;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // ── Control Bar Gradient Overlays (1 cell wide, pass-through touches) ──
                      if (!isHorizontal) ...[
                        Positioned(
                          key: const ValueKey('top_bar_gradient_overlay'),
                          top: topBarHeight,
                          left: 0,
                          right: 0,
                          height: overlayDepth,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppColors.surface.withValues(
                                      alpha: MinesweeperConfig
                                          .barGradientOverlayNearAlpha,
                                    ),
                                    AppColors.surface.withValues(
                                      alpha: MinesweeperConfig
                                          .barGradientOverlayFarAlpha,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          key: const ValueKey('bottom_bar_gradient_overlay'),
                          bottom: bottomBarHeight,
                          left: 0,
                          right: 0,
                          height: overlayDepth,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    AppColors.surface.withValues(
                                      alpha: MinesweeperConfig
                                          .barGradientOverlayNearAlpha,
                                    ),
                                    AppColors.surface.withValues(
                                      alpha: MinesweeperConfig
                                          .barGradientOverlayFarAlpha,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Positioned(
                          key: const ValueKey('left_sidebar_gradient_overlay'),
                          top: 0,
                          bottom: 0,
                          left: leftSidebarWidth,
                          width: overlayDepth,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    AppColors.surface.withValues(
                                      alpha: MinesweeperConfig
                                          .barGradientOverlayNearAlpha,
                                    ),
                                    AppColors.surface.withValues(
                                      alpha: MinesweeperConfig
                                          .barGradientOverlayFarAlpha,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          key: const ValueKey('right_sidebar_gradient_overlay'),
                          top: 0,
                          bottom: 0,
                          right: rightSidebarWidth,
                          width: overlayDepth,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerRight,
                                  end: Alignment.centerLeft,
                                  colors: [
                                    AppColors.surface.withValues(
                                      alpha: MinesweeperConfig
                                          .barGradientOverlayNearAlpha,
                                    ),
                                    AppColors.surface.withValues(
                                      alpha: MinesweeperConfig
                                          .barGradientOverlayFarAlpha,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],

                      // ── Top Control Bar (H-bar in portrait, left sidebar in landscape) ──
                      if (!isHorizontal)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            key: const ValueKey('control_bar_background'),
                            height: topBarHeight,
                            decoration: const BoxDecoration(
                              color: AppColors.surface,
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.outlineDim,
                                  width: 1.0,
                                ),
                              ),
                            ),
                            child: SafeArea(
                              bottom: false,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal:
                                      MinesweeperConfig.headerCornerPadding,
                                  vertical:
                                      MinesweeperConfig.headerControlTop,
                                ),
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: SizedBox(
                                    width: headerWidth,
                                    child: headerWidth < minRequiredHeaderWidth
                                        ? FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.center,
                                            child: SizedBox(
                                              width: minRequiredHeaderWidth,
                                              child: headerRow,
                                            ),
                                          )
                                        : headerRow,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Positioned(
                          top: 0,
                          bottom: 0,
                          left: 0,
                          child: Container(
                            key: const ValueKey('control_bar_background'),
                            width: leftSidebarWidth,
                            decoration: const BoxDecoration(
                              color: AppColors.surface,
                              border: Border(
                                right: BorderSide(
                                  color: AppColors.outlineDim,
                                  width: 1.0,
                                ),
                              ),
                            ),
                            child: SafeArea(
                              right: false,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical:
                                      MinesweeperConfig.headerControlTop,
                                  horizontal:
                                      MinesweeperConfig.headerCornerPadding,
                                ),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.topCenter,
                                        child: rankBadge,
                                      ),
                                    ),
                                    mineCounterBadge,
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: pauseButton,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      // ── Bottom Control Bar (H-bar in portrait, right sidebar in landscape) ──
                      if (!isHorizontal)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            key: const ValueKey('bottom_control_bar_background'),
                            height: bottomBarHeight,
                            decoration: const BoxDecoration(
                              color: AppColors.surface,
                              border: Border(
                                top: BorderSide(
                                  color: AppColors.outlineDim,
                                  width: 1.0,
                                ),
                              ),
                            ),
                            child: SafeArea(
                              top: false,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal:
                                      MinesweeperConfig.headerCornerPadding,
                                  vertical:
                                      MinesweeperConfig.headerControlTop,
                                ),
                                child: bottomBarRow,
                              ),
                            ),
                          ),
                        )
                      else
                        Positioned(
                          top: 0,
                          bottom: 0,
                          right: 0,
                          child: Container(
                            key: const ValueKey('bottom_control_bar_background'),
                            width: rightSidebarWidth,
                            decoration: const BoxDecoration(
                              color: AppColors.surface,
                              border: Border(
                                left: BorderSide(
                                  color: AppColors.outlineDim,
                                  width: 1.0,
                                ),
                              ),
                            ),
                            child: SafeArea(
                              left: false,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical:
                                      MinesweeperConfig.headerControlTop,
                                  horizontal:
                                      MinesweeperConfig.headerCornerPadding,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Spacer(),
                                    InventorySlotButton(
                                      key: const ValueKey('bottom_bar_top_button'),
                                      slotKey: _inventorySlotKeys[0],
                                      itemType: _inventory.isNotEmpty
                                          ? _inventory[0]
                                          : null,
                                      onTap: () => _useInventorySlot(0),
                                    ),
                                    const SizedBox(height: 8.0),
                                    InventorySlotButton(
                                      key: const ValueKey(
                                          'bottom_bar_bottom_button'),
                                      slotKey: _inventorySlotKeys[1],
                                      itemType: _inventory.length > 1
                                          ? _inventory[1]
                                          : null,
                                      onTap: () => _useInventorySlot(1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      // ── Expanded Minimap Backdrop Barrier ───────────────────────────
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: !_isMinimapExpanded,
                          child: AnimatedOpacity(
                            duration: MinesweeperConfig.minimapExpandDuration,
                            curve: MinesweeperConfig.minimapExpandCurve,
                            opacity: _isMinimapExpanded ? 1.0 : 0.0,
                            child: GestureDetector(
                              key: const ValueKey('minimap_barrier'),
                              behavior: HitTestBehavior.opaque,
                              onTap: _selectAndCollapseMinimap,
                              child: const ColoredBox(
                                color: AppColors.overlayBarrier,
                                child: SizedBox.expand(),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ── Minimap (Animated Position, Size & Expansion) ──
                      AnimatedPositioned(
                        duration: MinesweeperConfig.minimapExpandDuration,
                        curve: MinesweeperConfig.minimapExpandCurve,
                        top: targetTop,
                        left: targetLeft,
                        width: targetWidth,
                        height: targetHeight,
                        child: RepaintBoundary(
                          child: Transform.scale(
                            scale: minimapScale,
                            child: RegionMiniMapSelector(
                              regionsX: widget.regionsX,
                              regionsY: widget.regionsY,
                              isInfiniteWorld: widget.isInfiniteWorld,
                              currentRegionRow: _currentRegionRow,
                              currentRegionCol: _currentRegionCol,
                              initialRegionRow: widget.initialRegionY,
                              initialRegionCol: widget.initialRegionX,
                              selectedRegionRow: _isMinimapExpanded
                                  ? (_extendedSelectedRegion?.$1 ??
                                      _currentRegionRow)
                                  : ((_isThresholdFlipped ||
                                          _isTransitioning)
                                      ? (_currentRegionRow + _swipeDRow)
                                      : _currentRegionRow),
                              selectedRegionCol: _isMinimapExpanded
                                  ? (_extendedSelectedRegion?.$2 ??
                                      _currentRegionCol)
                                  : ((_isThresholdFlipped ||
                                          _isTransitioning)
                                      ? (_currentRegionCol + _swipeDCol)
                                      : _currentRegionCol),
                              regionRows: widget.regionRows,
                              regionCols: widget.regionCols,
                              hasRegionRevealed: (r, c) =>
                                  _hasRegionRevealed(r, c),
                              isRegionCompleted: (r, c) =>
                                  _isRegionCompleted(r, c),
                              isRegionAccessible: _isRegionAccessible,
                              isRegionUnknownBiome: (r, c) {
                                final reg = _regions[(r, c)];
                                if (reg != null) {
                                  return reg.biome == BiomeType.unknown &&
                                      reg.isBiomeRevealed;
                                }
                                return false;
                              },
                              getRegionBiomeBorderColor: (r, c) {
                                final reg = _regions[(r, c)];
                                if (reg != null &&
                                    reg.isBiomeRevealed &&
                                    reg.biome != BiomeType.regular) {
                                  return MinesweeperConfig
                                      .biomeBorderColor(reg.biome);
                                }
                                return null;
                              },
                              getRegionSymbol: (r, c) {
                                if (_questRegions.contains((r, c))) return '!';
                                if (_hintRegions.contains((r, c))) return '?';
                                return null;
                              },
                              unlockFadeDuration:
                                  widget.regionUnlockFadeDuration,
                              planeOffset: _planeOffset,
                              strideX: strideX,
                              strideY: strideY,
                              isExpanded: _isMinimapExpanded,
                              onSelectedRegionChanged: (region) {
                                _extendedSelectedRegion = region;
                              },
                              minRegionRow: minRow,
                              maxRegionRow: maxRow,
                              minRegionCol: minCol,
                              maxRegionCol: maxCol,
                              sizeRatio: minimapSizeRatio,
                              onTap: () {
                                if (_isMinimapExpanded) {
                                  _selectAndCollapseMinimap();
                                } else {
                                  setState(() {
                                    _isMinimapExpanded = true;
                                    _extendedSelectedRegion = (
                                      _currentRegionRow,
                                      _currentRegionCol
                                    );
                                    _idlePulseController.stop();
                                    _idlePulseController.value = 0.0;
                                    _entryPulseController.stop();
                                    _entryPulseController.value = 0.0;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // 3. Flying Item Overlays
              for (final flight in _activeItemFlights)
                _buildFlyingItemOverlay(
                  flight: flight,
                  virtualWidth: virtualWidth,
                  virtualHeight: virtualHeight,
                  safePadding: MediaQuery.of(context).padding,
                  isHorizontal: availableWidth > availableHeight,
                  totalTileSize: totalTileSize,
                  cellGap: cellGap,
                  paddingAmount: paddingAmount,
                  borderWidth: borderWidth,
                  panelGap: panelGap,
                ),
            ],
          );
        },
      ),
    );
  }

  Offset _getSlotFallbackCenter(
    int slotIndex,
    double virtualWidth,
    double virtualHeight,
    EdgeInsets safePadding,
    bool isHorizontal,
  ) {
    if (!isHorizontal) {
      final x0 = safePadding.left +
          MinesweeperConfig.headerCornerPadding +
          (MinesweeperConfig.headerButtonSize / 2.0);
      final y0 = virtualHeight -
          safePadding.bottom -
          MinesweeperConfig.headerControlTop -
          (MinesweeperConfig.headerButtonSize / 2.0);
      if (slotIndex == 0) {
        return Offset(x0, y0);
      } else {
        return Offset(x0 + MinesweeperConfig.headerButtonSize + 8.0, y0);
      }
    } else {
      final x0 = safePadding.left +
          MinesweeperConfig.headerCornerPadding +
          (MinesweeperConfig.headerButtonSize / 2.0);
      final y1 = virtualHeight -
          safePadding.bottom -
          MinesweeperConfig.headerCornerPadding -
          (MinesweeperConfig.headerButtonSize / 2.0);
      final y0 = y1 - MinesweeperConfig.headerButtonSize - 8.0;
      if (slotIndex == 0) {
        return Offset(x0, y0);
      } else {
        return Offset(x0, y1);
      }
    }
  }

  Widget _buildFlyingItemOverlay({
    required ActiveItemFlightData flight,
    required double virtualWidth,
    required double virtualHeight,
    required EdgeInsets safePadding,
    required bool isHorizontal,
    required double totalTileSize,
    required double cellGap,
    required double paddingAmount,
    required double borderWidth,
    required double panelGap,
  }) {
    final activeGridWidth = widget.regionCols * totalTileSize;
    final activeGridHeight = widget.regionRows * totalTileSize;
    final panelWidth =
        activeGridWidth + (paddingAmount * 2) + (borderWidth * 2);
    final panelHeight =
        activeGridHeight + (paddingAmount * 2) + (borderWidth * 2);

    final strideX = panelWidth + panelGap;
    final strideY = panelHeight + panelGap;

    final originX = (virtualWidth - panelWidth) / 2.0;
    final originY = (virtualHeight - panelHeight) / 2.0;

    final dc = flight.regionC - _currentRegionCol;
    final dr = flight.regionR - _currentRegionRow;

    final panelLeft = originX + (dc * strideX) + _planeOffset.dx;
    final panelTop = originY + (dr * strideY) + _planeOffset.dy;

    final cellCenterX = panelLeft +
        paddingAmount +
        borderWidth +
        (flight.localC * totalTileSize) +
        (totalTileSize / 2);
    final cellCenterY = panelTop +
        paddingAmount +
        borderWidth +
        (flight.localR * totalTileSize) +
        (totalTileSize / 2);
    final startOffset = Offset(cellCenterX, cellCenterY);

    Offset? targetOffset;
    if (flight.targetSlot != null) {
      final slotKey = _inventorySlotKeys[flight.targetSlot!];
      final renderBox =
          slotKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize && mounted) {
        final globalCenter = renderBox.localToGlobal(
          Offset(renderBox.size.width / 2, renderBox.size.height / 2),
        );
        final rootBox = context.findRenderObject() as RenderBox?;
        targetOffset = rootBox != null
            ? rootBox.globalToLocal(globalCenter)
            : globalCenter;
      } else {
        targetOffset = _getSlotFallbackCenter(
          flight.targetSlot!,
          virtualWidth,
          virtualHeight,
          safePadding,
          isHorizontal,
        );
      }
    }

    return FlyingItemOverlayWidget(
      key: flight.id,
      flight: flight,
      startPosition: startOffset,
      targetSlotPosition: targetOffset,
      onCompleted: () {
        if (!mounted) return;
        setState(() {
          if (flight.targetSlot != null) {
            _reservedInventorySlots.remove(flight.targetSlot);
            _inventory[flight.targetSlot!] = flight.itemType;
          }
          _activeItemFlights.remove(flight);
        });
      },
    );
  }
}
