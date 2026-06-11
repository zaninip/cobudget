import 'package:flutter/material.dart';

const _monthAbbreviations = [
  'gen', 'feb', 'mar', 'apr', 'mag', 'giu',
  'lug', 'ago', 'set', 'ott', 'nov', 'dic',
];

/// Formatta un mese come "mag 2026" (in italiano, senza dipendere da `intl`
/// e dalla relativa inizializzazione delle locale).
String formatMonthYear(DateTime date) => '${_monthAbbreviations[date.month - 1]} ${date.year}';

/// Selettore di un mese/anno (vedi UI_DESIGN.md - sezione 5, "spalma su più mesi").
class MonthSelector extends StatelessWidget {
  const MonthSelector({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(now.year - 1, now.month);
    final months = List.generate(36, (i) => DateTime(start.year, start.month + i));

    final normalizedValue = DateTime(value.year, value.month);
    if (!months.contains(normalizedValue)) {
      months
        ..add(normalizedValue)
        ..sort();
    }

    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DateTime>(
          value: normalizedValue,
          isExpanded: true,
          items: [
            for (final month in months)
              DropdownMenuItem(value: month, child: Text(formatMonthYear(month))),
          ],
          onChanged: (month) {
            if (month != null) onChanged(month);
          },
        ),
      ),
    );
  }
}
