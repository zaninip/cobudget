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
import '../../domain/tag.dart';
import '../utils/category_visuals.dart';
import '../utils/expense_summary.dart';
import '../widgets/expense_detail_dialog.dart';
import '../widgets/expense_filters_card.dart';

/// Spese del budget selezionato e accesso al form di inserimento manuale
/// (vedi UI_DESIGN.md - sezione 3).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.budgetId});

  final String budgetId;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Stato dei filtri: stesso modello della pagina grafici, senza il periodo
  // (le box mostrano sempre il mese corrente, la lista sempre tutto lo storico).
  final Set<String> _categoryIds = {};
  final Set<String> _subcategoryIds = {};
  final Set<String> _tagIds = {};
  bool _excludeExceptional = false;

  @override
  Widget build(BuildContext context) {
    final budgetId = widget.budgetId;
    final budget = ref.watch(budgetByIdProvider(budgetId));
    final expensesAsync = ref.watch(recentExpensesProvider(budgetId));
    final categoriesAsync = ref.watch(expenseCategoriesProvider(budgetId));
    final tagsAsync = ref.watch(tagsProvider(budgetId));

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
          final categories = categoriesAsync.value ?? const <ExpenseCategory>[];
          final tags = tagsAsync.value ?? const <Tag>[];

          // Filtri (categorie/sottocategorie/tag/straordinarie) applicati su tutto
          // lo storico: la lista mostra l'elenco filtrato per intero, mentre le box
          // ripartono dallo stesso elenco ma limitato al mese corrente.
          final filtered = filterExpenses(
            expenses,
            period: SummaryPeriod.all,
            categoryIds: _categoryIds,
            subcategoryIds: _subcategoryIds,
            tagIds: _tagIds,
            excludeExceptional: _excludeExceptional,
          );

          final now = DateTime.now();
          bool isCurrentMonth(DateTime d) => d.year == now.year && d.month == now.month;

          var monthExpenses = 0.0;
          var monthIncome = 0.0;
          for (final e in filtered) {
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
              _buildFilters(categories, tags),
              const SizedBox(height: 16),
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
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    expenses.isEmpty
                        ? 'Nessun movimento registrato'
                        : 'Nessun movimento per i filtri selezionati',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              else
                for (final expense in filtered) ...[
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
        onPressed: () => _showAddOptions(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuova spesa'),
      ),
    );
  }

  /// Barra filtri (stesso aspetto della pagina grafici, senza il periodo).
  Widget _buildFilters(List<ExpenseCategory> categories, List<Tag> tags) {
    void toggleCategory(String id) {
      setState(() {
        if (!_categoryIds.remove(id)) _categoryIds.add(id);
        // Rimuove le sottocategorie non più coerenti con le categorie scelte.
        final validSubIds = <String>{
          for (final c in categories)
            if (_categoryIds.contains(c.id))
              for (final s in c.subcategories) s.id,
        };
        _subcategoryIds.removeWhere((id) => !validSubIds.contains(id));
      });
    }

    void toggleSubcategory(String id) {
      setState(() {
        if (!_subcategoryIds.remove(id)) _subcategoryIds.add(id);
      });
    }

    void toggleTag(String id) {
      setState(() {
        if (!_tagIds.remove(id)) _tagIds.add(id);
      });
    }

    return ExpenseFiltersCard(
      categories: categories,
      tags: tags,
      categoryIds: _categoryIds,
      subcategoryIds: _subcategoryIds,
      tagIds: _tagIds,
      onToggleCategory: toggleCategory,
      onToggleSubcategory: toggleSubcategory,
      onToggleTag: toggleTag,
      excludeExceptional: _excludeExceptional,
      onExcludeExceptionalChanged: (v) => setState(() => _excludeExceptional = v),
    );
  }

  /// Mostra le due modalità di inserimento (vedi UI_DESIGN.md - sezione 4).
  Future<void> _showAddOptions(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                child: const Icon(Icons.edit_outlined),
              ),
              title: const Text('Inserire spesa manuale'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('/budget/${widget.budgetId}/expenses/new');
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.secondaryContainer,
                foregroundColor: scheme.onSecondaryContainer,
                child: const Icon(Icons.document_scanner_outlined),
              ),
              title: const Text('Inserire da screenshot'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('/budget/${widget.budgetId}/import');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
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
