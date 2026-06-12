import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/supabase_expense_repository.dart';
import '../utils/category_visuals.dart';

/// Dialog per la creazione di una nuova categoria (nome, icona, colore),
/// vedi ARCHITECTURE.md - flow 4.
class NewCategoryDialog extends ConsumerStatefulWidget {
  const NewCategoryDialog({super.key, required this.budgetId});

  final String budgetId;

  @override
  ConsumerState<NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends ConsumerState<NewCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String _selectedIcon = availableCategoryIcons.first;
  String _selectedColor = availableCategoryColors.first;
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
      final category = await ref.read(expenseRepositoryProvider).createCategory(
            budgetId: widget.budgetId,
            name: _nameController.text.trim(),
            icon: _selectedIcon,
            color: _selectedColor,
          );
      final _ = await ref.refresh(expenseCategoriesProvider(widget.budgetId).future);
      if (mounted) Navigator.of(context).pop(category);
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
      title: const Text('Nuova categoria'),
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
