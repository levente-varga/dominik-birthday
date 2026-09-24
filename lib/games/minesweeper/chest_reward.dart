import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'inventory.dart';

// ── Chest Reward Option Models & Generator ─────────────────────────────────

enum ChestRewardType {
  item,
  quest,
  hint,
  boon,
  roll,
  money,
}

class ChestRewardOption {
  final ChestRewardType type;
  final String title;
  final String description;
  final String categoryLabel;
  final IconData icon;
  final Color accentColor;
  final InventoryItemType? itemType;
  final int? tokenAmount;
  final (int, int)? targetRegion;
  final String? boonEffect;

  const ChestRewardOption({
    required this.type,
    required this.title,
    required this.description,
    required this.categoryLabel,
    required this.icon,
    required this.accentColor,
    this.itemType,
    this.tokenAmount,
    this.targetRegion,
    this.boonEffect,
  });

  factory ChestRewardOption.item(InventoryItemType item) {
    if (item == InventoryItemType.shield) {
      return const ChestRewardOption(
        type: ChestRewardType.item,
        title: 'Energy Shield',
        description: 'Passive protection. Automatically defuses one detonating mine to prevent game over.',
        categoryLabel: 'Item',
        icon: Icons.shield_rounded,
        accentColor: Color(0xFF42A5F5),
        itemType: InventoryItemType.shield,
      );
    } else {
      return const ChestRewardOption(
        type: ChestRewardType.item,
        title: 'Obvious Detector',
        description: 'Active consumable. Automatically flags all mathematically deduced mines in the active region.',
        categoryLabel: 'Item',
        icon: Icons.flag_rounded,
        accentColor: Color(0xFFFFA726),
        itemType: InventoryItemType.flagObvious,
      );
    }
  }

  factory ChestRewardOption.money(int amount) {
    return ChestRewardOption(
      type: ChestRewardType.money,
      title: 'Token Pouch',
      description: 'Receive +$amount tokens immediately for permanent skill upgrades.',
      categoryLabel: 'Money',
      icon: Icons.token_rounded,
      accentColor: const Color(0xFFFFD54F),
      tokenAmount: amount,
    );
  }

  factory ChestRewardOption.quest((int, int) target) {
    return ChestRewardOption(
      type: ChestRewardType.quest,
      title: 'Expedition Quest',
      description: 'Reach region (${target.$1}, ${target.$2}) marked with "!" to claim an ancient relic.',
      categoryLabel: 'Quest',
      icon: Icons.explore_rounded,
      accentColor: const Color(0xFF26A69A),
      targetRegion: target,
    );
  }

  factory ChestRewardOption.hint((int, int) target) {
    return ChestRewardOption(
      type: ChestRewardType.hint,
      title: 'Cartographer Hint',
      description: 'Reveals a distant secret sector marked with "?" on your minimap containing valuable spoils.',
      categoryLabel: 'Hint',
      icon: Icons.help_outline_rounded,
      accentColor: const Color(0xFFAB47BC),
      targetRegion: target,
    );
  }

  factory ChestRewardOption.boon(String effectName, String description) {
    return ChestRewardOption(
      type: ChestRewardType.boon,
      title: effectName,
      description: description,
      categoryLabel: 'Boon',
      icon: Icons.auto_awesome_rounded,
      accentColor: const Color(0xFF7E57C2),
      boonEffect: effectName,
    );
  }

  factory ChestRewardOption.roll() {
    return const ChestRewardOption(
      type: ChestRewardType.roll,
      title: "Fortune's Die",
      description: 'Roll the die to tempt fate: chance for legendary treasures or wild anomalies.',
      categoryLabel: 'Roll',
      icon: Icons.casino_rounded,
      accentColor: Color(0xFFEC407A),
    );
  }

  /// Generates a pair of unique, distinct chest reward options.
  static List<ChestRewardOption> generateTwoUniqueOptions(
    math.Random rng, {
    required (int, int) currentRegion,
    int rank = 0,
  }) {
    // Determine token reward scaled somewhat by rank
    final tokenAmount = 10 + (rank * 5) + rng.nextInt(11);

    // Pick a candidate target for quest (2 to 3 regions away)
    final questDr = (rng.nextBool() ? 1 : -1) * (2 + rng.nextInt(2));
    final questDc = (rng.nextBool() ? 1 : -1) * (1 + rng.nextInt(3));
    final questTarget = (currentRegion.$1 + questDr, currentRegion.$2 + questDc);

    // Pick a candidate target for hint (3 to 5 regions away)
    final hintDr = (rng.nextBool() ? 1 : -1) * (3 + rng.nextInt(3));
    final hintDc = (rng.nextBool() ? 1 : -1) * (3 + rng.nextInt(3));
    final hintTarget = (currentRegion.$1 + hintDr, currentRegion.$2 + hintDc);

    // Define all candidate reward options
    final List<ChestRewardOption> candidatePool = [
      ChestRewardOption.item(InventoryItemType.shield),
      ChestRewardOption.item(InventoryItemType.flagObvious),
      ChestRewardOption.money(tokenAmount),
      ChestRewardOption.quest(questTarget),
      ChestRewardOption.hint(hintTarget),
      ChestRewardOption.boon(
        'Ascension Boon',
        'Increases difficulty and spoils: all future regions generate with +1 rank.',
      ),
      ChestRewardOption.roll(),
    ];

    candidatePool.shuffle(rng);

    final first = candidatePool.removeAt(0);
    // Ensure second option is distinct in type or title
    final second = candidatePool.firstWhere(
      (opt) => opt.type != first.type && opt.title != first.title,
      orElse: () => candidatePool.first,
    );

    return [first, second];
  }
}
