import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../domain/category.dart';
import '../../domain/expense.dart';
import '../utils/category_visuals.dart';
import 'delete_expense_dialog.dart';
import 'edit_expense_dialog.dart';

/// Dettaglio di una spesa, con accesso a modifica ed eliminazione.
class ExpenseDetailDialog extends StatelessWidget {
  const ExpenseDetailDialog({super.key, required this.expense, required this.category});

  final Expense expense;
  final ExpenseCategory? category;

  Future<void> _edit(BuildContext context) async {
    // Cattura il Navigator prima del pop: dopo, `context` non è più nell'albero,
    // mentre `navigator.context` resta valido per aprire il dialog successivo.
    final navigator = Navigator.of(context);
    navigator.pop();
    await showDialog<void>(
      context: navigator.context,
      builder: (_) => EditExpenseDialog(expense: expense),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final navigator = Navigator.of(context);
    navigator.pop();
    await showDialog<void>(
      context: navigator.context,
      builder: (_) => DeleteExpenseDialog(expense: expense),
    );
  }

  @override
  Widget build(BuildContext context) {
    Subcategory? subcategory;
    if (category != null && expense.subcategoryId != null) {
      for (final sub in category!.subcategories) {
        if (sub.id == expense.subcategoryId) {
          subcategory = sub;
          break;
        }
      }
    }

    return AlertDialog(
      title: Text(expense.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                category != null ? categoryIcon(category!.icon) : Icons.category,
                color: category != null ? categoryColor(category!.color) : null,
              ),
              const SizedBox(width: 8),
              Text(
                subcategory != null
                    ? '${category?.name} · ${subcategory.name}'
                    : category?.name ?? 'Senza categoria',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Data: ${formatDate(expense.date)}'),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Importo: ',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              AmountText(expense.amount, fontSize: 20, color: Theme.of(context).colorScheme.primary),
            ],
          ),
          if (expense.spreadGroupId != null) ...[
            const SizedBox(height: 12),
            Text(
              'Spesa spalmata su più mesi',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _delete(context),
          icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
          label: Text('Elimina', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
        FilledButton.icon(
          onPressed: () => _edit(context),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Modifica'),
        ),
      ],
    );
  }
}
