import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';
import '../game_state.dart';
import '../utils/number_formatter.dart';

/// Shows a styled confirmation popup matching the app's glass-card aesthetic.
///
/// [title]          — bold header text (e.g. "Delete All Data?")
/// [icon]           — icon shown left of the title in the header strip
/// [iconColor]      — color of the header icon and confirm button accent
/// [body]           — explanatory message shown in the card body
/// [confirmLabel]   — label for the confirm / destructive action button
/// [cancelLabel]    — label for the cancel button (default "Cancel")
/// [onConfirm]      — callback invoked when the confirm button is pressed;
///                    the popup is already dismissed before the callback fires
void showConfirmPopup(
  BuildContext context, {
  required String title,
  required IconData icon,
  required Color iconColor,
  required String body,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  required VoidCallback onConfirm,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: AppColors.overlayBarrier,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, animation, _) => _ConfirmPopup(
      title: title,
      icon: icon,
      iconColor: iconColor,
      body: body,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      onConfirm: onConfirm,
    ),
    transitionBuilder: (ctx, animation, _, child) {
      final scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOut),
      );
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

/// Shows a styled information popup with a single bottom-centered OK button and no close (X) button.
void showOkPopup(
  BuildContext context, {
  required String title,
  required IconData icon,
  required Color iconColor,
  required String body,
  String okLabel = 'OK',
  VoidCallback? onOk,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: AppColors.overlayBarrier,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, animation, _) => _OkPopup(
      title: title,
      icon: icon,
      iconColor: iconColor,
      body: body,
      okLabel: okLabel,
      onOk: onOk,
    ),
    transitionBuilder: (ctx, animation, _, child) {
      final scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOut),
      );
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

/// Shows a styled popup dialog allowing developers to add a custom amount of tokens.
void showAddDevTokensPopup(
  BuildContext context, {
  required GameStateManager gameState,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Add Dev Tokens',
    barrierColor: AppColors.overlayBarrier,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, animation, _) => _AddDevTokensPopup(
      gameState: gameState,
    ),
    transitionBuilder: (ctx, animation, _, child) {
      final scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOut),
      );
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

class _ConfirmPopup extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final String body;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;

  const _ConfirmPopup({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 360,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.outlineMedium,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.overlayBarrier,
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header strip
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                  decoration: BoxDecoration(
                    color: Color.lerp(AppColors.surface, theme.colorScheme.surfaceContainerHighest, 0.45)!,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(17)),
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.outlineDim,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 16, color: iconColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textBright,
                      height: 1.5,
                    ),
                  ),
                ),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 32,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 0),
                            minimumSize: Size.zero,
                            backgroundColor: AppColors.surface,
                            side: BorderSide(
                              color: AppColors.outlineMedium,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            cancelLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textBright,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 32,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onConfirm();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 0),
                            minimumSize: Size.zero,
                            backgroundColor: Color.lerp(AppColors.surface, iconColor, 0.12)!,
                            side: BorderSide(
                              color: Color.lerp(AppColors.surface, iconColor, 0.5)!,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: Icon(icon, size: 14, color: iconColor),
                          label: Text(
                            confirmLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: iconColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OkPopup extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final String body;
  final String okLabel;
  final VoidCallback? onOk;

  const _OkPopup({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.body,
    required this.okLabel,
    this.onOk,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 360,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.outlineMedium,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.overlayBarrier,
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header strip without close (X) button
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: Color.lerp(AppColors.surface, theme.colorScheme.surfaceContainerHighest, 0.45)!,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(17)),
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.outlineDim,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 16, color: iconColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textBright,
                      height: 1.5,
                    ),
                  ),
                ),

                // Action button: single OK button in the bottom center
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 32,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onOk?.call();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 0),
                            minimumSize: Size.zero,
                            backgroundColor: Color.lerp(AppColors.surface, iconColor, 0.12)!,
                            side: BorderSide(
                              color: Color.lerp(AppColors.surface, iconColor, 0.5)!,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            okLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: iconColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddDevTokensPopup extends StatefulWidget {
  final GameStateManager gameState;

  const _AddDevTokensPopup({required this.gameState});

  @override
  State<_AddDevTokensPopup> createState() => _AddDevTokensPopupState();
}

class _AddDevTokensPopupState extends State<_AddDevTokensPopup> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  String? _errorMessage;

  static const List<int> _presetAmounts = [100, 500, 1000, 10000, 100000];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '100');
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    final amount = int.tryParse(text);
    if (amount == null || amount <= 0) {
      setState(() {
        _errorMessage = 'Please enter a positive integer.';
      });
      return;
    }

    widget.gameState.addDevTokens(amount);
    Navigator.of(context).pop();
  }

  void _setAmount(int amount) {
    setState(() {
      _controller.text = amount.toString();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
      _errorMessage = null;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = Colors.amber.shade400;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 380,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.outlineMedium,
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.overlayBarrier,
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header strip
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      AppColors.surface,
                      theme.colorScheme.surfaceContainerHighest,
                      0.45,
                    )!,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(17),
                    ),
                    border: const Border(
                      bottom: BorderSide(
                        color: AppColors.outlineDim,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.token_rounded, size: 16, color: iconColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Add Dev Tokens',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current balance indicator
                      Row(
                        children: [
                          const Text(
                            'Current Balance: ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMedium,
                            ),
                          ),
                          const Icon(
                            Icons.token,
                            size: 13,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formatWithCommas(widget.gameState.tokens),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Input Field
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.panelMedium,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _errorMessage != null
                                ? AppColors.error
                                : AppColors.outlineMedium,
                            width: 1.2,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.add_rounded,
                              size: 18,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                autofocus: true,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                                onChanged: (_) {
                                  if (_errorMessage != null) {
                                    setState(() {
                                      _errorMessage = null;
                                    });
                                  }
                                },
                                cursorColor: Colors.amber,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textBright,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Amount of tokens...',
                                  hintStyle: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 14,
                                    color: AppColors.textDim,
                                  ),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red.shade400,
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Preset Quick-Select Buttons
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final preset in _presetAmounts)
                            SizedBox(
                              height: 26,
                              child: OutlinedButton(
                                onPressed: () => _setAmount(preset),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 0,
                                  ),
                                  minimumSize: Size.zero,
                                  backgroundColor: AppColors.panelDim,
                                  side: const BorderSide(
                                    color: AppColors.outlineDim,
                                    width: 1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: Text(
                                  '+${formatWithCommas(preset)}',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber.shade300,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 32,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 0,
                            ),
                            minimumSize: Size.zero,
                            backgroundColor: AppColors.surface,
                            side: const BorderSide(
                              color: AppColors.outlineMedium,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textBright,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 32,
                        child: OutlinedButton.icon(
                          onPressed: _submit,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 0,
                            ),
                            minimumSize: Size.zero,
                            backgroundColor: Color.lerp(
                              AppColors.surface,
                              iconColor,
                              0.12,
                            )!,
                            side: BorderSide(
                              color: Color.lerp(
                                AppColors.surface,
                                iconColor,
                                0.5,
                              )!,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: Icon(Icons.add_rounded, size: 14, color: iconColor),
                          label: Text(
                            'Add Tokens',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: iconColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
