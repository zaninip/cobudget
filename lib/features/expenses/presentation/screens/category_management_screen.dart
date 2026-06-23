import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/supabase_expense_repository.dart';
import '../../domain/category.dart';
import '../utils/category_visuals.dart';
import '../widgets/new_category_dialog.dart';

/// Schermata "Gestione categorie": elenca le categorie disponibili nel budget
/// (predefinite + create dall'utente) e permette di modificarne icona, nome e
/// colore o di crearne di nuove. Modificare una predefinita ne crea una copia
/// legata al budget senza intaccare le spese già salvate (vedi 0012_edit_category.sql).
class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key, required this.budgetId});

  final String budgetId;

  Future<void> _edit(BuildContext context, ExpenseCategory category) {
    return showDialog(
      context: context,
      builder: (_) => NewCategoryDialog(budgetId: budgetId, category: category),
    );
  }

  Future<void> _create(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => NewCategoryDialog(budgetId: budgetId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(expenseCategoriesProvider(budgetId));

    return Scaffold(
      appBar: AppBar(title: const Text('Gestione categorie')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuova'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: categoriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Errore nel caricamento delle categorie: $error')),
              data: (categories) => ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return _CategoryTile(
                    category: category,
                    onTap: () => _edit(context, category),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});

  final ExpenseCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(category.color);
    final subtitle = category.isGlobal
        ? 'Predefinita'
        : (category.subcategories.isEmpty
            ? 'Personalizzata'
            : '${category.subcategories.length} sottocategorie');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.18),
          child: Icon(categoryIcon(category.icon), color: color),
        ),
        title: Text(category.name),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.edit_outlined),
      ),
    );
  }
}
