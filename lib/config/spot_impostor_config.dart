import 'dart:math';
import 'package:flutter/material.dart';

import 'config.dart';

// ── Icon Entry ─────────────────────────────────────────────────────────────
// A single icon in a series — either a Material icon or an image asset.

class ImpostorIconEntry {
  final IconData? iconData;
  final String? assetPath; // e.g. 'assets/icons/anchor_1.png'
  final double rotation; // applied via Transform.rotate

  const ImpostorIconEntry.asset(String path, {this.rotation = 0.0})
    : iconData = null,
      assetPath = path;

  const ImpostorIconEntry.icon(IconData icon, {this.rotation = 0.0})
    : iconData = icon,
      assetPath = null;
}

// ── Icon Series ────────────────────────────────────────────────────────────
// An ordered list of visually similar entries.
// Each adjacent pair is a valid round config — neighbours look alike.
// randomPair() picks one adjacent pair; which is base vs impostor is also random.

class ImpostorIconSeries {
  final List<ImpostorIconEntry> entries;

  const ImpostorIconSeries(this.entries);

  ({ImpostorIconEntry base, ImpostorIconEntry impostor}) randomPair(
    Random rng,
  ) {
    final i = rng.nextInt(entries.length - 1);
    return rng.nextBool()
        ? (base: entries[i], impostor: entries[i + 1])
        : (base: entries[i + 1], impostor: entries[i]);
  }
}

// ── Spot Impostor Config ───────────────────────────────────────────────────

class SpotImpostorConfig extends BaseGameConfig {
  static const int baseGridSize = 10;
  static const int gridSizeDecreasePerSkillLevel = 1;
  static const int minGridSize = 5;

  static const int baseTotalRounds = 6;
  static const int roundsDecreasePerSkillLevel = 1;
  static const int minTotalRounds = 1;

  const SpotImpostorConfig() : super(icon: Icons.search);

  static const List<ImpostorIconSeries> seriesPool = [
    // Anchor
    ImpostorIconSeries([
      ImpostorIconEntry.asset('assets/icons/anchor_1.png'),
      ImpostorIconEntry.asset('assets/icons/anchor_2.png'),
      ImpostorIconEntry.asset('assets/icons/anchor_3.png'),
    ]),

    // Article
    ImpostorIconSeries([
      ImpostorIconEntry.asset('assets/icons/article_1.png'),
      ImpostorIconEntry.asset('assets/icons/article_2.png'),
    ]),

    // Badge
    ImpostorIconSeries([
      ImpostorIconEntry.asset('assets/icons/badge_1.png'),
      ImpostorIconEntry.asset('assets/icons/badge_2.png'),
    ]),

    // Ball
    ImpostorIconSeries([
      ImpostorIconEntry.asset('assets/icons/ball_1.png'),
      ImpostorIconEntry.asset('assets/icons/ball_2.png'),
    ]),

    // Battery
    ImpostorIconSeries([
      ImpostorIconEntry.asset('assets/icons/battery_1.png'),
      ImpostorIconEntry.asset('assets/icons/battery_2.png'),
    ]),

    // Chess
    ImpostorIconSeries([
      ImpostorIconEntry.asset('assets/icons/chess_1.png'),
      ImpostorIconEntry.asset('assets/icons/chess_2.png'),
    ]),

    // Cloud
    ImpostorIconSeries([
      ImpostorIconEntry.asset('assets/icons/cloud_1.png'),
      ImpostorIconEntry.asset('assets/icons/cloud_2.png'),
    ]),

    // Dice
    ImpostorIconSeries([
      ImpostorIconEntry.asset('assets/icons/dice_1.png'),
      ImpostorIconEntry.asset('assets/icons/dice_2.png'),
    ]),

    // Cycle
    ImpostorIconSeries([
      ImpostorIconEntry.asset('assets/icons/cycle_1.png'),
      ImpostorIconEntry.asset('assets/icons/cycle_2.png'),
    ]),

    // Home
    ImpostorIconSeries([
      ImpostorIconEntry.asset('assets/icons/home_1.png'),
      ImpostorIconEntry.asset('assets/icons/home_2.png'),
    ]),

    // Railway
    ImpostorIconSeries([
      ImpostorIconEntry.asset('assets/icons/railway_1.png'),
      ImpostorIconEntry.asset('assets/icons/railway_2.png'),
    ]),

    // Server
    ImpostorIconSeries([
      ImpostorIconEntry.asset('assets/icons/server_1.png'),
      ImpostorIconEntry.asset('assets/icons/server_2.png'),
      ImpostorIconEntry.asset('assets/icons/server_3.png'),
      ImpostorIconEntry.asset('assets/icons/server_4.png'),
    ]),

    // Smoking
    ImpostorIconSeries([
      ImpostorIconEntry.asset('assets/icons/smoking_1.png'),
      ImpostorIconEntry.asset('assets/icons/smoking_2.png'),
    ]),

    // Trail
    ImpostorIconSeries([
      ImpostorIconEntry.asset('assets/icons/trail_1.png'),
      ImpostorIconEntry.asset('assets/icons/trail_2.png'),
      ImpostorIconEntry.asset('assets/icons/trail_3.png'),
    ]),

    // Widgets
    ImpostorIconSeries([
      ImpostorIconEntry.asset('assets/icons/widgets_1.png'),
      ImpostorIconEntry.asset('assets/icons/widgets_2.png'),
    ]),
  ];
}
