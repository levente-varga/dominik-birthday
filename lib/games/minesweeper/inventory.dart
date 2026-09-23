import 'package:flutter/material.dart';
import '../../config/config.dart';
import '../../constants/colors.dart';

/// Available inventory item types.
enum InventoryItemType {
  shield,
  flagObvious,
}

/// Metadata and visual properties for an inventory item.
class InventoryItem {
  final InventoryItemType type;
  final String name;
  final String description;
  final IconData icon;
  final Color iconColor;
  final bool isPassive;

  const InventoryItem({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.isPassive,
  });

  static const InventoryItem shield = InventoryItem(
    type: InventoryItemType.shield,
    name: 'Shield',
    description:
        'Passive: Prevents game over by immediately defusing a triggered mine. Cannot protect against 2+ mines revealed at once during chording. Breaks upon use.',
    icon: Icons.shield_rounded,
    iconColor: Color(0xFF64B5F6), // Light blue
    isPassive: true,
  );

  static const InventoryItem flagObvious = InventoryItem(
    type: InventoryItemType.flagObvious,
    name: 'Flag Obvious Mines',
    description:
        'Active: Flags all obvious mines clearly indicated by numbers. Breaks upon use.',
    icon: Icons.flag_outlined,
    iconColor: Color(0xFFFFA726), // Amber/Orange
    isPassive: false,
  );

  static InventoryItem fromType(InventoryItemType type) {
    switch (type) {
      case InventoryItemType.shield:
        return shield;
      case InventoryItemType.flagObvious:
        return flagObvious;
    }
  }
}

/// Widget representing a single inventory slot button in the bottom bar.
///
/// Can be empty (`item == null`) matching the empty button appearance, or
/// filled with an item icon and interaction for active items.
class InventorySlotButton extends StatelessWidget {
  final InventoryItemType? itemType;
  final Key? slotKey;
  final VoidCallback? onTap;

  const InventorySlotButton({
    super.key,
    this.itemType,
    this.slotKey,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final item = itemType != null ? InventoryItem.fromType(itemType!) : null;

    final child = Container(
      key: slotKey,
      width: MinesweeperConfig.headerButtonSize,
      height: MinesweeperConfig.headerButtonSize,
      decoration: BoxDecoration(
        color: item != null
            ? item.iconColor.withValues(alpha: 0.12)
            : AppColors.panelDim,
        borderRadius:
            BorderRadius.circular(MinesweeperConfig.headerControlRadius),
        border: Border.all(
          color: item != null
              ? item.iconColor.withValues(alpha: 0.6)
              : AppColors.outlineDim,
          width: MinesweeperConfig.headerControlBorderWidth,
        ),
      ),
      child: item != null
          ? Center(
              child: Icon(
                item.icon,
                size: 20.0,
                color: item.iconColor,
              ),
            )
          : null,
    );

    if (item != null && !item.isPassive && onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      );
    }

    return child;
  }
}
