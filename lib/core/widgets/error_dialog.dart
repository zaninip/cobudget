import 'package:flutter/material.dart';

/// Mostra un popup di errore con un unico pulsante di chiusura.
Future<void> showErrorDialog(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
      title: const Text('Errore'),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
