import 'package:flutter/material.dart';

/// [FilledButton] che mostra uno spinner al posto del contenuto mentre
/// [loading] è `true` (e nel frattempo si disabilita).
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    super.key,
    required this.loading,
    required this.onPressed,
    required this.child,
    this.style,
    this.spinnerSize = 20,
    this.spinnerColor,
  });

  final bool loading;
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final double spinnerSize;
  final Color? spinnerColor;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: style,
      child: loading
          ? SizedBox(
              height: spinnerSize,
              width: spinnerSize,
              child: CircularProgressIndicator(strokeWidth: 2, color: spinnerColor),
            )
          : child,
    );
  }
}
