import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';

import '../game_state.dart';
import '../config/achievement_config.dart';
import '../config/key_slots_config.dart';
import '../game_registry.dart';
import '../config/skill_tree_config.dart';
import '../widgets/menu_button.dart';
import '../utils/number_formatter.dart';
import 'achievements_screen.dart';
import 'skill_tree_screen.dart';
import 'statistics_screen.dart';
import '../widgets/confirm_popup.dart';
import '../widgets/completionist_reward_popup.dart';
import '../widgets/options_popup.dart';
import '../generated/embedded_assets.dart';

/// The main menu of the Birthday Gauntlet.
///
/// Displays:
/// - The persistent key board (15 character slots) at the top.
/// - Buttons: Start Run, Skill Tree, Statistics, Options.
class MainMenuScreen extends StatefulWidget {
  final GameStateManager gameState;

  const MainMenuScreen({super.key, required this.gameState});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  bool _isDevMode = false;
  static const bool displayPhotos = true;
  final GlobalKey<_KeyBoardState> _keyBoardKey = GlobalKey<_KeyBoardState>();

  static final List<String> _dominikImages = [
    for (int i = 1; i <= 72; i++) 'assets/images/dominik$i.jpg',
  ];
  static String? _lastShownDominikImage;
  late String _currentDominikImage;
  int _konamiIndex = 0;
  Timer? _konamiTimer;
  bool _konamiClickWindowActive = false;

  static const List<LogicalKeyboardKey> _konamiCode = [
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.keyB,
    LogicalKeyboardKey.keyA,
  ];

  @override
  void initState() {
    super.initState();
    _isDevMode = widget.gameState.isDevMode;
    _currentDominikImage = _pickDominikImage();
    HardwareKeyboard.instance.addHandler(_handleKonamiKey);
  }

  @override
  void dispose() {
    _konamiTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleKonamiKey);
    super.dispose();
  }

  void _startKonamiClickWindow() {
    _konamiTimer?.cancel();
    _konamiClickWindowActive = true;
    _konamiTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _konamiClickWindowActive = false;
        _konamiIndex = 0;
      }
    });
  }

  bool _handleKonamiKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;

    // If click window was active and the user presses 'A' (after completing through B), refresh the window.
    if (_konamiClickWindowActive &&
        key == LogicalKeyboardKey.keyA &&
        _konamiIndex == 9) {
      _konamiIndex = 10;
      _startKonamiClickWindow();
      return false;
    }

    // If another key is pressed while the click window is active, disrupt and reset:
    if (_konamiClickWindowActive) {
      _konamiTimer?.cancel();
      _konamiClickWindowActive = false;
      _konamiIndex = (key == LogicalKeyboardKey.arrowUp) ? 1 : 0;
      return false;
    }

    final expected = _konamiCode[_konamiIndex];
    if (key == expected) {
      _konamiIndex++;
      // Activate 3-second click window once reaching B (index 9) or A (index 10)
      if (_konamiIndex == 9 || _konamiIndex == _konamiCode.length) {
        _startKonamiClickWindow();
      }
    } else {
      // Disrupted: restart detection.
      // If the disruptive key happens to be arrowUp, restart at index 1, otherwise 0.
      _konamiIndex = (key == LogicalKeyboardKey.arrowUp) ? 1 : 0;
    }

    return false;
  }

  void _onTopLeftCornerTapped() {
    if (_isDevMode) {
      // When dev mode is already on, tapping toggles it off
      setState(() {
        _isDevMode = false;
        widget.gameState.isDevMode = false;
      });
      return;
    }

    // Must be within the 3s secret click window
    if (_konamiClickWindowActive) {
      _konamiTimer?.cancel();
      _konamiClickWindowActive = false;
      _konamiIndex = 0;
      setState(() {
        _isDevMode = true;
        widget.gameState.isDevMode = true;
      });
    }
  }

  String _pickDominikImage([String? current]) {
    final previous = current ?? _lastShownDominikImage;
    if (widget.gameState.statistics.totalRunsStarted == 0 && previous == null) {
      _lastShownDominikImage = 'assets/images/dominik1.jpg';
      return 'assets/images/dominik1.jpg';
    }
    final candidates = previous != null
        ? _dominikImages.where((img) => img != previous).toList()
        : _dominikImages;
    if (candidates.isEmpty) return _dominikImages.first;
    final chosen = candidates[math.Random().nextInt(candidates.length)];
    _lastShownDominikImage = chosen;
    return chosen;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: SafeArea(
          child: ListenableBuilder(
            listenable: widget.gameState,
            builder: (context, _) {
              final isPracticeUnlocked = widget.gameState.isSkillUnlocked(
                'practice',
              );
              final hasEarnedTokens =
                  widget.gameState.statistics.totalTokensEarned > 0;
              final hasPlayedRuns =
                  widget.gameState.statistics.totalGamesCompleted > 0 ||
                  widget.gameState.statistics.totalDeaths > 0;

              return Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 32),

                        // ── Header Row with individual badge visibility ──
                        SizedBox(
                          height: 36,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isDevMode) ...[
                                // Dev button (Delete save file - red floppy)
                                SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: OutlinedButton(
                                    onPressed: () => _confirmDeleteAll(context),
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      backgroundColor: AppColors.panelMedium,
                                      side: BorderSide(
                                        color: AppColors.outlineDim,
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.save_rounded,
                                      size: 14,
                                      color: Colors.red.shade400,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Dev button (Delete achievements - red trophy)
                                SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        _confirmDeleteAchievements(context),
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      backgroundColor: AppColors.panelMedium,
                                      side: BorderSide(
                                        color: AppColors.outlineDim,
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.emoji_events_rounded,
                                      size: 14,
                                      color: Colors.red.shade400,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (hasEarnedTokens || _isDevMode) ...[
                                MouseRegion(
                                  cursor: _isDevMode
                                      ? SystemMouseCursors.click
                                      : MouseCursor.defer,
                                  child: GestureDetector(
                                    onTap: _isDevMode
                                        ? () => showAddDevTokensPopup(
                                              context,
                                              gameState: widget.gameState,
                                            )
                                        : null,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.panelMedium,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.outlineDim,
                                          width: 1.5,
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
                                            formatWithCommas(
                                              widget.gameState.tokens,
                                            ),
                                            style: TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber.shade400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              // Token Multiplier Badge (hidden at ×1.0 unless dev mode)
                              if (widget.gameState.tokenMultiplier > 1.0 ||
                                  _isDevMode) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.panelMedium,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.outlineDim,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    '×${widget.gameState.tokenMultiplier.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.pink.shade400,
                                    ),
                                  ),
                                ),
                              ],
                              // Anomaly Probability Badge (hidden at 0% unless dev mode)
                              if (widget.gameState.anomalyProbability > 0 ||
                                  _isDevMode) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.panelMedium,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.outlineDim,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      EmbeddedAssets.getImage(
                                        'assets/icons/skull.png',
                                        width: 16,
                                        height: 16,
                                        color: AppColors.anomalyBadgeText,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        widget
                                            .gameState
                                            .formattedAnomalyProbability,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.anomalyBadgeText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (_isDevMode) ...[
                                const SizedBox(width: 6),
                                // Dev button (Add custom tokens)
                                SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: OutlinedButton(
                                    onPressed: () => showAddDevTokensPopup(
                                      context,
                                      gameState: widget.gameState,
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      backgroundColor: AppColors.panelMedium,
                                      side: const BorderSide(
                                        color: AppColors.outlineDim,
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.add_rounded,
                                      size: 14,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Dev button (Test Achievement Toast Popup)
                                SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: OutlinedButton(
                                    onPressed: () => widget.gameState
                                        .triggerTestAchievementToast(),
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      backgroundColor: AppColors.panelMedium,
                                      side: BorderSide(
                                        color: AppColors.outlineDim,
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.emoji_events_rounded,
                                      size: 14,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Persistent key board (15 slots) ──────────────────
                        _KeyBoard(
                          key: _keyBoardKey,
                          gameState: widget.gameState,
                          unlockedKeyChars: widget.gameState.unlockedKeyChars,
                          isPracticeUnlocked: isPracticeUnlocked,
                          isDevMode: _isDevMode,
                          isCompletionistCollected:
                              widget.gameState.getAchievementStatus(
                                'completionist',
                              ) ==
                              AchievementStatus.collected,
                          onTestStage: (stage) => _testStage(context, stage),
                        ),

                        const Spacer(),

                        // ── Title ───────────────────────────────────────────
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              'Boldog Szülinapot La',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMedium,
                              ),
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                final gs = widget.gameState;
                                if (gs.getAchievementStatus('hidden_c_click') ==
                                        AchievementStatus.locked &&
                                    gs.isAchievementPopupShown(
                                      'hidden_c_click',
                                    )) {
                                  gs.setAchievementStatus(
                                    'hidden_c_click',
                                    AchievementStatus.unlocked,
                                  );
                                }
                              },
                              child: Text(
                                'c',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color:
                                      widget.gameState.getAchievementStatus(
                                            'hidden_c_click',
                                          ) ==
                                          AchievementStatus.locked
                                      ? AppColors.textMedium
                                      : AppColors.textBright,
                                ),
                              ),
                            ),
                            Text(
                              'i!',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMedium,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        if (displayPhotos)
                          // ── Central Square Container ────────────────────────
                          GestureDetector(
                            onTap: _isDevMode
                                ? () {
                                    setState(() {
                                      _currentDominikImage =
                                          _pickDominikImage(_currentDominikImage);
                                    });
                                  }
                                : null,
                            child: SizedBox(
                              width: 240,
                              height: 240,
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: EmbeddedAssets.getImage(
                                      _currentDominikImage,
                                      width: 240,
                                      height: 240,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: AppColors.outlineDim,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const Spacer(flex: 2),

                        const SizedBox(height: 48),

                        // ── Horizontal Menu buttons ───────────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 1. Options (Side - smallest: 46px)
                            SizedBox(
                              width: 46,
                              height: 46,
                              child: MenuButton(
                                label: 'Options',
                                icon: Icons.settings_rounded,
                                size: 46,
                                iconSize: 22,
                                onPressed: () => showOptionsPopup(context),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // 2. Achievements (Inner Left: 56px)
                            SizedBox(
                              width: 56,
                              height: 56,
                              child:
                                  (widget
                                          .gameState
                                          .hasAnyUnlockedOrCollectedAchievements ||
                                      _isDevMode)
                                  ? MenuButton(
                                      label: 'Achievements',
                                      icon: Icons.emoji_events_rounded,
                                      size: 56,
                                      iconSize: 26,
                                      showYellowDot: widget
                                          .gameState
                                          .hasAnyUnclaimedAchievements,
                                      onPressed: () =>
                                          _openAchievements(context),
                                    )
                                  : const MenuButtonMockup(size: 56),
                            ),
                            const SizedBox(width: 10),

                            // 3. Play (Center - biggest: 68px)
                            SizedBox(
                              width: 68,
                              height: 68,
                              child: MenuButton(
                                label: widget.gameState.isGameComplete
                                    ? 'Victory Lap'
                                    : 'Start Run',
                                icon: Icons.play_arrow_rounded,
                                size: 68,
                                iconSize: 34,
                                onPressed: () => _startRun(context),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // 4. Skill Tree (Inner Right: 56px)
                            SizedBox(
                              width: 56,
                              height: 56,
                              child: (hasEarnedTokens || _isDevMode)
                                  ? MenuButton(
                                      label: 'Skill Tree',
                                      icon: Icons.account_tree_rounded,
                                      size: 56,
                                      iconSize: 26,
                                      showYellowDot: widget.gameState
                                          .canAffordAnySkill(
                                            defaultSkillTreeNodes,
                                          ),
                                      onPressed: () => _openSkillTree(context),
                                    )
                                  : const MenuButtonMockup(size: 56),
                            ),
                            const SizedBox(width: 10),

                            // 5. Stats (Side - smallest: 46px)
                            SizedBox(
                              width: 46,
                              height: 46,
                              child: (hasPlayedRuns || _isDevMode)
                                  ? MenuButton(
                                      label: 'Statistics',
                                      icon: Icons.bar_chart_rounded,
                                      size: 46,
                                      iconSize: 22,
                                      showYellowDot: !widget
                                          .gameState
                                          .statistics
                                          .hasOpenedStatistics,
                                      onPressed: () => _openStatistics(context),
                                    )
                                  : const MenuButtonMockup(size: 46),
                            ),
                          ],
                        ),

                        const SizedBox(height: 48),
                      ],
                    ),
                  ),

                  // ── Top-Left Dev Mode Secret Click Target (Always present, invisible) ──
                  Positioned(
                    top: 0,
                    left: 0,
                    width: 50,
                    height: 50,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _onTopLeftCornerTapped,
                      child: const SizedBox.expand(),
                    ),
                  ),

                  // ── Top-Left Dev Mode Toggle Button (Visible only when Dev Mode is ON) ──
                  if (_isDevMode)
                    Positioned(
                      top: 16,
                      left: 16,
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: OutlinedButton(
                          onPressed: _onTopLeftCornerTapped,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            backgroundColor: AppColors.panelMedium,
                            side: const BorderSide(
                              color: AppColors.amberBright,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Icon(
                            Icons.code,
                            size: 14,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ),

                  // ── Subtle Version String at Bottom ──
                  const Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        'v1.0.3',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                          color: AppColors.textDim,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _startRun(BuildContext context) async {
    await Navigator.of(context).pushNamed('/run');
    if (mounted) {
      setState(() {
        _currentDominikImage = _pickDominikImage(_currentDominikImage);
      });
    }
  }

  void _openSkillTree(BuildContext context) {
    showSkillTreePopup(context, widget.gameState, isDevMode: _isDevMode);
  }

  void _openStatistics(BuildContext context) {
    widget.gameState.markStatisticsOpened();
    showStatisticsPopup(context, widget.gameState, isDevMode: _isDevMode);
  }

  void _openAchievements(BuildContext context) async {
    final claimed = await showAchievementsPopup(
      context,
      widget.gameState,
      isDevMode: _isDevMode,
    );
    if (claimed == true) {
      _keyBoardKey.currentState?.playCompletionistAnimation();
    }
  }

  void _testStage(BuildContext context, int stageNumber) async {
    await Navigator.of(context).pushNamed(
      '/practice',
      arguments: {'stageNumber': stageNumber, 'isDevMode': _isDevMode},
    );
    if (mounted) {
      setState(() {
        _currentDominikImage = _pickDominikImage(_currentDominikImage);
      });
    }
  }

  void _confirmDeleteAll(BuildContext context) {
    showConfirmPopup(
      context,
      title: 'Delete All Data?',
      icon: Icons.save_rounded,
      iconColor: Colors.red.shade400,
      body: 'This will erase all progress, statistics, and achievements.',
      confirmLabel: 'Delete Everything',
      onConfirm: () => widget.gameState.clearAllData(),
    );
  }

  void _confirmDeleteAchievements(BuildContext context) {
    showConfirmPopup(
      context,
      title: 'Reset All Achievements?',
      icon: Icons.emoji_events_rounded,
      iconColor: Colors.red.shade400,
      body: 'This will reset all achievements.',
      confirmLabel: 'Reset Achievements',
      onConfirm: () => widget.gameState.resetAchievements(),
    );
  }
}

// ── Key board widget ───────────────────────────────────────────────────────

/// Timings for the 15 completionist golden slot flip reveals.
/// Starts slow, accelerates around midway, and settles into a fast, consistent cadence for the second half.
class CompletionistCutsceneTimings {
  static const double startDelay = 0.12;
  static const double halfDuration = 0.008; // 100ms half-flip

  // Precomputed normalized start times for ranks 0..14 across 12.5s total duration.
  // Delay starts at 1500ms, transitions smoothly in the middle, and settles at a constant 220ms for slots 9-15.
  static const List<double> slotStartTimes = [
    0.1200, // Slot 1:  1.50s (delay 0ms)
    0.2400, // Slot 2:  3.00s (delay 1500ms)
    0.3543, // Slot 3:  4.43s (delay 1429ms)
    0.4540, // Slot 4:  5.68s (delay 1246ms)
    0.5337, // Slot 5:  6.67s (delay 996ms)
    0.5916, // Slot 6:  7.40s (delay 724ms)
    0.6295, // Slot 7:  7.87s (delay 474ms)
    0.6528, // Slot 8:  8.16s (delay 291ms)
    0.6704, // Slot 9:  8.38s (delay 220ms - fast constant cadence begins)
    0.6880, // Slot 10: 8.60s (delay 220ms)
    0.7056, // Slot 11: 8.82s (delay 220ms)
    0.7232, // Slot 12: 9.04s (delay 220ms)
    0.7408, // Slot 13: 9.26s (delay 220ms)
    0.7584, // Slot 14: 9.48s (delay 220ms)
    0.7760, // Slot 15: 9.70s (delay 220ms)
  ];

  static (bool isGolden, bool isFlipping, double flipAngle) computeSlotState({
    required double t,
    required int rank,
  }) {
    if (rank < 0 || rank >= slotStartTimes.length) {
      return (false, false, 0.0);
    }
    final startT = slotStartTimes[rank];
    final midT = startT + halfDuration;
    final endT = startT + (halfDuration * 2);

    final isPastMid = t >= midT;
    final isAnimating = t >= startT && t < endT;

    double flipAngle = 0.0;
    if (isAnimating) {
      if (!isPastMid) {
        final progress = (t - startT) / halfDuration;
        flipAngle = progress.clamp(0.0, 1.0) * (math.pi / 2);
      } else {
        final progress = (t - midT) / halfDuration;
        flipAngle = -math.pi / 2 + progress.clamp(0.0, 1.0) * (math.pi / 2);
      }
    }

    return (isPastMid, isAnimating, flipAngle);
  }
}

class _KeyBoard extends StatefulWidget {
  final GameStateManager gameState;
  final List<String?> unlockedKeyChars;
  final bool isPracticeUnlocked;
  final bool isDevMode;
  final bool isCompletionistCollected;
  final void Function(int stageNumber) onTestStage;

  const _KeyBoard({
    super.key,
    required this.gameState,
    required this.unlockedKeyChars,
    required this.isPracticeUnlocked,
    required this.isDevMode,
    this.isCompletionistCollected = false,
    required this.onTestStage,
  });

  @override
  State<_KeyBoard> createState() => _KeyBoardState();
}

class _KeyBoardState extends State<_KeyBoard>
    with SingleTickerProviderStateMixin {
  int? _hoveredSlotIndex;
  OverlayEntry? _overlayEntry;
  OverlayEntry? _cutsceneOverlayEntry;
  final LayerLink _layerLink = LayerLink();
  final GlobalKey<_OverlayDimWrapperState> _overlayWrapperKey =
      GlobalKey<_OverlayDimWrapperState>();
  final ValueNotifier<int?> _hoveredSlotNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<double> _cutsceneProgressNotifier = ValueNotifier<double>(
    0.0,
  );
  Timer? _fadeTimer;

  late final AnimationController _completionistFlipController;
  bool _isAwaitingOrPlayingCutscene = false;
  bool _cutsceneCompleted = false;

  @override
  void initState() {
    super.initState();
    _cutsceneCompleted = widget.isCompletionistCollected;
    _completionistFlipController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 12500),
        )..addListener(() {
          _cutsceneProgressNotifier.value = _completionistFlipController.value;
          setState(() {});
        });
  }

  @override
  void didUpdateWidget(_KeyBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isCompletionistCollected) {
      if (_cutsceneCompleted || _isAwaitingOrPlayingCutscene) {
        setState(() {
          _cutsceneCompleted = false;
          _isAwaitingOrPlayingCutscene = false;
        });
        _completionistFlipController.stop();
        _completionistFlipController.value = 0.0;
        _removeCutsceneOverlay();
        _removeOverlayImmediately();
      }
    } else if (!oldWidget.isCompletionistCollected &&
        widget.isCompletionistCollected &&
        !_isAwaitingOrPlayingCutscene &&
        !_cutsceneCompleted) {
      playCompletionistAnimation();
    }
  }

  void playCompletionistAnimation() {
    if (_isAwaitingOrPlayingCutscene || _cutsceneCompleted) return;

    setState(() {
      _isAwaitingOrPlayingCutscene = true;
      _cutsceneCompleted = false;
    });

    widget.gameState.setAchievementOverlayPaused(true);
    _removeOverlayImmediately();
    _removeCutsceneOverlay();

    _cutsceneProgressNotifier.value = 0.0;
    _cutsceneOverlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return ValueListenableBuilder<double>(
          valueListenable: _cutsceneProgressNotifier,
          builder: (context, t, _) {
            double backdropOpacity = 0.0;
            if (t <= 0.04) {
              backdropOpacity = (t / 0.04).clamp(0.0, 1.0);
            } else if (t <= 0.90) {
              backdropOpacity = 1.0;
            } else {
              backdropOpacity = ((1.0 - t) / 0.10).clamp(0.0, 1.0);
            }

            final double slotsOpacity = (t / 0.04).clamp(0.0, 1.0);

            return Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: DefaultTextStyle(
                  style: const TextStyle(decoration: TextDecoration.none),
                  child: AbsorbPointer(
                    absorbing:
                        true, // Prevent ALL interaction across the entire screen!
                    child: Stack(
                      children: [
                        // ── Full-Screen Dark Dim Backdrop (fades out at end of cutscene) ──
                        Positioned.fill(
                          child: Container(
                            color: Color.lerp(
                              Colors.transparent,
                              const Color(0xF2000000), // 95% dark overlay
                              backdropOpacity,
                            ),
                          ),
                        ),
                        // ── Cutscene Elevated Slots Row (glow and slots fade in at start and stay at full opacity) ──
                        Opacity(
                          opacity: slotsOpacity,
                          child: CompositedTransformFollower(
                            link: _layerLink,
                            showWhenUnlinked: false,
                            child: _CutsceneSlotsFollower(
                              unlockedKeyChars: widget.unlockedKeyChars,
                              t: t,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    Overlay.of(context).insert(_cutsceneOverlayEntry!);

    _completionistFlipController.forward(from: 0.0).then((_) {
      _removeCutsceneOverlay();
      widget.gameState.setAchievementOverlayPaused(false);
      if (mounted) {
        setState(() {
          _isAwaitingOrPlayingCutscene = false;
          _cutsceneCompleted = true;
        });
        showCompletionistRewardPopup(context);
      }
    });
  }

  void _removeCutsceneOverlay() {
    _cutsceneOverlayEntry?.remove();
    _cutsceneOverlayEntry = null;
  }

  void _updateOverlay(int? slotIndex) {
    if (_isAwaitingOrPlayingCutscene) return;
    if (slotIndex == null || widget.unlockedKeyChars[slotIndex] == null) {
      _removeOverlayWithFade();
      return;
    }

    _fadeTimer?.cancel();

    if (_overlayEntry == null) {
      _hoveredSlotNotifier.value = slotIndex;
      final theme = Theme.of(context);
      final isPractice = widget.isPracticeUnlocked;
      final isDev = widget.isDevMode;

      _overlayEntry = OverlayEntry(
        builder: (overlayContext) {
          return Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: DefaultTextStyle(
                style: const TextStyle(decoration: TextDecoration.none),
                child: IgnorePointer(
                  ignoring: true,
                  child: ValueListenableBuilder<int?>(
                    valueListenable: _hoveredSlotNotifier,
                    builder: (context, currentSlot, _) {
                      if (currentSlot == null) return const SizedBox();

                      return _OverlayDimWrapper(
                        key: _overlayWrapperKey,
                        slotHighlight: CompositedTransformFollower(
                          link: _layerLink,
                          showWhenUnlinked: false,
                          child: _KeyBoardHoverHighlight(
                            hoveredSlotIndex: currentSlot,
                            unlockedKeyChars: widget.unlockedKeyChars,
                            isPracticeUnlocked: isPractice,
                            isDevMode: isDev,
                            isCompletionistCollected:
                                widget.isCompletionistCollected,
                            theme: theme,
                          ),
                        ),
                        hintCard: _CenteredHintCard(
                          hoveredSlotIndex: currentSlot,
                          unlockedKeyChars: widget.unlockedKeyChars,
                          theme: theme,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      );

      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _hoveredSlotNotifier.value = slotIndex;
      _overlayWrapperKey.currentState?.show();
    }
  }

  void _removeOverlayWithFade() {
    _fadeTimer?.cancel();
    _overlayWrapperKey.currentState?.hide();
    _fadeTimer = Timer(const Duration(milliseconds: 750), () {
      _removeOverlayImmediately();
    });
  }

  void _removeOverlayImmediately() {
    _fadeTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
    _hoveredSlotNotifier.value = null;
  }

  @override
  void dispose() {
    if (_isAwaitingOrPlayingCutscene) {
      widget.gameState.setAchievementOverlayPaused(false);
    }
    _removeOverlayImmediately();
    _removeCutsceneOverlay();
    _hoveredSlotNotifier.dispose();
    _cutsceneProgressNotifier.dispose();
    _completionistFlipController.dispose();
    super.dispose();
  }

  Widget _buildSlot(int i) {
    final bool isCompleted = widget.unlockedKeyChars[i] != null;
    bool slotIsGolden = false;
    double flipAngle = 0.0;
    bool isSlotFlipping = false;

    if (_isAwaitingOrPlayingCutscene &&
        _completionistFlipController.isAnimating) {
      final sortedIndices = List<int>.generate(15, (k) => k)
        ..sort((a, b) => getSlotNumber(a).compareTo(getSlotNumber(b)));
      final rank = sortedIndices.indexOf(i);

      final state = CompletionistCutsceneTimings.computeSlotState(
        t: _completionistFlipController.value,
        rank: rank,
      );
      slotIsGolden = state.$1;
      isSlotFlipping = state.$2;
      flipAngle = state.$3;
    } else if (_cutsceneCompleted) {
      slotIsGolden = true;
    }

    Widget slotWidget = _ProgressSlot(
      isUnlocked: isCompleted,
      isHovered: (isCompleted || slotIsGolden) && _hoveredSlotIndex == i,
      isGolden: slotIsGolden,
      slotNumber: getSlotNumber(i),
      flipAngle: flipAngle,
      isFlipping: isSlotFlipping,
    );

    final bool isUnlockedOrGolden = isCompleted || slotIsGolden;
    final bool showSlotDot =
        isUnlockedOrGolden && !widget.gameState.hasHoveredKeySlot(i);

    if (isUnlockedOrGolden) {
      slotWidget = MouseRegion(
        onEnter: (_) {
          widget.gameState.markKeySlotHovered(i);
          if (_isAwaitingOrPlayingCutscene) return;
          if (_hoveredSlotIndex != i) {
            setState(() {
              _hoveredSlotIndex = i;
            });
            _updateOverlay(i);
          }
        },
        onExit: (_) {
          if (_isAwaitingOrPlayingCutscene) return;
          if (_hoveredSlotIndex == i) {
            setState(() {
              _hoveredSlotIndex = null;
            });
            _updateOverlay(null);
          }
        },
        child: slotWidget,
      );
    }

    if (showSlotDot) {
      slotWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          slotWidget,
          const Positioned(
            top: -3,
            right: -3,
            child: IgnorePointer(child: PingingYellowDot(size: 10)),
          ),
        ],
      );
    }

    return slotWidget;
  }

  Widget _buildPracticeButton(int i) {
    final stage = i + 1;
    final isCompleted = widget.unlockedKeyChars[i] != null;
    final isImplemented = GameRegistry.isImplemented(stage);

    final bool showButton = widget.isDevMode
        ? isImplemented
        : (widget.isPracticeUnlocked && isCompleted && isImplemented);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 22,
      height: 24,
      child: showButton
          ? OutlinedButton(
              onPressed: () => widget.onTestStage(stage),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                backgroundColor: AppColors.panelMedium,
                side: const BorderSide(color: AppColors.outlineDim, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: Icon(
                Icons.circle,
                size: 12,
                color: AppColors.textBright,
              ),
            )
          : const SizedBox(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isBoardGolden = _cutsceneCompleted;
    final bool isGoldenGlow = isBoardGolden;

    final Color dashColor =
        (_isAwaitingOrPlayingCutscene &&
            _completionistFlipController.isAnimating)
        ? Color.lerp(
            AppColors.textDim,
            Colors.amber.shade400,
            _completionistFlipController.value.clamp(0.0, 1.0),
          )!
        : (isBoardGolden ? Colors.amber.shade400 : AppColors.textDim);

    return CompositedTransformTarget(
      link: _layerLink,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Slots Row (Wrapped with golden glow around ONLY the slots) ──
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: isGoldenGlow
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66FFA000), // Golden amber glow
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                              BoxShadow(
                                color: Color(0x33FFC107),
                                blurRadius: 40,
                                spreadRadius: 8,
                              ),
                            ],
                          )
                        : null,
                    child: Row(
                      textDirection: TextDirection.rtl,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Third group (stages 11..15, slots 10..14)
                        for (int i = 14; i >= 10; i--) _buildSlot(i),
                        _DashSeparator(color: dashColor),
                        // Second group (stages 6..10, slots 5..9)
                        for (int i = 9; i >= 5; i--) _buildSlot(i),
                        _DashSeparator(color: dashColor),
                        // First group (stages 1..5, slots 0..4)
                        for (int i = 4; i >= 0; i--) _buildSlot(i),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // ── Practice Buttons Row (Outside the glow) ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < 5; i++) _buildPracticeButton(i),
                        const _DashSpace(),
                        for (int i = 5; i < 10; i++) _buildPracticeButton(i),
                        const _DashSpace(),
                        for (int i = 10; i < 15; i++) _buildPracticeButton(i),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressSlot extends StatelessWidget {
  final bool isUnlocked;
  final bool isHovered;
  final bool isGolden;
  final int slotNumber;
  final double flipAngle;
  final bool isFlipping;

  const _ProgressSlot({
    required this.isUnlocked,
    this.isHovered = false,
    this.isGolden = false,
    this.slotNumber = 0,
    this.flipAngle = 0.0,
    this.isFlipping = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeHover = (isUnlocked || isGolden) && isHovered;

    Widget content;
    if (isGolden) {
      final borderColor = activeHover ? Colors.white : Colors.amber.shade400;
      final textColor = activeHover ? Colors.white : Colors.amber.shade400;

      content = Container(
        width: 22,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: AppColors.amberDim,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: activeHover
              ? const [
                  BoxShadow(
                    color: AppColors.whiteBright,
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : const [
                  BoxShadow(
                    color: AppColors.amberMedium,
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              '$slotNumber',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textColor,
                decoration: TextDecoration.none,
                height: 1.0,
              ),
            ),
          ),
        ),
      );
    } else {
      final borderColor = activeHover
          ? Colors.white
          : (isUnlocked ? Colors.green : AppColors.outlineDim);

      content = AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 22,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isUnlocked ? AppColors.greenBright : AppColors.panelMedium,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: activeHover
              ? const [
                  BoxShadow(
                    color: AppColors.whiteBright,
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : (isUnlocked
                    ? const [
                        BoxShadow(
                          color: AppColors.greenMedium,
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : null),
        ),
        alignment: Alignment.center,
        child: isUnlocked
            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
            : null,
      );
    }

    if (isFlipping) {
      content = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.003)
          ..rotateY(flipAngle),
        child: content,
      );
    }

    return content;
  }
}

class _DashSeparator extends StatelessWidget {
  final Color? color;
  const _DashSeparator({this.color});

  @override
  Widget build(BuildContext context) {
    final dashColor = color ?? AppColors.textDim;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        width: 12,
        height: 30,
        child: Center(
          child: Text(
            '–',
            style: TextStyle(
              fontSize: 16,
              color: dashColor,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashSpace extends StatelessWidget {
  const _DashSpace();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(width: 12, height: 24),
    );
  }
}

class _CutsceneSlotsFollower extends StatelessWidget {
  final List<String?> unlockedKeyChars;
  final double t;

  const _CutsceneSlotsFollower({
    required this.unlockedKeyChars,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final sortedIndices = List<int>.generate(15, (i) => i)
      ..sort((a, b) => getSlotNumber(a).compareTo(getSlotNumber(b)));

    final dashColor = Color.lerp(
      AppColors.textDim,
      Colors.amber.shade400,
      t.clamp(0.0, 1.0),
    )!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66FFA000), // Golden amber glow
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: Color(0x33FFC107),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Third group (slots 10..14)
                      for (int i = 14; i >= 10; i--)
                        _buildCutsceneSlot(i, sortedIndices),
                      _DashSeparator(color: dashColor),
                      // Second group (slots 5..9)
                      for (int i = 9; i >= 5; i--)
                        _buildCutsceneSlot(i, sortedIndices),
                      _DashSeparator(color: dashColor),
                      // First group (slots 0..4)
                      for (int i = 4; i >= 0; i--)
                        _buildCutsceneSlot(i, sortedIndices),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCutsceneSlot(int i, List<int> sortedIndices) {
    final isCompleted = unlockedKeyChars[i] != null;
    final rank = sortedIndices.indexOf(i);

    final state = CompletionistCutsceneTimings.computeSlotState(
      t: t,
      rank: rank,
    );

    return _ProgressSlot(
      isUnlocked: isCompleted,
      isGolden: state.$1,
      slotNumber: getSlotNumber(i),
      flipAngle: state.$3,
      isFlipping: state.$2,
    );
  }
}

class _KeyBoardHoverHighlight extends StatelessWidget {
  final int hoveredSlotIndex;
  final List<String?> unlockedKeyChars;
  final bool isPracticeUnlocked;
  final bool isDevMode;
  final bool isCompletionistCollected;
  final ThemeData theme;

  const _KeyBoardHoverHighlight({
    required this.hoveredSlotIndex,
    required this.unlockedKeyChars,
    required this.isPracticeUnlocked,
    required this.isDevMode,
    this.isCompletionistCollected = false,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final dashColor = isCompletionistCollected
        ? Colors.amber.shade400
        : AppColors.textDim;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Third group (slots 10..14)
                      for (int i = 14; i >= 10; i--)
                        _HighlightedSlotColumn(
                          slotIndex: i,
                          unlockedKeyChars: unlockedKeyChars,
                          isHovered: i == hoveredSlotIndex,
                          isGolden: isCompletionistCollected,
                          slotNumber: getSlotNumber(i),
                        ),
                      Opacity(
                        opacity: 0.0,
                        child: _DashSeparator(color: dashColor),
                      ),
                      // Second group (slots 5..9)
                      for (int i = 9; i >= 5; i--)
                        _HighlightedSlotColumn(
                          slotIndex: i,
                          unlockedKeyChars: unlockedKeyChars,
                          isHovered: i == hoveredSlotIndex,
                          isGolden: isCompletionistCollected,
                          slotNumber: getSlotNumber(i),
                        ),
                      Opacity(
                        opacity: 0.0,
                        child: _DashSeparator(color: dashColor),
                      ),
                      // First group (slots 0..4)
                      for (int i = 4; i >= 0; i--)
                        _HighlightedSlotColumn(
                          slotIndex: i,
                          unlockedKeyChars: unlockedKeyChars,
                          isHovered: i == hoveredSlotIndex,
                          isGolden: isCompletionistCollected,
                          slotNumber: getSlotNumber(i),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredHintCard extends StatelessWidget {
  final int hoveredSlotIndex;
  final List<String?> unlockedKeyChars;
  final ThemeData theme;

  const _CenteredHintCard({
    required this.hoveredSlotIndex,
    required this.unlockedKeyChars,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 300,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xff1e1c20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.whiteMedium, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(height: 1.5, color: Color(0xFF777777)),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 26,
                  color: Color(0xffffd54f),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(height: 1.5, color: Color(0xFF777777)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: SingleChildScrollView(
                  child: _SequentialFadeText(
                    text: getSlotHintText(hoveredSlotIndex, unlockedKeyChars),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.normal,
                      fontSize: 13,
                      height: 1.4,
                      color: const Color(0xffb0adb5),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightedSlotColumn extends StatelessWidget {
  final int slotIndex;
  final List<String?> unlockedKeyChars;
  final bool isHovered;
  final bool isGolden;
  final int slotNumber;

  const _HighlightedSlotColumn({
    required this.slotIndex,
    required this.unlockedKeyChars,
    required this.isHovered,
    this.isGolden = false,
    this.slotNumber = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = unlockedKeyChars[slotIndex] != null;

    if (!isHovered) {
      return const Opacity(
        opacity: 0.0,
        child: SizedBox(width: 26, height: 30),
      );
    }

    return _ProgressSlot(
      isUnlocked: isCompleted,
      isHovered: true,
      isGolden: isGolden,
      slotNumber: slotNumber,
    );
  }
}

class _OverlayDimWrapper extends StatefulWidget {
  final Widget slotHighlight;
  final Widget hintCard;

  const _OverlayDimWrapper({
    super.key,
    required this.slotHighlight,
    required this.hintCard,
  });

  @override
  State<_OverlayDimWrapper> createState() => _OverlayDimWrapperState();
}

class _OverlayDimWrapperState extends State<_OverlayDimWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCirc,
    );

    show();
  }

  void show() {
    _controller.forward();
  }

  void hide() {
    _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final progress = _animation.value;
        final opacity = progress.clamp(0.0, 1.0);
        final scale = 0.6 + (progress * 0.4);
        final flipAngle = -(1.0 - progress) * math.pi / 2.3;

        return Opacity(
          opacity: opacity,
          child: Stack(
            children: [
              // 1. Fullscreen dark dimming overlay (flat, NO 3D rotation)
              Positioned.fill(
                child: Container(color: Colors.black.withValues(alpha: 0.80)),
              ),
              // 2. Un-dimmed highlight layer for hovered slot box (flat over code line)
              widget.slotHighlight,
              // 3. Centered 3D Hint Card (ONLY THIS CARD ROTATES IN 3D!)
              Center(
                child: Transform.scale(
                  scale: scale,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0012)
                      ..rotateY(flipAngle),
                    child: widget.hintCard,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SequentialFadeText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const _SequentialFadeText({required this.text, this.style});

  @override
  State<_SequentialFadeText> createState() => _SequentialFadeTextState();
}

class _SequentialFadeTextState extends State<_SequentialFadeText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late String _displayedText;

  @override
  void initState() {
    super.initState();
    _displayedText = widget.text;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);

    _controller.value = 1.0;

    _controller.addListener(() {
      if (_controller.status == AnimationStatus.forward &&
          _controller.value >= 0.5 &&
          _displayedText != widget.text) {
        setState(() {
          _displayedText = widget.text;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant _SequentialFadeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      if (_displayedText == oldWidget.text) {
        _controller.forward(from: 0.0);
      } else {
        _displayedText = widget.text;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        final currentOpacity = _opacityAnimation.value;
        final baseColor = widget.style?.color ?? Colors.white;

        return Text(
          _displayedText,
          style: widget.style?.copyWith(
            color: Color.lerp(AppColors.surface, baseColor, currentOpacity)!,
          ),
          textAlign: TextAlign.left,
        );
      },
    );
  }
}
