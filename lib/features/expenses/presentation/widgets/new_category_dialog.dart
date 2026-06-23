import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/loading_button.dart';
import '../../data/supabase_expense_repository.dart';
import '../../domain/category.dart';
import '../utils/category_visuals.dart';

/// Dialog per creare una nuova categoria oppure modificarne una esistente
/// (nome, icona, colore), vedi ARCHITECTURE.md - flow 4.
///
/// Se [category] è valorizzata il dialog è in modalità modifica: i campi sono
/// precompilati e al salvataggio viene aggiornata (le predefinite vengono "forkate"
/// in una copia legata al budget, senza perdere le spese collegate).
class NewCategoryDialog extends ConsumerStatefulWidget {
  const NewCategoryDialog({super.key, required this.budgetId, this.category});

  final String budgetId;
  final ExpenseCategory? category;

  @override
  ConsumerState<NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends ConsumerState<NewCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController =
      TextEditingController(text: widget.category?.name ?? '');

  late String _selectedIcon = widget.category?.icon ?? availableCategoryIcons.first;
  late String _selectedColor = widget.category?.color ?? availableCategoryColors.first;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.category != null;

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
      final repository = ref.read(expenseRepositoryProvider);
      Object? result;
      if (_isEditing) {
        await repository.updateCategory(
          budgetId: widget.budgetId,
          category: widget.category!,
          name: _nameController.text.trim(),
          icon: _selectedIcon,
          color: _selectedColor,
        );
        // Il fork di una predefinita ri-aggancia le spese del budget alla copia:
        // ricarichiamo anche le spese perché la categoria mostrata può cambiare.
        ref.invalidate(recentExpensesProvider(widget.budgetId));
      } else {
        result = await repository.createCategory(
          budgetId: widget.budgetId,
          name: _nameController.text.trim(),
          icon: _selectedIcon,
          color: _selectedColor,
        );
      }
      // refresh (e non invalidate) per attendere il ricaricamento: così la
      // categoria aggiornata è già nella lista quando lo schermo chiamante la usa.
      final _ = await ref.refresh(expenseCategoriesProvider(widget.budgetId).future);
      if (mounted) Navigator.of(context).pop(result);
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
      title: Text(_isEditing ? 'Modifica categoria' : 'Nuova categoria'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
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
              const SizedBox(height: 16),
              Text('Icona', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final icon in availableCategoryIcons)
                    _IconChoice(
                      icon: icon,
                      selected: icon == _selectedIcon,
                      color: categoryColor(_selectedColor),
                      onTap: () => setState(() => _selectedIcon = icon),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Colore', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final color in availableCategoryColors)
                    _ColorChoice(
                      color: color,
                      selected: color == _selectedColor,
                      onTap: () => setState(() => _selectedColor = color),
                    ),
                ],
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
          child: Text(_isEditing ? 'Salva' : 'Crea'),
        ),
      ],
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: CircleAvatar(
        radius: 22,
        backgroundColor:
            selected ? color.withValues(alpha: 0.2) : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(categoryIcon(icon), color: selected ? color : Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({required this.color, required this.selected, required this.onTap});

  final String color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final swatchColor = categoryColor(color);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: swatchColor,
          shape: BoxShape.circle,
          border: selected ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3) : null,
        ),
        child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
      ),
    );
  }
}
