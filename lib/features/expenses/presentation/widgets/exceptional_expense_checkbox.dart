import 'package:flutter/material.dart';

/// Checkbox "Spesa straordinaria" usata nei form di inserimento, modifica e
/// review da screenshot. Marca la voce come eccezionale/fuori budget, così da
/// poterla escludere dai grafici e dalla lista con il filtro dedicato.
class ExceptionalExpenseCheckbox extends StatelessWidget {
  const ExceptionalExpenseCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      title: const Text('Spesa straordinaria'),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
    );
  }
}
