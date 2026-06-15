import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/error_message.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../data/supabase_budget_repository.dart';
import '../../domain/budget.dart';

/// Dialog per creare un nuovo budget. Ritorna il [Budget] creato (o `null` se
/// annullato). Segue lo stesso pattern di `NewCategoryDialog`.
class CreateBudgetDialog extends ConsumerStatefulWidget {
  const CreateBudgetDialog({super.key});

  @override
  ConsumerState<CreateBudgetDialog> createState() => _CreateBudgetDialogState();
}

class _CreateBudgetDialogState extends ConsumerState<CreateBudgetDialog> {
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
      final budget =
          await ref.read(budgetRepositoryProvider).createBudget(_nameController.text.trim());
      ref.invalidate(userBudgetsProvider);
      if (mounted) Navigator.of(context).pop(budget);
    } catch (error) {
      setState(() {
        _isSaving = false;
        _errorMessage = errorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuovo budget'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Crea un budget e ottieni un codice da condividere.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome budget'),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
              onFieldSubmitted: (_) => _save(),
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
        LoadingButton(
          loading: _isSaving,
          onPressed: _save,
          spinnerSize: 16,
          child: const Text('Crea'),
        ),
      ],
    );
  }
}

/// Dialog per unirsi a un budget esistente tramite codice invito. Ritorna il
/// [Budget] (o `null` se annullato).
class JoinBudgetDialog extends ConsumerStatefulWidget {
  const JoinBudgetDialog({super.key});

  @override
  ConsumerState<JoinBudgetDialog> createState() => _JoinBudgetDialogState();
}

class _JoinBudgetDialogState extends ConsumerState<JoinBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final budget =
          await ref.read(budgetRepositoryProvider).joinBudget(_codeController.text.trim());
      ref.invalidate(userBudgetsProvider);
      if (mounted) Navigator.of(context).pop(budget);
    } catch (error) {
      setState(() {
        _isSaving = false;
        _errorMessage = errorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Unisciti con codice'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inserisci il codice invito di un budget esistente.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Codice invito'),
              autofocus: true,
              onFieldSubmitted: (_) => _save(),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Inserisci un codice' : null,
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
        LoadingButton(
          loading: _isSaving,
          onPressed: _save,
          spinnerSize: 16,
          child: const Text('Unisciti'),
        ),
      ],
    );
  }
}
