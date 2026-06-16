import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
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
            icon: Icons.insights_outlined,
            tooltip: 'Riepilogo',
            onPressed: () => context.push('/budget/$budgetId/summary'),
          ),
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
          final now = DateTime.now();
          bool isCurrentMonth(DateTime d) => d.year == now.year && d.month == now.month;

          var monthExpenses = 0.0;
          var monthIncome = 0.0;
          for (final e in expenses) {
            if (!isCurrentMonth(e.date)) continue;
            if (e.isIncome) {
              monthIncome += e.amount;
            } else {
              monthExpenses += e.amount;
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Uscite mese corrente',
                        amount: monthExpenses,
                        accent: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Entrate mese corrente',
                        amount: monthIncome,
                        accent: context.appColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Ultimi movimenti', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (expenses.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Nessun movimento registrato',
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'import',
            onPressed: () => context.push('/budget/$budgetId/import'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Theme.of(context).colorScheme.onSecondary,
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Da screenshot'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'manual',
            onPressed: () => context.push('/budget/$budgetId/expenses/new'),
            icon: const Icon(Icons.add),
            label: const Text('Nuova spesa'),
          ),
        ],
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

/// Card di riepilogo (uscite/entrate del mese) con importo in evidenza.
/// Il colore del testo si adatta alla luminosità dell'accento per restare
/// leggibile sia in tema chiaro che scuro.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.amount, required this.accent});

  final String label;
  final double amount;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final onAccent =
        accent.computeLuminance() > 0.5 ? const Color(0xFF1A1A1A) : Colors.white;
    final accentEnd = Color.lerp(accent, Colors.black, 0.22)!;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, accentEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: onAccent.withValues(alpha: 0.9),
                ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AmountText(amount, fontSize: 26, color: onAccent),
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
              AmountText(
                expense.amount,
                fontSize: 16,
                fontWeight: expense.isIncome ? FontWeight.w800 : FontWeight.w700,
                color: expense.isIncome ? context.appColors.success : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
