import 'dart:math';

import 'package:flutter/material.dart';
import '../constants/colors.dart';

import '../game_state.dart';
import '../models/gauntlet_stage.dart';
import '../config/skill_tree_config.dart';
import '../utils/number_formatter.dart';
import '../widgets/confirm_popup.dart';
import '../widgets/shockwave_layer.dart';
import '../generated/embedded_assets.dart';

/// Show the Skill Tree progression popup.
void showSkillTreePopup(
  BuildContext context,
  GameStateManager gameState, {
  bool isDevMode = false,
}) {
  gameState.markSkillTreeOpened();
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Skill Tree',
    barrierColor: AppColors.overlayBarrier,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return SkillTreePopup(gameState: gameState, isDevMode: isDevMode);
    },
    transitionBuilder: (ctx, animation, _, child) {
      final scaleAnimation = Tween<double>(
        begin: 0.92,
        end: 1.0,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
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

// ── Skill Tree Popup Dialog ────────────────────────────────────────────────

class SkillTreePopup extends StatefulWidget {
  final GameStateManager gameState;
  final List<SkillNodeConfig>? nodes;
  final bool isDevMode;

  const SkillTreePopup({
    super.key,
    required this.gameState,
    this.nodes,
    this.isDevMode = false,
  });

  @override
  State<SkillTreePopup> createState() => _SkillTreePopupState();
}

class _SkillTreePopupState extends State<SkillTreePopup> {
  SkillNodeConfig? _hoveredNode;

  List<SkillNodeConfig> get _nodes => widget.nodes ?? defaultSkillTreeNodes;

  /// A node shows a cost label IF:
  /// - In dev mode, OR
  /// - (It is root OR any of its parents has level >= 1) AND it is not maxed out.
  bool _showsCostLabel(String nodeId, GameStateManager gs) {
    final node = _nodes.firstWhere((n) => n.id == nodeId);
    final level = gs.getSkillLevel(nodeId);
    if (level >= node.maxLevel) return false;
    if (widget.isDevMode) return true;
    if (node.checkIfLocked(gs)) {
      return false;
    }
    if (node.parentIds.isEmpty) return true;
    return node.parentIds.any((pId) => gs.getSkillLevel(pId) >= 1);
  }

  /// A node is revealed (shown on grid) IF:
  /// - In dev mode, OR
  /// - It is root node, OR
  /// - Any of its parents has level >= 1, OR
  /// - Any of its parents currently shows a cost label.
  bool _isNodeRevealed(String nodeId, GameStateManager gs) {
    if (widget.isDevMode) return true;
    if (nodeId == 'root') return true;
    final node = _nodes.firstWhere((n) => n.id == nodeId);
    if (node.parentIds.isEmpty) return true;
    return node.parentIds.any(
      (pId) => gs.getSkillLevel(pId) >= 1 || _showsCostLabel(pId, gs),
    );
  }

  void _showRefundConfirmPopup(BuildContext context, GameStateManager gs) {
    showConfirmPopup(
      context,
      title: 'Refund All Skills?',
      icon: Icons.undo_rounded,
      iconColor: Colors.red.shade400,
      body:
          'This will reset all skill nodes back to level 0 '
          'and refund all spent tokens. This cannot be undone.',
      confirmLabel: 'Refund',
      onConfirm: () {
        setState(() {
          _hoveredNode = null;
        });
        gs.refundAllSkillTokens(_nodes);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Material(
        color: AppColors.transparent,
        child: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Bar: Circular Close Button placed outside top-right
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.panelMedium,
                        foregroundColor: AppColors.textBright,
                        side: BorderSide(
                          color: AppColors.outlineDim,
                          width: 1.5,
                        ),
                        shape: const CircleBorder(),
                      ),
                    ),
                  ),
                ),
              ),

              // Main Popup Container
              Container(
                height: 560,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.outlineMedium,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.60),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: ListenableBuilder(
                  listenable: widget.gameState,
                  builder: (context, _) {
                    final gs = widget.gameState;

                    return Column(
                      children: [
                        // ── Clean Header: Title & Token Counter ───────
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.panelMedium,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.outlineDim,
                              ),
                            ),
                          ),
                          child: SizedBox(
                            height: 28,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.account_tree_rounded,
                                      size: 20,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Skill Tree',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (widget.isDevMode ||
                                        gs.isSkillUnlocked('refund')) ...[
                                      SizedBox(
                                        height: 28,
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _showRefundConfirmPopup(
                                                context,
                                                gs,
                                              ),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 0,
                                            ),
                                            minimumSize: Size.zero,
                                            backgroundColor:
                                                AppColors.panelMedium,
                                            side: BorderSide(
                                              color: AppColors.outlineDim,
                                              width: 1.2,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          icon: Icon(
                                            Icons.undo_rounded,
                                            size: 14,
                                            color: Colors.red.shade400,
                                          ),
                                          label: Text(
                                            'Refund',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.red.shade400,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                        // Token Balance Pill
                                        MouseRegion(
                                          cursor: widget.isDevMode
                                              ? SystemMouseCursors.click
                                              : MouseCursor.defer,
                                          child: GestureDetector(
                                            onTap: widget.isDevMode
                                                ? () => showAddDevTokensPopup(
                                                      context,
                                                      gameState:
                                                          widget.gameState,
                                                    )
                                                : null,
                                            child: Container(
                                              height: 28,
                                              alignment: Alignment.center,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    theme.colorScheme.surface,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: AppColors.amberDim,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.token,
                                                    size: 16,
                                                    color: Colors.amber,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '${formatWithCommas(gs.tokens)} Tokens',
                                                    style: TextStyle(
                                                      fontFamily: 'monospace',
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Colors.amber.shade400,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // ── Dynamic Responsive Interactive Grid Canvas ───────────
                            Expanded(
                              child: Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final canvasWidth = constraints.maxWidth;
                                        final canvasHeight = constraints.maxHeight;

                                        // Auto-compute cell size dynamically from min/max grid coords in the node list
                                        final minGX = _nodes.isEmpty
                                            ? 0.0
                                            : _nodes.fold(
                                                double.infinity,
                                                (m, n) => n.gridX < m ? n.gridX : m,
                                              );
                                        final maxGX = _nodes.isEmpty
                                            ? 0.0
                                            : _nodes.fold(
                                                0.0,
                                                (m, n) => n.gridX > m ? n.gridX : m,
                                              );
                                        final minGY = _nodes.isEmpty
                                            ? 0.0
                                            : _nodes.fold(
                                                double.infinity,
                                                (m, n) => n.gridY < m ? n.gridY : m,
                                              );
                                        final maxGY = _nodes.isEmpty
                                            ? 0.0
                                            : _nodes.fold(
                                                0.0,
                                                (m, n) => n.gridY > m ? n.gridY : m,
                                              );

                                        final rangeX = maxGX >= minGX
                                            ? maxGX - minGX
                                            : 0.0;
                                        final rangeY = maxGY >= minGY
                                            ? maxGY - minGY
                                            : 0.0;

                                        final cellW = canvasWidth / (rangeX + 1);
                                        final cellH = canvasHeight / (rangeY + 1);
                                        Offset nodePos(SkillNodeConfig n) => Offset(
                                          (n.gridX - minGX) * cellW + cellW / 2,
                                          (n.gridY - minGY) * cellH + cellH / 2,
                                        );

                                        return SizedBox(
                                          width: canvasWidth,
                                          height: canvasHeight,
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              // Connection Lines Painter
                                              CustomPaint(
                                                size: Size(
                                                  canvasWidth,
                                                  canvasHeight,
                                                ),
                                                painter: _SkillTreeCanvasPainter(
                                                  nodes: _nodes,
                                                  gameState: gs,
                                                  canvasWidth: canvasWidth,
                                                  canvasHeight: canvasHeight,
                                                  isNodeRevealed: (id) =>
                                                      _isNodeRevealed(id, gs),
                                                ),
                                              ),

                                              // Freeform Skill Node Widgets
                                              for (final node in _nodes) ...[
                                                () {
                                                  final isRevealed =
                                                      _isNodeRevealed(node.id, gs);
                                                  if (!isRevealed) {
                                                    return const SizedBox();
                                                  }

                                                  final showsCostLabel =
                                                      _showsCostLabel(node.id, gs);
                                                  final level = gs.getSkillLevel(
                                                    node.id,
                                                  );

                                                  final pos = nodePos(node);
                                                  final posX = pos.dx;
                                                  final posY = pos.dy;

                                                  return Positioned(
                                                    left:
                                                        posX -
                                                        (node.isInfinite ? 26 : 22),
                                                    top:
                                                        posY -
                                                        (node.isInfinite ? 26 : 22),
                                                    child: MouseRegion(
                                                      onEnter: (_) {
                                                        if (isRevealed &&
                                                            (showsCostLabel ||
                                                                level >= 1)) {
                                                          setState(() {
                                                            _hoveredNode = node;
                                                          });
                                                        }
                                                      },
                                                      onExit: (_) {
                                                        setState(() {
                                                          _hoveredNode = null;
                                                        });
                                                      },
                                                      child: _SkillNodeWidget(
                                                        node: node,
                                                        level: level,
                                                        isRevealed: isRevealed,
                                                        showsCostLabel:
                                                            showsCostLabel,
                                                        canAfford:
                                                            widget.isDevMode ||
                                                            gs.tokens >=
                                                                node.costForLevel(
                                                                  level,
                                                                ),
                                                        onTap: () {
                                                          if (isRevealed &&
                                                              showsCostLabel &&
                                                              level <
                                                                  node.maxLevel) {
                                                            gs.upgradeSkill(
                                                              node.id,
                                                              node.maxLevel,
                                                              node.costForLevel(
                                                                level,
                                                              ),
                                                            );
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                  );
                                                }(),
                                              ],

                                              if (widget.isDevMode)
                                                _SkillTreeDebugGridLayer(
                                                  canvasWidth: canvasWidth,
                                                  canvasHeight: canvasHeight,
                                                  nodes: _nodes,
                                                ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),

                                  // ── Smart Dynamic Floating Hover Tooltip Card ────
                                  if (_hoveredNode != null) ...[
                                    () {
                                      final n = _hoveredNode!;
                                      final level = gs.getSkillLevel(n.id);
                                      final showsCostLabel = _showsCostLabel(n.id, gs);

                                      if (!showsCostLabel && level == 0) {
                                        return const SizedBox.shrink();
                                      }

                                      final minGX = _nodes.isEmpty
                                          ? 0.0
                                          : _nodes.fold(
                                              double.infinity,
                                              (m, nd) => nd.gridX < m ? nd.gridX : m,
                                            );
                                      final maxGX = _nodes.isEmpty
                                          ? 0.0
                                          : _nodes.fold(
                                              0.0,
                                              (m, nd) => nd.gridX > m ? nd.gridX : m,
                                            );
                                      final minGY = _nodes.isEmpty
                                          ? 0.0
                                          : _nodes.fold(
                                              double.infinity,
                                              (m, nd) => nd.gridY < m ? nd.gridY : m,
                                            );
                                      final maxGY = _nodes.isEmpty
                                          ? 0.0
                                          : _nodes.fold(
                                              0.0,
                                              (m, nd) => nd.gridY > m ? nd.gridY : m,
                                            );

                                      final rangeX = maxGX >= minGX ? maxGX - minGX : 0.0;
                                      final rangeY = maxGY >= minGY ? maxGY - minGY : 0.0;

                                      final isLeftHalf = (n.gridX - minGX) < (rangeX / 2);
                                      final isTopHalf = (n.gridY - minGY) < (rangeY / 2);

                                      return Positioned(
                                        left: isLeftHalf ? null : 16,
                                        right: isLeftHalf ? 16 : null,
                                        top: isTopHalf ? null : 16,
                                        bottom: isTopHalf ? 16 : null,
                                        child: _NodeHoverTooltip(
                                          node: n,
                                          level: level,
                                          canAfford:
                                              widget.isDevMode ||
                                              gs.tokens >= n.costForLevel(level),
                                          gameState: gs,
                                          isDevMode: widget.isDevMode,
                                        ),
                                      );
                                    }(),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkillTreeDebugGridLayer extends StatelessWidget {
  final double canvasWidth;
  final double canvasHeight;
  final List<SkillNodeConfig> nodes;

  const _SkillTreeDebugGridLayer({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.nodes,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size(canvasWidth, canvasHeight),
        painter: _SkillTreeDebugGridPainter(nodes: nodes),
      ),
    );
  }
}

class _SkillTreeDebugGridPainter extends CustomPainter {
  final List<SkillNodeConfig> nodes;
  const _SkillTreeDebugGridPainter({required this.nodes});

  @override
  void paint(Canvas canvas, Size size) {
    final minGX = nodes.isEmpty
        ? 0.0
        : nodes.fold(double.infinity, (m, n) => n.gridX < m ? n.gridX : m);
    final maxGX = nodes.isEmpty
        ? 0.0
        : nodes.fold(0.0, (m, n) => n.gridX > m ? n.gridX : m);
    final minGY = nodes.isEmpty
        ? 0.0
        : nodes.fold(double.infinity, (m, n) => n.gridY < m ? n.gridY : m);
    final maxGY = nodes.isEmpty
        ? 0.0
        : nodes.fold(0.0, (m, n) => n.gridY > m ? n.gridY : m);

    final rangeX = maxGX >= minGX ? maxGX - minGX : 0.0;
    final rangeY = maxGY >= minGY ? maxGY - minGY : 0.0;

    final cols = (rangeX + 1).ceil();
    final rows = (rangeY + 1).ceil();
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    final linePaint = Paint()
      ..color = Color.lerp(AppColors.surface, const Color(0xFF8B5CF6), 0.25)!
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final boundaryPaint = Paint()
      ..color = Color.lerp(AppColors.surface, const Color(0xFF8B5CF6), 0.5)!
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;

    for (int x = 0; x <= cols; x++) {
      final dx = x * cellW;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), linePaint);
    }

    for (int y = 0; y <= rows; y++) {
      final dy = y * cellH;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), linePaint);
    }

    canvas.drawRect(Offset.zero & size, boundaryPaint);

    // Label each cell center with its integer grid coordinate
    for (int gx = 0; gx < cols; gx++) {
      for (int gy = 0; gy < rows; gy++) {
        final actualGX = (minGX + gx).round();
        final actualGY = (minGY + gy).round();
        final textSpan = TextSpan(
          text: '$actualGX,$actualGY',
          style: TextStyle(
            color: Color.lerp(
              AppColors.surface,
              const Color(0xFF8B5CF6),
              0.55,
            )!,
            fontSize: 8,
            fontWeight: FontWeight.w600,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();
        final cx = gx * cellW + cellW / 2;
        final cy = gy * cellH + cellH / 2;
        textPainter.paint(
          canvas,
          Offset(cx - textPainter.width / 2, cy - textPainter.height / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SkillTreeDebugGridPainter oldDelegate) => false;
}

// ── Custom Canvas Painter for Connecting Lines & 4-Directional Arrows ─────

class _SkillTreeCanvasPainter extends CustomPainter {
  final List<SkillNodeConfig> nodes;
  final GameStateManager gameState;
  final double canvasWidth;
  final double canvasHeight;
  final bool Function(String) isNodeRevealed;

  _SkillTreeCanvasPainter({
    required this.nodes,
    required this.gameState,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.isNodeRevealed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Auto-compute cell size dynamically from min/max grid coords
    final minGX = nodes.isEmpty
        ? 0.0
        : nodes.fold(double.infinity, (m, n) => n.gridX < m ? n.gridX : m);
    final maxGX = nodes.isEmpty
        ? 0.0
        : nodes.fold(0.0, (m, n) => n.gridX > m ? n.gridX : m);
    final minGY = nodes.isEmpty
        ? 0.0
        : nodes.fold(double.infinity, (m, n) => n.gridY < m ? n.gridY : m);
    final maxGY = nodes.isEmpty
        ? 0.0
        : nodes.fold(0.0, (m, n) => n.gridY > m ? n.gridY : m);

    final rangeX = maxGX >= minGX ? maxGX - minGX : 0.0;
    final rangeY = maxGY >= minGY ? maxGY - minGY : 0.0;

    final cellW = canvasWidth / (rangeX + 1);
    final cellH = canvasHeight / (rangeY + 1);
    Offset pos(SkillNodeConfig n) => Offset(
      (n.gridX - minGX) * cellW + cellW / 2,
      (n.gridY - minGY) * cellH + cellH / 2,
    );

    final nodeMap = {for (var n in nodes) n.id: n};

    for (final node in nodes) {
      final fromRevealed = isNodeRevealed(node.id);
      final fromUnlocked = gameState.getSkillLevel(node.id) >= 1;

      final p = pos(node);
      final pX = p.dx;
      final pY = p.dy;

      for (final parentId in node.parentIds) {
        final parent = nodeMap[parentId];
        if (parent == null) continue;

        final parentUnlocked = gameState.getSkillLevel(parentId) >= 1;
        final parentRevealed = isNodeRevealed(parentId);

        final tp = pos(parent);
        final toX = tp.dx;
        final toY = tp.dy;

        final isPathUnlocked = parentUnlocked && (fromUnlocked || fromRevealed);
        final isPathRevealed = parentRevealed && fromRevealed;

        if (!isPathRevealed) {
          continue; // Only draw arrows when both parent and child nodes are visible
        }

        final paint = Paint()
          ..color = isPathUnlocked
              ? AppColors.amberMedium
              : AppColors.outlineMedium
          ..strokeWidth = isPathUnlocked ? 2.5 : 1.5
          ..style = PaintingStyle.stroke;

        // Draw connecting line from parent to child (top to bottom)
        canvas.drawLine(Offset(toX, toY), Offset(pX, pY), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SkillTreeCanvasPainter oldDelegate) => true;
}

// ── Individual Skill Node Tile (Opaque Backgrounds & Tiny Dots) ────────────

class _SkillNodeWidget extends StatefulWidget {
  final SkillNodeConfig node;
  final int level;
  final bool isRevealed;
  final bool showsCostLabel;
  final bool canAfford;
  final VoidCallback onTap;

  const _SkillNodeWidget({
    required this.node,
    required this.level,
    required this.isRevealed,
    required this.showsCostLabel,
    required this.canAfford,
    required this.onTap,
  });

  @override
  State<_SkillNodeWidget> createState() => _SkillNodeWidgetState();
}

class _SkillNodeWidgetState extends State<_SkillNodeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shockwaveController;
  late final Animation<double> _shockwaveAnimation;
  bool _justPurchased = false;

  @override
  void initState() {
    super.initState();
    _shockwaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _shockwaveAnimation = CurvedAnimation(
      parent: _shockwaveController,
      curve: Curves.easeOutExpo,
    );

    if (_isAffordable(widget)) {
      _shockwaveController.repeat();
    }
  }

  bool _isAffordable(_SkillNodeWidget w) {
    final isFullyUpgraded =
        !w.node.isInfinite && w.node.maxLevel > 0 && w.level >= w.node.maxLevel;
    return w.isRevealed && w.showsCostLabel && !isFullyUpgraded && w.canAfford;
  }

  @override
  void didUpdateWidget(_SkillNodeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final affordable = _isAffordable(widget);
    if (affordable && !_shockwaveController.isAnimating) {
      _shockwaveController.repeat();
    } else if (!affordable && _shockwaveController.isAnimating) {
      _shockwaveController.stop();
      _shockwaveController.reset();
    }

    if (widget.level > oldWidget.level &&
        !widget.node.isInfinite &&
        widget.node.maxLevel > 0 &&
        widget.level >= widget.node.maxLevel) {
      setState(() {
        _justPurchased = true;
      });
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _justPurchased = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _shockwaveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final level = widget.level;
    final isRevealed = widget.isRevealed;
    final showsCostLabel = widget.showsCostLabel;
    final canAfford = widget.canAfford;
    final onTap = widget.onTap;

    final theme = Theme.of(context);
    final isUnlocked = level >= 1;

    if (!isRevealed) {
      return const SizedBox();
    }

    if (!showsCostLabel && !isUnlocked) {
      // Locked preview node (Dark container with lock icon, no cost badge)
      final size = node.isInfinite ? 52.0 : 44.0;
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outlineMedium),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: AppColors.textDim,
            ),
          ),
        ),
      );
    }

    // A non-legendary upgradeable node that is maxed out gets the same gold
    // treatment as legendary nodes (but without the starburst/star decoration).
    final isLegendaryStyle = node.isLegendary || node.isInfinite;
    final isFullyUpgraded =
        !node.isInfinite &&
        node.maxLevel > 0 &&
        level >= node.maxLevel &&
        !_justPurchased;
    final isActive = isUnlocked && !isFullyUpgraded;
    final isActiveAffordable = isActive && canAfford;
    final isAffordable = _isAffordable(widget);

    // 100% Fully Opaque Solid Background Colors for all node states
    final nodeBgColor = isActive
        ? const Color(
            0xFF4A2B00,
          ) // Solid dark golden bronze for all upgradeable
        : isFullyUpgraded
        ? const Color(0xFF231911)
        : theme.colorScheme.surfaceContainerHighest;

    // Gold border only when actually unlocked (or maxed). Locked legendary nodes
    // look like any other locked node — grey — but keep their starburst decoration.
    final borderColor = isActive
        ? (canAfford
              ? Colors.amber.shade400
              : Color.lerp(Colors.amber.shade400, AppColors.amberMedium, 0.5)!)
        : isFullyUpgraded
        ? AppColors.amberMedium
        : AppColors.outlineMedium;

    final iconColor = isActive
        ? Colors.amber.shade300
        : isFullyUpgraded
        ? Colors.amber.shade300
        : AppColors.textMedium;

    Widget nodeContent = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: nodeBgColor,
        borderRadius: BorderRadius.circular(isLegendaryStyle ? 12 : 10),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: isActiveAffordable
            ? [
                BoxShadow(
                  color: AppColors.amberBright,
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // ── Cost Badge (top-right corner, only when upgradeable & shows cost label) ──
          if (showsCostLabel &&
              !isFullyUpgraded &&
              !(node.isLegendary && isUnlocked))
            Positioned(
              top: -7,
              right: -7,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: canAfford
                        ? Colors.amber.shade700
                        : Colors.grey.shade700,
                    width: 1,
                  ),
                ),
                child: Text(
                  formatShortNumber(node.costForLevel(level)),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: canAfford
                        ? Colors.amber.shade400
                        : Colors.grey.shade500,
                    height: 1,
                  ),
                ),
              ),
            ),

          // Icon / Image Asset
          if (node.imageAsset != null)
            EmbeddedAssets.getImage(
              node.imageAsset!,
              width: 20,
              height: 20,
              color: iconColor,
            )
          else if (node.icon != null)
            Icon(node.icon, size: 20, color: iconColor),

          // ── Row of Tiny Dots (Level Pips) or Infinite Level Badge at Bottom ──
          if (node.isInfinite)
            Positioned(
              bottom: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isUnlocked
                        ? Colors.amber.shade400
                        : AppColors.outlineMedium,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  'lvl. $level',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: level > 0
                        ? Colors.amber.shade300
                        : AppColors.textMedium,
                  ),
                ),
              ),
            )
          else if (!node.isLegendary && node.maxLevel > 1)
            Positioned(
              bottom: 3,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(node.maxLevel, (i) {
                  final isFilled = i < level;
                  return Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: isFilled
                          ? Colors.amber.shade400
                          : (isUnlocked
                                ? AppColors.emptySlotUnlocked
                                : AppColors.emptySlot),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),

          // Legendary Single Star Indicator at Bottom
          if (node.isLegendary)
            Positioned(
              bottom: 2,
              child: Icon(
                Icons.star_rounded,
                size: 8,
                color: isUnlocked ? Colors.amber.shade300 : AppColors.emptySlot,
              ),
            ),
        ],
      ),
    ); // End of nodeContent

    // Revealed Node Widget
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // ── Golden Shockwave for Affordable Nodes ──
          if (isAffordable)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _shockwaveAnimation,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _SkillNodeShockwavePainter(
                        progress: _shockwaveAnimation.value,
                        color: AppColors.warning,
                        cornerRadius: node.isInfinite
                            ? 16.0
                            : (isLegendaryStyle ? 12.0 : 10.0),
                        nodeSize: node.isInfinite ? 52.0 : 44.0,
                      ),
                    );
                  },
                ),
              ),
            ),

          // ── Layer 1 (Infinite / Ultimate Only): Normal-oriented bottom layer ──
          if (node.isInfinite)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive || isFullyUpgraded
                      ? Colors.amber.shade300.withValues(alpha: 0.4)
                      : Colors.grey.shade700.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
            ),

          // ── Layer 2 (Legendary & Infinite): Tilted layer ──
          if (isLegendaryStyle)
            Transform.rotate(
              angle: pi / 4,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Color.lerp(
                    Theme.of(context).colorScheme.surface,
                    nodeBgColor,
                    0.4,
                  )!,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isActive || isFullyUpgraded
                        ? Colors.amber.shade300.withValues(alpha: 0.4)
                        : Colors.grey.shade700.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
              ),
            ),

          // ── Layer 3: Main Node ──
          nodeContent,
        ],
      ),
    );
  }
}

class _SkillNodeShockwavePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double cornerRadius;
  final double nodeSize;

  _SkillNodeShockwavePainter({
    required this.progress,
    required this.color,
    required this.cornerRadius,
    required this.nodeSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    ShockwaveUtil.drawShockwave(
      canvas,
      size,
      progress,
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: nodeSize,
        height: nodeSize,
      ),
      color: color,
      maxExpansion: 16.0,
      cornerRadius: cornerRadius,
      strokeWidth: 2.0,
      fadeCurve: 1.8,
    );
  }

  @override
  bool shouldRepaint(covariant _SkillNodeShockwavePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.cornerRadius != cornerRadius ||
      oldDelegate.nodeSize != nodeSize;
}

// ── Hover Tooltip Card Overlay ─────────────────────────────────────────────

class _NodeHoverTooltip extends StatelessWidget {
  final SkillNodeConfig node;
  final int level;
  final bool canAfford;
  final GameStateManager gameState;
  final bool isDevMode;

  const _NodeHoverTooltip({
    required this.node,
    required this.level,
    required this.canAfford,
    required this.gameState,
    required this.isDevMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnlocked = level >= 1;
    final isMaxed = !node.isInfinite && level == node.maxLevel;
    final isLocked = !isDevMode && node.checkIfLocked(gameState);
    final isStageLocked =
        node.linkedStage != null &&
        !gameState.isStageVisited(node.linkedStage!) &&
        !isDevMode;

    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panelSolid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: node.isLegendary
              ? Colors.amber.shade400
              : AppColors.outlineMedium,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.60),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title & Rarity Tag
          Row(
            children: [
              if (node.imageAsset != null)
                EmbeddedAssets.getImage(
                  node.imageAsset!,
                  width: 16,
                  height: 16,
                  color: node.isInfinite
                      ? Colors.purple.shade300
                      : node.isLegendary
                      ? Colors.amber
                      : theme.colorScheme.primary,
                )
              else if (node.icon != null)
                Icon(
                  node.icon,
                  size: 16,
                  color: node.isLegendary
                      ? Colors.amber
                      : theme.colorScheme.primary,
                ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  node.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Rarity & Level Pips Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                node.isInfinite
                    ? 'Infinite Upgrade'
                    : node.isLegendary
                    ? 'Legendary Keystone'
                    : 'Common Upgrade',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: node.isInfinite
                      ? Colors.purple.shade300
                      : node.isLegendary
                      ? Colors.amber.shade400
                      : theme.colorScheme.primary,
                ),
              ),

              // Level Dots Preview or Infinite Level Text
              if (node.isInfinite)
                Text(
                  'Level $level',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: level > 0
                        ? Colors.amber.shade400
                        : AppColors.textMedium,
                  ),
                )
              else
                Row(
                  children: List.generate(node.maxLevel, (i) {
                    final isFilled = i < level;
                    return Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(left: 2),
                      decoration: BoxDecoration(
                        color: isFilled
                            ? Colors.amber.shade400
                            : (level > 0
                                  ? AppColors.emptySlotUnlocked
                                  : AppColors.emptySlot),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
            ],
          ),
          const Divider(height: 12),

          // Game Label Tag (shown if node is linked to a game)
          if (node.linkedStage != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.secContainerMedium,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.secondaryMedium),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    node.linkedStage!.displayName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Description
          Text(
            node.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textBright,
              fontSize: 11,
            ),
          ),
          if (node.formula != null && node.formula!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              node.formula!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textBright,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 8),

          // Action Status Hint
          Text(
            isMaxed
                ? 'Max Level Reached'
                : isStageLocked
                ? 'Try ${node.linkedStage!.displayName} first'
                : (isLocked && node.lockHint != null)
                ? node.lockHint!
                : isLocked
                ? 'Locked'
                : !canAfford
                ? 'Not enough tokens (${formatWithCommas(node.costForLevel(level))})'
                : (isUnlocked
                      ? 'Click to upgrade (${formatWithCommas(node.costForLevel(level))})'
                      : 'Click to unlock (${formatWithCommas(node.costForLevel(level))})'),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isMaxed
                  ? Colors.green
                  : isLocked
                  ? Colors.red.shade300
                  : !canAfford
                  ? Colors.grey.shade500
                  : Colors.amber.shade400,
            ),
          ),
        ],
      ),
    );
  }
}
