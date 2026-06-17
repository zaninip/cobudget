import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../../categorization/data/supabase_category_learning_repository.dart';
import '../../../categorization/presentation/learning_feedback.dart';
import '../../data/supabase_expense_repository.dart';
import '../../domain/expense.dart';
import 'category_selector.dart';

/// Dialog per modificare titolo e importo di una spesa esistente.
class EditExpenseDialog extends ConsumerStatefulWidget {
  const EditExpenseDialog({super.key, required this.expense});

  final Expense expense;

  @override
  ConsumerState<EditExpenseDialog> createState() => _EditExpenseDialogState();
}

class _EditExpenseDialogState extends ConsumerState<EditExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(text: widget.expense.title);
  late final _amountController = TextEditingController(
    text: widget.expense.amount.toStringAsFixed(2),
  );

  late String? _categoryId = widget.expense.categoryId;
  late String? _subcategoryId = widget.expense.subcategoryId;
  late DateTime _date = widget.expense.date;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.expense.spreadGroupId != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Spesa spalmata'),
          content: const Text(
            'Questa spesa è spalmata su più mesi, sei sicuro di voler applicare le modifiche?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Conferma'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final title = _titleController.text.trim();
      await ref.read(expenseRepositoryProvider).updateExpense(
            id: widget.expense.id,
            title: title,
            amount: parseAmount(_amountController.text)!,
            date: _date,
            categoryId: _categoryId!,
            subcategoryId: _subcategoryId,
          );
      // Alimenta la memoria di categorizzazione con la scelta dell'utente. Best-effort.
      var learningOk = true;
      try {
        await ref.read(categoryLearningRepositoryProvider).recordChoices(
          budgetId: widget.expense.budgetId,
          entries: [
            (title: title, categoryId: _categoryId!, subcategoryId: _subcategoryId),
          ],
        );
      } catch (_) {
        learningOk = false;
      }
      ref.invalidate(recentExpensesProvider(widget.expense.budgetId));
      if (mounted) {
        if (!learningOk) showLearningWarning(context);
        Navigator.of(context).pop();
      }
    } catch (_) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'Si è verificato un errore. Riprova.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(expenseCategoriesProvider(widget.expense.budgetId));

    return AlertDialog(
      title: const Text('Modifica spesa'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Titolo'),
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Inserisci un titolo' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Importo', prefixText: '€ '),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  final amount = parseAmount(value ?? '');
                  if (amount == null || amount <= 0) return 'Inserisci un importo valido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Data'),
                  child: Text(formatDate(_date)),
                ),
              ),
              const SizedBox(height: 16),
              categoriesAsync.when(
                data: (categories) => CategorySelector(
                  budgetId: widget.expense.budgetId,
                  categories: categories,
                  categoryId: _categoryId,
                  subcategoryId: _subcategoryId,
                  onCategoryChanged: (value) => setState(() {
                    _categoryId = value;
                    _subcategoryId = null;
                  }),
                  onSubcategoryChanged: (value) => setState(() => _subcategoryId = value),
                ),
                loading: () => const Center(child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                )),
                error: (error, _) => Text('Errore nel caricamento delle categorie: $error'),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        LoadingButton(
          loading: _isSaving,
          onPressed: _save,
          spinnerSize: 16,
          child: const Text('Salva'),
        ),
      ],
    );
  }
}
