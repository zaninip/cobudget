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
import '../utils/expense_summary.dart';
import '../widgets/summary_pie_chart.dart';
import '../widgets/summary_trend_chart.dart';

/// Pagina di riepilogo del budget: totali e ripartizione per categoria
/// ("Riepilogo") e andamento nel tempo ("Andamento"). Tutte le aggregazioni
/// sono calcolate client-side da `recentExpensesProvider` (vedi expense_summary.dart).
class BudgetSummaryScreen extends ConsumerStatefulWidget {
  const BudgetSummaryScreen({super.key, required this.budgetId});

  final String budgetId;

  @override
  ConsumerState<BudgetSummaryScreen> createState() => _BudgetSummaryScreenState();
}

class _BudgetSummaryScreenState extends ConsumerState<BudgetSummaryScreen> {
  SummaryPeriod _period = SummaryPeriod.thisYear;
  DateTime? _customStart;
  DateTime? _customEnd;
  final Set<String> _categoryIds = {};
  final Set<String> _subcategoryIds = {};
  int _tabIndex = 0;

  // Stato scheda "Andamento". L'andamento è sempre su base mensile.
  bool _showOutcome = true;
  bool _showIncome = true;
  bool _showBalance = false;

  @override
  Widget build(BuildContext context) {
    final budget = ref.watch(budgetByIdProvider(widget.budgetId));
    final expensesAsync = ref.watch(recentExpensesProvider(widget.budgetId));
    final categoriesAsync = ref.watch(expenseCategoriesProvider(widget.budgetId));

    return Scaffold(
      appBar: AppBar(
        leading: AppBarIconButton(
          icon: Icons.arrow_back,
          tooltip: 'Indietro',
          onPressed: () => context.pop(),
        ),
        leadingWidth: 56,
        title: Text(
          budget.when(
            data: (value) => value.name,
            loading: () => 'Riepilogo',
            error: (_, _) => 'Riepilogo',
          ),
        ),
        actions: [
          AppBarIconButton(
            icon: Icons.settings_outlined,
            tooltip: 'Impostazioni budget',
            onPressed: () => context.push('/budget/${widget.budgetId}/settings'),
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
          final filtered = filterExpenses(
            expenses,
            period: _period,
            categoryIds: _categoryIds,
            subcategoryIds: _subcategoryIds,
            customStart: _customStart,
            customEnd: _customEnd,
          );
          final singleCategoryId = _categoryIds.length == 1 ? _categoryIds.first : null;

          return ListView(
            // Aggiunge l'inset di sistema in basso (barra di navigazione del
            // telefono) così l'ultima riga non resta coperta.
            padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + MediaQuery.paddingOf(context).bottom),
            children: [
              _buildFilters(context, categories),
              const SizedBox(height: 16),
              _TabPill(
                tabs: const ['Riepilogo', 'Andamento'],
                index: _tabIndex,
                onChanged: (i) => setState(() => _tabIndex = i),
              ),
              const SizedBox(height: 20),
              if (_tabIndex == 0)
                _SummaryTab(
                  expenses: filtered,
                  categories: categories,
                  singleCategoryId: singleCategoryId,
                )
              else
                _TrendTab(
                  expenses: filtered,
                  period: _period,
                  granularity: TrendGranularity.month,
                  customStart: _customStart,
                  customEnd: _customEnd,
                  showOutcome: _showOutcome,
                  showIncome: _showIncome,
                  showBalance: _showBalance,
                  onShowOutcomeChanged: (v) => setState(() => _showOutcome = v),
                  onShowIncomeChanged: (v) => setState(() => _showIncome = v),
                  onShowBalanceChanged: (v) => setState(() => _showBalance = v),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Errore nel caricamento dei dati: $error')),
      ),
    );
  }

  /// Barra filtri condivisa: periodo (con opzione personalizzata), categorie e
  /// sottocategorie (queste ultime limitate alle categorie selezionate).
  Widget _buildFilters(BuildContext context, List<ExpenseCategory> categories) {
    final subOptions = <Subcategory>[
      for (final c in categories)
        if (_categoryIds.contains(c.id)) ...c.subcategories,
    ];

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

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<SummaryPeriod>(
              initialValue: _period,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Periodo', isDense: true),
              items: [
                for (final p in SummaryPeriod.values)
                  DropdownMenuItem(value: p, child: Text(p.label)),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _period = value);
                }
              },
            ),
            if (_period == SummaryPeriod.custom) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Da',
                      value: _customStart,
                      onTap: () => _pickCustomDate(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateField(
                      label: 'A',
                      value: _customEnd,
                      onTap: () => _pickCustomDate(isStart: false),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            _FilterChips(
              label: 'Categorie',
              options: [for (final c in categories) (id: c.id, name: c.name)],
              selected: _categoryIds,
              onToggle: toggleCategory,
            ),
            if (subOptions.isNotEmpty) ...[
              const SizedBox(height: 8),
              _FilterChips(
                label: 'Sottocategorie',
                options: [for (final s in subOptions) (id: s.id, name: s.name)],
                selected: _subcategoryIds,
                onToggle: toggleSubcategory,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickCustomDate({required bool isStart}) async {
    final initial = (isStart ? _customStart : _customEnd) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _customStart = picked;
      } else {
        _customEnd = picked;
      }
    });
  }
}

/// Campo data tappabile (apre il date picker) usato dal periodo personalizzato.
class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap});

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, isDense: true),
        child: Text(
          value != null ? formatDate(value!) : 'gg/mm/aaaa',
          style: TextStyle(
            color: value != null
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

typedef _ChipOption = ({String id, String name});

/// Gruppo di chip a selezione multipla (vuoto = "Tutte").
class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.label,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final String label;
  final List<_ChipOption> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final o in options)
              FilterChip(
                label: Text(o.name),
                selected: selected.contains(o.id),
                onSelected: (_) => onToggle(o.id),
              ),
          ],
        ),
      ],
    );
  }
}

/// Selettore a pill full-width per le due schede (stile coerente con auth).
class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.tabs,
    required this.index,
    required this.onChanged,
  });

  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: i == index ? scheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: i == index ? scheme.onPrimary : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Scheda "Riepilogo": totali del periodo e due ciambelle (uscite ed entrate).
class _SummaryTab extends StatelessWidget {
  const _SummaryTab({
    required this.expenses,
    required this.categories,
    required this.singleCategoryId,
  });

  final List<Expense> expenses;
  final List<ExpenseCategory> categories;
  final String? singleCategoryId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totals = computeTotals(expenses);

    if (totals.isEmpty) {
      return const _EmptyState(
        icon: Icons.pie_chart_outline,
        message: 'Nessun movimento nel periodo o nei filtri selezionati.',
      );
    }

    final balanceColor =
        totals.balance >= 0 ? context.appColors.success : scheme.error;

    final outcomeSlices = breakdownByCategory(
      expenses,
      categories: categories,
      type: ExpenseType.expense,
      categoryId: singleCategoryId,
    );
    final incomeSlices = breakdownByCategory(
      expenses,
      categories: categories,
      type: ExpenseType.income,
      categoryId: singleCategoryId,
    );
    final shaded = singleCategoryId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _TotalTile(label: 'Uscite', amount: totals.outcome, color: scheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TotalTile(
                label: 'Entrate',
                amount: totals.income,
                color: context.appColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TotalTile(label: 'Saldo', amount: totals.balance, color: balanceColor),
            ),
          ],
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            // Mostra solo le torte che hanno dati per la selezione corrente.
            final sections = <Widget>[
              if (outcomeSlices.isNotEmpty)
                _PieSection(title: 'Uscite', slices: outcomeSlices, shaded: shaded),
              if (incomeSlices.isNotEmpty)
                _PieSection(title: 'Entrate', slices: incomeSlices, shaded: shaded),
            ];

            // Schermo largo con entrambe le torte: affiancate (metà schermo
            // ciascuna), legende sotto. Altrimenti impilate.
            if (constraints.maxWidth >= 640 && sections.length == 2) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: sections[0]),
                  const SizedBox(width: 24),
                  Expanded(child: sections[1]),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < sections.length; i++) ...[
                  if (i > 0) const SizedBox(height: 28),
                  sections[i],
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Una ciambella con titolo e legenda (uscite o entrate).
class _PieSection extends StatelessWidget {
  const _PieSection({required this.title, required this.slices, required this.shaded});

  final String title;
  final List<CategorySlice> slices;
  final bool shaded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = slices.fold<double>(0, (sum, s) => sum + s.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SummaryPieChart(slices: slices, total: total, shaded: shaded),
        const SizedBox(height: 16),
        for (var i = 0; i < slices.length; i++)
          _LegendRow(
            slice: slices[i],
            color: summarySliceColor(
              slices[i],
              i,
              slices.length,
              shaded: shaded,
              neutral: scheme.onSurfaceVariant,
            ),
            total: total,
          ),
      ],
    );
  }
}

/// Scheda "Andamento": barre raggruppate con serie selezionabili.
class _TrendTab extends StatelessWidget {
  const _TrendTab({
    required this.expenses,
    required this.period,
    required this.granularity,
    required this.customStart,
    required this.customEnd,
    required this.showOutcome,
    required this.showIncome,
    required this.showBalance,
    required this.onShowOutcomeChanged,
    required this.onShowIncomeChanged,
    required this.onShowBalanceChanged,
  });

  final List<Expense> expenses;
  final SummaryPeriod period;
  final TrendGranularity granularity;
  final DateTime? customStart;
  final DateTime? customEnd;
  final bool showOutcome;
  final bool showIncome;
  final bool showBalance;
  final ValueChanged<bool> onShowOutcomeChanged;
  final ValueChanged<bool> onShowIncomeChanged;
  final ValueChanged<bool> onShowBalanceChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final buckets = bucketByTime(
      expenses,
      period: period,
      granularity: granularity,
      customStart: customStart,
      customEnd: customEnd,
    );
    final hasData = buckets.any((b) => !b.isEmpty);
    final anySeries = showOutcome || showIncome || showBalance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('Uscite'),
              selected: showOutcome,
              onSelected: onShowOutcomeChanged,
            ),
            FilterChip(
              label: const Text('Entrate'),
              selected: showIncome,
              onSelected: onShowIncomeChanged,
            ),
            FilterChip(
              label: const Text('Saldo'),
              selected: showBalance,
              onSelected: onShowBalanceChanged,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (!anySeries)
          const _EmptyState(
            icon: Icons.bar_chart,
            message: 'Seleziona almeno una serie da mostrare.',
          )
        else if (!hasData)
          const _EmptyState(
            icon: Icons.bar_chart,
            message: 'Nessun movimento nel periodo o nei filtri selezionati.',
          )
        else ...[
          SummaryTrendChart(
            buckets: buckets,
            showOutcome: showOutcome,
            showIncome: showIncome,
            showBalance: showBalance,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (showOutcome) _LegendDot(color: scheme.primary, label: 'Uscite'),
              if (showIncome) _LegendDot(color: context.appColors.success, label: 'Entrate'),
              if (showBalance) _LegendDot(color: scheme.secondary, label: 'Saldo'),
            ],
          ),
        ],
      ],
    );
  }
}

/// Numero di riepilogo (uscite/entrate/saldo) in card bordata.
class _TotalTile extends StatelessWidget {
  const _TotalTile({required this.label, required this.amount, required this.color});

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AmountText(amount, fontSize: 18, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Riga di legenda della ciambella: pallino, nome, importo e percentuale.
class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.slice, required this.color, required this.total});

  final CategorySlice slice;
  final Color color;
  final double total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              slice.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${slice.percentOf(total).round()}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(width: 12),
          AmountText(slice.amount, fontSize: 14),
        ],
      ),
    );
  }
}

/// Pallino + etichetta per la legenda del grafico a barre.
class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Stato vuoto curato per periodo/filtri senza dati.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
