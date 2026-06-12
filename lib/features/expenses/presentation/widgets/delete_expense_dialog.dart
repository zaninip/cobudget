import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/supabase_expense_repository.dart';
import '../../domain/expense.dart';

/// Dialog di conferma eliminazione di una spesa. Se la spesa è spalmata su
/// più mesi, offre la scelta tra eliminare solo questa rata o tutte quelle
/// collegate.
class DeleteExpenseDialog extends ConsumerStatefulWidget {
  const DeleteExpenseDialog({super.key, required this.expense});

  final Expense expense;

  @override
  ConsumerState<DeleteExpenseDialog> createState() => _DeleteExpenseDialogState();
}

class _DeleteExpenseDialogState extends ConsumerState<DeleteExpenseDialog> {
  bool _isDeleting = false;
  String? _errorMessage;

  Future<void> _delete({required bool wholeGroup}) async {
    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(expenseRepositoryProvider);
      if (wholeGroup) {
        await repository.deleteSpreadGroup(widget.expense.spreadGroupId!);
      } else {
        await repository.deleteExpense(widget.expense.id);
      }
      ref.invalidate(recentExpensesProvider(widget.expense.budgetId));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() {
        _isDeleting = false;
        _errorMessage = 'Si è verificato un errore. Riprova.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSpread = widget.expense.spreadGroupId != null;

    return AlertDialog(
      title: Text(isSpread ? 'Spesa spalmata' : 'Eliminare la spesa?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isSpread
                ? 'Questa è una spesa spalmata su più mesi. Cosa vuoi eliminare?'
                : 'Vuoi eliminare "${widget.expense.title}"?',
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        if (isSpread)
          TextButton(
            onPressed: _isDeleting ? null : () => _delete(wholeGroup: true),
            child: Text(
              'Elimina tutte le spese collegate',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        FilledButton(
          onPressed: _isDeleting ? null : () => _delete(wholeGroup: false),
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          child: _isDeleting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(isSpread ? 'Elimina solo questa' : 'Elimina'),
        ),
      ],
    );
  }
}
