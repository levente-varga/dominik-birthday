import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/config.dart';
import '../../constants/colors.dart';

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
  final bool Function(int r, int c)? hasRegionRevealed;
  final bool Function(int r, int c)? isRegionCompleted;
  final bool Function(int r, int c)? isRegionAccessible;
  final bool Function(int r, int c)? isRegionUnknownBiome;
  final Color? Function(int r, int c)? getRegionBiomeBorderColor;
  final String? Function(int r, int c)? getRegionSymbol;
  final Duration unlockFadeDuration;
  final Offset planeOffset;
  final double strideX;
  final double strideY;
  final VoidCallback onTap;
  final bool isExpanded;
  final ValueChanged<(int, int)>? onSelectedRegionChanged;
  final int? minRegionRow;
  final int? maxRegionRow;
  final int? minRegionCol;
  final int? maxRegionCol;
  final double sizeRatio;
  final bool isInfiniteWorld;

  const RegionMiniMapSelector({
    super.key,
    required this.regionsX,
    required this.regionsY,
    this.isInfiniteWorld = MinesweeperConfig.isInfiniteWorld,
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
    this.hasRegionRevealed,
    this.isRegionCompleted,
    this.isRegionAccessible,
    this.isRegionUnknownBiome,
    this.getRegionBiomeBorderColor,
    this.getRegionSymbol,
    this.unlockFadeDuration = MinesweeperConfig.regionUnlockFadeDuration,
    this.planeOffset = Offset.zero,
    this.strideX = 1.0,
    this.strideY = 1.0,
    required this.onTap,
    this.isExpanded = false,
    this.onSelectedRegionChanged,
    this.minRegionRow,
    this.maxRegionRow,
    this.minRegionCol,
    this.maxRegionCol,
    this.sizeRatio = 1.0,
  });

  @override
  State<RegionMiniMapSelector> createState() => _RegionMiniMapSelectorState();
}

class _RegionMiniMapSelectorState extends State<RegionMiniMapSelector>
    with TickerProviderStateMixin {
  late AnimationController _sectorController;
  late Animation<Offset> _sectorAnimation;
  late Offset _targetSector;

  late AnimationController _panSnapController;
  Animation<Offset>? _panSnapAnimation;
  Offset _panOffset = Offset.zero;

  Offset _getTargetSector() {
    final targetCol = widget.selectedRegionCol ?? widget.currentRegionCol;
    final targetRow = widget.selectedRegionRow ?? widget.currentRegionRow;
    return Offset(targetCol.toDouble(), targetRow.toDouble());
  }

  @override
  void initState() {
    super.initState();
    _targetSector = _getTargetSector();
    _sectorController = AnimationController(
      vsync: this,
      duration: MinesweeperConfig.minimapJumpDuration,
    )..addListener(() {
        setState(() {});
      });
    _sectorAnimation = AlwaysStoppedAnimation<Offset>(_targetSector);

    _panSnapController = AnimationController(
      vsync: this,
      duration: MinesweeperConfig.minimapJumpDuration,
    )..addListener(() {
        if (_panSnapAnimation != null) {
          setState(() {
            _panOffset = _panSnapAnimation!.value;
          });
        }
      });
  }

  @override
  void didUpdateWidget(covariant RegionMiniMapSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isExpanded && !widget.isExpanded) {
      _panSnapController.stop();
      _panOffset = Offset.zero;
    } else if (!oldWidget.isExpanded && widget.isExpanded) {
      _panSnapController.stop();
      _panOffset = Offset.zero;
    }

    final newTarget = _getTargetSector();
    if (newTarget != _targetSector) {
      _animateToSector(newTarget);
    }
  }

  void _animateToSector(Offset newTarget) {
    final currentPos = _sectorAnimation.value;
    _targetSector = newTarget;
    _sectorAnimation = Tween<Offset>(
      begin: currentPos,
      end: newTarget,
    ).animate(
      CurvedAnimation(
        parent: _sectorController,
        curve: MinesweeperConfig.minimapJumpCurve,
      ),
    );
    _sectorController.duration = MinesweeperConfig.minimapJumpDuration;
    _sectorController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _sectorController.dispose();
    _panSnapController.dispose();
    super.dispose();
  }

  static const double _cellSlot = MinesweeperConfig.minimapCellSlot;
  static const double _cellInner = MinesweeperConfig.minimapCellInner;
  static const double _cellMargin = MinesweeperConfig.minimapCellMargin;
  static const double _cellRadius = MinesweeperConfig.minimapCellRadius;
  static const double _overlayRadius = MinesweeperConfig.minimapOverlayRadius;
  static const double _padding = MinesweeperConfig.minimapPadding;
  static const double _dotSize = MinesweeperConfig.minimapDotSize;

  int get _minCol =>
      widget.minRegionCol ??
      (widget.isInfiniteWorld ? widget.currentRegionCol : 0);
  int get _maxCol =>
      widget.maxRegionCol ??
      (widget.isInfiniteWorld
          ? widget.currentRegionCol
          : (widget.regionsX > 0 ? widget.regionsX - 1 : 0));
  int get _minRow =>
      widget.minRegionRow ??
      (widget.isInfiniteWorld ? widget.currentRegionRow : 0);
  int get _maxRow =>
      widget.maxRegionRow ??
      (widget.isInfiniteWorld
          ? widget.currentRegionRow
          : (widget.regionsY > 0 ? widget.regionsY - 1 : 0));

  (int, int) _findClosestDiscoveredRegion(double floatCol, double floatRow) {
    int bestRow = widget.currentRegionRow;
    int bestCol = widget.currentRegionCol;
    double bestDistSq = double.infinity;
    final curTargetRow = _targetSector.dy.round();
    final curTargetCol = _targetSector.dx.round();

    for (int r = _minRow; r <= _maxRow; r++) {
      for (int c = _minCol; c <= _maxCol; c++) {
        final isAccessible = widget.isRegionAccessible?.call(r, c) ?? true;
        if (!isAccessible) continue;

        final dCol = c - floatCol;
        final dRow = r - floatRow;
        final distSq = dCol * dCol + dRow * dRow;
        if (distSq < bestDistSq - 1e-6 ||
            ((distSq - bestDistSq).abs() < 1e-6 &&
                r == curTargetRow &&
                c == curTargetCol)) {
          bestDistSq = distSq;
          bestRow = r;
          bestCol = c;
        }
      }
    }
    return (bestRow, bestCol);
  }

  void _onPanStart(DragStartDetails details) {
    _panSnapController.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final minPanX = (widget.currentRegionCol - _maxCol) * _cellSlot;
    final maxPanX = (widget.currentRegionCol - _minCol) * _cellSlot;
    final minPanY = (widget.currentRegionRow - _maxRow) * _cellSlot;
    final maxPanY = (widget.currentRegionRow - _minRow) * _cellSlot;

    final lowerX = min(minPanX, maxPanX);
    final upperX = max(minPanX, maxPanX);
    final lowerY = min(minPanY, maxPanY);
    final upperY = max(minPanY, maxPanY);

    final newX = (_panOffset.dx + details.delta.dx).clamp(lowerX, upperX);
    final newY = (_panOffset.dy + details.delta.dy).clamp(lowerY, upperY);

    setState(() {
      _panOffset = Offset(newX, newY);
    });

    final floatCol = widget.currentRegionCol - (_panOffset.dx / _cellSlot);
    final floatRow = widget.currentRegionRow - (_panOffset.dy / _cellSlot);
    final (closestRow, closestCol) =
        _findClosestDiscoveredRegion(floatCol, floatRow);
    final target = Offset(closestCol.toDouble(), closestRow.toDouble());

    if (target != _targetSector) {
      _animateToSector(target);
      widget.onSelectedRegionChanged?.call((closestRow, closestCol));
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _snapPanToClosestSector();
  }

  void _snapPanToClosestSector() {
    final floatCol = widget.currentRegionCol - (_panOffset.dx / _cellSlot);
    final floatRow = widget.currentRegionRow - (_panOffset.dy / _cellSlot);
    final (closestRow, closestCol) =
        _findClosestDiscoveredRegion(floatCol, floatRow);

    final targetX = (widget.currentRegionCol - closestCol) * _cellSlot;
    final targetY = (widget.currentRegionRow - closestRow) * _cellSlot;
    final targetOffset = Offset(targetX, targetY);

    if (targetOffset == _panOffset) return;

    final startOffset = _panOffset;
    _panSnapAnimation = Tween<Offset>(
      begin: startOffset,
      end: targetOffset,
    ).animate(
      CurvedAnimation(
        parent: _panSnapController,
        curve: MinesweeperConfig.minimapJumpCurve,
      ),
    );
    _panSnapController.duration = MinesweeperConfig.minimapJumpDuration;
    _panSnapController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final targetRadius = MinesweeperConfig.minimapCornerRadius(
      isExpanded: widget.isExpanded,
      sizeRatio: widget.sizeRatio,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: const ValueKey('minimap_selector'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onPanStart: widget.isExpanded ? _onPanStart : null,
        onPanUpdate: widget.isExpanded ? _onPanUpdate : null,
        onPanEnd: widget.isExpanded ? _onPanEnd : null,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: targetRadius),
          duration: MinesweeperConfig.minimapExpandDuration,
          curve: MinesweeperConfig.minimapExpandCurve,
          builder: (context, radius, child) {
            final innerRadius = radius *
                (MinesweeperConfig.minimapInnerRadius /
                    MinesweeperConfig.minimapRadius);
            return Container(
              padding: _padding > 0 ? const EdgeInsets.all(_padding) : null,
              decoration: BoxDecoration(
                color: AppColors.panelDim,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: AppColors.outlineDim, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(innerRadius),
                child: child,
              ),
            );
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewportWidth = constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : (widget.minimapCols * _cellSlot);
              final viewportHeight = constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : (widget.minimapRows * _cellSlot);
              final centerX = viewportWidth / 2.0;
              final centerY = viewportHeight / 2.0;

              final scaleX =
                  widget.strideX > 0 ? _cellSlot / widget.strideX : 0.0;
              final scaleY =
                  widget.strideY > 0 ? _cellSlot / widget.strideY : 0.0;

              final activeSelectedRow = _targetSector.dy.round();
              final activeSelectedCol = _targetSector.dx.round();

              final mapLeft = (centerX -
                      (widget.currentRegionCol * _cellSlot +
                          (_cellSlot / 2.0))) +
                  (widget.planeOffset.dx * scaleX) +
                  _panOffset.dx;
              final mapTop = (centerY -
                      (widget.currentRegionRow * _cellSlot +
                          (_cellSlot / 2.0))) +
                  (widget.planeOffset.dy * scaleY) +
                  _panOffset.dy;

              final sectorPos = _sectorAnimation.value;
              final overlayLeft =
                  mapLeft + (sectorPos.dx * _cellSlot) + _cellMargin;
              final overlayTop =
                  mapTop + (sectorPos.dy * _cellSlot) + _cellMargin;

              final centerColInView = (widget.currentRegionCol -
                      (_panOffset.dx / _cellSlot))
                  .round();
              final centerRowInView = (widget.currentRegionRow -
                      (_panOffset.dy / _cellSlot))
                  .round();
              final colsInView = (viewportWidth / _cellSlot).ceil() + 2;
              final rowsInView = (viewportHeight / _cellSlot).ceil() + 2;
              final halfCols = (colsInView / 2).ceil();
              final halfRows = (rowsInView / 2).ceil();
              final minCol = centerColInView - halfCols;
              final maxCol = centerColInView + halfCols;
              final minRow = centerRowInView - halfRows;
              final maxRow = centerRowInView + halfRows;

              final int startCol;
              final int endCol;
              final int startRow;
              final int endRow;

              if (!widget.isExpanded) {
                startCol = minCol;
                endCol = maxCol;
                startRow = minRow;
                endRow = maxRow;
              } else {
                final boundMinCol = widget.isInfiniteWorld ? (_minCol - 1) : 0;
                final boundMaxCol = widget.isInfiniteWorld
                    ? (_maxCol + 1)
                    : (widget.regionsX > 0 ? widget.regionsX - 1 : 0);
                final boundMinRow = widget.isInfiniteWorld ? (_minRow - 1) : 0;
                final boundMaxRow = widget.isInfiniteWorld
                    ? (_maxRow + 1)
                    : (widget.regionsY > 0 ? widget.regionsY - 1 : 0);

                startCol = max(minCol, boundMinCol);
                endCol = min(maxCol, boundMaxCol);
                startRow = max(minRow, boundMinRow);
                endRow = min(maxRow, boundMaxRow);
              }

              final startR = widget.initialRegionRow ?? MinesweeperConfig.initialRegionY;
              final startC = widget.initialRegionCol ?? MinesweeperConfig.initialRegionX;

              final localDotLeft = (startC - sectorPos.dx) * _cellSlot +
                  ((_cellInner - _dotSize) / 2.0);
              final localDotTop = (startR - sectorPos.dy) * _cellSlot +
                  ((_cellInner - _dotSize) / 2.0);
              final isNearStartingRegion =
                  (startC - sectorPos.dx).abs() < 1.5 &&
                  (startR - sectorPos.dy).abs() < 1.5;

              return SizedBox(
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
                          for (int c = startCol; c <= endCol; c++)
                            for (int r = startRow; r <= endRow; r++)
                              Positioned(
                                left: mapLeft + (c * _cellSlot),
                                top: mapTop + (r * _cellSlot),
                                width: _cellSlot,
                                height: _cellSlot,
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
                      width: _cellInner,
                      height: _cellInner,
                      child: IgnorePointer(
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(_overlayRadius),
                          child: AnimatedContainer(
                            key: const ValueKey('active_minimap_sector'),
                            duration: Duration.zero,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(_overlayRadius),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                if (isNearStartingRegion)
                                  Positioned(
                                    left: localDotLeft,
                                    top: localDotTop,
                                    width: _dotSize,
                                    height: _dotSize,
                                    child: const DecoratedBox(
                                      key: ValueKey(
                                          'active_minimap_starting_dot'),
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMiniMapCell(int r, int c) {
    final isOutOfBounds = !widget.isInfiniteWorld &&
        (r < 0 || r >= widget.regionsY || c < 0 || c >= widget.regionsX);
    if (isOutOfBounds) {
      return Container(
        key: ValueKey('minimap_sector_${c + 1}_${r + 1}'),
        margin: const EdgeInsets.all(_cellMargin),
        child: Container(
          width: _cellInner,
          height: _cellInner,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(_cellRadius),
          ),
        ),
      );
    }

    final isAccessible = widget.isRegionAccessible?.call(r, c) ?? true;
    if (!isAccessible) {
      return Container(
        key: ValueKey('minimap_sector_${c + 1}_${r + 1}'),
        margin: const EdgeInsets.all(_cellMargin),
        child: Container(
          width: _cellInner,
          height: _cellInner,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(_cellRadius),
          ),
        ),
      );
    }

    final isCompleted = widget.isRegionCompleted?.call(r, c) ?? false;
    final hasRevealed = widget.hasRegionRevealed?.call(r, c) ?? false;

    Color cellBg;
    if (isCompleted) {
      cellBg = MinesweeperConfig.minimapFinishedColor;
    } else if (hasRevealed) {
      cellBg = MinesweeperConfig.minimapStartedColor;
    } else {
      cellBg = MinesweeperConfig.minimapDiscoveredColor;
    }

    final startR = widget.initialRegionRow ?? MinesweeperConfig.initialRegionY;
    final startC = widget.initialRegionCol ?? MinesweeperConfig.initialRegionX;
    final isStartingRegion = (r == startR && c == startC);
    final isUnknownBiome = widget.isRegionUnknownBiome?.call(r, c) ?? false;
    final biomeBorderColor = widget.getRegionBiomeBorderColor?.call(r, c) ??
        (isUnknownBiome ? MinesweeperConfig.unknownBiomeBorderColor : null);

    return Container(
      key: ValueKey('minimap_sector_${c + 1}_${r + 1}'),
      margin: const EdgeInsets.all(_cellMargin),
      child: AnimatedContainer(
        duration: widget.unlockFadeDuration,
        curve: Curves.easeOut,
        width: _cellInner,
        height: _cellInner,
        decoration: BoxDecoration(
          color: cellBg,
          borderRadius: BorderRadius.circular(_cellRadius),
          border: biomeBorderColor != null
              ? Border.all(
                  color: biomeBorderColor,
                  width: MinesweeperConfig.unknownBiomeMinimapBorderWidth,
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
                    width: _dotSize,
                    height: _dotSize,
                  ),
                ),
              )
            : (widget.getRegionSymbol?.call(r, c) != null
                ? Center(
                    child: Text(
                      widget.getRegionSymbol!(r, c)!,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: widget.getRegionSymbol!(r, c) == '!'
                            ? Colors.amberAccent
                            : const Color(0xFFCE93D8),
                      ),
                    ),
                  )
                : null),
      ),
    );
  }
}
