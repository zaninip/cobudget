import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/formatters.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../budget/data/supabase_budget_repository.dart';
import '../../data/supabase_expense_repository.dart';
import '../../domain/category.dart';
import '../utils/category_visuals.dart';
import '../widgets/expense_detail_dialog.dart';

/// Spese del budget selezionato e accesso al form di inserimento manuale
/// (vedi UI_DESIGN.md - sezione 3).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.budgetId});

  final String budgetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(budgetByIdProvider(budgetId));
    final expensesAsync = ref.watch(recentExpensesProvider(budgetId));
    final categoriesAsync = ref.watch(expenseCategoriesProvider(budgetId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'I tuoi budget',
          onPressed: () => context.go('/'),
        ),
        title: Text(
          budget.when(
            data: (value) => value.name,
            loading: () => 'coBudget',
            error: (_, _) => 'coBudget',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Impostazioni budget',
            onPressed: () => context.push('/budget/$budgetId/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: expensesAsync.when(
        data: (expenses) {
          if (expenses.isEmpty) {
            return const Center(child: Text('Nessuna spesa registrata'));
          }

          final categories = categoriesAsync.value ?? [];

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final expense = expenses[index];

              ExpenseCategory? category;
              for (final c in categories) {
                if (c.id == expense.categoryId) {
                  category = c;
                  break;
                }
              }

              return ListTile(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => ExpenseDetailDialog(expense: expense, category: category),
                ),
                leading: CircleAvatar(
                  backgroundColor: category != null
                      ? categoryColor(category.color).withValues(alpha: 0.15)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(
                    category != null ? categoryIcon(category.icon) : Icons.category,
                    color: category != null ? categoryColor(category.color) : null,
                  ),
                ),
                title: Text(expense.title),
                subtitle: Text(formatDate(expense.date)),
                trailing: Text('€ ${expense.amount.toStringAsFixed(2)}'),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Errore nel caricamento delle spese: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/budget/$budgetId/expenses/new'),
        tooltip: 'Nuova spesa',
        child: const Icon(Icons.add),
      ),
    );
  }
}
