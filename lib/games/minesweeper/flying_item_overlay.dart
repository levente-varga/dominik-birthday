import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../config/config.dart';
import 'inventory.dart';

// ── Active Item Flight Model ────────────────────────────────────────────────

class ActiveItemFlightData {
  final Key id;
  final InventoryItemType itemType;
  final int regionR;
  final int regionC;
  final int localR;
  final int localC;
  final int? targetSlot; // null when inventory is full

  const ActiveItemFlightData({
    required this.id,
    required this.itemType,
    required this.regionR,
    required this.regionC,
    required this.localR,
    required this.localC,
    this.targetSlot,
  });
}

// ── Flying Item Overlay Widget ──────────────────────────────────────────────

class FlyingItemOverlayWidget extends StatefulWidget {
  final ActiveItemFlightData flight;
  final Offset startPosition;
  final Offset? targetSlotPosition;
  final VoidCallback onCompleted;

  const FlyingItemOverlayWidget({
    super.key,
    required this.flight,
    required this.startPosition,
    this.targetSlotPosition,
    required this.onCompleted,
  });

  @override
  State<FlyingItemOverlayWidget> createState() => _FlyingItemOverlayWidgetState();
}

class _FlyingItemOverlayWidgetState extends State<FlyingItemOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Duration _totalDuration;
  late double _delayRatio;

  @override
  void initState() {
    super.initState();
    final delay = MinesweeperConfig.itemAppearanceDelay;
    final bool hasTarget =
        widget.flight.targetSlot != null && widget.targetSlotPosition != null;

    final actionDuration = hasTarget
        ? MinesweeperConfig.itemFlightDuration
        : MinesweeperConfig.itemVanishDuration;

    _totalDuration = delay + actionDuration;
    _delayRatio = delay.inMicroseconds / _totalDuration.inMicroseconds;

    _controller = AnimationController(
      vsync: this,
      duration: _totalDuration,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onCompleted();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = InventoryItem.fromType(widget.flight.itemType);
    final bool hasTarget =
        widget.flight.targetSlot != null && widget.targetSlotPosition != null;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        Offset currentPos;
        double currentScale = 1.0;
        double currentOpacity = 1.0;

        if (progress < _delayRatio) {
          // Phase 1: Resting on the cell
          currentPos = widget.startPosition;
          final spawnT = (progress / (_delayRatio * 0.4)).clamp(0.0, 1.0);
          currentScale = Curves.easeOutBack.transform(spawnT);
          currentOpacity = 1.0;
        } else {
          // Phase 2: Action (flight or vanish)
          final actionProgress =
              ((progress - _delayRatio) / (1.0 - _delayRatio)).clamp(0.0, 1.0);

          if (hasTarget) {
            // Flying to target inventory slot
            final curvedFlight =
                Curves.easeInOutCubic.transform(actionProgress);
            final linearPos = Offset.lerp(
              widget.startPosition,
              widget.targetSlotPosition!,
              curvedFlight,
            )!;
            // Arc path
            final arcOffset = -28.0 * math.sin(curvedFlight * math.pi);
            currentPos = Offset(linearPos.dx, linearPos.dy + arcOffset);
            currentScale = 1.0 + (0.18 * math.sin(curvedFlight * math.pi));
            currentOpacity = 1.0;
          } else {
            // No free slot: slowly scale up and fade out and vanish
            currentPos = widget.startPosition;
            final vanishScaleCurve =
                Curves.easeOut.transform(actionProgress);
            final vanishOpacityCurve =
                Curves.easeIn.transform(actionProgress);
            currentScale =
                ui.lerpDouble(1.0, 2.0, vanishScaleCurve) ?? 2.0;
            currentOpacity =
                ui.lerpDouble(1.0, 0.0, vanishOpacityCurve) ?? 0.0;
          }
        }

        const size = 34.0;
        return Positioned(
          left: currentPos.dx - (size / 2),
          top: currentPos.dy - (size / 2),
          child: IgnorePointer(
            child: Opacity(
              opacity: currentOpacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: currentScale.clamp(0.0, 3.0),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.iconColor.withValues(alpha: 0.22),
                    border: Border.all(
                      color: item.iconColor.withValues(alpha: 0.85),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: item.iconColor.withValues(alpha: 0.45),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      item.icon,
                      size: 20.0,
                      color: item.iconColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
