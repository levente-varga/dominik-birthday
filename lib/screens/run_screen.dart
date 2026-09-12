import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../game_registry.dart';
import '../game_state.dart';
import '../widgets/anomaly_background.dart';

/// The game loop controller screen for Minesweeper.
///
/// Runs the infinite Minesweeper world.
/// On game failure → returns directly to the main menu.
class RunScreen extends StatefulWidget {
  final GameStateManager gameState;

  const RunScreen({super.key, required this.gameState});

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen>
    with SingleTickerProviderStateMixin {
  GameStateManager get _gs => widget.gameState;
  bool _isTransitioning = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _gs.startRun(notify: false);
    _gs.addListener(_onGameStateChanged);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _gs.removeListener(_onGameStateChanged);
    _fadeController.dispose();
    super.dispose();
  }

  void _onGameStateChanged() {
    if (!_gs.isRunActive && mounted && !_isTransitioning) {
      setState(() {
        _isTransitioning = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _gs,
      builder: (context, _) {
        final stageNum = _gs.currentStageNumber;
        final game = GameRegistry.getStage(stageNum);

        return AnomalyBackgroundWidget(
          key: ValueKey('run_anomaly_bg_${_gs.currentStageIndex}'),
          isEnabled: _gs.isCurrentGameAnomaly,
          child: Scaffold(
            backgroundColor: AppColors.transparent,
            body: Stack(
              children: [
                if (_gs.isCurrentGameAnomaly)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 140,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                SafeArea(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: KeyedSubtree(
                      key: ValueKey(_gs.currentStageIndex),
                      child: Center(
                        child: game.buildGame(
                          context: context,
                          onComplete: _onGameComplete,
                          onFail: _onGameFail,
                          gameState: _gs,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onGameComplete() {
    if (!mounted || _isTransitioning) return;

    setState(() {
      _isTransitioning = true;
    });

    _gs.completeCurrentGame();

    _fadeController.forward().then((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  void _onGameFail() {
    if (!mounted || _isTransitioning) return;
    setState(() {
      _isTransitioning = true;
    });
    _gs.failGame();
    if (mounted) {
      // Return directly to the main menu
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}
