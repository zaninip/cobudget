import 'package:flutter/material.dart';

/// Pulsante icona per l'AppBar con superficie tonale arrotondata (look "pill"),
/// usato nelle barre superiori dell'app.
class AppBarIconButton extends StatelessWidget {
  const AppBarIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: IconButton(
        icon: Icon(icon, color: tint),
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: (color ?? scheme.primary).withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
