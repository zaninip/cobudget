import 'package:flutter/material.dart';

import '../../domain/category.dart';
import '../utils/category_visuals.dart';
import 'new_category_dialog.dart';
import 'new_subcategory_dialog.dart';

/// Valori "sentinella" usati come ultima voce dei dropdown per aprire i dialog
/// di creazione di una nuova categoria/sottocategoria.
const _newCategoryValue = '__new_category__';
const _newSubcategoryValue = '__new_subcategory__';

/// Selettore di categoria + sottocategoria, con l'opzione "Nuova …" come ultima
/// voce di ciascun menu a tendina (vedi UI_DESIGN.md - sezione 5).
///
/// È un [FormField] solo per la categoria (obbligatoria): va usato dentro un
/// [Form] perché la validazione partecipi al `validate()` del form chiamante.
/// Lo stato selezionato è controllato dal chiamante tramite [categoryId]/
/// [subcategoryId] e i callback; [onCategoryChanged] dovrebbe azzerare la
/// sottocategoria a monte.
class CategorySelector extends StatefulWidget {
  const CategorySelector({
    super.key,
    required this.budgetId,
    required this.categories,
    required this.categoryId,
    required this.subcategoryId,
    required this.onCategoryChanged,
    required this.onSubcategoryChanged,
  });

  final String budgetId;
  final List<ExpenseCategory> categories;
  final String? categoryId;
  final String? subcategoryId;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onSubcategoryChanged;

  @override
  State<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<CategorySelector> {
  // Incrementato dopo ogni apertura di un dialog "Nuova …" per forzare la
  // ricostruzione dei DropdownButtonFormField: senza questo il loro stato
  // interno resterebbe sul valore sentinella anche dopo annulla/conferma.
  int _resetTick = 0;

  Future<void> _addCategory() async {
    final category = await showDialog<ExpenseCategory>(
      context: context,
      builder: (_) => NewCategoryDialog(budgetId: widget.budgetId),
    );
    setState(() => _resetTick++);
    if (category != null) widget.onCategoryChanged(category.id);
  }

  Future<void> _addSubcategory(String categoryId) async {
    final subcategory = await showDialog<Subcategory>(
      context: context,
      builder: (_) => NewSubcategoryDialog(budgetId: widget.budgetId, categoryId: categoryId),
    );
    setState(() => _resetTick++);
    if (subcategory != null) widget.onSubcategoryChanged(subcategory.id);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    ExpenseCategory? selectedCategory;
    for (final category in widget.categories) {
      if (category.id == widget.categoryId) {
        selectedCategory = category;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('category-$_resetTick'),
          initialValue: widget.categoryId,
          decoration: const InputDecoration(labelText: 'Categoria'),
          items: [
            for (final category in widget.categories)
              DropdownMenuItem(
                value: category.id,
                child: Row(
                  children: [
                    Icon(categoryIcon(category.icon), color: categoryColor(category.color), size: 20),
                    const SizedBox(width: 8),
                    Text(category.name),
                  ],
                ),
              ),
            DropdownMenuItem(
              value: _newCategoryValue,
              child: Row(
                children: [
                  Icon(Icons.add, size: 20, color: primary),
                  const SizedBox(width: 8),
                  Text('Nuova categoria…', style: TextStyle(color: primary)),
                ],
              ),
            ),
          ],
          onChanged: (value) {
            if (value == _newCategoryValue) {
              _addCategory();
            } else {
              widget.onCategoryChanged(value);
            }
          },
          validator: (value) =>
              (value == null || value == _newCategoryValue) ? 'Seleziona una categoria' : null,
        ),
        if (selectedCategory != null) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            key: ValueKey('subcategory-${widget.categoryId}-$_resetTick'),
            initialValue: widget.subcategoryId,
            decoration: const InputDecoration(labelText: 'Sottocategoria'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Nessuna')),
              for (final subcategory in selectedCategory.subcategories)
                DropdownMenuItem(value: subcategory.id, child: Text(subcategory.name)),
              DropdownMenuItem<String?>(
                value: _newSubcategoryValue,
                child: Row(
                  children: [
                    Icon(Icons.add, size: 20, color: primary),
                    const SizedBox(width: 8),
                    Text('Nuova sottocategoria…', style: TextStyle(color: primary)),
                  ],
                ),
              ),
            ],
            onChanged: (value) {
              if (value == _newSubcategoryValue) {
                _addSubcategory(selectedCategory!.id);
              } else {
                widget.onSubcategoryChanged(value);
              }
            },
          ),
        ],
      ],
    );
  }
}
