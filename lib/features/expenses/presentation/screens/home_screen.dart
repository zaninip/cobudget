import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/app_bar_icon_button.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../budget/data/supabase_budget_repository.dart';
import '../../data/supabase_expense_repository.dart';
import '../../domain/category.dart';
import '../../domain/expense.dart';
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
        leading: AppBarIconButton(
          icon: Icons.arrow_back,
          tooltip: 'I tuoi budget',
          onPressed: () => context.go('/'),
        ),
        leadingWidth: 56,
        title: Text(
          budget.when(
            data: (value) => value.name,
            loading: () => 'coBudget',
            error: (_, _) => 'coBudget',
          ),
        ),
        actions: [
          AppBarIconButton(
            icon: Icons.settings_outlined,
            tooltip: 'Impostazioni budget',
            onPressed: () => context.push('/budget/$budgetId/settings'),
          ),
          AppBarIconButton(
            icon: Icons.logout,
            tooltip: 'Logout',
            color: Theme.of(context).colorScheme.error,
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: expensesAsync.when(
        data: (expenses) {
          final categories = categoriesAsync.value ?? const [];
          final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _TotalCard(total: total, count: expenses.length),
              const SizedBox(height: 24),
              Text('Ultime spese', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (expenses.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Nessuna spesa registrata',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              else
                for (final expense in expenses) ...[
                  _ExpenseTile(
                    expense: expense,
                    category: _categoryFor(categories, expense.categoryId),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Errore nel caricamento delle spese: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/budget/$budgetId/expenses/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nuova spesa'),
      ),
    );
  }

  ExpenseCategory? _categoryFor(List<ExpenseCategory> categories, String categoryId) {
    for (final c in categories) {
      if (c.id == categoryId) return c;
    }
    return null;
  }
}

/// Card di riepilogo con il totale delle spese in evidenza (Space Grotesk).
class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total, required this.count});

  final double total;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.primaryContainer],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Totale spese',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onPrimary.withValues(alpha: 0.85),
                ),
          ),
          const SizedBox(height: 8),
          AmountText(total, fontSize: 40, color: scheme.onPrimary),
          const SizedBox(height: 4),
          Text(
            count == 1 ? '1 spesa registrata' : '$count spese registrate',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onPrimary.withValues(alpha: 0.85),
                ),
          ),
        ],
      ),
    );
  }
}

/// Voce della lista spese: icona categoria, titolo, data e importo.
class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense, required this.category});

  final Expense expense;
  final ExpenseCategory? category;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = category != null ? categoryColor(category!.color) : scheme.primary;

    return Card(
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => ExpenseDetailDialog(expense: expense, category: category),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  category != null ? categoryIcon(category!.icon) : Icons.category_outlined,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category != null ? '${category!.name} · ${formatDate(expense.date)}' : formatDate(expense.date),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AmountText(expense.amount, fontSize: 16),
            ],
          ),
        ),
      ),
    );
  }
}
