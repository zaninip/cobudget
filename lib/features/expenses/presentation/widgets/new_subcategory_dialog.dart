import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/supabase_expense_repository.dart';

/// Dialog per la creazione di una nuova sottocategoria sotto [categoryId],
/// vedi ARCHITECTURE.md - flow 4.
class NewSubcategoryDialog extends ConsumerStatefulWidget {
  const NewSubcategoryDialog({super.key, required this.budgetId, required this.categoryId});

  final String budgetId;
  final String categoryId;

  @override
  ConsumerState<NewSubcategoryDialog> createState() => _NewSubcategoryDialogState();
}

class _NewSubcategoryDialogState extends ConsumerState<NewSubcategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final subcategory = await ref.read(expenseRepositoryProvider).createSubcategory(
            categoryId: widget.categoryId,
            name: _nameController.text.trim(),
          );
      final _ = await ref.refresh(expenseCategoriesProvider(widget.budgetId).future);
      if (mounted) Navigator.of(context).pop(subcategory);
    } catch (_) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'Si è verificato un errore. Riprova.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuova sottocategoria'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Inserisci un nome' : null,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Crea'),
        ),
      ],
    );
  }
}
