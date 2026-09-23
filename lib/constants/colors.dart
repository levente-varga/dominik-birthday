import 'package:flutter/material.dart';

abstract final class AppColors {
  // Brand & Theme Colors
  static const Color primary = Colors.deepPurple;
  static const Color primaryAccent = Colors.purpleAccent;
  static const Color secondary = Colors.cyan;
  static const Color secondaryAccent = Colors.cyanAccent;
  static const Color cyanAccent = Colors.cyanAccent;

  // Status & Feedback Colors
  static const Color success = Colors.green;
  static const Color error = Color(0xFFC62828);
  static const Color warning = Colors.amber;
  static const Color warningAccent = Colors.amberAccent;
  static const Color info = Colors.blueAccent;
  static const Color infoLight = Colors.lightBlueAccent;

  // Accent Colors for Games & Badges
  static const Color red = Colors.red;
  static const Color orange = Colors.orange;
  static const Color orangeAccent = Colors.orangeAccent;
  static const Color teal = Colors.teal;
  static const Color tealAccent = Colors.tealAccent;
  static const Color pink = Colors.pink;
  static const Color pinkAccent = Colors.pinkAccent;
  static const Color purple = Colors.purple;
  static const Color purpleAccent = Colors.purpleAccent;
  static const Color lightGreen = Colors.lightGreenAccent;
  static const Color blue = Colors.blue;
  static const Color yellow = Colors.yellow;

  // Code Cracker Palette
  static const Color codeRed = Colors.red;
  static const Color codeBlue = Colors.blue;
  static const Color codeGreen = Colors.green;
  static const Color codeYellow = Colors.yellow;
  static const Color codeOrange = Colors.orange;
  static const Color codePurple = Colors.purple;
  static const Color codeCyan = Colors.cyan;
  static const Color codePink = Colors.pink;

  // Neutral Colors
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color transparent = Colors.transparent;

  // Overlays & Barriers
  static const Color overlayBarrier = Color(0x8C000000); // Black 55%

  // Effects & Shines
  static const Color shineAmber = Color(0x26FFC107); // Amber 15%
  static const Color shineWhite = Color(0x66FFFFFF); // White 40%
  
  // Empty Slots
  static const Color emptySlot = Colors.white12;
  static const Color emptySlotUnlocked = Colors.white24;
  
  // Game specific
  static const Color wallRunnerShockwave = Color(0xFFD32F2F);
  static const Color wallRunnerFailOverlay = Color(0xCC4A1010); // 80% opacity
  static const Color wallRunnerWinOverlay = Color(0xD90F381E); // 85% opacity
  static const Color wallRunnerTrackActive = Color(0x73424242); // Grey 800 @ 45%
  static const Color wallRunnerTrackIdle = Color(0xB3212121); // Grey 900 @ 70%
  static const Color wallRunnerTrackStart = Color(0xE6616161); // Grey 700 @ 90%
  static const Color wallRunnerFinishAccent = Color(0x264CAF50); // Green @ 15%

  // Anomaly System Colors
  static const Color anomalyBadgeText = Color(0xFFEF5350); // Red 400
  static const Color anomalyBadgeBorder = Color(0xFF5E1A1A); // Dark red border

  // Practice Mode Colors
  static const Color practiceBadgeText = Color(0xFF42A5F5);
  static const Color practiceBadgeBorder = Color(0xFF1A3D5C);

  // Stage Progress Colors
  static const Color stageDotCompleted = Colors.green;
  static const Color stageDotCurrentBorder = Color(0xFF5C3D99);

  // UI Chrome Colors
  static const Color headerButtonBackground = Color(0xFF302C35);
  static const Color headerButtonBorder = Color(0xFF2A2A30);
  static const Color headerButtonIcon = Color(0xFFD9D9D9);

  // Simplified panels (replaces surfHigh04...98)
  static const Color panelDim = Color(0xFF1B191F);     // ~0.20 blend
  static const Color panelMedium = Color(0xFF201E24);  // ~0.35 blend
  static const Color panelHigh = Color(0xFF25232A);    // ~0.50 blend
  static const Color panelSolid = Color(0xFF35333A);   // ~0.98 blend

  // Simplified outlines (replaces outline12...40)
  static const Color outlineTransparent = Color(0x279E9E9E); // 25% Grey for all inactive borders
  static const Color outlineDim = outlineTransparent;
  static const Color outlineMedium = outlineTransparent;

  // Simplified text (replaces onSurf20...85)
  static const Color textDim = Color(0xFF49464C);      // ~0.25 blend
  static const Color textMedium = Color(0xFF7D7981);   // ~0.50 blend
  static const Color textBright = Color(0xFFC7C1CA);   // ~0.85 blend

  // Simplified theme colors
  static const Color primaryDim = Color(0xFF302C3B);   // ~0.15 blend
  static const Color primaryMedium = Color(0xFF5F5674); // ~0.40 blend
  static const Color primaryContMedium = Color(0xFF20192F);
  static const Color secondaryMedium = Color(0xFF706A7A);
  static const Color secContainerMedium = Color(0xFF342E46);
  static const Color errorDim = Color(0xFF49191D);
  static const Color errContainerDim = Color(0xFF2A1115);
  static const Color errContainerMedium = Color(0xFF341113);

  // Simplified named colors
  static const Color greenDim = Color(0xFF1F3123);     // ~0.20
  static const Color greenMedium = Color(0xFF28492C);  // ~0.35
  static const Color greenBright = Color(0xFF449748);  // ~0.85

  static const Color blueDim = Color(0xFF1A2B3D);      // ~0.20
  static const Color blueMedium = Color(0xFF264766);   // ~0.35 (pale blue for started minimap regions)
  static const Color blueBright = Color(0xFF3B72A0);   // ~0.85

  static const Color redDim = Color(0xFF411C1E);
  static const Color redMedium = Color(0xFF622323);
  static const Color redAccentDim = Color(0xFF8A3235);

  static const Color amberDim = Color(0xFF372C15);     // ~0.15
  static const Color amberMedium = Color(0xFF664F12);  // ~0.35
  static const Color amberBright = Color(0xFF8A6A10);  // ~0.50

  static const Color whiteDim = Color(0xFF222026);     // ~0.06
  static const Color whiteMedium = Color(0xFF4F4D52);  // ~0.25
  static const Color whiteBright = Color(0xFF8A898C);  // ~0.50

  static const Color purpleAccentMedium = Color(0xFF8E2EA0);
  static const Color cyanBright = Color(0xFF47BDCD);
  static const Color greyMedium = Color(0xFF333235);
  static const Color greySolid = Color(0xFF59595A);
  static const Color pinkMedium = Color(0xFF6A243F);

  // Base surface color
  static const Color surface = Color(0xFF141218);
}
