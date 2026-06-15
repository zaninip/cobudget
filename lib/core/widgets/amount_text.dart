import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/formatters.dart';

/// Importo in euro reso con Space Grotesk e cifre tabulari, per un look moderno
/// e numeri allineati (vedi UI_DESIGN.md - componente `AmountText`).
class AmountText extends StatelessWidget {
  const AmountText(
    this.amount, {
    super.key,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w700,
    this.color,
  });

  final double amount;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      formatCurrency(amount),
      style: GoogleFonts.spaceGrotesk(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? Theme.of(context).colorScheme.onSurface,
        fontFeatures: const [FontFeature.tabularFigures()],
        height: 1.1,
      ),
    );
  }
}
